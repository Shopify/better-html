require 'erubis/engine/eruby'
require_relative 'token'
require_relative 'location'

module BetterHtml
  class NodeIterator
    class JavascriptErb < ::Erubis::Eruby
      attr_reader :tokens

      def initialize(document)
        @document = ""
        @tokens = []
        super
      end

      def add_text(src, text)
        add_token(:text, text)
        append(text)
      end

      def add_stmt(src, code)
        text = "<%#{code}%>"
        add_token(:stmt, text, code)
        append(text)
      end

      def add_expr_literal(src, code)
        text = "<%=#{code}%>"
        add_token(:expr_literal, text, code)
        append(text)
      end

      def add_expr_escaped(src, code)
        text = "<%==#{code}%>"
        add_token(:expr_escaped, text, code)
        append(text)
      end

      private

      def add_token(type, text, code = nil)
        start = @document.size
        stop = start + text.size
        lines = @document.split("\n", -1)
        line = lines.empty? ? 1 : lines.size
        column = lines.empty? ? 0 : lines.last.size
        @tokens << Token.new(
          type: type,
          text: text,
          code: code,
          location: Location.new(start, stop, line, column)
        )
      end

      def append(text)
        @document << text
      end
    end
  end
end
