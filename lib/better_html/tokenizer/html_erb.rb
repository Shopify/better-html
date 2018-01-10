require 'html_tokenizer'
require_relative 'base_erb'

module BetterHtml
  module Tokenizer
    class HtmlErb < BaseErb
      attr_reader :parser

      def initialize(document)
        @parser = HtmlTokenizer::Parser.new
        super(document)
      end

      def current_position
        @parser.document_length
      end

      private

      def append(text)
        @parser.append_placeholder(text)
      end

      def add_text(text)
        @parser.parse(text) do |type, start, stop, _line, _column|
          add_token(type, start, stop)
        end
      end
    end
  end
end
