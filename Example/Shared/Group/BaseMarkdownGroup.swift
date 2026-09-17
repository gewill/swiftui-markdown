//
//  BaseMarkdownGroup.swift
//  Example
//
//  Created by 王楚江 on 2022/3/11.
//
import Markdown
import SwiftUI

struct BaseMarkdownGroup: View {
    @State private var mdStr: String = """
        Base Markdown
        ===

        [![Test](https://github.com/gewill/swiftui-markdown/actions/workflows/test.yml/badge.svg)](https://github.com/gewill/swiftui-markdown/actions/workflows/test.yml)
        ![SwiftUI Support](https://shields.io/badge/SwiftUI-macOS%20v11%20%7C%20iOS%20v14%20%7C%20visionOS%20v1-green?logo=Swift&style=flat)

        Render Markdown text in SwiftUI. The preview is rendered by [`@wcj/markdown-to-html`](https://github.com/jaywcjlove/markdown-to-html), which is built on unified/remark/rehype.

        ## Installation

        You can add MarkdownUI to an Xcode project by adding it as a package dependency.

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
            @State private var mdStr: String = \"\""
              ## Hello World
              
              Render Markdown text in SwiftUI.
              \"\""
            var body: some View {
              VStack {
                Markdown(content: $mdStr)
                TextEditor(text: $mdStr)
              }
            }
        }
        ```

        ## License

        Licensed under the MIT License.
        
        Here is a simple footnote[^1]. With some additional text after it.

        [^1]: My reference.
        
        """
    var body: some View {
        Markdown(content: $mdStr)
    }
}
