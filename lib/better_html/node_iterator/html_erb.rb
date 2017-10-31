require 'erubi'
require 'html_tokenizer'
require_relative 'token'
require_relative 'location'

module BetterHtml
  class NodeIterator
    class HtmlErb < ::Erubi::Engine
      attr_reader :tokens
      attr_reader :parser

      REGEXP_WITHOUT_TRIM = /<%(={1,2}|-|%)?(.*?)(?:[-=])?()?%>([ \t]*\r?\n)?/m

      def initialize(document)
        @parser = HtmlTokenizer::Parser.new
        @tokens = []
        super(document, regexp: REGEXP_WITHOUT_TRIM, trim: false)
      end

      def add_text(text)
        @parser.parse(text) { |*args| add_tokens(*args) }
      end

      def add_code(code)
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

      def add_expression(indicator, code)
        text = "<%#{indicator}#{code}%>"
        start = @parser.document_length
        stop = start + text.size
        @tokens << Token.new(
          type: indicator == '=' ? :expr_literal : :expr_escaped,
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
