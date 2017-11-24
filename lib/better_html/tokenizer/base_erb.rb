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
        type = case indicator
        when nil
          :stmt
        when '#'
          :comment
        when '='
          :expr_literal
        when '=='
          :expr_escaped
        else
          raise ArgumentError
        end

        start = current_position
        code_start = start + 2 + (ltrim&.length || 0) + (indicator&.length || 0)
        code_stop = code_start + code.length
        stop = code_stop + (rtrim&.length || 0) + 2

        add_token(
          type, start, stop, nil, nil,
          code_location: Location.new(@document, code_start, code_stop - 1)
        )
      end

      def add_token(type, start, stop, line = nil, column = nil, **extra_attributes)
        token = Token.new(
          type: type,
          location: Location.new(@document, start, stop - 1, line, column),
          **extra_attributes
        )
        @tokens << token
        token
      end
    end
  end
end
