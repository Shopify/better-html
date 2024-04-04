# frozen_string_literal: true

require "test_helper"
# setup dummy app
ENV["RAILS_ENV"] ||= "test"
require_relative "../dummy/config/environment"

module BetterHtml
  class RailtieTest < ActiveSupport::TestCase
    if Rails::VERSION::STRING >= "6.1"
      test "configuration is copied from ActionView" do
        _ = ActionView::Base

        assert_equal true, BetterHtml.config.annotate_rendered_view_with_filenames
      end
    end
  end
end
