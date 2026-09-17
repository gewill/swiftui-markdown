# Changelog

All notable changes to this fork are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This file starts at the last upstream sync, [`ccf278a`][upstream sync]
(2026-05-28). Version 1.1.0 and everything before it belong to
[jaywcjlove/swiftui-markdown](https://github.com/jaywcjlove/swiftui-markdown);
see that repository for their history. Entries below are the changes this fork
adds on top of that baseline.

## [Unreleased]

### Added

- DocC documentation for the public API, with a landing page and an article on
  bundling fonts. `.spi.yml` lets Swift Package Index build and host it ([#18]).

### Changed

- Strip the README down to this fork. It carried the upstream author's app
  promotion banner, sponsor and social badges, a CI badge reporting another
  repository's builds, and installation instructions pointing at the upstream
  package — following them installed something else. The platform badge said
  macOS 10.15 and iOS 13, where the package requires macOS 11, iOS 14 and
  visionOS 1. The example pages carried copies of the same badges and URL
  ([#19]).

### Fixed

- Links to `markdownStyle(_:)` in the documentation resolve. They named the
  `SwiftUI` module, but `View` lives in `SwiftUICore` in current SDKs, so all
  four rendered as plain text. The build that produced them reported no
  problems only because DocC was reusing cached output ([#20]).

### Internal

- Documentation is built on every pull request with warnings as errors, so a
  link that stops resolving fails CI ([#20]).
- The site workflow no longer asks GitHub for the latest release. It did so only
  to word a commit message, and failed on every push to `main` until the first
  release existed. It is renamed from "CI" to "Deploy Site", since the tests
  live in their own workflow ([#20]).
- Only the site workflow publishes the gh-pages branch; the release workflow
  duplicated that build and now only creates the release, linking to the
  documentation on Swift Package Index ([#20]).


## [2.0.0] - 2026-09-16

Custom font support for the Markdown preview, plus the correctness, performance
and API work that followed from reviewing it, and the renderer sync that came
out of asking where the HTML actually comes from. Major because of the two
public API changes marked **Breaking** below; the renderer also crossed two of
its own major versions.

### Added

- Font configuration on `MarkdownStyle`: `fontFamily`, `fontSize`, `lineHeight`
  and `codeFontFamily`. Every field is optional on its own, so changing only the
  size keeps the default typeface ([#2], [#10]).
- `MarkdownFontFace` and `MarkdownFontSource` for loading a face from a file URL,
  an app resource, or an explicit `Bundle`. Faces are injected as `@font-face`
  rules carrying a base64 data URL, so the WebView never reads across bundles
  ([#2]).
- Style changes made through `.markdownStyle(_:)` now reach a live WebView.
  Previously they only applied when the view was created ([#2]).
- A Fonts page in the example app covering system stacks and the bundled
  Atkinson Hyperlegible and Merriweather four-face families ([#2]).
- Continuous integration: the test suite plus the macOS and iOS example builds
  run on every pull request. The only previous workflow rendered the README into
  a site on pushes to `main`, so nothing ran the tests ([#2]).

### Changed

- **Breaking.** `MarkdownFontFace` takes `MarkdownFontWeight` and
  `MarkdownFontStyle` instead of `String?`. They cover what `@font-face`
  accepts — `.normal`, `.bold`, `.value(700)`, `.range(400, 700)`, `.italic`,
  `.oblique`, `.obliqueAngle(14)` — and a value CSS would reject is dropped with
  a log rather than written into the rule. Migration: `fontWeight: "700"` becomes
  `.bold` or `.value(700)`, `fontStyle: "italic"` becomes `.italic` ([#10]).
- **Breaking.** `MarkdownStyle` has one initialiser instead of five. Three of the
  old ones differed only in which padding arguments they accepted, and the two
  that took font settings required `fontFamily`. Padding behaviour is unchanged:
  per-edge values apply over `padding`, so passing only `paddingTop` leaves the
  other three edges at the default. Call sites that pass only padding, or a full
  font configuration, compile unchanged ([#10]).
- Custom properties are written directly to `documentElement.style`, and
  `@font-face` rules live in their own element that is rebuilt only when the
  faces change, with the encoding done off the main thread. Previously every
  style change rewrote a single sheet holding both: for the four-face
  Merriweather family that meant re-sending and re-parsing 1.4 MB, which dropped
  every loaded font back to `unloaded` — changing only the font size flashed
  fallback text. A style update now ships 201 bytes instead of 1.5 MB, and
  escaping it on the main thread went from 9.6 ms to 0.08 ms ([#6]).
- Encoded faces are held in a bounded `NSCache` instead of a static dictionary
  that was never reclaimed ([#6]).
- `@font-face` declares `format()`, inferred from the file extension and omitted
  for unknown ones so WebKit can still sniff them ([#6]).
- The example ships its fonts as woff2: 1.3 MB of TrueType became 398 KB, and
  the OFL texts are in the built app, which previously shipped the fonts without
  the license the OFL asks to accompany them ([#9]).

- Sync the bundled renderer, `@wcj/markdown-to-html`, from 1.0.0 (2022) to 3.0.6.
  Its public surface is unchanged — `markdown.default()`, `getCodeString()` and
  the `rewrite` option all behave the same — and the minified bundle drops from
  3.2 MB to 1.2 MB. The stylesheet it ships was re-patched with this fork's font
  variables rather than overwritten ([#14]).

### Fixed

- Theme switching works. `setTheme` was adding `theme-light` and `theme-dark`
  classes that no stylesheet has ever read; light and dark actually came from
  the `prefers-color-scheme` queries in the old stylesheet, so the `theme`
  argument had no effect. 3.0.6 keys its colour variables off a
  `data-color-mode` attribute instead, which is now set on the document element
  — without it every colour variable would be undefined ([#14]).
- Drop the `.math.math-inline` rule. It existed to clear the grey background of
  the `<code>` element that used to wrap inline KaTeX; 3.0.6 emits the KaTeX
  span directly, so the rule matched nothing ([#14]).
- Fenced code blocks keep their monospace stack when only `fontFamily` is set.
  A single custom property fed both inline code and code blocks, so setting a
  body typeface turned code blocks into it and destroyed column alignment.
  Inline code still inherits the body font ([#2]).
- An `appResource` whose `bundleIdentifier` does not resolve drops the face
  instead of quietly searching the main bundle, where it could pick up an
  unrelated font with the same name. The missing-resource and unreadable-file
  paths log in debug builds ([#2]).
- The preview recovers when the web content process is terminated. The view kept
  believing the page was live, so every later update was dropped and the preview
  stayed blank until the view was recreated ([#8]).
- `@font-face` descriptors can no longer inject CSS. The rule is assembled as
  text, so a `font-weight` or `font-style` carrying `;` or `}` could close it and
  append rules of its own. Restricted in [#8] and made unrepresentable by the
  typed descriptors in [#10]. Family names were already safe: the escaped value
  parses as a single font name ([#8], [#10]).
- Calls issued before the page is ready are no longer silently discarded from
  paths that could reach them: the padding helpers are private, since they are
  only ever driven at the right time ([#8]).

- Name the renderer correctly. The preview has always been rendered by
  `@wcj/markdown-to-html`, built on unified/remark/rehype, not by
  [marked](https://github.com/markedjs/marked); `marked.css` is github-markdown-css
  under a misleading name. The README and three example pages said otherwise
  ([#13], [#12]).

### Removed

- `doc/custom-font-development-plan.md`, a progress table with every row marked
  done ([#9]).

### Internal

- Test coverage went from 8 to 23 cases. `javascriptStringLiteral` — the only
  thing between a Markdown style and arbitrary JavaScript, since the CSS it
  escapes is interpolated into an evaluated script — had none; its new cases were
  checked against a deliberately broken version of it. Reverting to the default
  style, the replay of updates queued before the page is ready, and the numeric
  bounds of the font descriptors are covered too ([#9], [#10]).
- The encoded-font cache can be reset, so a test asserting on encoding no longer
  reads an entry left by an earlier run ([#9]).
- `/build/` is anchored in `.gitignore`; the unanchored pattern ignored any file
  or directory with that name at any depth ([#9]).

[Unreleased]: https://github.com/gewill/swiftui-markdown/compare/v2.0.0...main
[2.0.0]: https://github.com/gewill/swiftui-markdown/compare/ccf278a...v2.0.0
[upstream sync]: https://github.com/gewill/swiftui-markdown/commit/ccf278a
[#2]: https://github.com/gewill/swiftui-markdown/pull/2
[#6]: https://github.com/gewill/swiftui-markdown/pull/6
[#8]: https://github.com/gewill/swiftui-markdown/pull/8
[#9]: https://github.com/gewill/swiftui-markdown/pull/9
[#10]: https://github.com/gewill/swiftui-markdown/pull/10
[#12]: https://github.com/gewill/swiftui-markdown/issues/12
[#13]: https://github.com/gewill/swiftui-markdown/pull/13
[#14]: https://github.com/gewill/swiftui-markdown/pull/14
[#18]: https://github.com/gewill/swiftui-markdown/pull/18
[#19]: https://github.com/gewill/swiftui-markdown/pull/19
[#20]: https://github.com/gewill/swiftui-markdown/pull/20
