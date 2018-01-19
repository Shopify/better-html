require_relative 'base'
require 'better_html/test_helper/ruby_node'

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
              ruby_node = RubyNode.parse(source)
              validate_tag_interpolation(code_node, ruby_node, attribute.name) if ruby_node
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

            ruby_node = RubyNode.parse(source)
            validate_ruby_helper(code_node, ruby_node) if ruby_node
          end
        end

        def validate_ruby_helper(parent_token, ruby_node)
          ruby_node.descendants(:send, :csend).each do |send_node|
            send_node.child_nodes.select(&:hash?).each do |hash_node|
              hash_node.child_nodes.select(&:pair?).each do |pair_node|
                validate_ruby_helper_hash_entry(parent_token, ruby_node, nil, *pair_node.children)
              end
            end
          end
        end

        def validate_ruby_helper_hash_entry(parent_token, ruby_node, key_prefix, key_node, value_node)
          return unless [:sym, :str].include?(key_node.type)
          key = [key_prefix, key_node.children.first.to_s].compact.join('-').dasherize
          case value_node.type
          when :dstr
            validate_ruby_helper_hash_value(parent_token, ruby_node, key, value_node)
          when :hash
            if key == 'data'
              value_node.child_nodes.select(&:pair?).each do |pair_node|
                validate_ruby_helper_hash_entry(parent_token, ruby_node, key, *pair_node.children)
              end
            end
          end
        end

        def validate_ruby_helper_hash_value(parent_token, ruby_node, attr_name, hash_value)
          hash_value.child_nodes.select(&:begin?).each do |begin_node|
            validate_tag_interpolation(parent_token, begin_node, attr_name)
          end
        end

        def validate_tag_interpolation(parent_token, ruby_node, attr_name)
          return if ruby_node.static_return_value?

          location = Tokenizer::Location.new(
            parent_token.loc.document,
            parent_token.loc.start + ruby_node.loc.expression.begin_pos,
            parent_token.loc.start + ruby_node.loc.expression.end_pos - 1
          )

          method_calls = ruby_node.return_values.select(&:method_call?)
          if @config.javascript_attribute_name?(attr_name) && method_calls.empty?
            add_error(
              "erb interpolation in javascript attribute must call '(...).to_json'",
              location: location
            )
            return
          end

          method_calls.each do |call|
            if call.method_name?(:raw)
              add_error(
                "erb interpolation with '<%= raw(...) %>' inside html attribute is never safe",
                location: location
              )
            elsif call.method_name?(:html_safe)
              add_error(
                "erb interpolation with '<%= (...).html_safe %>' inside html attribute is never safe",
                location: location
              )
            elsif @config.javascript_attribute_name?(attr_name) && !@config.javascript_safe_method?(call.method_name)
              add_error(
                "erb interpolation in javascript attribute must call '(...).to_json'",
                location: location
              )
            end
          end
        end
      end
    end
  end
end
