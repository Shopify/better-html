require 'test_helper'
require 'better_html/tokenizer/location'
require 'better_html/tokenizer/token'

module BetterHtml
  module Tokenizer
    class TokenTest < ActiveSupport::TestCase
      test "token inspect" do
        loc = Location.new("foo", 0, 2)
        token = Token.new(type: :foo, loc: loc)
        assert_equal "t(:foo, \"foo\")", token.inspect
      end
    end
  end
end
