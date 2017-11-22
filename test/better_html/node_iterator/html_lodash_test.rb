require 'test_helper'

module BetterHtml
  class NodeIterator
    class HtmlLodashTest < ActiveSupport::TestCase
      test "matches text" do
        scanner = BetterHtml::NodeIterator::HtmlLodash.new("just some text")
        assert_equal 1, scanner.tokens.size
        token = scanner.tokens[0]
        assert_equal :text, token.type
        assert_equal "just some text", token.text
        assert_nil token.code
        assert_equal 0, token.location.start
        assert_equal 13, token.location.stop
        assert_equal 1, token.location.line
        assert_equal 0, token.location.column
      end

      test "matches strings to be escaped" do
        scanner = BetterHtml::NodeIterator::HtmlLodash.new("[%= foo %]")
        assert_equal 1, scanner.tokens.size
        token = scanner.tokens[0]
        assert_equal :expr_literal, token.type
        assert_equal "[%= foo %]", token.text
        assert_equal " foo ", token.code
        assert_equal 0, token.location.start
        assert_equal 9, token.location.stop
        assert_equal 1, token.location.line
        assert_equal 0, token.location.column
      end

      test "matches interpolate" do
        scanner = BetterHtml::NodeIterator::HtmlLodash.new("[%! foo %]")
        assert_equal 1, scanner.tokens.size
        token = scanner.tokens[0]
        assert_equal :expr_escaped, token.type
        assert_equal "[%! foo %]", token.text
        assert_equal " foo ", token.code
        assert_equal 0, token.location.start
        assert_equal 9, token.location.stop
        assert_equal 1, token.location.line
        assert_equal 0, token.location.column
      end

      test "matches statement" do
        scanner = BetterHtml::NodeIterator::HtmlLodash.new("[% foo %]")
        assert_equal 1, scanner.tokens.size
        token = scanner.tokens[0]
        assert_equal :stmt, token.type
        assert_equal "[% foo %]", token.text
        assert_equal " foo ", token.code
        assert_equal 0, token.location.start
        assert_equal 8, token.location.stop
        assert_equal 1, token.location.line
        assert_equal 0, token.location.column
      end

      test "matches text before and after" do
        scanner = BetterHtml::NodeIterator::HtmlLodash.new("before\n[%= foo %]\nafter")
        assert_equal 3, scanner.tokens.size

        token = scanner.tokens[0]
        assert_equal :text, token.type
        assert_equal "before\n", token.text
        assert_nil token.code
        assert_equal 0, token.location.start
        assert_equal 6, token.location.stop
        assert_equal 1, token.location.line
        assert_equal 0, token.location.column

        token = scanner.tokens[1]
        assert_equal :expr_literal, token.type
        assert_equal "[%= foo %]", token.text
        assert_equal " foo ", token.code
        assert_equal 7, token.location.start
        assert_equal 16, token.location.stop
        assert_equal 2, token.location.line
        assert_equal 0, token.location.column

        token = scanner.tokens[2]
        assert_equal :text, token.type
        assert_equal "\nafter", token.text
        assert_nil token.code
        assert_equal 17, token.location.start
        assert_equal 22, token.location.stop
        assert_equal 2, token.location.line
        assert_equal 10, token.location.column
      end

      test "matches multiple" do
        scanner = BetterHtml::NodeIterator::HtmlLodash.new("[% if() { %][%= foo %][% } %]")
        assert_equal 3, scanner.tokens.size

        token = scanner.tokens[0]
        assert_equal :stmt, token.type
        assert_equal "[% if() { %]", token.text
        assert_equal " if() { ", token.code
        assert_equal 0, token.location.start
        assert_equal 11, token.location.stop
        assert_equal 1, token.location.line
        assert_equal 0, token.location.column

        token = scanner.tokens[1]
        assert_equal :expr_literal, token.type
        assert_equal "[%= foo %]", token.text
        assert_equal " foo ", token.code
        assert_equal 12, token.location.start
        assert_equal 21, token.location.stop
        assert_equal 1, token.location.line
        assert_equal 12, token.location.column

        token = scanner.tokens[2]
        assert_equal :stmt, token.type
        assert_equal "[% } %]", token.text
        assert_equal " } ", token.code
        assert_equal 22, token.location.start
        assert_equal 28, token.location.stop
        assert_equal 1, token.location.line
        assert_equal 22, token.location.column
      end

      test "parses out html correctly" do
        scanner = BetterHtml::NodeIterator::HtmlLodash.new('<div class="[%= foo %]">')
        assert_equal 9, scanner.tokens.size
        assert_equal [:tag_start, :tag_name, :whitespace, :attribute_name,
          :equal, :attribute_quoted_value_start, :expr_literal,
          :attribute_quoted_value_end, :tag_end], scanner.tokens.map(&:type)
        assert_equal ["<", "div", " ", "class", "=", "\"", "[%= foo %]", "\"", ">"], scanner.tokens.map(&:text)
      end
    end
  end
end
