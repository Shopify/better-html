require 'erubis/engine/eruby'
require 'html_tokenizer'
require_relative 'token'
require_relative 'location'

module BetterHtml
  class NodeIterator
    class HtmlErb < ::Erubis::Eruby
      attr_reader :tokens
      attr_reader :parser

      def initialize(document)
        @parser = HtmlTokenizer::Parser.new
        @tokens = []
        super
      end

      def add_text(src, text)
        @parser.parse(text) { |*args| add_tokens(*args) }
      end

      def add_stmt(src, code)
        text = "<%#{code}%>"
        start = @parser.document_length
        stop = start + text.size
        @tokens << Token.new(
          type: :stmt,
          code: code,
          text: text,
          location: Location.new(start, stop, @parser.line_number, @parser.column_number)
        )
        @parser.append_placeholder(text)
      end

      def add_expr_literal(src, code)
        text = "<%=#{code}%>"
        start = @parser.document_length
        stop = start + text.size
        @tokens << Token.new(
          type: :expr_literal,
          code: code,
          text: text,
          location: Location.new(start, stop, @parser.line_number, @parser.column_number)
        )
        @parser.append_placeholder(text)
      end

      def add_expr_escaped(src, code)
        text = "<%==#{code}%>"
        start = @parser.document_length
        stop = start + text.size
        @tokens << Token.new(
          type: :expr_escaped,
          code: code,
          text: text,
          location: Location.new(start, stop, @parser.line_number, @parser.column_number)
        )
        @parser.append_placeholder(text)
      end

      private

      def add_tokens(type, start, stop, line, column)
        extra_attributes = if type == :tag_end
          {
            self_closing: @parser.self_closing_tag?
          }
        end
        @tokens << Token.new(
          type: type,
          text: @parser.extract(start, stop),
          location: Location.new(start, stop, line, column),
          **(extra_attributes || {})
        )
      end
    end
  end
end
