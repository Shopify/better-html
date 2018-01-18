require_relative 'base'
require 'better_html/test_helper/ruby_expr'

module BetterHtml
  module TestHelper
    module SafeErb
      class ScriptInterpolation < Base
        def validate
          script_tags.each do |tag, content_node|
            if content_node.present? && (tag.attributes['type']&.value || "text/javascript") == "text/javascript"
              validate_script(content_node)
            end
          end

          if @parser.template_language == :javascript
            @parser.nodes_with_type(:text).each do |node|
              validate_script(node)
            end
          end
        end

        private

        def validate_script(node)
          erb_nodes(node).each do |erb_node, indicator_node, code_node|
            next unless indicator_node.present?
            indicator = indicator_node.loc.source
            next if indicator == '#'
            source = code_node.loc.source

            begin
              expr = RubyExpr.parse(source)
              validate_script_interpolation(erb_node, expr)
            rescue RubyExpr::ParseError
            end
          end
        end

        def validate_script_interpolation(parent_node, expr)
          if expr.calls.empty?
            add_error(
              "erb interpolation in javascript tag must call '(...).to_json'",
              location: parent_node.loc,
            )
            return
          end

          expr.calls.each do |call|
            if call.method == :raw
              call.arguments.each do |argument_node|
                arguments_expr = RubyExpr.new(argument_node)
                validate_script_interpolation(parent_node, arguments_expr)
              end
            elsif call.method == :html_safe
              instance_expr = RubyExpr.new(call.instance)
              validate_script_interpolation(parent_node, instance_expr)
            elsif !@config.javascript_safe_method?(call.method)
              add_error(
                "erb interpolation in javascript tag must call '(...).to_json'",
                location: parent_node.loc,
              )
            end
          end
        end
      end
    end
  end
end
