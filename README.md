# Improve html in your Rails app.

This gem replaces the normal ERB parsing with an HTML-aware ERB parsing.
This makes your templates smarter by adding runtime checks around the data
interpolated from Ruby into HTML.

## How to use

Add better-html to your Gemfile with its dependency:
```ruby
gem "better_html"
```

### Helpers

If you want to use `html_attributes` helper as described further down, add it to your `app/helpers/application_helper.rb`,

```ruby
module ApplicationHelper
  include BetterHtml::Helpers

  ...
```

## Configuration

A global configuration for the app is stored at `BetterHtml.config`. The default
configuration can be changed like this:

```ruby
# config/initializers/better_html.rb
BetterHtml.configure do |config|
  config.allow_single_quoted_attributes = false
end
```

or if you prefer storing the config elsewhere, in a yml file for example:

```ruby
# config/initializers/better_html.rb
BetterHtml.config = BetterHtml::Config.new(YAML.load(File.read('/path/to/.better-html.yml')))
```

Available configuration options are:

* `partial_tag_name_pattern`: Regex to validate `foo` in `<foo>`. Defaults to `/\A[a-z0-9\-\:]+\z/`.
* `partial_attribute_name_pattern`: Regex to validate `bar` in `<foo bar=1>`. Defaults to `/\A[a-zA-Z0-9\-\:]+\z/`.
* `allow_single_quoted_attributes`: When true, `<foo bar='1'>` is valid syntax. Defaults to `true`.
* `allow_unquoted_attributes`: When true, `<foo bar=1>` is valid syntax. Defaults to `false`.
* `javascript_safe_methods`: List of methods that return javascript-safe strings. This list is used
  by `SafeErbTester` when determining whether ruby interpolation is safe for a given attribute.
  Defaults to `['to_json']`.
* `lodash_safe_javascript_expression`: Same as `javascript_safe_methods`, but for lodash templates.
  Defaults to `[/\AJSON\.stringify\(/]`.
* `javascript_attribute_names`: List of all attribute names that contain javascript code. This list is used
  by `SafeErbTester` when determining whether or not a given attribute value will be eval'ed as javascript.
  Defaults to `[/\Aon/i]` (matches `onclick` for example).
* `template_exclusion_filter`: This is called when determining whether to apply runtime checks on a `.erb` template.
  When this `Proc` returns false, no safety checks are applied and parsing is done using the default Rails erubi engine.
  For example, to exclude erb templates provided by libraries, use: `Proc.new { |filename| !filename.start_with?(Rails.root.to_s) }`.
  Defaults to `nil` (all html.erb templates are parsed).

By default, only files named `.html.erb` are parsed at runtime using BetterHtml's erubi implementation.
To change this behavior and parse other file types, assign the erubi implementation into `BetterHtml::BetterErb.content_types` like this:

```ruby
# config/initializers/better_html.rb
impl = BetterHtml::BetterErb.content_types['html.erb']
BetterHtml::BetterErb.content_types['htm.erb'] = impl
BetterHtml::BetterErb.content_types['atom.erb'] = impl
BetterHtml::BetterErb.content_types['html+variant.erb'] = impl
```

## Syntax restriction

In order to apply effective runtime checks, it is necessary to enforce the
validity of all HTML contained in an application's  templates. This comes with an opinionated
approach to what ERB syntax is allowed given any HTML context. The next section
describes the allowed syntax.

Use ruby expressions inside quoted html attributes.
```erb
Allowed ✅
<img class="<%= value %>">

Not allowed ❌
<img <%= value %>>

Not allowed ❌
<img class=<%= value %>>
```

Use interpolation into tag or attribute names.
```erb
Allowed ✅
<img data-<%= value %>="true">

Allowed ✅
<ns:<%= value %>>

Not allowed ❌ (missing space after closing quote)
<img class="hidden"<%= value %>>

Not allowed ❌
<img <%= value %>="true">
```

