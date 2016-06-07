require 'test_helper'

class BetterHtml::HelperTest < ActiveSupport::TestCase
  test "#% interpolates arguments" do
    result = html("foo %{arg} baz") % { arg: 'bar' }
    assert_equal "foo bar baz", result.to_s
  end

  test "#format interpolates arguments" do
    result = html("foo %{arg} baz").format({ arg: 'bar' })
    assert_equal "foo bar baz", result.to_s
  end

  test "#format non existent key" do
    e = assert_raises(KeyError) do
      result = html("foo %{nonexistent} baz").format({})
    end
    assert_equal "key not found: :nonexistent", e.message
  end

  test "#format unclosed marker" do
    e = assert_raises(RuntimeError) do
      html("foo %{bar").format({ bar: '' })
    end
    assert_equal "Unclosed marker at position 4: %{bar", e.message
  end

  test "#format interpolate in html" do
    result = html('<a title="%{title}">').format({ title: 'my "title" here' })
    assert_equal '<a title="my &quot;title&quot; here">', result.to_s
  end

  private

  def html(template)
    BetterHtml::HtmlNode.new(template)
  end
end
