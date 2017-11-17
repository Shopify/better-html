require_relative 'base'
require 'better_html/test_helper/ruby_expr'

module BetterHtml
  module TestHelper
    module SafeErb
      class NoJavascriptTagHelper < Base
        def validate
          no_javascript_tag_helper(ast)
        end

        private

        def no_javascript_tag_helper(node)
          erb_nodes(node).each do |erb_node, indicator_node, code_node|
            indicator = indicator_node&.loc&.source
            next if indicator == '#'
            source = code_node.loc.source

            begin
              expr = RubyExpr.parse(source)

              if expr.calls.size == 1 && expr.calls.first.method == :javascript_tag
                add_error(
                  "'javascript_tag do' syntax is deprecated; use inline <script> instead",
                  location: erb_node.loc,
                )
              end
            rescue RubyExpr::ParseError
            end
          end
        end
      end
    end
  end
end
