require 'test_helper'
require 'better_html/test_helper/safe_erb_tester'

module BetterHtml
  module TestHelper
    class SafeErbTesterTest < ActiveSupport::TestCase
      setup do
        BetterHtml.config
          .stubs(:javascript_safe_methods)
          .returns(['j', 'escape_javascript', 'to_json'])
      end

      test "string without interpolation is safe" do
        errors = parse(<<-EOF).errors
          <a onclick="alert('<%= "something" %>')">
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= "something" %>', errors.first.token.text
        assert_equal "erb interpolation in javascript attribute must call '(...).to_json'", errors.first.message
      end

      test "string with interpolation" do
        errors = parse(<<-EOF).errors
          <a onclick="<%= "hello \#{name}" %>">
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= "hello #{name}" %>', errors.first.token.text
        assert_equal "erb interpolation in javascript attribute must call '(...).to_json'", errors.first.message
      end

      test "string with interpolation and ternary" do
        errors = parse(<<-EOF).errors
          <a onclick="<%= "hello \#{foo ? bar : baz}" if bla? %>">
        EOF

        assert_equal 2, errors.size

        assert_equal '<%= "hello #{foo ? bar : baz}" if bla? %>', errors.first.token.text
        assert_equal "erb interpolation in javascript attribute must call '(...).to_json'", errors.first.message

        assert_equal '<%= "hello #{foo ? bar : baz}" if bla? %>', errors.first.token.text
        assert_equal "erb interpolation in javascript attribute must call '(...).to_json'", errors.first.message
      end

      test "plain erb tag in html attribute" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= unsafe %>)">
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= unsafe %>', errors.first.token.text
        assert_equal "erb interpolation in javascript attribute must call '(...).to_json'", errors.first.message
      end

      test "to_json is safe in html attribute" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= unsafe.to_json %>)">
        EOF
        assert_equal [], errors
      end

      test "ternary with safe javascript escaping" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= foo ? bar.to_json : j(baz) %>)">
        EOF
        assert_equal [], errors
      end

      test "ternary with unsafe javascript escaping" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= foo ? bar : j(baz) %>)">
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= foo ? bar : j(baz) %>', errors.first.token.text
        assert_equal "erb interpolation in javascript attribute must call '(...).to_json'", errors.first.message
      end

      test "j is safe in html attribute" do
        errors = parse(<<-EOF).errors
          <a onclick="method('<%= j unsafe %>')">
        EOF
        assert_equal 0, errors.size
      end

      test "j() is safe in html attribute" do
        errors = parse(<<-EOF).errors
          <a onclick="method('<%= j(unsafe) %>')">
        EOF
        assert_equal 0, errors.size
      end

      test "escape_javascript is safe in html attribute" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= escape_javascript unsafe %>)">
        EOF
        assert_equal 0, errors.size
      end

      test "escape_javascript() is safe in html attribute" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= escape_javascript(unsafe) %>)">
        EOF
        assert_equal 0, errors.size
      end

      test "html_safe is never safe in html attribute, even non javascript attributes like href" do
        errors = parse(<<-EOF).errors
          <a href="<%= unsafe.html_safe %>">
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= unsafe.html_safe %>', errors.first.token.text
        assert_equal "erb interpolation with '<%= (...).html_safe %>' inside html attribute is never safe", errors.first.message
      end

      test "html_safe is never safe in html attribute, even with to_json" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= unsafe.to_json.html_safe %>)">
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= unsafe.to_json.html_safe %>', errors.first.token.text
        assert_equal "erb interpolation with '<%= (...).html_safe %>' inside html attribute is never safe", errors.first.message
      end

      test "<%== is never safe in html attribute, even non javascript attributes like href" do
        errors = parse(<<-EOF).errors
          <a href="<%== unsafe %>">
        EOF

        assert_equal 1, errors.size
        assert_equal '<%== unsafe %>', errors.first.token.text
        assert_includes "erb interpolation with '<%==' inside html attribute is never safe", errors.first.message
      end

      test "<%== is never safe in html attribute, even with to_json" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%== unsafe.to_json %>)">
        EOF

        assert_equal 1, errors.size
        assert_equal '<%== unsafe.to_json %>', errors.first.token.text
        assert_includes "erb interpolation with '<%==' inside html attribute is never safe", errors.first.message
      end

      test "raw is never safe in html attribute, even non javascript attributes like href" do
        errors = parse(<<-EOF).errors
          <a href="<%= raw unsafe %>">
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= raw unsafe %>', errors.first.token.text
        assert_equal "erb interpolation with '<%= raw(...) %>' inside html attribute is never safe", errors.first.message
      end

      test "raw is never safe in html attribute, even with to_json" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= raw unsafe.to_json %>)">
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= raw unsafe.to_json %>', errors.first.token.text
        assert_equal "erb interpolation with '<%= raw(...) %>' inside html attribute is never safe", errors.first.message
      end

      test "unsafe erb in <script> tag without type" do
        errors = parse(<<-EOF).errors
          <script>
            if (a < 1) { <%= unsafe %> }
          </script>
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= unsafe %>', errors.first.token.text
        assert_equal "erb interpolation in javascript tag must call '(...).to_json'", errors.first.message
      end

      test "<script> tag without calls is unsafe" do
        errors = parse(<<-EOF).errors
          <script>
            if (a < 1) { <%= "unsafe" %> }
          </script>
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= "unsafe" %>', errors.first.token.text
        assert_equal "erb interpolation in javascript tag must call '(...).to_json'", errors.first.message
      end

      test "unsafe erb in javascript_tag" do
        errors = parse(<<-EOF).errors
          <%= javascript_tag do %>
            if (a < 1) { <%= unsafe %> }
          <% end %>
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= javascript_tag do %>', errors.first.token.text
        assert_includes "'javascript_tag do' syntax is deprecated; use inline <script> instead", errors.first.message
      end

      test "unsafe erb in <script> tag with text/javascript content type" do
        errors = parse(<<-EOF).errors
          <script type="text/javascript">
            if (a < 1) { <%= unsafe %> }
          </script>
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= unsafe %>', errors.first.token.text
        assert_equal "erb interpolation in javascript tag must call '(...).to_json'", errors.first.message
      end

      test "<script> tag with non executable content type is ignored" do
        errors = parse(<<-EOF).errors
          <script type="text/html">
            <a onclick="<%= unsafe %>">
          </script>
        EOF

        assert_equal 0, errors.size
      end

      test "statements not allowed in script tags" do
        errors = parse(<<-EOF).errors
          <script type="text/javascript">
            <% if foo? %>
              bla
            <% end %>
          </script>
        EOF

        assert_equal 2, errors.size
        assert_equal "<%             if foo? \n%>", errors.first.token.text
        assert_equal "erb statement not allowed here; did you mean '<%=' ?", errors.first.message
        assert_equal "<%             end \n%>", errors.last.token.text
        assert_equal "erb statement not allowed here; did you mean '<%=' ?", errors.last.message
      end

      test "script tag without content" do
        errors = parse(<<-EOF).errors
          <script type="text/javascript"></script>
        EOF

        assert_equal 0, errors.size
      end

      private
      def parse(data)
        SafeErbTester.new(data)
      end
    end
  end
end
