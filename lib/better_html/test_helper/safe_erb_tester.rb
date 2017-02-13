require 'better_html/test_helper/ruby_expr'

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
        tester.errors.each do |e|
          message << format_erb_safety_error(data, e)
        end

        message << SAFETY_TIPS

        assert_predicate tester.errors, :empty?, message
      end

      private

      def format_erb_safety_error(data, error)
        loc = error.token.location
        s = "On line #{loc.line}\n"
        s << "#{error.message}\n"
        line = extract_line(data, loc.line)
        s << "#{line}\n"
        length = [loc.stop - loc.start, line.length - loc.column].min
        s << "#{' ' * loc.column}#{'^' * length}\n\n"
        s
      end

      def extract_line(data, line)
        line = data.lines[line-1]
        line.nil? ? "" : line.gsub(/\n$/, '')
      end

      class SafetyError < InterpolatorError
        attr_reader :node, :token

        def initialize(node, token, message)
          @node = node
          @token = token
          super(message)
        end
      end

      class Tester
        attr_reader :errors

        VALID_JAVASCRIPT_TAG_TYPES = ['text/javascript', 'text/template', 'text/html']

        def initialize(data, **options)
          @data = data
          @errors = []
          @options = options.present? ? options.dup : {}
          @options[:template_language] ||= :html
          @tree = BetterHtml::Tree.new(data, @options.slice(:template_language))
          validate!
        end

        def add_error(node, token, message)
          @errors << SafetyError.new(node, token, message)
        end

        def validate!
          @tree.nodes.each_with_index do |node, index|
            case node
            when BetterHtml::Tree::Tag
              validate_tag(node)

              if node.name_text == 'script'
                next_node = @tree.nodes[index + 1]
                if next_node.is_a?(BetterHtml::Tree::ContentNode) && !node.closing?
                  if javascript_tag_type?(node, "text/javascript")
                    validate_script_tag_content(next_node)
                  end
                  validate_no_statements(next_node) unless javascript_tag_type?(node, "text/html")
                end

                validate_javascript_tag_type(node) unless node.closing?
              end
            when BetterHtml::Tree::Text
              if @tree.template_language == :javascript
                validate_script_tag_content(node)
                validate_no_statements(node)
              else
                validate_no_javascript_tag(node)
              end
            when BetterHtml::Tree::CData, BetterHtml::Tree::Comment
              validate_no_statements(node)
            end
          end
        end

        def javascript_tag_type?(node, which)
          typeattr = node.find_attr('type')
          value = typeattr&.value_text_without_quotes || "text/javascript"
          value == which
        end

        def validate_javascript_tag_type(node)
          typeattr = node.find_attr('type')
          return if typeattr.nil?
          if !VALID_JAVASCRIPT_TAG_TYPES.include?(typeattr.value_text_without_quotes)
            add_error(node, typeattr.value.first, "#{typeattr.value_text} is not a valid type, valid types are #{VALID_JAVASCRIPT_TAG_TYPES.join(', ')}")
          end
        end

        def validate_tag(node)
          node.attributes.each do |attr_token|
            attr_name = attr_token.name_text
            attr_token.value.each do |value_token|
              case value_token.type
              when :expr_literal
                validate_tag_expression(node, attr_name, value_token)
              when :expr_escaped
                add_error(node, value_token, "erb interpolation with '<%==' inside html attribute is never safe")
              end
            end
          end
        end

        def validate_tag_expression(node, attr_name, value_token)
          expr = RubyExpr.new(code: value_token.code)

          if javascript_attribute_name?(attr_name) && expr.calls.empty?
            add_error(node, value_token, "erb interpolation in javascript attribute must call '(...).to_json'")
            return
          end

          expr.calls.each do |call|
            if call.method == 'raw'
              add_error(node, value_token, "erb interpolation with '<%= raw(...) %>' inside html attribute is never safe")
            elsif call.method == 'html_safe'
              add_error(node, value_token, "erb interpolation with '<%= (...).html_safe %>' inside html attribute is never safe")
            elsif javascript_attribute_name?(attr_name) && !javascript_safe_method?(call.method)
              add_error(node, value_token, "erb interpolation in javascript attribute must call '(...).to_json'")
            end
          end
        end

        def javascript_attribute_name?(name)
          BetterHtml.config.javascript_attribute_names.any?{ |other| other === name }
        end

        def javascript_safe_method?(name)
          BetterHtml.config.javascript_safe_methods.include?(name)
        end

        def validate_script_tag_content(node)
          node.content.each do |token|
            case token.type
            when :expr_literal, :expr_escaped
              expr = RubyExpr.new(code: token.code)
              if expr.calls.empty?
                add_error(node, token, "erb interpolation in javascript tag must call '(...).to_json'")
              else
                validate_script_expression(node, token, expr)
              end
            end
          end
        end

        def validate_script_expression(node, token, expr)
          expr.calls.each do |call|
            if call.method == 'raw'
              arguments_expr = RubyExpr.new(tree: call.arguments)
              validate_script_expression(node, token, arguments_expr)
            elsif call.method == 'html_safe'
              instance_expr = RubyExpr.new(tree: call.instance)
              validate_script_expression(node, token, instance_expr)
            elsif !javascript_safe_method?(call.method)
              add_error(node, token, "erb interpolation in javascript tag must call '(...).to_json'")
            end
          end
        end

        def validate_no_statements(node)
          node.content.each do |token|
            if token.type == :stmt && !(/\A\s*end/m === token.code)
              add_error(node, token, "erb statement not allowed here; did you mean '<%=' ?")
            end
          end
        end

        def validate_no_javascript_tag(node)
          node.content.each do |token|
            if [:stmt, :expr_literal, :expr_escaped].include?(token.type)
              expr = begin
                RubyExpr.new(code: token.code)
              rescue RubyExpr::ParseError
                next
              end
              if expr.calls.size == 1 && expr.calls.first.method == 'javascript_tag'
                add_error(node, token, "'javascript_tag do' syntax is deprecated; use inline <script> instead")
              end
            end
          end
        end
      end
    end
  end
end
