require 'test_helper'
require 'ostruct'
require 'better_html/better_erb'

class BetterHtml::BetterErb::ImplementationTest < ActiveSupport::TestCase
  test "simple template rendering" do
    assert_equal "<foo>some value<foo>",
      render("<foo><%= bar %><foo>", { bar: 'some value' })
  end

  test "html_safe interpolation" do
    assert_equal "<foo><bar /><foo>",
      render("<foo><%= bar %><foo>", { bar: '<bar />'.html_safe })
  end

  test "non html_safe interpolation" do
    assert_equal "<foo>&lt;bar /&gt;<foo>",
      render("<foo><%= bar %><foo>", { bar: '<bar />' })
  end

  private

  def render(source, locals)
    src = BetterHtml::BetterErb::Implementation.new(source).src
    context = OpenStruct.new(locals)
    context.instance_eval(src)
  end
end
