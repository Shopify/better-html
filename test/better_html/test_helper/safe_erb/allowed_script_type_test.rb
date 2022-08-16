# frozen_string_literal: true

require "test_helper"
require "better_html/parser"
require "better_html/test_helper/safe_erb/allowed_script_type"

module BetterHtml
  module TestHelper
    module SafeErb
      class AllowedScriptTypeTest < ActiveSupport::TestCase
        setup do
          @config = BetterHtml::Config.new(
            javascript_safe_methods: ["j", "escape_javascript", "to_json"],
            javascript_attribute_names: [/\Aon/i, "data-eval"],
          )
        end

        test "allowed script type" do
          errors = validate(<<-EOF).errors
            <script type="text/javascript">
            </script>
          EOF

          assert_predicate errors, :empty?
        end

        test "disallowed script types" do
          errors = validate(<<-EOF).errors
            <script type="text/bogus">
            </script>
          EOF

          assert_equal 1, errors.size
          assert_equal 'type="text/bogus"', errors.first.location.source

          expected_message = "text/bogus is not a valid type, valid types are " \
            "#{BetterHtml::TestHelper::SafeErb::AllowedScriptType::VALID_JAVASCRIPT_TAG_TYPES.join(", ")}"
          assert_equal expected_message, errors.first.message
        end

        private

        def validate(data, template_language: :html)
          parser = BetterHtml::Parser.new(buffer(data), template_language: template_language)
          tester = BetterHtml::TestHelper::SafeErb::AllowedScriptType.new(parser, config: @config)
          tester.validate
          tester
        end
      end
    end
  end
end
