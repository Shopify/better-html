$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "better_html/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "better_html"
  s.version     = BetterHtml::VERSION
  s.authors     = ["Francois Chagnon"]
  s.email       = ["francois.chagnon@shopify.com"]
  s.homepage    = "https://github.com/Shopify/better-html"
  s.summary     = "Better HTML for Rails."
  s.description = "Better HTML for Rails. Provides sane html helpers that make it easier to do the right thing."
  s.license     = "MIT"

  s.metadata = {
    "bug_tracker_uri" => "https://github.com/Shopify/better-html/issues",
    "changelog_uri" => "https://github.com/Shopify/better-html/releases",
    "source_code_uri" => "https://github.com/Shopify/better-html/tree/v#{s.version}",
    "allowed_push_host" => "https://rubygems.org"
  }

  s.files = Dir["{app,config,db,lib,ext}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]
  s.require_paths = ["lib"]

  s.add_dependency 'ast', '~> 2.0'
  s.add_dependency 'erubi', '~> 1.4'
  s.add_dependency 'activesupport', '>= 4.0'
  s.add_dependency 'actionview', '>= 4.0'
  s.add_dependency 'parser', '>= 2.4'
  s.add_dependency 'smart_properties'
  s.add_dependency 'html_tokenizer', '~> 0.0.6'

  s.add_development_dependency 'rake', '~> 13'
end
