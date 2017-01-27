require 'better_html/test_helper/ruby_expr'

module BetterHtml
  module TestHelper
    class SafeErbTester
      attr_reader :errors

      VALID_JAVASCRIPT_TAG_TYPES = ['"text/javascript"', '"text/template"', '"text/html"']

      class Error < InterpolatorError
        attr_reader :node, :token

        def initialize(node, token, message)
          @node = node
          @token = token
          super(message)
        end
      end

      def initialize(data, options={})
        @data = data
        @errors = []
        @tree = BetterHtml::Tree.new(data)
        validate!
      end

      private

      def add_error(node, token, message)
        @errors << Error.new(node, token, message)
      end

      def validate!
        @tree.nodes.each_with_index do |node, index|
          case node
          when BetterHtml::Tree::Tag
            validate_tag(node)

            if node.name_text == 'script'
              next_node = @tree.nodes[index + 1]
              if next_node.is_a?(BetterHtml::Tree::ContentNode) && !node.closing?
                if javascript_tag_type?(node)
                  validate_script_tag_content(next_node)
                end
                validate_no_statements(next_node)
              end

              validate_javascript_tag_type(node) unless node.closing?
            end
          when BetterHtml::Tree::Text
            validate_no_javascript_tag(node)
          when BetterHtml::Tree::CData, BetterHtml::Tree::Comment
            validate_no_statements(node)
          end
        end
      end

      def javascript_tag_type?(node)
        typeattr = node.find_attr('type')
        typeattr.nil? || typeattr.value_text == '"text/javascript"'
      end

      def validate_javascript_tag_type(node)
        typeattr = node.find_attr('type')
        if typeattr.nil?
          add_error(node, node.name.first, "midding type attribute for script tag, choose one of #{VALID_JAVASCRIPT_TAG_TYPES.join(', ')}")
        elsif !VALID_JAVASCRIPT_TAG_TYPES.include?(typeattr.value_text)
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
