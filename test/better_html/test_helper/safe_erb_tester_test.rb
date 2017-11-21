require 'test_helper'
require 'better_html/test_helper/safe_erb_tester'

module BetterHtml
  module TestHelper
    class SafeErbTesterTest < ActiveSupport::TestCase
      setup do
        @config = BetterHtml::Config.new(
          javascript_safe_methods: ['j', 'escape_javascript', 'to_json'],
          javascript_attribute_names: [/\Aon/i, 'data-eval'],
        )
      end

      test "multi line erb comments in text" do
        errors = parse(<<-EOF).errors
          text
          <%#
             this is a nice comment
             !@\#{$%?&*()}
          %>
        EOF

        assert_predicate errors, :empty?
      end

      test "multi line erb comments in html attribute" do
        errors = parse(<<-EOF).errors
          <div title="
            <%#
               this is a comment right in the middle of an attribute for some reason
            %>
            ">
        EOF

        assert_predicate errors, :empty?
      end

      test "string without interpolation is safe" do
        errors = parse(<<-EOF).errors
          <a onclick="alert('<%= "something" %>')">
        EOF

        assert_equal 0, errors.size
      end

      test "string with interpolation" do
        errors = parse(<<-EOF).errors
          <a onclick="<%= "hello \#{name}" %>">
        EOF

        assert_equal 1, errors.size
        assert_equal '"hello #{name}"', errors.first.location.source
        assert_equal "erb interpolation in javascript attribute must call '(...).to_json'", errors.first.message
      end

      test "string with interpolation and ternary" do
        errors = parse(<<-EOF).errors
          <a onclick="<%= "hello \#{foo ? bar : baz}" if bla? %>">
        EOF

        assert_equal 2, errors.size

        assert_equal '"hello #{foo ? bar : baz}" if bla?', errors.first.location.source
        assert_equal "erb interpolation in javascript attribute must call '(...).to_json'", errors.first.message

        assert_equal '"hello #{foo ? bar : baz}" if bla?', errors.first.location.source
        assert_equal "erb interpolation in javascript attribute must call '(...).to_json'", errors.first.message
      end

      test "plain erb tag in html attribute" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= unsafe %>)">
        EOF

        assert_equal 1, errors.size
        assert_equal 'unsafe', errors.first.location.source
        assert_equal "erb interpolation in javascript attribute must call '(...).to_json'", errors.first.message
      end

      test "to_json is safe in html attribute" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= unsafe.to_json %>)">
        EOF
        assert_predicate errors, :empty?
      end

      test "ternary with safe javascript escaping" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= foo ? bar.to_json : j(baz) %>)">
        EOF
        assert_predicate errors, :empty?
      end

      test "ternary with unsafe javascript escaping" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= foo ? bar : j(baz) %>)">
        EOF

        assert_equal 1, errors.size
        assert_equal 'foo ? bar : j(baz)', errors.first.location.source
        assert_equal "erb interpolation in javascript attribute must call '(...).to_json'", errors.first.message
      end

      test "j is safe in html attribute" do
        errors = parse(<<-EOF).errors
          <a onclick="method('<%= j unsafe %>')">
        EOF
        assert_predicate errors, :empty?
      end

      test "j() is safe in html attribute" do
        errors = parse(<<-EOF).errors
          <a onclick="method('<%= j(unsafe) %>')">
        EOF
        assert_predicate errors, :empty?
      end

      test "escape_javascript is safe in html attribute" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= escape_javascript unsafe %>)">
        EOF
        assert_predicate errors, :empty?
      end

      test "escape_javascript() is safe in html attribute" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= escape_javascript(unsafe) %>)">
        EOF
        assert_predicate errors, :empty?
      end

      test "html_safe is never safe in html attribute, even non javascript attributes like href" do
        errors = parse(<<-EOF).errors
          <a href="<%= unsafe.html_safe %>">
        EOF

        assert_equal 1, errors.size
        assert_equal 'unsafe.html_safe', errors.first.location.source
        assert_equal "erb interpolation with '<%= (...).html_safe %>' inside html attribute is never safe", errors.first.message
      end

      test "html_safe is never safe in html attribute, even with to_json" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= unsafe.to_json.html_safe %>)">
        EOF

        assert_equal 1, errors.size
        assert_equal 'unsafe.to_json.html_safe', errors.first.location.source
        assert_equal "erb interpolation with '<%= (...).html_safe %>' inside html attribute is never safe", errors.first.message
      end

      test "<%== is never safe in html attribute, even non javascript attributes like href" do
        errors = parse(<<-EOF).errors
          <a href="<%== unsafe %>">
        EOF

        assert_equal 1, errors.size
        assert_equal '<%== unsafe %>', errors.first.location.source
        assert_includes "erb interpolation with '<%==' inside html attribute is never safe", errors.first.message
      end

      test "<%== is never safe in html attribute, even with to_json" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%== unsafe.to_json %>)">
        EOF

        assert_equal 1, errors.size
        assert_equal '<%== unsafe.to_json %>', errors.first.location.source
        assert_includes "erb interpolation with '<%==' inside html attribute is never safe", errors.first.message
      end

      test "raw is never safe in html attribute, even non javascript attributes like href" do
        errors = parse(<<-EOF).errors
          <a href="<%= raw unsafe %>">
        EOF

        assert_equal 1, errors.size
        assert_equal 'raw unsafe', errors.first.location.source
        assert_equal "erb interpolation with '<%= raw(...) %>' inside html attribute is never safe", errors.first.message
      end

      test "raw is never safe in html attribute, even with to_json" do
        errors = parse(<<-EOF).errors
          <a onclick="method(<%= raw unsafe.to_json %>)">
        EOF

        assert_equal 1, errors.size
        assert_equal 'raw unsafe.to_json', errors.first.location.source
        assert_equal "erb interpolation with '<%= raw(...) %>' inside html attribute is never safe", errors.first.message
      end

      test "unsafe erb in <script> tag without type" do
        errors = parse(<<-EOF).errors
          <script>
            if (a < 1) { <%= unsafe %> }
          </script>
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= unsafe %>', errors.first.location.source
        assert_equal "erb interpolation in javascript tag must call '(...).to_json'", errors.first.message
      end

      test "unsafe erb in javascript template" do
        errors = parse(<<-JS, template_language: :javascript).errors
          if (a < 1) { <%= unsafe %> }
        JS

        assert_equal 1, errors.size
        assert_equal '<%= unsafe %>', errors.first.location.source
        assert_equal "erb interpolation in javascript tag must call '(...).to_json'", errors.first.message
      end

      test "<script> tag without calls is unsafe" do
        errors = parse(<<-EOF).errors
          <script type="text/javascript">
            if (a < 1) { <%= "unsafe" %> }
          </script>
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= "unsafe" %>', errors.first.location.source
        assert_equal "erb interpolation in javascript tag must call '(...).to_json'", errors.first.message
      end

      test "javascript template without calls is unsafe" do
        errors = parse(<<-JS, template_language: :javascript).errors
          if (a < 1) { <%= "unsafe" %> }
        JS

        assert_equal 1, errors.size
        assert_equal '<%= "unsafe" %>', errors.first.location.source
        assert_equal "erb interpolation in javascript tag must call '(...).to_json'", errors.first.message
      end

      test "unsafe erb in javascript_tag" do
        errors = parse(<<-EOF).errors
          <%= javascript_tag do %>
            if (a < 1) { <%= unsafe %> }
          <% end %>
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= javascript_tag do %>', errors.first.location.source
        assert_includes "'javascript_tag do' syntax is deprecated; use inline <script> instead", errors.first.message
      end

      test "unsafe erb in <script> tag with text/javascript content type" do
        errors = parse(<<-EOF).errors
          <script type="text/javascript">
            if (a < 1) { <%= unsafe %> }
          </script>
        EOF

        assert_equal 1, errors.size
        assert_equal '<%= unsafe %>', errors.first.location.source
        assert_equal "erb interpolation in javascript tag must call '(...).to_json'", errors.first.message
      end

      test "<script> tag with non executable content type is ignored" do
        errors = parse(<<-EOF).errors
          <script type="text/html">
            <a onclick="<%= unsafe %>">
          </script>
        EOF

        assert_predicate errors, :empty?
      end

      test "statements not allowed in script tags" do
        errors = parse(<<-EOF).errors
          <script type="text/javascript">
            <% if foo? %>
              bla
            <% end %>
          </script>
        EOF

        assert_equal 1, errors.size
        assert_equal "<% if foo? %>", errors.first.location.source
        assert_equal "erb statement not allowed here; did you mean '<%=' ?", errors.first.message
      end

      test "disallowed script types" do
        errors = parse(<<-EOF).errors
          <script type="text/bogus">
          </script>
        EOF

        assert_equal 1, errors.size
        assert_equal 'type="text/bogus"', errors.first.location.source
        assert_equal "text/bogus is not a valid type, valid types are text/javascript, text/template, text/html", errors.first.message
      end

      test "statements not allowed in javascript template" do
        errors = parse(<<-JS, template_language: :javascript).errors
          <% if foo %>
            bla
          <% end %>
        JS

        assert_equal 1, errors.size
        assert_equal "<% if foo %>", errors.first.location.source
        assert_equal "erb statement not allowed here; did you mean '<%=' ?", errors.first.message
      end

      test "erb comments allowed in scripts" do
        errors = parse(<<-EOF).errors
          <script type="text/javascript">
            <%# comment %>
          </script>
        EOF

        assert_predicate errors, :empty?
      end

      test "script tag without content" do
        errors = parse(<<-EOF).errors
          <script type="text/javascript"></script>
        EOF

        assert_predicate errors, :empty?
      end

      test "statement after script regression" do
        errors = parse(<<-EOF).errors
          <script type="text/javascript">
            foo()
          </script>
          <% if condition? %>
        EOF

        assert_predicate errors, :empty?
      end

      test "<script> with to_json is safe" do
        errors = parse(<<-EOF).errors
          <script type="text/javascript">
            <%= unsafe.to_json %>
          </script>
        EOF

        assert_predicate errors, :empty?
      end

      test "javascript template with to_json is safe" do
        errors = parse(<<-JS, template_language: :javascript).errors
          <%= unsafe.to_json %>
        JS

        assert_predicate errors, :empty?
      end

      test "<script> with raw and to_json is safe" do
        errors = parse(<<-EOF).errors
          <script type="text/javascript">
            <%= raw unsafe.to_json %>
          </script>
        EOF

        assert_predicate errors, :empty?
      end

      test "javascript template with raw and to_json is safe" do
        errors = parse(<<-JS, template_language: :javascript).errors
          <%= raw unsafe.to_json %>
        JS

        assert_predicate errors, :empty?
      end

      test "end statements are allowed in script tags" do
        errors = parse(<<-EOF).errors
          <script type="text/template">
            <%= ui_form do %>
              <div></div>
            <% end %>
          </script>
        EOF

        assert_predicate errors, :empty?
      end

      test "statements are allowed in text/html tags" do
        errors = parse(<<-EOF).errors
          <script type="text/html">
            <% if condition? %>
              <div></div>
            <% end %>
          </script>
        EOF

        assert_predicate errors, :empty?
      end

      test "unsafe javascript methods in helper calls with new hash syntax" do
        errors = parse(<<-EOF).errors
          <%= ui_my_helper(:foo, onclick: "alert(\#{unsafe})", onmouseover: "alert(\#{unsafe.to_json})") %>
        EOF

        assert_equal 1, errors.size
        assert_equal "\#{unsafe}", errors[0].location.source
        assert_equal "erb interpolation in javascript attribute must call '(...).to_json'", errors[0].message
      end

      test "unsafe javascript methods in helper calls with old hash syntax" do
        errors = parse(<<-EOF).errors
          <%= ui_my_helper(:foo, :onclick => "alert(\#{unsafe})") %>
        EOF

        assert_equal 1, errors.size
        assert_equal "\#{unsafe}", errors.first.location.source
        assert_equal "erb interpolation in javascript attribute must call '(...).to_json'", errors.first.message
      end

      test "unsafe javascript methods in helper calls with string as key" do
        errors = parse(<<-EOF).errors
          <%= ui_my_helper(:foo, 'data-eval' => "alert(\#{unsafe})") %>
        EOF

        assert_equal 1, errors.size
        assert_equal "\#{unsafe}", errors.first.location.source
        assert_equal "erb interpolation in javascript attribute must call '(...).to_json'", errors.first.message
      end

      test "unsafe javascript methods in helper calls with nested data key" do
        errors = parse(<<-EOF).errors
          <%= ui_my_helper(:foo, data: { eval: "alert(\#{unsafe})" }) %>
        EOF

        assert_equal 1, errors.size
        assert_equal "\#{unsafe}", errors.first.location.source
        assert_equal "erb interpolation in javascript attribute must call '(...).to_json'", errors.first.message
      end

      test "ivar missing .to_json is unsafe" do
        errors = parse('<script><%= @feature.html_safe %></script>').errors

        assert_equal 1, errors.size
        assert_equal "<%= @feature.html_safe %>", errors.first.location.source
        assert_equal "erb interpolation in javascript tag must call '(...).to_json'", errors.first.message
      end

      private
      def parse(data, template_language: :html)
        SafeErbTester::Tester.new(data, config: @config, template_language: template_language)
      end
    end
  end
end
