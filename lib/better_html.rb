module BetterHtml
end

require 'better_html/version'
require 'better_html/helper'
require 'better_html/errors'
require 'better_html/html_node'
require 'better_html_ext'

require 'better_html/railtie' if defined?(Rails)
