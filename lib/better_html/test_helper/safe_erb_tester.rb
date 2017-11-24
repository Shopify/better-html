require 'better_html/test_helper/ruby_expr'
require 'better_html/test_helper/safety_error'
require 'better_html/parser'
require 'parser/current'

module BetterHtml
  module TestHelper
    module SafeErbTester
      SAFETY_TIPS = <<-EOF
-----------

The javascript snippets listed above do not appear to be escaped properly
in a javascript context. Here are some tips:

Never use html_safe inside a html tag, since it is _never_ safe:
  <a href="<%= value.html_safe %>">
                    ^^^^^^^^^^

Always use .to_json for html attributes which contain javascript, like 'onclick',
or twine attributes like 'data-define', 'data-context', 'data-eval', 'data-bind', etc:
  <div onclick="<%= value.to_json %>">
                         ^^^^^^^^

Always use raw and to_json together within <script> tags:
  <script type="text/javascript">
    var yourValue = <%= raw value.to_json %>;
  </script>             ^^^      ^^^^^^^^

-----------
EOF

      def assert_erb_safety(data, **options)
        tester = Tester.new(data, **options)

        message = ""
        tester.errors.each do |error|
          message << <<~EOL
            On line #{error.location.line}
            #{error.message}
            #{error.location.line_source_with_underline}\n
          EOL
        end

        message << SAFETY_TIPS

        assert_predicate tester.errors, :empty?, message
      end

      private

      class Tester
        attr_reader :errors

        VALID_JAVASCRIPT_TAG_TYPES = ['text/javascript', 'text/template', 'text/html']

        def initialize(data, config: BetterHtml.config, **options)
          @data = data
          @config = config
          @errors = Errors.new
          @options = options.present? ? options.dup : {}
          @options[:template_language] ||= :html
          @nodes = BetterHtml::Parser.new(data, @options.slice(:template_language))
          validate!
        end

        def add_error(message, location:)
          @errors.add(SafetyError.new(message, location: location))
        end

        def validate!
          @nodes.each_with_index do |node, index|
            case node
            when BetterHtml::Parser::Element
              validate_element(node)

              if node.name == 'script'
                next_node = @nodes[index + 1]
                if next_node.is_a?(BetterHtml::Parser::ContentNode) && !node.closing?
                  if javascript_tag_type?(node, "text/javascript")
                    validate_script_tag_content(next_node)
                  end
                  validate_no_statements(next_node) unless javascript_tag_type?(node, "text/html")
                end

                validate_javascript_tag_type(node) unless node.closing?
              end
            when BetterHtml::Parser::Text
              validate_text_content(node)

              if @nodes.template_language == :javascript
                validate_script_tag_content(node)
                validate_no_statements(node)
              else
                validate_no_javascript_tag(node)
              end
            when BetterHtml::Parser::CData, BetterHtml::Parser::Comment
              validate_no_statements(node)
            end
          end
        end

        def javascript_tag_type?(element, which)
          typeattr = element['type']
          value = typeattr&.unescaped_value || "text/javascript"
          value == which
        end

        def validate_javascript_tag_type(element)
          typeattr = element['type']
          return if typeattr.nil?
          if !VALID_JAVASCRIPT_TAG_TYPES.include?(typeattr.unescaped_value)
            add_error(
              "#{typeattr.value} is not a valid type, valid types are #{VALID_JAVASCRIPT_TAG_TYPES.join(', ')}",
              location: typeattr.value_parts.first.location
            )
          end
        end

        def validate_element(element)
          element.attributes.each do |attr_token|
            attr_token.value_parts.each do |value_token|
              case value_token.type
              when :expr_literal
                begin
                  expr = RubyExpr.parse(value_token.code)
                  validate_tag_expression(value_token, expr, attr_token.name)
                rescue RubyExpr::ParseError
                  nil
                end
              when :expr_escaped
                add_error(
                  "erb interpolation with '<%==' inside html attribute is never safe",
                  location: value_token.location
                )
              end
            end
          end
        end

        def validate_text_content(text)
          text.content_parts.each do |text_token|
            case text_token.type
            when :stmt, :expr_literal, :expr_escaped
              next if text_token.type == :stmt
              begin
                expr = RubyExpr.parse(text_token.code)
                validate_ruby_helper(text_token, expr)
              rescue RubyExpr::ParseError
                nil
              end
            end
          end
        end

        def validate_ruby_helper(parent_token, expr)
          expr.traverse(only: [:send, :csend]) do |send_node|
            expr.each_child_node(send_node, only: :hash) do |hash_node|
              expr.each_child_node(hash_node, only: :pair) do |pair_node|
                validate_ruby_helper_hash_entry(parent_token, expr, nil, *pair_node.children)
              end
            end
          end
        end

        def validate_ruby_helper_hash_entry(parent_token, expr, key_prefix, key_node, value_node)
          return unless [:sym, :str].include?(key_node.type)
          key = [key_prefix, key_node.children.first.to_s].compact.join('-').dasherize
          case value_node.type
          when :dstr
            validate_ruby_helper_hash_value(parent_token, expr, key, value_node)
          when :hash
            if key == 'data'
              expr.each_child_node(value_node, only: :pair) do |pair_node|
                validate_ruby_helper_hash_entry(parent_token, expr, key, *pair_node.children)
              end
            end
          end
        end

        def validate_ruby_helper_hash_value(parent_token, expr, attr_name, hash_value)
          expr.each_child_node(hash_value, only: :begin) do |child|
            validate_tag_expression(parent_token, RubyExpr.new(child), attr_name)
          end
        end

        def validate_tag_expression(parent_token, expr, attr_name)
          return if expr.static_value?

          if @config.javascript_attribute_name?(attr_name) && expr.calls.empty?
            add_error(
              "erb interpolation in javascript attribute must call '(...).to_json'",
              location: Tokenizer::Location.new(
                @data,
                parent_token.code_location.start + expr.start,
                parent_token.code_location.start + expr.end
              )
            )
            return
          end

          expr.calls.each do |call|
            if call.method == :raw
              add_error(
                "erb interpolation with '<%= raw(...) %>' inside html attribute is never safe",
                location: Tokenizer::Location.new(
                  @data,
                  parent_token.code_location.start + expr.start,
                  parent_token.code_location.start + expr.end - 1
                )
              )
            elsif call.method == :html_safe
              add_error(
                "erb interpolation with '<%= (...).html_safe %>' inside html attribute is never safe",
                location: Tokenizer::Location.new(
                  @data,
                  parent_token.code_location.start + expr.start,
                  parent_token.code_location.start + expr.end - 1
                )
              )
            elsif @config.javascript_attribute_name?(attr_name) && !@config.javascript_safe_method?(call.method)
              add_error(
                "erb interpolation in javascript attribute must call '(...).to_json'",
                location: Tokenizer::Location.new(
                  @data,
                  parent_token.code_location.start + expr.start,
                  parent_token.code_location.start + expr.end - 1
                )
              )
            end
          end
        end

        def validate_script_tag_content(node)
          node.content_parts.each do |token|
            case token.type
            when :expr_literal, :expr_escaped
              expr = RubyExpr.parse(token.code)
              validate_script_expression(node, token, expr)
            end
          end
        end

        def validate_script_expression(node, token, expr)
          if expr.calls.empty?
            add_error(
              "erb interpolation in javascript tag must call '(...).to_json'",
              location: token.location,
            )
            return
          end

          expr.calls.each do |call|
            if call.method == :raw
              call.arguments.each do |argument_node|
                arguments_expr = RubyExpr.new(argument_node)
                validate_script_expression(node, token, arguments_expr)
              end
            elsif call.method == :html_safe
              instance_expr = RubyExpr.new(call.instance)
              validate_script_expression(node, token, instance_expr)
            elsif !@config.javascript_safe_method?(call.method)
              add_error(
                "erb interpolation in javascript tag must call '(...).to_json'",
                location: token.location,
              )
            end
          end
        end

        def validate_no_statements(node)
          node.content_parts.each do |token|
            if token.type == :stmt && !(/\A\s*end/m === token.code)
              add_error(
                "erb statement not allowed here; did you mean '<%=' ?",
                location: token.location,
              )
            end
          end
        end

        def validate_no_javascript_tag(node)
          node.content_parts.each do |token|
            next if token.type == :stmt
            if [:stmt, :expr_literal, :expr_escaped].include?(token.type)
              expr = begin
                RubyExpr.parse(token.code)
              rescue RubyExpr::ParseError
                next
              end
              if expr.calls.size == 1 && expr.calls.first.method == :javascript_tag
                add_error(
                  "'javascript_tag do' syntax is deprecated; use inline <script> instead",
                  location: token.location,
                )
              end
            end
          end
        end
      end
    end
  end
end
