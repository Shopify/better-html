require 'test_helper'

module BetterHtml
  class NodeIterator
    class HtmlErbTest < ActiveSupport::TestCase
      test "text" do
        scanner = BetterHtml::NodeIterator::HtmlErb.new("just some text")
        assert_equal 1, scanner.tokens.size
        token = scanner.tokens[0]
        assert_attributes ({ type: :text, text: 'just some text', code: nil }), token
        assert_attributes ({ start: 0, stop: 14, line: 1, column: 0 }), token.location
      end

      test "statement" do
        scanner = BetterHtml::NodeIterator::HtmlErb.new("<% statement %>")
        assert_equal 1, scanner.tokens.size
        token = scanner.tokens[0]
        assert_attributes ({ type: :stmt, text: '<% statement %>', code: ' statement ' }), token
        assert_attributes ({ start: 0, stop: 15, line: 1, column: 0 }), token.location
      end

      test "when multi byte characters are present in erb" do
        code = "<% ui_helper 'your store’s' %>"
        scanner = BetterHtml::NodeIterator::HtmlErb.new(code)
        assert_equal 1, scanner.tokens.size

        token = scanner.tokens[0]
        assert_attributes ({ type: :stmt, code: " ui_helper 'your store’s' ", location: { start: 0, stop: 30 } }), token
      end

      test "when multi byte characters are present in text" do
        code = "your store’s"
        scanner = BetterHtml::NodeIterator::HtmlErb.new(code)
        assert_equal 1, scanner.tokens.size

        token = scanner.tokens[0]
        assert_attributes ({ type: :text, text: 'your store’s', location: { start: 0, stop: 12 } }), token
      end

      test "when multi byte characters are present in html" do
        code = "<div title='your store’s'>foo</div>"
        scanner = BetterHtml::NodeIterator::HtmlErb.new(code)
        assert_equal 14, scanner.tokens.size

        assert_attributes ({ type: :tag_start, text: '<', location: { start: 0, stop: 1 } }), scanner.tokens[0]
        assert_attributes ({ type: :tag_name, text: 'div', location: { start: 1, stop: 4} }), scanner.tokens[1]
        assert_attributes ({ type: :whitespace, text: ' ', location: { start: 4, stop: 5 } }), scanner.tokens[2]
        assert_attributes ({ type: :attribute_name, text: "title", location: { start: 5, stop: 10 } }), scanner.tokens[3]
        assert_attributes ({ type: :equal, text: "=", location: { start: 10, stop: 11 } }), scanner.tokens[4]
        assert_attributes ({ type: :attribute_quoted_value_start, text: "'", location: { start: 11, stop: 12 } }), scanner.tokens[5]
        assert_attributes ({ type: :attribute_quoted_value, text: "your store’s", location: { start: 12, stop: 24 } }), scanner.tokens[6]
        assert_attributes ({ type: :attribute_quoted_value_end, text: "'", location: { start: 24, stop: 25 } }), scanner.tokens[7]
      end

      test "expression literal" do
        scanner = BetterHtml::NodeIterator::HtmlErb.new("<%= literal %>")
        assert_equal 1, scanner.tokens.size
        token = scanner.tokens[0]
        assert_attributes ({ type: :expr_literal, text: '<%= literal %>', code: ' literal ' }), token
        assert_attributes ({ start: 0, stop: 14, line: 1, column: 0 }), token.location
      end

      test "expression escaped" do
        scanner = BetterHtml::NodeIterator::HtmlErb.new("<%== escaped %>")
        assert_equal 1, scanner.tokens.size
        token = scanner.tokens[0]
        assert_attributes ({ type: :expr_escaped, text: '<%== escaped %>', code: ' escaped ' }), token
        assert_attributes ({ start: 0, stop: 15, line: 1, column: 0 }), token.location
      end

      test "line number for multi-line statements" do
        scanner = BetterHtml::NodeIterator::HtmlErb.new("before <% multi\nline %> after")
        assert_equal 3, scanner.tokens.size

        assert_attributes ({ type: :text, text: 'before ' }), scanner.tokens[0]
        assert_attributes ({ line: 1 }), scanner.tokens[0].location

        assert_attributes ({ type: :stmt, text: "<% multi\nline %>" }), scanner.tokens[1]
        assert_attributes ({ line: 1 }), scanner.tokens[1].location

        assert_attributes ({ type: :text, text: " after" }), scanner.tokens[2]
        assert_attributes ({ line: 2 }), scanner.tokens[2].location
      end

      test "multi-line statements with trim" do
        scanner = BetterHtml::NodeIterator::HtmlErb.new("before\n<% multi\nline -%>\nafter")
        assert_equal 4, scanner.tokens.size

        assert_attributes ({ type: :text, text: "before\n" }), scanner.tokens[0]
        assert_attributes ({ line: 1, start: 0, stop: 7 }), scanner.tokens[0].location

        assert_attributes ({ type: :stmt, text: "<% multi\nline %>" }), scanner.tokens[1]
        assert_attributes ({ line: 2, start: 7, stop: 23 }), scanner.tokens[1].location

        assert_attributes ({ type: :text, text: "\n" }), scanner.tokens[2]
        assert_attributes ({ line: 3, start: 23, stop: 24 }), scanner.tokens[2].location

        assert_attributes ({ type: :text, text: "after" }), scanner.tokens[3]
        assert_attributes ({ line: 4, start: 24, stop: 29 }), scanner.tokens[3].location
      end

      test "multi-line expression with trim" do
        scanner = BetterHtml::NodeIterator::HtmlErb.new("before\n<%= multi\nline -%>\nafter")
        assert_equal 4, scanner.tokens.size

        assert_attributes ({ type: :text, text: "before\n" }), scanner.tokens[0]
        assert_attributes ({ line: 1 }), scanner.tokens[0].location

        assert_attributes ({ type: :expr_literal, text: "<%= multi\nline %>" }), scanner.tokens[1]
        assert_attributes ({ line: 2 }), scanner.tokens[1].location

        assert_attributes ({ type: :text, text: "\n" }), scanner.tokens[2]
        assert_attributes ({ line: 3 }), scanner.tokens[2].location

        assert_attributes ({ type: :text, text: "after" }), scanner.tokens[3]
        assert_attributes ({ line: 4 }), scanner.tokens[3].location
      end

      test "line counts with comments" do
        scanner = BetterHtml::NodeIterator::HtmlErb.new("before\n<%# BO$$ Mode %>\nafter")
        assert_equal 4, scanner.tokens.size

        assert_attributes ({ type: :text, text: "before\n" }), scanner.tokens[0]
        assert_attributes ({ line: 1 }), scanner.tokens[0].location

        assert_attributes ({ type: :stmt, text: "<%# BO$$ Mode %>" }), scanner.tokens[1]
        assert_attributes ({ line: 2 }), scanner.tokens[1].location

        assert_attributes ({ type: :text, text: "\n" }), scanner.tokens[2]
        assert_attributes ({ line: 2 }), scanner.tokens[2].location

        assert_attributes ({ type: :text, text: "after" }), scanner.tokens[3]
        assert_attributes ({ line: 3 }), scanner.tokens[3].location
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
