# frozen_string_literal: true

require "test_helper"
require "ostruct"
require "better_html/better_erb"
require "json"

BetterHtml::BetterErb.prepend!

module BetterHtml
  class BetterErb
    class ImplementationTest < ActiveSupport::TestCase
      test "simple template rendering" do
        assert_equal "<foo>some value<foo>",
          render("<foo><%= bar %><foo>", locals: { bar: "some value" })
      end

      test "html_safe interpolation" do
        assert_equal "<foo><bar /><foo>",
          render("<foo><%= bar %><foo>", locals: { bar: "<bar />".html_safe })
      end

      test "non html_safe interpolation" do
        assert_equal "<foo>&lt;bar /&gt;<foo>",
          render("<foo><%= bar %><foo>", locals: { bar: "<bar />" })
      end

      test "interpolate non-html_safe inside attribute is escaped" do
        assert_equal "<a href=\" &#39;&quot;&gt;x \">",
          render("<a href=\"<%= value %>\">", locals: { value: ' \'">x ' })
      end

      test "interpolate html_safe inside attribute is magically force-escaped" do
        e = assert_raises(ActionView::Template::Error) do
          render("<a href=\"<%= value %>\">", locals: { value: ' \'">x '.html_safe })
        end
        assert_kind_of BetterHtml::UnsafeHtmlError, e.cause
        assert_equal "Detected invalid characters as part of the interpolation " \
          "into a quoted attribute value. The value cannot contain the character \".",
          e.message
      end

      test "interpolate html_safe inside single quoted attribute" do
        config = build_config(allow_single_quoted_attributes: true)
        e = assert_raises(ActionView::Template::Error) do
          render("<a href='<%= value %>'>", config: config, locals: { value: ' \'">x '.html_safe })
        end
        assert_kind_of BetterHtml::UnsafeHtmlError, e.cause
        assert_equal "Detected invalid characters as part of the interpolation " \
          "into a quoted attribute value. The value cannot contain the character '.",
          e.message
      end

      test "interpolate in attribute name" do
        assert_equal "<a data-safe-foo>",
          render("<a data-<%= value %>-foo>", locals: { value: "safe" })
      end

      test "interpolate in attribute name with unsafe value with spaces" do
        e = assert_raises(ActionView::Template::Error) do
          render("<a data-<%= value %>-foo>", locals: { value: "un safe" })
        end
        assert_kind_of BetterHtml::UnsafeHtmlError, e.cause
        assert_equal "Detected invalid characters as part of the interpolation " \
          "into a attribute name around 'data-<%= value %>'.",
          e.message
      end

      test "interpolate in attribute name with unsafe value with equal sign" do
        e = assert_raises(ActionView::Template::Error) do
          render("<a data-<%= value %>-foo>", locals: { value: "un=safe" })
        end
        assert_kind_of BetterHtml::UnsafeHtmlError, e.cause
        assert_equal "Detected invalid characters as part of the " \
          "interpolation into a attribute name around 'data-<%= value %>'.",
          e.message
      end

      test "interpolate in attribute name with unsafe value with quote" do
        e = assert_raises(ActionView::Template::Error) do
          render("<a data-<%= value %>-foo>", locals: { value: "un\"safe" })
        end
        assert_kind_of BetterHtml::UnsafeHtmlError, e.cause
        assert_equal "Detected invalid characters as part of the " \
          "interpolation into a attribute name around 'data-<%= value %>'.",
          e.message
      end

      test "interpolate after an attribute name without a value" do
        assert_equal '<a data-foo foo="bar">',
          render("<a data-foo <%= html_attributes(foo: 'bar') %>>")
      end

      test "interpolate after an attribute name with equal sign" do
        config = build_config(allow_unquoted_attributes: true, disable_parser_validation: true)
        e = assert_raises(ActionView::Template::Error) do
          render("<a data-foo=<%= html_attributes(foo: 'bar') %>>", config: config)
        end
        assert_kind_of BetterHtml::DontInterpolateHere, e.cause
        assert_equal "Do not interpolate without quotes after " \
          "attribute around 'data-foo=<%= html_attributes(foo: 'bar') %>'.",
          e.message
      end

      test "interpolate after an attribute value" do
        e = assert_raises(ActionView::Template::Error) do
          render("<a foo=\"xx\"<%= html_attributes(foo: 'bar') %>>")
        end
        assert_kind_of BetterHtml::DontInterpolateHere, e.cause
        assert_equal "Add a space after this attribute value. " \
          "Instead of <a foo=\"xx\"<%= html_attributes(foo: 'bar') %>> " \
          "try <a foo=\"xx\" <%= html_attributes(foo: 'bar') %>>.",
          e.message
      end

      test "interpolate in attribute without quotes" do
        config = build_config(allow_unquoted_attributes: true, disable_parser_validation: true)
        e = assert_raises(ActionView::Template::Error) do
          render("<a href=<%= value %>>", config: config, locals: { value: "un safe" })
        end
        assert_kind_of BetterHtml::DontInterpolateHere, e.cause
        assert_equal "Do not interpolate without quotes after " \
          "attribute around 'href=<%= value %>'.",
          e.message
      end

      test "interpolate in attribute after value" do
        config = build_config(allow_unquoted_attributes: true)
        e = assert_raises(ActionView::Template::Error) do
          render("<a href=something<%= value %>>", config: config, locals: { value: "" })
        end
        assert_kind_of BetterHtml::DontInterpolateHere, e.cause
        assert_equal "Do not interpolate without quotes around this " \
          "attribute value. Instead of <a href=something<%= value %>> " \
          "try <a href=\"something<%= value %>\">.",
          e.message
      end

      test "interpolate in tag name" do
        assert_equal "<tag-safe-foo>",
          render("<tag-<%= value %>-foo>", locals: { value: "safe" })
      end

      test "interpolate in tag name with space" do
        e = assert_raises(ActionView::Template::Error) do
          render("<tag-<%= value %>-foo>", locals: { value: "un safe" })
        end
        assert_kind_of BetterHtml::UnsafeHtmlError, e.cause
        assert_equal "Detected invalid characters as part of the interpolation " \
          "into a tag name around: <tag-<%= value %>>.",
          e.message
      end

      test "interpolate in tag name with slash" do
        e = assert_raises(ActionView::Template::Error) do
          render("<tag-<%= value %>-foo>", locals: { value: "un/safe" })
        end
        assert_kind_of BetterHtml::UnsafeHtmlError, e.cause
        assert_equal "Detected invalid characters as part of the interpolation " \
          "into a tag name around: <tag-<%= value %>>.",
          e.message
      end

      test "interpolate in tag name with end of tag" do
        e = assert_raises(ActionView::Template::Error) do
          render("<tag-<%= value %>-foo>", locals: { value: "><script>" })
        end
        assert_kind_of BetterHtml::UnsafeHtmlError, e.cause
        assert_equal "Detected invalid characters as part of the interpolation " \
          "into a tag name around: <tag-<%= value %>>.",
          e.message
      end

      test "interpolate in comment" do
        assert_equal "<!-- safe -->",
          render("<!-- <%= value %> -->", locals: { value: "safe" })
      end

      test "interpolate in comment with end-of-comment" do
        e = assert_raises(ActionView::Template::Error) do
          render("<!-- <%= value %> -->", locals: { value: "-->".html_safe })
        end
        assert_kind_of BetterHtml::UnsafeHtmlError, e.cause
        assert_equal "Detected invalid characters as part of the interpolation " \
          "into a html comment around: <!-- <%= value %>.",
          e.message
      end

      test "non html_safe interpolation into comment tag" do
        assert_equal "<!-- --&gt; -->",
          render("<!-- <%= value %> -->", locals: { value: "-->" })
      end

      test "interpolate in script tag" do
        assert_equal "<script> foo safe bar</script>",
          render("<script> foo <%= value %> bar</script>", locals: { value: "safe" })
      end

      test "interpolate in script tag with start of comment" do
        skip "skip for now; causing problems"
        e = assert_raises(ActionView::Template::Error) do
          render("<script> foo <%= value %> bar<script>", locals: { value: "<!--".html_safe })
        end
        assert_kind_of BetterHtml::UnsafeHtmlError, e.cause
        assert_equal "Detected invalid characters as part of the interpolation " \
          "into a script tag around: <script> foo <%= value %>. " \
          "A script tag cannot contain <script or </script anywhere inside of it.",
          e.message
      end

      test "interpolate in script tag with start of script" do
        e = assert_raises(ActionView::Template::Error) do
          render("<script> foo <%= value %> bar</script>", locals: { value: "<script".html_safe })
        end
        assert_kind_of BetterHtml::UnsafeHtmlError, e.cause
        assert_equal "Detected invalid characters as part of the interpolation " \
          "into a script tag around: <script> foo <%= value %>. " \
          "A script tag cannot contain <script or </script anywhere inside of it.",
          e.message
      end

      test "interpolate in script tag with raw interpolation" do
        assert_equal "<script> x = \"foo\" </script>",
          render("<script> x = <%== value %> </script>", locals: { value: JSON.dump("foo") })
      end

      test "interpolate in script tag with start of script case insensitive" do
        e = assert_raises(ActionView::Template::Error) do
          render("<script> foo <%= value %> bar</script>", locals: { value: "<ScRIpT".html_safe })
        end
        assert_kind_of BetterHtml::UnsafeHtmlError, e.cause
        assert_equal "Detected invalid characters as part of the interpolation " \
          "into a script tag around: <script> foo <%= value %>. " \
          "A script tag cannot contain <script or </script anywhere inside of it.",
          e.message
      end

      test "interpolate in script tag with end of script" do
        e = assert_raises(ActionView::Template::Error) do
          render("<script> foo <%= value %> bar</script>", locals: { value: "</script".html_safe })
        end
        assert_kind_of BetterHtml::UnsafeHtmlError, e.cause
        assert_equal "Detected invalid characters as part of the interpolation " \
          "into a script tag around: <script> foo <%= value %>. " \
          "A script tag cannot contain <script or </script anywhere inside of it.",
          e.message
      end

      test "interpolate html_attributes" do
        assert_equal "<a foo=\"bar\">",
          render("<a <%= html_attributes(foo: 'bar') %>>")
      end

      test "interpolate without html_attributes" do
        e = assert_raises(ActionView::Template::Error) do
          render("<a <%= 'foo=\"bar\"' %>>")
        end
        assert_kind_of BetterHtml::DontInterpolateHere, e.cause
        assert_equal "Do not interpolate String in a tag. Instead " \
          "of <a <%= 'foo=\"bar\"' %>> please try <a <%= html_attributes(attr: value) %>>.",
          e.message
      end

      test "non html_safe interpolation into rawtext tag" do
        assert_equal "<title>&lt;/title&gt;</title>",
          render("<title><%= value %></title>", locals: { value: "</title>" })
      end

      test "html_safe interpolation into rawtext tag" do
        assert_equal "<title><safe></title>",
          render("<title><%= value %></title>", locals: { value: "<safe>".html_safe })
      end

      test "html_safe interpolation terminating the current tag" do
        e = assert_raises(ActionView::Template::Error) do
          render("<title><%= value %></title>", locals: { value: "</title>".html_safe })
        end
        assert_kind_of BetterHtml::UnsafeHtmlError, e.cause
        assert_equal "Detected invalid characters as part of the interpolation " \
          "into a title tag around: <title><%= value %>.",
          e.message
      end

      test "interpolate block in middle of tag" do
        e = assert_raises(ActionView::Template::Error) do
          render(<<-HTML)
        <a href="" <%= something do %>
          foo
        <% end %>
          HTML
        end
        assert_kind_of BetterHtml::DontInterpolateHere, e.cause
        assert_equal "Ruby statement not allowed.\n" \
          "In 'tag' on line 1 column 19:\n        " \
          "<a href=\"\" <%= something do %>\n                   " \
          "^^^^^^^^^^^^^^^^^^^",
          e.message
      end

      test "interpolate with output block is valid syntax" do
        assert_nothing_raised do
          render(<<-HTML)
        <%= capture do %>
          <foo>
        <% end %>
          HTML
        end
      end

      test "interpolate with statement block is valid syntax" do
        assert_nothing_raised do
          render(<<-HTML)
        <% capture do %>
          <foo>
        <% end %>
          HTML
        end
      end

      test "can interpolate method calls without parenthesis" do
        assert_equal(
          "<div><input type=\"submit\" name=\"commit\" value=\"Save changes\" data-disable-with=\"Save changes\" />" \
            "</div>",
          render("<div><%= send 'submit_tag' %></div>"),
        )
      end

      test "tag names are validated against tag_name_pattern regexp" do
        e = assert_raises(ActionView::Template::Error) do
          render("<foo~bar></foo~bar>")
        end
        assert_kind_of BetterHtml::HtmlError, e.cause
        assert_equal "Invalid tag name \"foo~bar\" does not match regular expression /\\A[a-z0-9\\-\\:]+\\z/\n" \
          "On line 1 column 1:\n" \
          "<foo~bar></foo~bar>\n " \
          "^^^^^^^",
          e.message
      end

      test "attribute names are validated against attribute_name_pattern regexp" do
        e = assert_raises(ActionView::Template::Error) do
          render("<foo bar_baz=\"1\">")
        end
        assert_kind_of BetterHtml::HtmlError, e.cause
        assert_equal "Invalid attribute name \"bar_baz\" does not match regular expression " \
          "#{build_config.partial_attribute_name_pattern.inspect}\n" \
          "On line 1 column 5:\n" \
          "<foo bar_baz=\"1\">\n     " \
          "^^^^^^^",
          e.message
      end

      test "single quotes are disallowed when allow_single_quoted_attributes=false" do
        config = build_config(allow_single_quoted_attributes: false)
        e = assert_raises(ActionView::Template::Error) do
          render("<foo bar='1'>", config: config)
        end
        assert_kind_of BetterHtml::HtmlError, e.cause
        assert_equal "Single-quoted attributes are not allowed\n" \
          "On line 1 column 9:\n" \
          "<foo bar='1'>\n         " \
          "^",
          e.message
      end

      test "single quotes are allowed when allow_single_quoted_attributes=true" do
        config = build_config(allow_single_quoted_attributes: true)
        assert_nothing_raised do
          render("<foo bar='1'>", config: config)
        end
      end

      test "unquoted values are disallowed when allow_unquoted_attributes=false" do
        config = build_config(allow_unquoted_attributes: false)
        e = assert_raises(ActionView::Template::Error) do
          render("<foo bar=1>", config: config)
        end
        assert_kind_of BetterHtml::HtmlError, e.cause
        assert_equal "Unquoted attribute values are not allowed\n" \
          "On line 1 column 9:\n" \
          "<foo bar=1>\n         " \
          "^",
          e.message
      end

      test "unquoted values are allowed when allow_unquoted_attributes=true" do
        config = build_config(allow_unquoted_attributes: true)
        assert_nothing_raised do
          render("<foo bar=1>", config: config)
        end
      end

      if ActionView.version >= Gem::Version.new("6.1")
        test "with ActionView 6.1 comments are added to show the filename when annotate_rendered_view_with_filenames=true" do
          config = build_config(annotate_rendered_view_with_filenames: true)
          assert_equal "<!-- BEGIN _better_test.html.erb --><foo>bar<foo><!-- END _better_test.html.erb -->",
            render("<foo>bar<foo>", config: config, filename: "_better_test.html.erb")
        end
      else
        test "with ActionView 6.0 annotate_rendered_view_with_filenames=true does not change the output" do
          config = build_config(annotate_rendered_view_with_filenames: true)
          assert_equal "<foo>bar<foo>",
            render("<foo>bar<foo>", config: config, filename: "_better_test.html.erb")
        end
      end

      test "capture works as intended" do
        output = render(<<-HTML)
      <%- foo = capture do -%>
        <foo>
      <%- end -%>
      <bar><%= foo %></bar>
        HTML

        assert_equal "      <bar>        <foo>\n</bar>\n", output
      end

      test "validate! raises when tag is not terminated at end of document" do
        document = compile("<foo")
        e = assert_raises(BetterHtml::HtmlError) do
          document.validate!
        end
        assert_equal "Detected an open tag at the end of this document.", e.message
      end

      test "validate! raises when rawtext tag is not terminated at end of document" do
        document = compile("<script>")
        e = assert_raises(BetterHtml::HtmlError) do
          document.validate!
        end
        assert_equal "Detected an open tag at the end of this document.", e.message
      end

      test "validate! raises parsing error for attribute name" do
        document = compile("<foo bar~baz=\"1\">")
        e = assert_raises(BetterHtml::HtmlError) do
          document.validate!
        end
        assert_equal "2 error(s) found in HTML document.\n" \
          "expected whitespace, '>' or '=' after attribute name\n" \
          "On line 1 column 8:\n" \
          "<foo bar~baz=\"1\">\n        " \
          "^^^^^^^^^expected whitespace, '>', attribute name or value\n" \
          "On line 1 column 8:\n" \
          "<foo bar~baz=\"1\">\n        " \
          "^^^^^^^^^",
          e.message
      end

      private

      class ViewContext < ActionView::Base
        include(ActionView::Helpers)
        include(BetterHtml::Helpers)
        attr_accessor :output_buffer
      end

      def build_config(**options)
        BetterHtml::Config.new(**options)
      end

      def render(source, config: build_config, locals: {}, filename: "test.html.erb")
        old_config = BetterHtml.config
        BetterHtml.config = config

        ActionView::Template.new(
          source,
          filename,
          ActionView::Template::Handlers::ERB.new,
          virtual_path: "partial",
          format: :html,
          locals: locals.keys,
        ).render(ViewContext.with_empty_template_cache.empty, locals)
      ensure
        BetterHtml.config = old_config
      end

      def compile(source, config: build_config)
        BetterHtml::BetterErb::ErubiImplementation.new(source, config: config)
      end
    end
  end
end
