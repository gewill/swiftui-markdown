# Bundling fonts

Use a font your app ships, rather than one the system already has.

## Overview

A font stack in ``MarkdownStyle/fontFamily`` can only name fonts the web view
can already see. To use one your app bundles, describe its files with
``MarkdownFontFace`` so the preview installs them first.

Each file is read and embedded as a data URL, so the web view never has to
reach across bundle boundaries. `ttf`, `otf`, `woff` and `woff2` are supported;
`woff2` is the smallest.

### One file

The family name in the face and in the font stack has to match:

```swift
Markdown(content: $text)
    .markdownStyle(
        MarkdownStyle(
            fontFamily: "'LXGW WenKai', -apple-system, sans-serif",
            fontFaces: [
                MarkdownFontFace(
                    fontFamily: "LXGW WenKai",
                    source: .bundleResource(
                        name: "LXGWWenKai-Regular",
                        fileExtension: "woff2",
                        bundle: .main
                    )
                )
            ]
        )
    )
```

With only a regular file, WebKit synthesises bold and italic by slanting and
thickening it.

### A full family

For real bold and italic letterforms, give every file its own face and say what
it covers:

```swift
func face(
    _ name: String,
    _ weight: MarkdownFontWeight,
    _ style: MarkdownFontStyle
) -> MarkdownFontFace {
    MarkdownFontFace(
        fontFamily: "Merriweather",
        source: .appResource(name: name, fileExtension: "woff2", bundleIdentifier: nil),
        fontWeight: weight,
        fontStyle: style
    )
}

let style = MarkdownStyle(
    fontFamily: "'Merriweather', Georgia, serif",
    fontFaces: [
        face("Merriweather-Regular", .normal, .normal),
        face("Merriweather-Bold", .bold, .normal),
        face("Merriweather-Italic", .normal, .italic),
        face("Merriweather-BoldItalic", .bold, .italic)
    ]
)
```

A variable font is one face covering a span: `.range(400, 700)`.

### Code blocks

Setting only ``MarkdownStyle/fontFamily`` leaves fenced code blocks in their
monospace stack, so column alignment inside a block survives a proportional
body font. Inline code follows the body font, since it sits in a line of prose.

Set ``MarkdownStyle/codeFontFamily`` to give all code a stack of its own:

```swift
MarkdownStyle(
    fontFamily: "'Merriweather', Georgia, serif",
    codeFontFamily: "'SF Mono', Menlo, monospace"
)
```

### When a face does not appear

A face that cannot be read is dropped and the text falls back to the rest of
the stack. Debug builds log the reason: a bundle identifier that does not
resolve, a resource that is not in the bundle, a file that cannot be read, or a
non-local URL.

The example app's Fonts page exercises all of this with two bundled families.
