# mdBook Theme Customizations

This directory overrides mdBook's default syntax highlighting stylesheets and Ruby grammar.

## Syntax Highlighting Theme (`Atom One`)

mdBook maps its five built-in book themes to three Highlight.js stylesheets:

* `highlight.css` — used by the **Light** and **Rust** book themes; contains Highlight.js's [`atom-one-light`](https://github.com/highlightjs/highlight.js/blob/main/src/styles/atom-one-light.css) theme.
* `tomorrow-night.css` — used by the **Navy** and **Coal** book themes; contains Highlight.js's [`atom-one-dark`](https://github.com/highlightjs/highlight.js/blob/main/src/styles/atom-one-dark.css) theme.
* `ayu-highlight.css` — used by the **Ayu** book theme; also contains [`atom-one-dark`](https://github.com/highlightjs/highlight.js/blob/main/src/styles/atom-one-dark.css) so all dark book themes share the same syntax palette.

## Custom `highlight.js`

mdBook ships with **Highlight.js v10.1.1** rather than v11+ because mdBook's hidden ["boring" lines](https://rust-lang.github.io/mdBook/format/mdbook.html#hiding-code-lines) feature relies on the internal `mergeStreams` API that was removed in Highlight.js v11.

However, the Ruby grammar in Highlight.js v10.1.1 only highlights class names in `class` / `module` definitions (`class Author`) and leaves standalone class/module references (`include Dynamoid::Document`, `Author.create`), `UPPER_CASE` constants, and `@instance_variables` unstyled.

To get Highlight.js v11 Ruby highlighting without breaking mdBook:

* `highlight.js` retains mdBook's bundled Highlight.js v10.1.1 core engine, with the `ruby` language definition (`hljs.registerLanguage("ruby", ...)`) upgraded to the [Highlight.js v11 Ruby grammar](https://github.com/highlightjs/highlight.js/blob/main/src/languages/ruby.js).
* **Caveat if upgrading `highlight.js` in the future:** Replacing this file with a stock Highlight.js v11+ bundle will break mdBook's hidden "boring" code lines feature and log deprecation warnings for `hljs.highlightBlock`.

## Custom Stylesheet (`custom.css`)

Registered via `additional-css` in `book.toml`. It provides two adjustments:

* Disables italic formatting on comments (`.hljs-comment`, `.hljs-quote`) so they render upright across all themes.
* Normalizes font size, weight, and line height on inline code in the sidebar navigation (`.sidebar code`). mdBook sets `line-height: 2em;` and bundles Source Code Pro only in weight 500 (Medium), which causes code items to appear with inflated vertical gaps and bolder strokes than surrounding 400-weight text. Setting `font-size: unset;`, `line-height: inherit;`, and using system monospace fonts at weight 400 keeps vertical spacing, stroke thickness, and font size consistent with neighboring plain-text chapter titles.
