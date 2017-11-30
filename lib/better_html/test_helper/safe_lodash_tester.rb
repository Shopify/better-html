require 'better_html/test_helper/safety_error'
require 'better_html/parser'

module BetterHtml
  module TestHelper
    module SafeLodashTester
      SAFETY_TIPS = <<-EOF
-----------

The javascript snippets listed above do not appear to be escaped properly
in their context. Here are some tips:

Always use lodash's escape syntax inside a html tag:
  <a href="[%= value %]">
           ^^^^

Always use JSON.stringify() for html attributes which contain javascript, like 'onclick',
or twine attributes like 'data-define', 'data-context', 'data-eval', 'data-bind', etc:
  <div onclick="[%= JSON.stringify(value) %]">
                    ^^^^^^^^^^^^^^

Never use <script> tags inside lodash template.
  <script type="text/javascript">
  ^^^^^^^

-----------
EOF

      def assert_lodash_safety(data, **options)
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

        def initialize(data, config: BetterHtml.config)
          @data = data
          @config = config
          @errors = Errors.new
          @parser = BetterHtml::Parser.new(data, template_language: :lodash)
          validate!
        end

        def add_error(message, location:)
          @errors.add(SafetyError.new(message, location: location))
        end

        def validate!
          @parser.nodes_with_type(:element).each do |tag_node|
            tag = Tree::Tag.new(tag_node)
            validate_tag(tag)

            if tag.name == 'script' && !tag.closing?
              add_error(
                "No script tags allowed nested in lodash templates",
                location: tag.loc
              )
            end
          end

          @parser.nodes_with_type(:cdata, :comment).each do |node|
            validate_no_statements(node)
          end
        end

        def lodash_nodes(array)
          Enumerator.new do |yielder|
            array.each do |token|
              yielder << token if [:expr_literal, :expr_escaped, :stmt].include?(token.type)
            end
          end
        end

        def validate_tag(tag)
          tag.attributes.each do |attribute|
            lodash_nodes(attribute.node.name_parts).each do |token|
              add_no_statement_error(token.location) if token.type == :stmt
            end

            lodash_nodes(attribute.node.value_parts).each do |lodash_node|
              case lodash_node.type
              when :stmt
                add_no_statement_error(lodash_node.location)
              when :expr_literal
                validate_tag_expression(attribute, lodash_node)
              when :expr_escaped
                add_error(
                  "lodash interpolation with '[%!' inside html attribute is never safe",
                  location: lodash_node.location
                )
              end
            end
          end
        end

        def validate_tag_expression(attribute, lodash_node)
          source = lodash_node.code.strip
          if @config.javascript_attribute_name?(attribute.name) && !@config.lodash_safe_javascript_expression?(source)
            add_error(
              "lodash interpolation in javascript attribute "\
              "`#{attribute.name}` must call `JSON.stringify(#{source})`",
              location: lodash_node.location
            )
          end
        end

        def validate_no_statements(node)
          lodash_nodes(node.content_parts).each do |token|
            add_no_statement_error(token.location) if token.type == :stmt
          end
        end

        def add_no_statement_error(loc)
          add_error(
            "javascript statement not allowed here; did you mean '[%=' ?",
            location: loc
          )
        end
      end
    end
  end
end
