# ``Markdown``

Render Markdown text in SwiftUI.

## Overview

``Markdown/Markdown`` is a SwiftUI view that previews Markdown. It wraps a web
view running the bundled
[@wcj/markdown-to-html](https://github.com/jaywcjlove/markdown-to-html)
renderer, so GitHub Flavored Markdown, syntax highlighting and KaTeX all work
without further setup.

```swift
import SwiftUI
import Markdown

struct ContentView: View {
    @State private var text = """
    # Hello World

    Render Markdown text in SwiftUI.
    """

    var body: some View {
        Markdown(content: $text)
    }
}
```

The binding is read continuously, so pairing the preview with an editor updates
it as you type:

```swift
VStack {
    Markdown(content: $text)
    TextEditor(text: $text)
}
```

### Styling

Padding and typography come from ``MarkdownStyle``. Apply one with
``SwiftUI/View/markdownStyle(_:)``; every field stands on its own, so changing
a single thing leaves the rest at its default.

```swift
Markdown(content: $text)
    .markdownStyle(
        MarkdownStyle(
            padding: 24,
            fontFamily: "Georgia, serif",
            fontSize: 17,
            lineHeight: 1.7
        )
    )
```

Font stacks use CSS `font-family` syntax, so fallbacks are written the way they
are on the web. Changing the style on a preview that is already on screen
updates it in place.

### Light and dark

The preview follows the environment's colour scheme. To pin it, pass one to
``Markdown/Markdown/init(content:theme:)``.

## Topics

### Essentials

- ``Markdown/Markdown``
- ``SwiftUI/View/markdownStyle(_:)``

### Styling

- ``MarkdownStyle``

### Bundling fonts

- <doc:BundlingFonts>
- ``MarkdownFontFace``
- ``MarkdownFontSource``
- ``MarkdownFontWeight``
- ``MarkdownFontStyle``

### Hosting view

- ``MarkdownWebView``
