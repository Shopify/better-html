require 'active_support/core_ext/hash/keys'

module BetterHtml
  class Config
    # a tag name that may be partial
    cattr_accessor :partial_tag_name_pattern
    self.partial_tag_name_pattern = /\A[a-z\-\:]+\z/
  end

  def self.config
    @config ||= Config.new
    yield @config if block_given?
    @config
  end
end

require 'better_html/version'
require 'better_html/helpers'
require 'better_html/errors'
require 'better_html/html_attributes'

require 'better_html/railtie' if defined?(Rails)
