require 'smart_properties'

module BetterHtml
  class Config
    include SmartProperties

    # regex to validate "foo" in "<foo>"
    property :partial_tag_name_pattern, default: /\A[a-z0-9\-\:]+\z/

    # regex to validate "bar" in "<foo bar=1>"
    property :partial_attribute_name_pattern, default: /\A[a-zA-Z0-9\-\:]+\z/

    # true if "<foo bar='1'>" is valid syntax
    property :allow_single_quoted_attributes, default: true

    # true if "<foo bar=1>" is valid syntax
    property :allow_unquoted_attributes, default: false

    # all methods that return "javascript-safe" strings
    property :javascript_safe_methods, default: ['to_json']

    # name of all html attributes that may contain javascript
    property :javascript_attribute_names, default: [/\Aon/i]

    # block that can be used to selectively enable which templates to parse.
    property :template_exclusion_filter_block
    def template_exclusion_filter(&block)
      self.template_exclusion_filter_block = block
    end

    property :lodash_safe_javascript_expression, default: [/\AJSON\.stringify\(/]
  end
end
