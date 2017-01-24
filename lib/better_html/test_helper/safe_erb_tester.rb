require 'better_html/test_helper/ruby_expr'

module BetterHtml
  module TestHelper
    class SafeErbTester
      attr_reader :errors

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

            tag_name = node.name.map(&:text).join

            if tag_name == 'script'
              if javascript_tag_type?(node) && !node.closing?
                validate_script_tag(@tree.nodes[index + 1])
              end
              validate_no_statements(@tree.nodes[index + 1])
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
        return true if typeattr.nil?
        typeattr_value = typeattr.value.map(&:text).join

        '"text/javascript"' == typeattr_value
      end

      JAVASCRIPT_TAG_NAME = /\A(define\z|context\z|eval\z|track\-click\z|data\-track\-|bind(\-|\z)|on|data\-define\z|data\-context\z|data\-eval\z|data\-bind(\-|\z))/mi

      def validate_tag(node)
        node.attributes.each do |attr_token|
          attr_name = attr_token.name.map(&:text).join
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

        expr.calls.each do |call|
          if call.method == 'raw'
            add_error(node, value_token, "erb interpolation with '<%= raw(...) %>' inside html attribute is never safe")
          elsif call.method == 'html_safe'
            add_error(node, value_token, "erb interpolation with '<%= (...).html_safe %>' inside html attribute is never safe")
          elsif JAVASCRIPT_TAG_NAME === attr_name && !BetterHtml.config.javascript_safe_methods.include?(call.method)
            add_error(node, value_token, "erb interpolation in javascript attribute must call '(...).to_json'")
          end
        end
      end

      def validate_script_tag(node)
        node.content.each do |token|
          case token.type
          when :expr_literal, :expr_escaped
            expr = RubyExpr.new(code: token.code)
            validate_script_expression(node, token, expr)
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
          elsif !BetterHtml.config.javascript_safe_methods.include?(call.method)
            add_error(node, token, "erb interpolation in javascript tag must call '(...).to_json'")
          end
        end
      end

      def validate_no_statements(node)
        node.content.each do |token|
          if token.type == :stmt
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
