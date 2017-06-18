require_relative 'node_iterator/javascript_erb'
require_relative 'node_iterator/html_erb'
require_relative 'node_iterator/html_lodash'
require_relative 'node_iterator/cdata'
require_relative 'node_iterator/comment'
require_relative 'node_iterator/element'
require_relative 'node_iterator/attribute'
require_relative 'node_iterator/text'

module BetterHtml
  class NodeIterator
    attr_reader :nodes, :template_language

    delegate :each, :each_with_index, :[], to: :nodes
    delegate :parser, to: :@erb, allow_nil: true
    delegate :errors, to: :parser, allow_nil: true, prefix: true

    def initialize(document, template_language: :html)
      @document = document
      @template_language = template_language
      @erb = case template_language
      when :html
        HtmlErb.new(@document)
      when :lodash
        HtmlLodash.new(@document)
      when :javascript
        JavascriptErb.new(@document)
      else
        raise ArgumentError, "template_language can be :html or :javascript"
      end
      @nodes = parse!
    end

    private

    def parse!
      nodes = []
      tokens = @erb.tokens.dup
      while token = tokens[0]
        case token.type
        when :cdata_start
          tokens.shift
          nodes << consume_cdata(tokens)
        when :comment_start
          tokens.shift
          nodes << consume_comment(tokens)
        when :tag_start
          tokens.shift
          nodes << consume_element(tokens)
        when :text, :stmt, :expr_literal, :expr_escaped
          nodes << consume_text(tokens)
        else
          raise RuntimeError, "Unhandled token #{token.type} line #{token.location.line} column #{token.location.column}"
        end
      end
      nodes
    end

    def consume_cdata(tokens)
      node = CData.new
      while tokens.any? && tokens[0].type != :cdata_end
        node.content_parts << tokens.shift
      end
      tokens.shift if tokens.any? && tokens[0].type == :cdata_end
      node
    end

    def consume_comment(tokens)
      node = Comment.new
      while tokens.any? && tokens[0].type != :comment_end
        node.content_parts << tokens.shift
      end
      tokens.shift if tokens.any? && tokens[0].type == :comment_end
      node
    end

    def consume_element(tokens)
      node = Element.new
      if tokens.any? && tokens[0].type == :solidus
        tokens.shift
        node.closing = true
      end
      while tokens.any? && [:tag_name, :stmt, :expr_literal, :expr_escaped].include?(tokens[0].type)
        node.name_parts << tokens.shift
      end
      while tokens.any?
        token = tokens[0]
        if token.type == :attribute_name
          node.attributes << consume_attribute(tokens)
        elsif token.type == :attribute_quoted_value_start
          node.attributes << consume_attribute_value(tokens)
        elsif token.type == :tag_end
          tokens.shift
          node.self_closing = token.self_closing
          break
        else
          tokens.shift
        end
      end
      node
    end

    def consume_attribute(tokens)
      node = Attribute.new
      while tokens.any? && [:attribute_name, :stmt, :expr_literal, :expr_escaped].include?(tokens[0].type)
        node.name_parts << tokens.shift
      end
      return node unless consume_equal?(tokens)
      while tokens.any? && [
          :attribute_quoted_value_start, :attribute_quoted_value,
          :attribute_quoted_value_end, :attribute_unquoted_value,
          :stmt, :expr_literal, :expr_escaped].include?(tokens[0].type)
        node.value_parts << tokens.shift
      end
      node
    end

    def consume_attribute_value(tokens)
      node = Attribute.new
      while tokens.any? && [
          :attribute_quoted_value_start, :attribute_quoted_value,
          :attribute_quoted_value_end, :attribute_unquoted_value,
          :stmt, :expr_literal, :expr_escaped].include?(tokens[0].type)
        node.value_parts << tokens.shift
      end
      node
    end

    def consume_equal?(tokens)
      while tokens.any? && [:whitespace, :equal].include?(tokens[0].type)
        return true if tokens.shift.type == :equal
      end
      false
    end

    def consume_text(tokens)
      node = Text.new
      while tokens.any? && [:text, :stmt, :expr_literal, :expr_escaped].include?(tokens[0].type)
        node.content_parts << tokens.shift
      end
      node
    end
  end
end
