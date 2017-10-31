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
        assert_attributes ({ line: 1 }), scanner.tokens[0].location

        assert_attributes ({ type: :stmt, text: "<% multi\nline %>" }), scanner.tokens[1]
        assert_attributes ({ line: 2 }), scanner.tokens[1].location

        assert_attributes ({ type: :text, text: "\n" }), scanner.tokens[2]
        assert_attributes ({ line: 3 }), scanner.tokens[2].location

        assert_attributes ({ type: :text, text: "after" }), scanner.tokens[3]
        assert_attributes ({ line: 4 }), scanner.tokens[3].location
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

      private

      def assert_attributes(attributes, token)
        attributes.each do |key, value|
          if value.nil?
            assert_nil token.send(key)
          else
            assert_equal value, token.send(key)
          end
        end
      end
    end
  end
end
