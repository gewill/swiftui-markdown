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
    internal private(set) var appliedFontFaces = [MarkdownFontFace]()
    private var currentStyle: MarkdownStyle?
    private var currentTheme: ColorScheme?

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
        currentTheme = theme
        if pageLoaded {
            executeSetTheme(theme)
        } else {
            pendingTheme = theme
        }
    }

    func setMarkdownStyle(_ style: MarkdownStyle) {
        currentStyle = style
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

        applyRootVariables(for: style)
        applyFontFaces(style.fontFaces)
    }

    /// Custom properties go straight onto the root element. Rewriting a <style>
    /// sheet instead re-parses every @font-face in it and drops the already
    /// loaded fonts, which shows up as a flash of fallback text on each change.
    private func applyRootVariables(for style: MarkdownStyle) {
        let assignments = Self.rootVariables(for: style)
            .map { "style.setProperty(\(Self.javascriptStringLiteral($0.name)), \(Self.javascriptStringLiteral($0.value)));" }
            .joined(separator: "\n            ")
        let names = Self.rootVariableNames
            .map(Self.javascriptStringLiteral)
            .joined(separator: ", ")

        let script = """
        (function() {
            var style = document.documentElement.style;
            [\(names)].forEach(function(name) { style.removeProperty(name); });
            \(assignments)
        })();
        """
        callJavascript(javascriptString: script)
    }

    /// Rebuilt only when the faces themselves change: the data URLs run to
    /// megabytes, and re-assigning them makes WebKit decode every font again.
    private func applyFontFaces(_ fontFaces: [MarkdownFontFace]) {
        guard fontFaces != appliedFontFaces else {
            return
        }
        appliedFontFaces = fontFaces

        guard !fontFaces.isEmpty else {
            injectFontFaceCSS("")
            return
        }

        // Reading and base64-encoding the files is slow enough to drop frames on
        // the SwiftUI update path, so keep it off the main thread.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let css = Self.fontFaceCSS(for: fontFaces)
            DispatchQueue.main.async {
                // A newer style may have landed while this was encoding.
                guard let self = self, self.appliedFontFaces == fontFaces else {
                    return
                }
                self.injectFontFaceCSS(css)
            }
        }
    }

    private func injectFontFaceCSS(_ css: String) {
        let script = """
        (function() {
            var styleElement = document.getElementById('__markdown_font_faces__');
            if (!styleElement) {
                styleElement = document.createElement('style');
                styleElement.id = '__markdown_font_faces__';
                document.head.appendChild(styleElement);
            }
            styleElement.textContent = \(Self.javascriptStringLiteral(css));
        })();
        """
        callJavascript(javascriptString: script)
    }

    /// Applies whatever arrived before the page was ready. Theme and style go
    /// first so the content is never rendered with default styling for a frame.
    internal func flushPendingUpdates() {
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

    private func setPadding(_ padding: Int) {
        callJavascript(javascriptString: "__markdown_preview__.style.padding = '\(padding)px';")
    }
    private func setPaddingTop(_ top: Int) {
        callJavascript(javascriptString: "__markdown_preview__.style.paddingTop = '\(top)px';")
    }
    private func setPaddingBottom(_ bottom: Int) {
        callJavascript(javascriptString: "__markdown_preview__.style.paddingBottom = '\(bottom)px';")
    }
    private func setPaddingLeft(_ left: Int) {
        callJavascript(javascriptString: "__markdown_preview__.style.paddingLeft = '\(left)px';")
    }
    private func setPaddingRight(_ right: Int) {
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

    /// The content process can be killed under memory pressure. Without this the
    /// view keeps believing the page is live and silently drops every later
    /// update, leaving a blank preview until the view is recreated.
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Self.log("web content process terminated, reloading the preview")

        pageLoaded = false
        appliedFontFaces = []
        pendingTheme = currentTheme
        pendingStyle = currentStyle
        pendingContent = currentContent

        loadPage()
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

        loadPage()
    }

    private func loadPage() {
        guard let bundlePath = Bundle.module.path(forResource: "web", ofType: "bundle"),
              let bundle = Bundle(path: bundlePath),
              let indexPath = bundle.path(forResource: "index", ofType: "html"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: indexPath)),
              let resourceURL = bundle.resourceURL else {
            Self.log("could not load the bundled preview page")
            return
        }

        webview.load(data, mimeType: "text/html", characterEncodingName: "utf-8", baseURL: resourceURL)
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
    /// Every custom property the style can define, cleared before each update so
    /// that dropping a property from the style also drops it from the page.
    static let rootVariableNames = [
        "--markdown-font-family",
        "--markdown-font-size",
        "--markdown-line-height",
        "--markdown-code-font-family",
        "--markdown-inline-code-font-family"
    ]

    static func rootVariables(for style: MarkdownStyle) -> [(name: String, value: String)] {
        var variables = [(name: String, value: String)]()

        if let fontFamily = style.fontFamily {
            variables.append((name: "--markdown-font-family", value: fontFamily))
        }
        if let fontSize = style.fontSize {
            variables.append((name: "--markdown-font-size", value: "\(fontSize)px"))
        }
        if let lineHeight = style.lineHeight {
            variables.append((name: "--markdown-line-height", value: "\(lineHeight)"))
        }
        if let codeFontFamily = style.codeFontFamily {
            variables.append((name: "--markdown-code-font-family", value: codeFontFamily))
            variables.append((name: "--markdown-inline-code-font-family", value: codeFontFamily))
        } else if let fontFamily = style.fontFamily {
            // Only inline code inherits the body font. Fenced code blocks keep the
            // monospace stack from marked.css so column alignment survives.
            variables.append((name: "--markdown-inline-code-font-family", value: fontFamily))
        }

        return variables
    }

    static func fontFaceCSS(for fontFaces: [MarkdownFontFace]) -> String {
        fontFaces.compactMap(fontFaceCSS).joined(separator: "\n")
    }

    /// The two halves combined into one sheet. The view injects them separately;
    /// this is what a page would look like with everything applied at once.
    static func css(for style: MarkdownStyle) -> String {
        var lines = [String]()

        let faces = fontFaceCSS(for: style.fontFaces)
        if !faces.isEmpty {
            lines.append(faces)
        }

        let variables = rootVariables(for: style)
        if !variables.isEmpty {
            let declarations = variables.map { "\($0.name): \($0.value);" }.joined(separator: " ")
            lines.append(":root { \(declarations) }")
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

    /// Encoded faces are held in a bounded cache: a four-face family runs to
    /// roughly 1.5 MB of base64, which used to be retained for the process
    /// lifetime with no way to reclaim it.
    private static let sourceCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    /// The cache outlives individual views, so tests that assert on encoding need
    /// a way back to a known state.
    internal static func clearFontCache() {
        sourceCache.removeAllObjects()
    }

    private static func cacheKey(for source: MarkdownFontSource) -> NSString {
        switch source {
        case .fileURL(let url):
            return "file|\(url.absoluteString)" as NSString
        case .appResource(let name, let fileExtension, let bundleIdentifier):
            return "app|\(bundleIdentifier ?? "")|\(name)|\(fileExtension ?? "")" as NSString
        case .bundleResource(let name, let fileExtension, let bundle):
            return "bundle|\(bundle.bundleURL.absoluteString)|\(name)|\(fileExtension ?? "")" as NSString
        }
    }

    private static func fontFaceCSS(_ fontFace: MarkdownFontFace) -> String? {
        guard let source = fontSource(for: fontFace.source) else {
            return nil
        }

        var declarations = [
            "font-family: '\(cssSingleQuoted(fontFace.fontFamily))';",
            "src: \(source);"
        ]

        if let fontWeight = sanitizedDescriptor(fontFace.fontWeight, name: "fontWeight") {
            declarations.append("font-weight: \(fontWeight);")
        }
        if let fontStyle = sanitizedDescriptor(fontFace.fontStyle, name: "fontStyle") {
            declarations.append("font-style: \(fontStyle);")
        }

        return "@font-face { \(declarations.joined(separator: " ")) }"
    }

    private static func url(for source: MarkdownFontSource) -> URL? {
        switch source {
        case .fileURL(let url):
            return url
        case .appResource(let name, let fileExtension, let bundleIdentifier):
            let bundle: Bundle
            if let bundleIdentifier = bundleIdentifier {
                guard let resolved = Bundle(identifier: bundleIdentifier) else {
                    log("bundle '\(bundleIdentifier)' is not loaded, skipping font '\(name)'")
                    return nil
                }
                bundle = resolved
            } else {
                bundle = .main
            }
            return resource(name, fileExtension, in: bundle)
        case .bundleResource(let name, let fileExtension, let bundle):
            return resource(name, fileExtension, in: bundle)
        }
    }

    private static func resource(_ name: String, _ fileExtension: String?, in bundle: Bundle) -> URL? {
        guard let url = bundle.url(forResource: name, withExtension: fileExtension) else {
            log("font '\(name)' not found in \(bundle.bundleURL.lastPathComponent)")
            return nil
        }
        return url
    }

    private static func log(_ message: String) {
        #if DEBUG
        print("WARNING: MarkdownStyle \(message)")
        #endif
    }

    /// Returns a ready-to-use `src` descriptor, e.g.
    /// `url('data:font/ttf;base64,...') format('truetype')`.
    private static func fontSource(for source: MarkdownFontSource) -> String? {
        let key = cacheKey(for: source)
        if let cached = sourceCache.object(forKey: key) {
            return cached as String
        }

        guard let url = url(for: source) else {
            return nil
        }

        // Validate local file URL
        guard url.isFileURL else {
            log("only supports local file URLs for font sources. Got: \(url)")
            return nil
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            log("could not read font at \(url.path): \(error.localizedDescription)")
            return nil
        }

        let mimeType: String
        let format: String?
        switch url.pathExtension.lowercased() {
        case "otf":
            (mimeType, format) = ("font/otf", "opentype")
        case "ttf":
            (mimeType, format) = ("font/ttf", "truetype")
        case "woff":
            (mimeType, format) = ("font/woff", "woff")
        case "woff2":
            (mimeType, format) = ("font/woff2", "woff2")
        default:
            // Let WebKit sniff an unknown extension rather than claim a format.
            (mimeType, format) = ("application/octet-stream", nil)
        }

        var descriptor = "url('data:\(mimeType);base64,\(data.base64EncodedString())')"
        if let format = format {
            descriptor += " format('\(format)')"
        }

        sourceCache.setObject(descriptor as NSString, forKey: key, cost: descriptor.utf8.count)
        return descriptor
    }

    /// `@font-face` is assembled as CSS text, so a descriptor carrying `;` or `}`
    /// could close the rule and append rules of its own. Everything CSS actually
    /// allows here — `normal`, `bold`, `700`, `400 700`, `oblique 14deg` — fits in
    /// letters, digits, spaces, dots and hyphens.
    private static func sanitizedDescriptor(_ value: String?, name: String) -> String? {
        guard let value = value else {
            return nil
        }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .-")
        guard !value.isEmpty, value.unicodeScalars.allSatisfy(allowed.contains) else {
            log("ignoring \(name) '\(value)': unexpected characters")
            return nil
        }

        return value
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
            flushPendingUpdates()
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
