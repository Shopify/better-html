require_relative 'base'
require 'better_html/test_helper/ruby_expr'

module BetterHtml
  module TestHelper
    module SafeErb
      class TagInterpolation < Base
        def validate
          @parser.nodes_with_type(:tag).each do |tag_node|
            tag = Tree::Tag.from_node(tag_node)
            tag.attributes.each do |attribute|
              validate_attribute(attribute)
            end
          end

          @parser.nodes_with_type(:text).each do |node|
            validate_text_node(node)
          end
        end

        private

        def validate_attribute(attribute)
          erb_nodes(attribute.value_node).each do |erb_node, indicator_node, code_node|
            next if indicator_node.nil?

            indicator = indicator_node.loc.source
            source = code_node.loc.source

            if indicator == '='
              begin
                expr = RubyExpr.parse(source)
                validate_tag_interpolation(code_node, expr, attribute.name)
              rescue RubyExpr::ParseError
                nil
              end
            elsif indicator == '=='
              add_error(
                "erb interpolation with '<%==' inside html attribute is never safe",
                location: erb_node.loc
              )
            end
          end
        end

        def validate_text_node(text_node)
          erb_nodes(text_node).each do |erb_node, indicator_node, code_node|
            indicator = indicator_node&.loc&.source
            next if indicator == '#'
            source = code_node.loc.source

            begin
              expr = RubyExpr.parse(source)
              validate_ruby_helper(code_node, expr)
            rescue RubyExpr::ParseError
              nil
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
            validate_tag_interpolation(parent_token, RubyExpr.new(child), attr_name)
          end
        end

        def validate_tag_interpolation(parent_token, expr, attr_name)
          return if expr.static_value?

          if @config.javascript_attribute_name?(attr_name) && expr.calls.empty?
            add_error(
              "erb interpolation in javascript attribute must call '(...).to_json'",
              location: Tokenizer::Location.new(
                parent_token.loc.document,
                parent_token.loc.start + expr.start,
                parent_token.loc.start + expr.end - 1
              )
            )
            return
          end

          expr.calls.each do |call|
            if call.method == :raw
              add_error(
                "erb interpolation with '<%= raw(...) %>' inside html attribute is never safe",
                location: Tokenizer::Location.new(
                  parent_token.loc.document,
                  parent_token.loc.start + expr.start,
                  parent_token.loc.start + expr.end - 1
                )
              )
            elsif call.method == :html_safe
              add_error(
                "erb interpolation with '<%= (...).html_safe %>' inside html attribute is never safe",
                location: Tokenizer::Location.new(
                  parent_token.loc.document,
                  parent_token.loc.start + expr.start,
                  parent_token.loc.start + expr.end - 1
                )
              )
            elsif @config.javascript_attribute_name?(attr_name) && !@config.javascript_safe_method?(call.method)
              add_error(
                "erb interpolation in javascript attribute must call '(...).to_json'",
                location: Tokenizer::Location.new(
                  parent_token.loc.document,
                  parent_token.loc.start + expr.start,
                  parent_token.loc.start + expr.end - 1
                )
              )
            end
          end
        end
      end
    end
  end
end
