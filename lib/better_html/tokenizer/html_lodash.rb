require 'active_support'
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
          add_token(type, start: start, stop: stop, line: line, column: column)
        end
      end

      def add_lodash_tokens(indicator, code)
        pos = @parser.document_length

        add_token(:lodash_begin, start: pos, stop: pos + 2)
        pos += 2

        if indicator
          add_token(:indicator, start: pos, stop: pos + indicator.length)
          pos += indicator.length
        end

        add_token(:code, start: pos, stop: pos + code.length)
        pos += code.length

        add_token(:lodash_end, start: pos, stop: pos + 2)
      end

      def add_token(type, start: nil, stop: nil, line: nil, column: nil)
        token = Token.new(
          type: type,
          loc: Location.new(@document, start, stop-1, line, column)
        )
        @tokens << token
        token
      end
    end
  end
end
