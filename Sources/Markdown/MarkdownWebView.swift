//
//  SwiftUIView.swift
//  
//
//  Created by 王楚江 on 2022/3/10.
//
import Foundation
import SwiftUI
import WebKit

#if os(OSX)
    import AppKit
    public typealias CustomView = NSView
#else
    import UIKit
    public typealias CustomView = UIView
#endif


// JS Func
typealias JavascriptCallback = (Result<Any?, Error>) -> Void
private struct JavascriptFunction {
    
    let functionString: String
    let callback: JavascriptCallback?
    
    init(functionString: String, callback: JavascriptCallback? = nil) {
        self.functionString = functionString
        self.callback = callback
    }
}

public class MarkdownWebView: CustomView, WKNavigationDelegate {
    @Environment(\.openURL) private var openURL
    private struct Constants {
        static let mdPreviewDidReady = "mdPreviewDidReady"
        static let mdPreviewDidChanged = "mdPreviewDidChanged"
    }
    private lazy var webview: WKWebView = {
        let preferences = WKPreferences()
        var userController = WKUserContentController()
        userController.add(self, name: Constants.mdPreviewDidReady) // Callback from Ace editor js
        userController.add(self, name: Constants.mdPreviewDidChanged)
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.userContentController = userController
        let webView = WKWebView(frame: bounds, configuration: configuration)
        webView.navigationDelegate = self

        #if DEBUG
        if #available(iOS 16.4, macOS 13.3, *) {
            webView.isInspectable = true
        }
        #endif
        
        #if os(OSX)
        webView.setValue(true, forKey: "drawsTransparentBackground") // Prevent white flick
        #elseif os(iOS)
        webView.isOpaque = false
        #endif
        
