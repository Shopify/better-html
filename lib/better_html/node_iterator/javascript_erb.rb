require 'erubi'
require_relative 'token'
require_relative 'location'

module BetterHtml
  class NodeIterator
    class JavascriptErb < ::Erubi::Engine
      attr_reader :tokens

      def initialize(source)
        @source = source
        @parsed_document = ""
        @tokens = []
        super(source, regexp: HtmlErb::REGEXP_WITHOUT_TRIM, trim: false)
      end

      def add_text(text)
        add_token(:text, text) if text.present?
        append(text)
      end

      def add_code(code)
        text = "<%#{code}%>"
        add_token(:stmt, text, code)
        append(text)
      end

      def add_expression(indicator, code)
        text = "<%#{indicator}#{code}%>"
        add_token(indicator == '=' ? :expr_literal : :expr_escaped, text, code)
        append(text)
      end

      private

      def add_token(type, text, code = nil)
        raise ArgumentError, "empty #{type} token" if text.size == 0
        start = @parsed_document.size
        stop = start + text.size - 1
        @tokens << Token.new(
          type: type,
          text: text,
          code: code,
          location: Location.new(@source, start, stop)
        )
      end

      def append(text)
        @parsed_document << text
      end
    end
  end
end
