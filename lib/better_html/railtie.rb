# frozen_string_literal: true

require "better_html/better_erb"

module BetterHtml
  class Railtie < Rails::Railtie
    initializer "better_html.better_erb.initialization" do |app|
      BetterHtml::BetterErb.prepend!

      action_view_config = app.config.action_view
      BetterHtml.config.annotate_rendered_view_with_filenames = action_view_config.annotate_rendered_view_with_filenames
    end
  end
end
