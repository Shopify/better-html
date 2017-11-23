require 'html_tokenizer'
require_relative 'base_erb'

module BetterHtml
  module Tokenizer
    class HtmlErb < BaseErb
      attr_reader :parser

      REGEXP_WITHOUT_TRIM = /<%(={1,2}|-|%)?(.*?)(?:[-=])?()?%>([ \t]*\r?\n)?/m

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
        @parser.parse(text) do |type, start, stop, line, column|
          extra_attributes = if type == :tag_end
            {
              self_closing: @parser.self_closing_tag?
            }
          end
          add_token(type, start, stop, nil, nil, **(extra_attributes || {}))
        end
      end
    end
  end
end