        return webView
    }()
    
    var textDidChanged: ((String) -> Void)?
    
    internal var pageLoaded = false
    private var currentContent: String = ""
    internal var pendingContent: String?
    internal var pendingStyle: MarkdownStyle?
    internal var pendingTheme: ColorScheme?
    
    override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        initWebView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initWebView()
    }
    
    func setContent(_ value: String) {
        guard currentContent != value else {
            return
        }
        currentContent = value
        
        if pageLoaded {
            executeSetContent(value)
        } else {
            pendingContent = value
        }
    }

    func setTheme(_ theme: ColorScheme) {
        if pageLoaded {
            executeSetTheme(theme)
        } else {
            pendingTheme = theme
        }
    }

    func setMarkdownStyle(_ style: MarkdownStyle) {
        if pageLoaded {
            executeSetMarkdownStyle(style)
        } else {
            pendingStyle = style
        }
    }

    private func executeSetContent(_ value: String) {
        //
        // It's tricky to pass FULL JSON or HTML text with \n or "", ... into JS Bridge
        // Have to wrap with `data_here`
        // And use String.raw to prevent escape some special string -> String will show exactly how it's
        // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals
        //
        let first = "var content = String.raw`"
        let content = """
        \(value)
        """.replacingOccurrences(of: "`", with: "\\`", options: .literal, range: nil)
            .replacingOccurrences(of: "{", with: "\\{", options: .literal, range: nil)
        
        let end = "`; markdownPreview(content.replace(/\\\\`/g, '`').replace(/\\\\{/g, '{'));"

        let script = first + content + end
        callJavascript(javascriptString: script)
    }

    private func executeSetTheme(_ theme: ColorScheme) {
        if theme == .dark {
            callJavascript(javascriptString: "document.body.classList.add('theme-dark');")
            callJavascript(javascriptString: "document.body.classList.remove('theme-light');")
        } else {
            callJavascript(javascriptString: "document.body.classList.remove('theme-dark');")
            callJavascript(javascriptString: "document.body.classList.add('theme-light');")
        }
    }

    private func executeSetMarkdownStyle(_ style: MarkdownStyle) {
        resetAllPaddings()

        if let padding = style.padding {
            setPadding(padding)
        }
        if let paddingTop = style.paddingTop {
            setPaddingTop(paddingTop)
        }
        if let paddingBottom = style.paddingBottom {
            setPaddingBottom(paddingBottom)
        }
        if let paddingLeft = style.paddingLeft {
            setPaddingLeft(paddingLeft)
        }
        if let paddingRight = style.paddingRight {
            setPaddingRight(paddingRight)
        }

        let css = Self.css(for: style)
        let script = """
        (function() {
            var styleElement = document.getElementById('__markdown_custom_style__');
            if (!styleElement) {
                styleElement = document.createElement('style');
                styleElement.id = '__markdown_custom_style__';
                document.head.appendChild(styleElement);
            }
            styleElement.textContent = \(Self.javascriptStringLiteral(css));
        })();
        """
        callJavascript(javascriptString: script)
    }

    private func resetAllPaddings() {
        let script = """
        if (window.__markdown_preview__) {
            __markdown_preview__.style.padding = '';
            __markdown_preview__.style.paddingTop = '';
            __markdown_preview__.style.paddingBottom = '';
            __markdown_preview__.style.paddingLeft = '';
            __markdown_preview__.style.paddingRight = '';
        }
        """
        callJavascript(javascriptString: script)
    }

    func setPadding(_ padding: Int) {
        callJavascript(javascriptString: "__markdown_preview__.style.padding = '\(padding)px';")
    }
    func setPaddingTop(_ top: Int) {
        callJavascript(javascriptString: "__markdown_preview__.style.paddingTop = '\(top)px';")
    }
    func setPaddingBottom(_ bottom: Int) {
        callJavascript(javascriptString: "__markdown_preview__.style.paddingBottom = '\(bottom)px';")
    }
    func setPaddingLeft(_ left: Int) {
        callJavascript(javascriptString: "__markdown_preview__.style.paddingLeft = '\(left)px';")
    }
    func setPaddingRight(_ right: Int) {
        callJavascript(javascriptString: "__markdown_preview__.style.paddingRight = '\(right)px';")
    }
    ///  open links in browsers
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if url.isFileURL == false {
                openURL(url)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        /// Disable right-click menu
        webView.evaluateJavaScript("document.body.setAttribute('oncontextmenu', 'event.preventDefault();');", completionHandler: nil);
    }
}


extension MarkdownWebView {
    private func initWebView() {
        webview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webview)
        webview.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        webview.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        webview.topAnchor.constraint(equalTo: topAnchor).isActive = true
        webview.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        guard let bundlePath = Bundle.module.path(forResource: "web", ofType: "bundle"),
            let bundle = Bundle(path: bundlePath),
            let indexPath = bundle.path(forResource: "index", ofType: "html") else {
                fatalError("Ace editor is missing")
        }
        
        let data = try! Data(contentsOf: URL(fileURLWithPath: indexPath))
        webview.load(data, mimeType: "text/html", characterEncodingName: "utf-8", baseURL: bundle.resourceURL!)
    }
    private func callJavascriptFunction(function: JavascriptFunction) {
        webview.evaluateJavaScript(function.functionString) { (response, error) in
            if let error = error {
                function.callback?(.failure(error))
            }
            else {
                function.callback?(.success(response))
            }
        }
    }
    private func callJavascript(javascriptString: String, callback: JavascriptCallback? = nil) {
        if pageLoaded {
            callJavascriptFunction(function: JavascriptFunction(functionString: javascriptString, callback: callback))
        }
        else {
            #if DEBUG
            print("WARNING: callJavascript was called before pageLoaded: \(javascriptString)")
            #endif
        }
    }
}

