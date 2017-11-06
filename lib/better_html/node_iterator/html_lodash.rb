require_relative 'token'
require_relative 'location'

module BetterHtml
  class NodeIterator
    class HtmlLodash
      attr_reader :tokens
      attr_reader :parser

      cattr_accessor :lodash_escape, :lodash_evaluate, :lodash_interpolate
      self.lodash_escape = %r{(?:\[\%)=(.+?)(?:\%\])}m
      self.lodash_evaluate = %r{(?:\[\%)(.+?)(?:\%\])}m
      self.lodash_interpolate = %r{(?:\[\%)!(.+?)(?:\%\])}m

      def initialize(source)
        @source = source
        @scanner = StringScanner.new(source)
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
              add_text(pre_match) unless pre_match.blank?
            end
            match = captures[1]
            if code = lodash_escape.match(match)
              add_expr_escape(match, code.captures[0])
            elsif code = lodash_interpolate.match(match)
              add_expr_interpolate(match, code.captures[0])
            elsif code = lodash_evaluate.match(match)
              add_stmt(match, code.captures[0])
            else
              raise RuntimeError, 'unexpected match'
            end
          else
            text = @source[(@scanner.pos)..(@source.size)]
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
          add_token(type, @parser.extract(start, stop), start: start, stop: stop, line: line, column: column)
        end
      end

      def add_stmt(text, code)
        add_token(:stmt, text, code: code)
        @parser.append_placeholder(text)
      end

      def add_expr_interpolate(text, code)
        add_token(:expr_escaped, text, code: code)
        @parser.append_placeholder(text)
      end

      def add_expr_escape(text, code)
        add_token(:expr_literal, text, code: code)
        @parser.append_placeholder(text)
      end

      def add_token(type, text, code: nil, start: nil, stop: nil, line: nil, column: nil)
        start ||= @parser.document_length
        stop ||= start + text.size
        extra_attributes = if type == :tag_end
          {
            self_closing: @parser.self_closing_tag?
          }
        end
        @tokens << Token.new(
          type: type,
          text: text,
          code: code,
          location: Location.new(@source, start, stop, line || @parser.line_number, column || @parser.column_number),
          **(extra_attributes || {})
        )
      end
    end
  end
end
