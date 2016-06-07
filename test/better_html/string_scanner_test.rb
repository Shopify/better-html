require 'test_helper'

class BetterHtml::StringScannerTest < ActiveSupport::TestCase
  test "scan text" do
    result = scan("\n    hello world\n    ")
    assert_equal [[:text, "\n    hello world\n    "]], result
  end

  test "scan marker" do
    result = scan("foo %{bar} baz")
    assert_equal [
      [:text, "foo "],
      [:marker_start, "%{"],
      [:identifier, "bar"],
      [:marker_end, "}"],
      [:text, " baz"]
    ], result
  end

  test "escaped marker with percent sign" do
    result = scan("foo %%{bar} baz")
    assert_equal [
      [:text, "foo "],
      [:percent, "%%"],
      [:text, "{bar} baz"]
    ], result
  end

  test "unclosed marker" do
    result = scan("foo %{bar")
    assert_equal [
      [:text, "foo "],
      [:marker_start, "%{"],
      [:identifier, "bar"],
    ], result
  end

  private

  def scan(str)
    tokens = []
    @scanner = BetterHtml::StringScanner.new
    @scanner.scan(str) { |name, start, stop| tokens << [name, str[start..(stop-1)]] }
    tokens
  end
end
