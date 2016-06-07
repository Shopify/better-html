require 'test_helper'

class BetterHtml::HelperTest < ActiveSupport::TestCase
  include BetterHtml::Helper

  test "html returns a HtmlNode" do
    assert_equal html("test").class, BetterHtml::HtmlNode
  end
end
