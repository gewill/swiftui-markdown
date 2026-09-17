SwiftUI Markdown
===

[![Test](https://github.com/gewill/swiftui-markdown/actions/workflows/test.yml/badge.svg)](https://github.com/gewill/swiftui-markdown/actions/workflows/test.yml)
[![Swift](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fgewill%2Fswiftui-markdown%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/gewill/swiftui-markdown)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fgewill%2Fswiftui-markdown%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/gewill/swiftui-markdown)

Render Markdown text in SwiftUI. The preview is rendered by [`@wcj/markdown-to-html`](https://github.com/jaywcjlove/markdown-to-html), which is built on unified/remark/rehype.

https://user-images.githubusercontent.com/1680273/159059803-d844769b-36ad-44c1-a296-a657de8d099c.mov

![Markdown Package Screenshot](https://user-images.githubusercontent.com/1680273/158006647-19d180e2-2549-4cd4-b108-91778beccc1b.png)

![Markdown Package Screenshot](https://user-images.githubusercontent.com/1680273/158075575-14c9c942-5b99-479c-9935-b631bac3828e.png)

![Markdown Package Screenshot](https://user-images.githubusercontent.com/1680273/158075581-925d267f-47ce-4468-b891-0fb2467b89df.png)

## Installation

You can add this package to an Xcode project as a package dependency.

1. From the File menu, select Add Packages…
2. Enter https://github.com/gewill/swiftui-markdown in the Search or Enter Package URL search field
3. Link `Markdown` to your application target

Or add the following to `Package.swift`:

```swift
.package(url: "https://github.com/gewill/swiftui-markdown", from: "2.0.0")
```

Or [add the package in Xcode](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app).

## Usage

```swift
import SwiftUI
import Markdown

struct ContentView: View {
  @State private var mdStr: String = """
    ## Hello World
    
    Render Markdown text in SwiftUI.
    """
  var body: some View {
    VStack {
      Markdown(content: $mdStr)
      TextEditor(text: $mdStr)
    }
  }
}
```

### `.markdownStyle()`

Setting markdown related styles.

```swift
Markdown(content: $mdStr)
  .markdownStyle(
      MarkdownStyle(
        padding: 0, paddingTop: 115, paddingBottom: 2, paddingLeft: 130, paddingRight: 5
      )
  )
```

```swift
Markdown(content: $mdStr)
  .markdownStyle(MarkdownStyle(padding: 35 ))
```

#### System fonts

Use CSS font-family syntax for built-in system fonts. Every field is optional
on its own, so changing just the size keeps the default typeface:

```swift
Markdown(content: $mdStr)
  .markdownStyle(MarkdownStyle(fontSize: 20))
```

```swift
Markdown(content: $mdStr)
  .markdownStyle(
    MarkdownStyle(
      fontFamily: "\"Avenir Next\", -apple-system, sans-serif",
      fontSize: 18,
      lineHeight: 1.6,
      codeFontFamily: "\"SF Mono\", Menlo, monospace"
    )
  )
```

#### App bundled fonts

Fonts imported by the host app can be exposed to the Markdown WebView with
`@font-face`. Use the same `fontFamily` name in the body font stack.
`ttf`, `otf`, `woff` and `woff2` files are supported; `woff2` is the smallest
and is what the example app ships.
Passing one regular face is valid; Markdown bold and italic will fall back to
WebKit synthesis when matching faces are not provided.
When `codeFontFamily` is not provided, inline code inherits `fontFamily` while
fenced code blocks keep the default monospace stack, so column alignment inside
code blocks is preserved. Set `codeFontFamily` to give both inline code and code
blocks a separate stack.

```swift
Markdown(content: $mdStr)
  .markdownStyle(
    MarkdownStyle(
      fontFamily: "'LXGW WenKai', -apple-system, sans-serif",
      fontFaces: [
        // Using a Bundle reference directly (e.g., .main, or .module in a Swift Package):
        MarkdownFontFace(
          fontFamily: "LXGW WenKai",
          source: .bundleResource(
            name: "LXGWWenKai-Regular",
            fileExtension: "ttf",
            bundle: .main
          )
        )
      ]
    )
  )
```

Or reference a bundle by its identifier:

```swift
MarkdownFontFace(
  fontFamily: "LXGW WenKai",
  source: .appResource(
    name: "LXGWWenKai-Regular",
    fileExtension: "ttf",
    bundleIdentifier: "com.example.AppFonts"
  )
)
```

`fontWeight` and `fontStyle` describe what a face covers. Besides `.normal`,
`.bold`, `.italic` and `.oblique` they take `.value(700)`, `.range(400, 700)`
for a variable font, and `.obliqueAngle(14)`.

For Markdown documents, provide regular, bold, italic, and bold italic faces
when you want `**strong**`, `*emphasis*`, and `***strong emphasis***` to use
real font files.

```swift
Markdown(content: $mdStr)
  .markdownStyle(
    MarkdownStyle(
      fontFamily: "'Merriweather', Georgia, serif",
      fontFaces: [
        MarkdownFontFace(
          fontFamily: "Merriweather",
          source: .appResource(name: "Merriweather-Regular", fileExtension: "ttf", bundleIdentifier: nil),
          fontWeight: .normal,
          fontStyle: .normal
        ),
        MarkdownFontFace(
          fontFamily: "Merriweather",
          source: .appResource(name: "Merriweather-Bold", fileExtension: "ttf", bundleIdentifier: nil),
          fontWeight: .bold,
          fontStyle: .normal
        ),
        MarkdownFontFace(
          fontFamily: "Merriweather",
          source: .appResource(name: "Merriweather-Italic", fileExtension: "ttf", bundleIdentifier: nil),
          fontWeight: .normal,
          fontStyle: .italic
        ),
        MarkdownFontFace(
          fontFamily: "Merriweather",
          source: .appResource(name: "Merriweather-BoldItalic", fileExtension: "ttf", bundleIdentifier: nil),
          fontWeight: .bold,
          fontStyle: .italic
        )
      ]
    )
  )
```

The example app includes a `Fonts` page that switches between the default
Markdown style, several named system font stacks, and app-bundled Atkinson
Hyperlegible / Merriweather static font families copied into the app bundle.

## Documentation

[**API documentation**](https://swiftpackageindex.com/gewill/swiftui-markdown/documentation/markdown),
hosted by Swift Package Index, including an article on bundling your own fonts.

To read it offline, open the package in Xcode and choose Product → Build
Documentation, or run:

```sh
xcodebuild docbuild -scheme Markdown -destination 'generic/platform=macOS'
```

See [CHANGELOG.md](CHANGELOG.md) for what this fork changes on top of upstream.

## Configure

In a sandboxed macOS app, the preview's web view needs outgoing network
connections. Select the macOS target in Xcode, open **Signing & Capabilities**,
and under **App Sandbox** enable **Outgoing Connections (Client)**, or add the
entitlement directly:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

## Contributors

As always, thanks to our amazing contributors!

<a href="https://github.com/gewill/swiftui-markdown/graphs/contributors">
  <img src="https://raw.githubusercontent.com/gewill/swiftui-markdown/gh-pages/CONTRIBUTORS.svg" />
</a>

Made with [contributors](https://github.com/jaywcjlove/github-action-contributors).

## License

Licensed under the MIT License.
 
