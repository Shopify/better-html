require_relative 'token'
require_relative 'location'

module BetterHtml
  module Tokenizer
    class HtmlLodash
      attr_reader :tokens
      attr_reader :parser

      cattr_accessor :lodash_escape, :lodash_evaluate, :lodash_interpolate
      self.lodash_escape = %r{(?:\[\%)=(.+?)(?:\%\])}m
      self.lodash_evaluate = %r{(?:\[\%)(.+?)(?:\%\])}m
      self.lodash_interpolate = %r{(?:\[\%)!(.+?)(?:\%\])}m

      def initialize(document)
        @document = document
        @scanner = StringScanner.new(document)
        @parser = HtmlTokenizer::Parser.new
        @tokens = []
        scan!
      end

      private

      def scan!
        while @scanner.rest?
          scanned = @scanner.scan_until(scan_pattern)
          if scanned.present?
            captures = scan_pattern.match(scanned).captures
            if pre_match = captures[0]
              add_text(pre_match) if pre_match.present?
            end
            match = captures[1]
            if code = lodash_escape.match(match)
              add_lodash_tokens("=", code.captures[0])
            elsif code = lodash_interpolate.match(match)
              add_lodash_tokens("!", code.captures[0])
            elsif code = lodash_evaluate.match(match)
              add_lodash_tokens(nil, code.captures[0])
            else
              raise RuntimeError, 'unexpected match'
            end
            @parser.append_placeholder(match)
          else
            text = @document[(@scanner.pos)..(@document.size)]
            add_text(text) unless text.blank?
            break
          end
        end
      end

      def scan_pattern
        @scan_pattern ||= begin
          patterns = [
            lodash_escape,
            lodash_interpolate,
            lodash_evaluate
          ].map(&:source).join("|")
          Regexp.new("(?<pre_patch>.*?)(?<match>" + patterns + ")", Regexp::MULTILINE)
        end
      end

      def add_text(text)
        @parser.parse(text) do |type, start, stop, line, column|
          extra_attributes = if type == :tag_end
            {
              self_closing: @parser.self_closing_tag?
            }
          end
          add_token(type, start, stop, **(extra_attributes || {}))
        end
      end

      def add_lodash_tokens(indicator, code)
        type = case indicator
        when nil
          :stmt
        when '='
          :expr_literal
        when '!'
          :expr_escaped
        else
          raise ArgumentError
        end

        start = @parser.document_length
        code_start = start + 2 + (indicator&.length || 0)
        code_stop = code_start + code.length
        stop = code_stop + 2

        add_token(
          type, start, stop,
          code_location: Location.new(@document, code_start, code_stop - 1)
        )
      end

      def add_token(type, start, stop, **extra_attributes)
        token = Token.new(
          type: type,
          location: Location.new(@document, start, stop - 1),
          **extra_attributes
        )
        @tokens << token
        token
      end
    end
  end
end
