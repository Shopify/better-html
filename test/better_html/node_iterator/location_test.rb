require 'test_helper'
require 'better_html/test_helper/safe_erb_tester'

module BetterHtml
  class NodeIterator
    class LocationTest < ActiveSupport::TestCase
      test "location without line and column" do
        loc = Location.new("foo\nbar\nbaz", 9, 10)

        assert_equal "a", loc.source
        assert_equal 3, loc.line
        assert_equal 1, loc.column
      end

      test "line_source_with_underline" do
        loc = Location.new("ui_helper(foo)", 10, 13)

        assert_equal "foo", loc.source
        assert_equal <<~EOL.strip, loc.line_source_with_underline
          ui_helper(foo)
                    ^^^
        EOL
      end

      test "line_source_with_underline removes empty spaces" do
        loc = Location.new("   \t   ui_helper(foo)", 17, 20)

        assert_equal "foo", loc.source
        assert_equal <<~EOL.strip, loc.line_source_with_underline
          ui_helper(foo)
                    ^^^
        EOL
      end
    end
  end
end
