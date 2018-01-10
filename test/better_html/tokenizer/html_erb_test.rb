require 'test_helper'
require 'better_html/tokenizer/html_erb'

module BetterHtml
  module Tokenizer
    class HtmlErbTest < ActiveSupport::TestCase
      test "text" do
        scanner = HtmlErb.new("just some text")
        assert_equal 1, scanner.tokens.size

        assert_attributes ({
          type: :text,
          loc: { start: 0, stop: 13, source: 'just some text' }
        }), scanner.tokens[0]
      end

      test "statement" do
        scanner = HtmlErb.new("<% statement %>")
        assert_equal 3, scanner.tokens.size

        assert_attributes ({ type: :erb_begin, loc: { start: 0, stop: 1, source: '<%' } }), scanner.tokens[0]
        assert_attributes ({ type: :code, loc: { start: 2, stop: 12, source: ' statement ' } }), scanner.tokens[1]
        assert_attributes ({ type: :erb_end, loc: { start: 13, stop: 14, source: '%>' } }), scanner.tokens[2]
      end

      test "debug statement" do
        scanner = HtmlErb.new("<%# statement %>")
        assert_equal 4, scanner.tokens.size

        assert_attributes ({ type: :erb_begin, loc: { start: 0, stop: 1, source: '<%' } }), scanner.tokens[0]
        assert_attributes ({ type: :indicator, loc: { start: 2, stop: 2, source: '#' } }), scanner.tokens[1]
        assert_attributes ({ type: :code, loc: { start: 3, stop: 13, source: ' statement ' } }), scanner.tokens[2]
        assert_attributes ({ type: :erb_end, loc: { start: 14, stop: 15, source: '%>' } }), scanner.tokens[3]
      end

      test "when multi byte characters are present in erb" do
        code = "<% ui_helper 'your store’s' %>"
        scanner = HtmlErb.new(code)
        assert_equal 3, scanner.tokens.size

        assert_attributes ({ type: :erb_begin, loc: { start: 0, stop: 1, source: '<%' } }), scanner.tokens[0]
        assert_attributes ({ type: :code, loc: { start: 2, stop: 27, source: " ui_helper 'your store’s' " } }), scanner.tokens[1]
        assert_attributes ({ type: :erb_end, loc: { start: 28, stop: 29, source: '%>' } }), scanner.tokens[2]
        assert_equal code.length, scanner.current_position
      end

      test "when multi byte characters are present in text" do
        code = "your store’s"
        scanner = HtmlErb.new(code)
        assert_equal 1, scanner.tokens.size

        assert_attributes ({ type: :text, loc: { start: 0, stop: 11, source: 'your store’s' } }), scanner.tokens[0]
        assert_equal code.length, scanner.current_position
      end

      test "when multi byte characters are present in html" do
        code = "<div title='your store’s'>foo</div>"
        scanner = HtmlErb.new(code)
        assert_equal 14, scanner.tokens.size

        assert_attributes ({ type: :tag_start, loc: { start: 0, stop: 0, source: '<' } }), scanner.tokens[0]
        assert_attributes ({ type: :tag_name, loc: { start: 1, stop: 3, source: "div" } }), scanner.tokens[1]
        assert_attributes ({ type: :whitespace, loc: { start: 4, stop: 4, source: " " } }), scanner.tokens[2]
        assert_attributes ({ type: :attribute_name, loc: { start: 5, stop: 9, source: "title" } }), scanner.tokens[3]
        assert_attributes ({ type: :equal, loc: { start: 10, stop: 10, source: "=" } }), scanner.tokens[4]
        assert_attributes ({ type: :attribute_quoted_value_start, loc: { start: 11, stop: 11, source: "'" } }), scanner.tokens[5]
        assert_attributes ({ type: :attribute_quoted_value, loc: { start: 12, stop: 23, source: "your store’s" } }), scanner.tokens[6]
        assert_attributes ({ type: :attribute_quoted_value_end, loc: { start: 24, stop: 24, source: "'" } }), scanner.tokens[7]
        assert_equal code.length, scanner.current_position
      end

      test "expression literal" do
        scanner = HtmlErb.new("<%= literal %>")
        assert_equal 4, scanner.tokens.size

        assert_attributes ({ type: :erb_begin, loc: { start: 0, stop: 1, source: '<%' } }), scanner.tokens[0]
        assert_attributes ({ type: :indicator, loc: { start: 2, stop: 2, source: '=' } }), scanner.tokens[1]
        assert_attributes ({ type: :code, loc: { start: 3, stop: 11, source: ' literal ' } }), scanner.tokens[2]
        assert_attributes ({ type: :erb_end, loc: { start: 12, stop: 13, source: '%>' } }), scanner.tokens[3]
      end

      test "expression escaped" do
        scanner = HtmlErb.new("<%== escaped %>")
        assert_equal 4, scanner.tokens.size

        assert_attributes ({ type: :erb_begin, loc: { start: 0, stop: 1, source: '<%' } }), scanner.tokens[0]
        assert_attributes ({ type: :indicator, loc: { start: 2, stop: 3, source: '==' } }), scanner.tokens[1]
        assert_attributes ({ type: :code, loc: { start: 4, stop: 12, source: ' escaped ' } }), scanner.tokens[2]
        assert_attributes ({ type: :erb_end, loc: { start: 13, stop: 14, source: '%>' } }), scanner.tokens[3]
      end

      test "line number for multi-line statements" do
        scanner = HtmlErb.new("before <% multi\nline %> after")
        assert_equal 5, scanner.tokens.size

        assert_attributes ({ type: :text, loc: { line: 1, source: 'before ' } }), scanner.tokens[0]
        assert_attributes ({ type: :erb_begin, loc: { line: 1, source: '<%' } }), scanner.tokens[1]
        assert_attributes ({ type: :code, loc: { line: 1, start_line: 1, stop_line: 2, source: " multi\nline " } }), scanner.tokens[2]
        assert_attributes ({ type: :erb_end, loc: { line: 2, source: "%>" } }), scanner.tokens[3]
        assert_attributes ({ type: :text, loc: { line: 2, source: " after" } }), scanner.tokens[4]
      end

      test "multi-line statements with trim" do
        scanner = HtmlErb.new("before\n<% multi\nline -%>\nafter")
        assert_equal 7, scanner.tokens.size

        assert_attributes ({ type: :text, loc: { line: 1, source: "before\n" } }), scanner.tokens[0]
        assert_attributes ({ type: :erb_begin, loc: { line: 2, source: '<%' } }), scanner.tokens[1]
        assert_attributes ({ type: :code, loc: { line: 2, source: " multi\nline " } }), scanner.tokens[2]
        assert_attributes ({ type: :trim, loc: { line: 3, source: "-" } }), scanner.tokens[3]
        assert_attributes ({ type: :erb_end, loc: { line: 3, source: "%>" } }), scanner.tokens[4]
        assert_attributes ({ type: :text, loc: { line: 3, source: "\n" } }), scanner.tokens[5]
        assert_attributes ({ type: :text, loc: { line: 4, source: "after" } }), scanner.tokens[6]
      end

      test "multi-line expression with trim" do
        scanner = HtmlErb.new("before\n<%= multi\nline -%>\nafter")
        assert_equal 8, scanner.tokens.size

        assert_attributes ({ type: :text, loc: { line: 1, source: "before\n" } }), scanner.tokens[0]
        assert_attributes ({ type: :erb_begin, loc: { line: 2, source: '<%' } }), scanner.tokens[1]
        assert_attributes ({ type: :indicator, loc: { line: 2, source: '=' } }), scanner.tokens[2]
        assert_attributes ({ type: :code, loc: { line: 2, source: " multi\nline " } }), scanner.tokens[3]
        assert_attributes ({ type: :trim, loc: { line: 3, source: "-" } }), scanner.tokens[4]
        assert_attributes ({ type: :erb_end, loc: { line: 3, source: "%>" } }), scanner.tokens[5]
        assert_attributes ({ type: :text, loc: { line: 3, source: "\n" } }), scanner.tokens[6]
        assert_attributes ({ type: :text, loc: { line: 4, source: "after" } }), scanner.tokens[7]
      end

      test "line counts with comments" do
        scanner = HtmlErb.new("before\n<%# BO$$ Mode %>\nafter")
        assert_equal 7, scanner.tokens.size

        assert_attributes ({ type: :text, loc: { line: 1, source: "before\n" } }), scanner.tokens[0]
        assert_attributes ({ type: :erb_begin, loc: { line: 2, source: '<%' } }), scanner.tokens[1]
        assert_attributes ({ type: :indicator, loc: { line: 2, source: '#' } }), scanner.tokens[2]
        assert_attributes ({ type: :code, loc: { line: 2, source: " BO$$ Mode " } }), scanner.tokens[3]
        assert_attributes ({ type: :erb_end, loc: { line: 2, source: "%>" } }), scanner.tokens[4]
        assert_attributes ({ type: :text, loc: { line: 2, source: "\n" } }), scanner.tokens[5]
        assert_attributes ({ type: :text, loc: { line: 3, source: "after" } }), scanner.tokens[6]
      end

      private

      def assert_attributes(attributes, token)
        attributes.each do |key, value|
          if value.nil?
            assert_nil token.send(key)
          elsif value.is_a?(Hash)
            assert_attributes(value, token.send(key))
          else
            assert_equal value, token.send(key)
          end
        end
      end
    end
  end
end
