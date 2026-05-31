import SwiftUI
import WebKit

#if os(OSX)
    import AppKit
    public typealias ViewRepresentable = NSViewRepresentable
#else
    import UIKit
    public typealias ViewRepresentable = UIViewRepresentable
#endif

public struct Markdown: ViewRepresentable {
    
    @Binding var content: String
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.markdownStyle) private var style: MarkdownStyle
    var textDidChanged: ((String) -> Void)?
    var theme: ColorScheme?

    public init(content: Binding<String>) {
        self._content = content
    }
    public init(content: Binding<String>, theme: ColorScheme?) {
        self._content = content
        self.theme = theme
    }
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator(content: $content, colorScheme: colorScheme, style: style)
    }
    private func getWebView(context: Context) -> MarkdownWebView {
        let codeView = MarkdownWebView()
        codeView.setContent(content)
        codeView.setMarkdownStyle(style)
        codeView.textDidChanged = { text in
            context.coordinator.set(content: text)
        }
        colorScheme == .dark ? codeView.setTheme(.dark) : codeView.setTheme(.light)
        return codeView
    }
    
    private func updateView(_ webview: MarkdownWebView, context: Context) {
        if context.coordinator.colorScheme != colorScheme {
            colorScheme == .dark ? webview.setTheme(.dark) : webview.setTheme(.light)
            context.coordinator.set(colorScheme: colorScheme)
        }
        if context.coordinator.content != content {
            webview.setContent(content)
        }
        if context.coordinator.style != style {
            webview.setMarkdownStyle(style)
            context.coordinator.set(style: style)
        }
    }
    // MARK: macOS
    public func makeNSView(context: Context) -> MarkdownWebView {
        return getWebView(context: context)
    }
    
    public func updateNSView(_ webview: MarkdownWebView, context: Context) {
        updateView(webview, context: context)
    }
    // MARK: iOS
    public func makeUIView(context: Context) -> MarkdownWebView {
        getWebView(context: context)
    }
    
    public func updateUIView(_ webview: MarkdownWebView, context: Context) {
        updateView(webview, context: context)
    }
    
}

extension View {
    public func markdownStyle(_ markdownStyle: MarkdownStyle) -> some View {
      return environment(\.markdownStyle, markdownStyle)
    }
}

public extension Markdown {
    class Coordinator: NSObject {
        @Binding private(set) var content: String
        private(set) var colorScheme: ColorScheme
        private(set) var style: MarkdownStyle
        
        init(content: Binding<String>, colorScheme: ColorScheme, style: MarkdownStyle) {
            _content = content
            self.colorScheme = colorScheme
            self.style = style
        }
        
        func set(content: String) {
            if self.content != content {
                self.content = content
            }
        }
        
        func set(colorScheme: ColorScheme) {
            if self.colorScheme != colorScheme {
                self.colorScheme = colorScheme
            }
        }

        func set(style: MarkdownStyle) {
            if self.style != style {
                self.style = style
            }
        }
    }
}

extension EnvironmentValues {
  fileprivate var markdownStyle: MarkdownStyle {
    get { self[MarkdownStyleKey.self] }
    set {
        self[MarkdownStyleKey.self] = newValue
    }
  }
}

private struct MarkdownStyleKey: EnvironmentKey {
  static let defaultValue = MarkdownStyle()
}

#if DEBUG
struct Markdown_Previews : PreviewProvider {
    static private var jsonString = """
    ## Hello World
    
    Markdown Preview.
    """
    static var previews: some View {
        Markdown(content: .constant(jsonString))
    }
}
#endif
