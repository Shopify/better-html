<h1 align="center">better_html (DEPRECATED)</h1>

> This project is no longer actively maintained. It has been superseded by the tools and guidance available at **https://herb-tools.dev/**.

## Deprecation Notice

`better_html` served to introduce HTML-aware ERB parsing and runtime safety validations for Rails templates. We are sunsetting further development and recommend migrating to the modern ecosystem and practices documented at:

https://herb-tools.dev/

Key improvements you'll find there:

* Updated guidance for template safety and escaping
* Modern alternatives and linters
* Consolidated tooling replacing this gem's runtime checks
* Actively maintained documentation and examples

## What does this mean?

* No new features will be added here.
* Only critical security issues may receive patches (best-effort, not guaranteed).
* Issues and PRs may be closed without merge if they introduce new functionality.

## Should I remove the gem?

You can continue using the last released version, but you should plan a migration. Start by reviewing the concepts on herb-tools.dev and introducing the recommended tooling alongside or in place of `better_html`.

## Historical Documentation

The full original documentation (usage, configuration, helpers, parser details) has been preserved here:

➡️ [Original README (archived)](./README-old.md)

## License

This project remains available under the MIT License. See `MIT-LICENSE` for details.

## Thank You

Thank you to everyone who contributed to and adopted `better_html`. Your feedback and usage informed safer defaults in the Ruby & Rails ecosystem.
