require 'test_helper'

class BetterHtml::HelpersTest < ActiveSupport::TestCase
  include BetterHtml::Helpers

  test "html returns a HtmlNode" do
    assert_equal BetterHtml::HtmlNode, html("test").class
  end

  test "html_attributes return a HtmlAttributes object" do
    assert_equal BetterHtml::HtmlAttributes, html_attributes(foo: "bar").class
  end

  test "html_attributes are formatted as string" do
    assert_equal 'foo="bar" baz="qux"',
      html_attributes(foo: "bar", baz: "qux").to_s
  end

  test "html_attributes keys cannot contain invalid characters" do
    e = assert_raises(ArgumentError) do
      html_attributes("invalid key": "bar", baz: "qux").to_s
    end
    assert_equal "attribute names should contain only lowercase letters, numbers, or :-._ symbols", e.message
  end

  test "html_attributes escapes html_safe values" do
    assert_equal 'foo=" &#39;&quot;&gt;&lt; "',
      html_attributes(foo: " '\">< ".html_safe).to_s
  end
end
