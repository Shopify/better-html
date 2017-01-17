require 'active_support/core_ext/hash/keys'

module BetterHtml
end

require 'better_html/version'
require 'better_html/helpers'
require 'better_html/errors'
require 'better_html/html_attributes'

require 'better_html/railtie' if defined?(Rails)