Insert conditional attributes using `html_attributes` helper.
```erb
Allowed ✅
<img <%= html_attributes(class: 'hidden') if condition? %>>

Not allowed ❌
<img <% if condition? %>class="hidden"<% end %>>
```

Only insert expressions (`<%=` or `<%==`) inside script tags, never statements (`<%`)
```erb
<script>
  // Allowed ✅
  var myValue = <%== value.to_json %>;
  if(myValue)
    doSomething();

  // Not allowed ❌
  <% if value %>
    doSomething();
  <% end %>
</script>
```

## Runtime validations of html attributes

Looking only at a ERB file, it's impossible to determine if a given
Ruby value is safe to interpolate. For example, consider:

```erb
<img class="<%= value %>">
```

Assuming `value` may not be escaped properly and could contain a
double-quote character (`"`) at runtime, then the resulting HTML would be invalid,
and the application would be vulnerable to XSS when `value` is user-controlled.

With HTML-aware ERB parsing, we wrap `value` into a runtime safety check that raises
and exception when `value` contains a dobule-quote character that would terminate
the html attribute. The safety check is performed after normal ERB escaping rules
are applied, so the standard html_safe helper can be used.

The `html_attributes` helper works the same way, it will raise when attribute values
are escaped improperly.

## Runtime validations of tag and attribute names

Consider the following ERB template

```erb
<img data-<%= value %>="true">
```

When `value` is user-controlled, an attacker may achieve XSS quite easily in this
situation. We wrap `value` in a runtime check that ensures it only contains characters
that are valid in a attribute name. This excludes `=`, `/` or space, which should
prevent any risk of injection.

The `html_attributes` helper works the same way, it will raise when attribute names
contain dangerous characters.

## Runtime validations of "raw text" tags (script, textarea, etc)

Consider the following ERB template:

```erb
<script>
  var myValue = <%== value.to_json %>;
</script>
```

In circumstances where `value` may contain input such as `</script><script>`,
an attacker can easily achieve XSS. We make
best-effort runtime validations on this value in order to make it safe against
some obvious attacks.

We wrap the contents of the script tag, including everything between the
original `<script>` and `</script>`, into a safety check that raises an exception
if a rogue `</script>` tag is inserted as a result of ruby data being interpolated
anywhere.

The same strategy is applied to other tags which contain non-html data,
such as `<textarea>`, html comments and CDATA tags.

## Testing for valid HTML and ERB

In addition to runtime validation, this gem provides test helpers that makes
it easy to write a test to assert `.to_json` is used in every script tag and
every html attribute which end up being executed as javascript (onclick and similar).
The main goal of this helper is to assert that Ruby data translates into Javascript
data, but never becomes javascript code.

Simply create `test/unit/erb_safety_test.rb` and add code like this:

```ruby
require 'test_helper'
require 'better_html/test_helper/safe_erb_tester'

class ErbSafetyTest < ActiveSupport::TestCase
  include BetterHtml::TestHelper::SafeErbTester

  ERB_GLOB = File.join(Rails.root, 'app/views/**/{*.htm,*.html,*.htm.erb,*.html.erb,*.html+*.erb}')

  Dir[ERB_GLOB].each do |filename|
    test "missing javascript escapes in #{Pathname.new(filename).relative_path_from(Rails.root)}" do
      assert_erb_safety File.read(filename)
    end
  end
end
```

You may also want to assert that all `.html.erb` templates are parseable, to avoid deploying
broken templates to production. Add this code in `test/unit/erb_implementation_test.rb`

```ruby
require 'test_helper'

class ErbImplementationTest < ActiveSupport::TestCase
  ERB_GLOB = File.join(Rails.root, 'app/views/**/{*.htm,*.html,*.htm.erb,*.html.erb,*.html+*.erb}')

  Dir[ERB_GLOB].each do |filename|
    test "html errors in #{Pathname.new(filename).relative_path_from(Rails.root)}" do
      data = File.read(filename)
      BetterHtml::BetterErb::ErubiImplementation.new(data).validate!
    end
  end
end
```