extension MarkdownWebView {
    static func css(for style: MarkdownStyle) -> String {
        var lines = style.fontFaces.compactMap(fontFaceCSS)
        var rootVariables = [String]()

        if let fontFamily = style.fontFamily {
            rootVariables.append("--markdown-font-family: \(fontFamily);")
        }
        if let fontSize = style.fontSize {
            rootVariables.append("--markdown-font-size: \(fontSize)px;")
        }
        if let lineHeight = style.lineHeight {
            rootVariables.append("--markdown-line-height: \(lineHeight);")
        }
        if let codeFontFamily = style.codeFontFamily {
            rootVariables.append("--markdown-code-font-family: \(codeFontFamily);")
        }

        if !rootVariables.isEmpty {
            lines.append(":root { \(rootVariables.joined(separator: " ")) }")
        }

        return lines.joined(separator: "\n")
    }

    static func javascriptStringLiteral(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let json = String(data: data, encoding: .utf8),
              json.count >= 2 else {
            return "\"\""
        }

        return String(json.dropFirst().dropLast())
    }

    private static var dataURLCache = [MarkdownFontSource: String]()
    private static let cacheQueue = DispatchQueue(label: "com.markdown.fontcache")

    private static func fontFaceCSS(_ fontFace: MarkdownFontFace) -> String? {
        guard let dataURL = dataURL(for: fontFace.source) else {
            return nil
        }

        var declarations = [
            "font-family: '\(cssSingleQuoted(fontFace.fontFamily))';",
            "src: url('\(dataURL)');"
        ]

        if let fontWeight = fontFace.fontWeight {
            declarations.append("font-weight: \(fontWeight);")
        }
        if let fontStyle = fontFace.fontStyle {
            declarations.append("font-style: \(fontStyle);")
        }

        return "@font-face { \(declarations.joined(separator: " ")) }"
    }

    private static func url(for source: MarkdownFontSource) -> URL? {
        switch source {
        case .fileURL(let url):
            return url
        case .appResource(let name, let fileExtension, let bundleIdentifier):
            let bundle = bundleIdentifier.flatMap(Bundle.init(identifier:)) ?? .main
            return bundle.url(forResource: name, withExtension: fileExtension)
        case .bundleResource(let name, let fileExtension, let bundle):
            return bundle.url(forResource: name, withExtension: fileExtension)
        }
    }

    private static func dataURL(for source: MarkdownFontSource) -> String? {
        var cached: String?
        cacheQueue.sync {
            cached = dataURLCache[source]
        }
        if let cached = cached {
            return cached
        }

        guard let url = url(for: source) else {
            return nil
        }

        // Validate local file URL
        guard url.isFileURL else {
            #if DEBUG
            print("WARNING: MarkdownStyle only supports local file URLs for font sources. Got: \(url)")
            #endif
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        let mimeType: String
        switch url.pathExtension.lowercased() {
        case "otf":
            mimeType = "font/otf"
        case "ttf":
            mimeType = "font/ttf"
        case "woff":
            mimeType = "font/woff"
        case "woff2":
            mimeType = "font/woff2"
        default:
            mimeType = "application/octet-stream"
        }

        let dataURL = "data:\(mimeType);base64,\(data.base64EncodedString())"
        cacheQueue.sync {
            dataURLCache[source] = dataURL
        }
        return dataURL
    }

    private static func cssSingleQuoted(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\A ")
    }
}


// MARK: WKScriptMessageHandler

extension MarkdownWebView: WKScriptMessageHandler {

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        // is Ready
        if message.name == Constants.mdPreviewDidReady {
            pageLoaded = true
            
            if let theme = pendingTheme {
                executeSetTheme(theme)
                pendingTheme = nil
            }
            if let style = pendingStyle {
                executeSetMarkdownStyle(style)
                pendingStyle = nil
            }
            if let content = pendingContent {
                executeSetContent(content)
                pendingContent = nil
            }
            return
        }
        
        // is Text change
        if message.name == Constants.mdPreviewDidChanged,
           let text = message.body as? String {
            
            self.textDidChanged?(text)

            return
        }
    }
}
