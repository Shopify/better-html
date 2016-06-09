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

  test "#format interpolate text in attribute" do
    result = html('<a title="%{title}">').format({ title: 'my "title" here' })
    assert_equal '<a title="my &quot;title&quot; here">', result.to_s
  end

  test "#format interpolate html in attribute" do
    result = html('<a title="%{title}">').format({ title: html('my "title" here') })
    assert_equal '<a title="my &quot;title&quot; here">', result.to_s
  end

  test "#format interpolate text in html" do
    result = html('<b>%{title}</b>').format({ title: 'my <title> here' })
    assert_equal '<b>my &lt;title&gt; here</b>', result.to_s
  end

  test "#format interpolate html in html" do
    result = html('<b>%{title}</b>').format({ title: html('my <title> here') })
    assert_equal '<b>my <title> here</b>', result.to_s
  end

  test "#format adds quotes around attribute" do
    result = html('<a title=%{title}>').format({ title: 'foo' })
    assert_equal '<a title="foo">', result.to_s
  end

  test "#format right after an attribute" do
    e = assert_raises(BetterHtml::DontInterpolateHere) do
      html('<a title="hello"%{title}>').format({ title: 'foo' })
    end
    assert_equal "Do not interpolate in a tag. Instead of <a %{title}> "\
      "please try <a name=%{title}>.", e.message
  end

  test "#format after tag name" do
    e = assert_raises(BetterHtml::DontInterpolateHere) do
      html('<a %{title}>').format({ title: 'foo' })
    end
    assert_equal "Do not interpolate in a tag. Instead of <a %{title}> "\
      "please try <a name=%{title}>.", e.message
  end

  test "#format inside tag name without space is safe" do
    assert_nothing_raised(BetterHtml::UnsafeHtmlError) do
      html('<foo-%{title}-bar>').format({ title: 'foobar' })
    end
  end

  test "#format inside tag name with space" do
    e = assert_raises(BetterHtml::UnsafeHtmlError) do
      html('<foo-%{title}-bar>').format({ title: 'foo bar' })
    end
    assert_equal "Detected / or whitespace interpolated in a "\
      "tag name around: <foo-%{title}.", e.message
  end

  test "#format inside closing tag name with space" do
    e = assert_raises(BetterHtml::UnsafeHtmlError) do
      html('</foo-%{title}-bar>').format({ title: 'foo bar' })
    end
    assert_equal "Detected / or whitespace interpolated in a "\
      "tag name around: <foo-%{title}.", e.message
  end

  test "#format html inside of tag name" do
    e = assert_raises(BetterHtml::UnsafeHtmlError) do
      html('<foo-%{title}-bar>').format({ title: html('foobar') })
    end
    assert_equal "Refusing to interpolate HTML from `%{title}` at: <foo-%{title}.", e.message
  end

  test "#format inside unquoted attribute" do
    e = assert_raises(BetterHtml::DontInterpolateHere) do
      html('<a title=foo%{title}>').format({ title: 'foo' })
    end
    assert_equal "Do not interpolate without quotes around this "\
      "attribute value. Instead of <a title=foo%{title}> try "\
      "<a title=\"foo%{title}\">.", e.message
  end

  test "#format html_safe string is no good" do
    e = assert_raises(BetterHtml::UnsafeHtmlError) do
      html('<a title="%{title}">').format({ title: 'foo'.html_safe })
    end
    assert_equal "Cowardly refusing to interpolate the value of %{title} which is marked html_safe.", e.message
  end

  private

  def html(template)
    BetterHtml::HtmlNode.new(template)
  end
end
