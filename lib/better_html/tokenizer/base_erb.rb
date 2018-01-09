require 'erubi'
require_relative 'token'
require_relative 'location'

module BetterHtml
  module Tokenizer
    class BaseErb < ::Erubi::Engine
      REGEXP_WITHOUT_TRIM = /<%(={1,2}|%)?(.*?)()?%>([ \t]*\r?\n)?/m
      STMT_TRIM_MATCHER = /\A(-|#)?(.*?)(-)?\z/m
      EXPR_TRIM_MATCHER = /\A(.*?)(-)?\z/m

      attr_reader :tokens
      attr_reader :current_position

      def initialize(document)
        @document = document
        @tokens = []
        @current_position = 0
        super(document, regexp: REGEXP_WITHOUT_TRIM, trim: false)
      end

      private

      def append(text)
        @current_position += text.length
      end

      def add_code(code)
        _, ltrim_or_comment, code, rtrim = *STMT_TRIM_MATCHER.match(code)
        ltrim = ltrim_or_comment if ltrim_or_comment == '-'
        indicator = ltrim_or_comment if ltrim_or_comment == '#'
        add_erb_tokens(ltrim, indicator, code, rtrim)
        append("<%#{ltrim}#{indicator}#{code}#{rtrim}%>")
      end

      def add_expression(indicator, code)
        _, code, rtrim = *EXPR_TRIM_MATCHER.match(code)
        add_erb_tokens(nil, indicator, code, rtrim)
        append("<%#{indicator}#{code}#{rtrim}%>")
      end

      def add_erb_tokens(ltrim, indicator, code, rtrim)
        pos = current_position

        token = add_token(:erb_begin, pos, pos + 2)
        pos += 2

        if ltrim
          token = add_token(:trim, pos, pos + ltrim.length)
          pos += ltrim.length
        end

        if indicator
          token = add_token(:indicator, pos, pos + indicator.length)
          pos += indicator.length
        end

        token = add_token(:code, pos, pos + code.length)
        pos += code.length

        if rtrim
          token = add_token(:trim, pos, pos + rtrim.length)
          pos += rtrim.length
        end

        token = add_token(:erb_end, pos, pos + 2)
      end

      def add_token(type, start, stop)
        token = Token.new(
          type: type,
          loc: Location.new(@document, start, stop - 1)
        )
        @tokens << token
        token
      end
    end
  end
end
