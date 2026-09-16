import XCTest
import SwiftUI
@testable import Markdown

final class MarkdownTests: XCTestCase {
    func testStyleBuildsSystemFontCSS() throws {
        let style = MarkdownStyle(
            fontFamily: "\"Avenir Next\", -apple-system, sans-serif",
            fontSize: 18,
            lineHeight: 1.65,
            codeFontFamily: "\"SF Mono\", monospace"
        )

        let css = MarkdownWebView.css(for: style)

        XCTAssertTrue(css.contains("--markdown-font-family: \"Avenir Next\", -apple-system, sans-serif;"))
        XCTAssertTrue(css.contains("--markdown-font-size: 18px;"))
        XCTAssertTrue(css.contains("--markdown-line-height: 1.65;"))
        XCTAssertTrue(css.contains("--markdown-code-font-family: \"SF Mono\", monospace;"))
        XCTAssertTrue(css.contains("--markdown-inline-code-font-family: \"SF Mono\", monospace;"))
    }

    func testInlineCodeInheritsBodyFontButCodeBlocksStayMonospaced() throws {
        let style = MarkdownStyle(
            fontFamily: "'DemoFont', -apple-system, sans-serif"
        )

        let css = MarkdownWebView.css(for: style)

        XCTAssertTrue(css.contains("--markdown-font-family: 'DemoFont', -apple-system, sans-serif;"))
        XCTAssertTrue(css.contains("--markdown-inline-code-font-family: 'DemoFont', -apple-system, sans-serif;"))
        // Leaving --markdown-code-font-family undefined lets marked.css fall back to
        // its monospace stack, so column alignment inside fenced blocks survives.
        XCTAssertFalse(css.contains("--markdown-code-font-family:"))
    }

    func testStyleBuildsAppFontFaceDataURL() throws {
        let fontURL = FileManager.default.temporaryDirectory.appendingPathComponent("MarkdownTestFont.ttf")
        try Data([0x00, 0x01, 0x02]).write(to: fontURL)
        defer { try? FileManager.default.removeItem(at: fontURL) }

        let style = MarkdownStyle(
            fontFamily: "'DemoFont', sans-serif",
            fontFaces: [
                MarkdownFontFace(
                    fontFamily: "DemoFont",
                    source: .fileURL(fontURL),
                    fontWeight: "400",
                    fontStyle: "normal"
                )
            ]
        )

        let css = MarkdownWebView.css(for: style)

        XCTAssertTrue(css.contains("@font-face"))
        XCTAssertTrue(css.contains("font-family: 'DemoFont';"))
        XCTAssertTrue(css.contains("src: url('data:font/ttf;base64,AAEC') format('truetype');"))
        XCTAssertTrue(css.contains("font-weight: 400;"))
        XCTAssertTrue(css.contains("font-style: normal;"))
    }

    func testStyleBuildsStaticMarkdownFontFamilyFaces() throws {
        let fontURLs = try makeTemporaryFontFiles([
            "Regular": Data([0x00, 0x01]),
            "Bold": Data([0x00, 0x02]),
            "Italic": Data([0x00, 0x03]),
            "BoldItalic": Data([0x00, 0x04])
        ])
        defer {
            for url in fontURLs.values {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let style = MarkdownStyle(
            fontFamily: "'Demo Serif', Georgia, serif",
            fontFaces: [
                MarkdownFontFace(fontFamily: "Demo Serif", source: .fileURL(fontURLs["Regular"]!), fontWeight: "400", fontStyle: "normal"),
                MarkdownFontFace(fontFamily: "Demo Serif", source: .fileURL(fontURLs["Bold"]!), fontWeight: "700", fontStyle: "normal"),
                MarkdownFontFace(fontFamily: "Demo Serif", source: .fileURL(fontURLs["Italic"]!), fontWeight: "400", fontStyle: "italic"),
                MarkdownFontFace(fontFamily: "Demo Serif", source: .fileURL(fontURLs["BoldItalic"]!), fontWeight: "700", fontStyle: "italic")
            ]
        )

        let css = MarkdownWebView.css(for: style)

        XCTAssertEqual(css.components(separatedBy: "@font-face").count - 1, 4)
        XCTAssertTrue(css.contains("--markdown-font-family: 'Demo Serif', Georgia, serif;"))
        XCTAssertTrue(css.contains("font-weight: 400; font-style: normal;"))
        XCTAssertTrue(css.contains("font-weight: 700; font-style: normal;"))
        XCTAssertTrue(css.contains("font-weight: 400; font-style: italic;"))
        XCTAssertTrue(css.contains("font-weight: 700; font-style: italic;"))
    }

    func testInvalidFileURLReturnsNil() throws {
        let remoteURL = URL(string: "https://example.com/font.ttf")!
        let style = MarkdownStyle(
            fontFamily: "'RemoteFont', sans-serif",
            fontFaces: [
                MarkdownFontFace(
                    fontFamily: "RemoteFont",
                    source: .fileURL(remoteURL),
                    fontWeight: "400",
                    fontStyle: "normal"
                )
            ]
        )
        let css = MarkdownWebView.css(for: style)
        XCTAssertFalse(css.contains("@font-face"))
        XCTAssertFalse(css.contains("data:"))
    }

    func testFontEncodingCache() throws {
        let fontURL = FileManager.default.temporaryDirectory.appendingPathComponent("CachedFont-\(UUID().uuidString).ttf")
        try Data([0x0A, 0x0B, 0x0C]).write(to: fontURL)
        defer { try? FileManager.default.removeItem(at: fontURL) }

        let source = MarkdownFontSource.fileURL(fontURL)
        let style = MarkdownStyle(
            fontFamily: "'CachedFont', sans-serif",
            fontFaces: [
                MarkdownFontFace(
                    fontFamily: "CachedFont",
                    source: source,
                    fontWeight: "400",
                    fontStyle: "normal"
                )
            ]
        )

        // 1. First execution creates cached entry
        let css1 = MarkdownWebView.css(for: style)
        XCTAssertTrue(css1.contains("src: url('data:font/ttf;base64,CgsM') format('truetype');"))

        // 2. Delete the physical file
        try FileManager.default.removeItem(at: fontURL)

        // 3. Second execution should succeed from cache despite the file being missing
        let css2 = MarkdownWebView.css(for: style)
        XCTAssertTrue(css2.contains("src: url('data:font/ttf;base64,CgsM') format('truetype');"))
    }

    func testBundleResourceLoading() throws {
        let source = MarkdownFontSource.bundleResource(name: "NonExistentFont", fileExtension: "ttf", bundle: Bundle.main)
        let style = MarkdownStyle(
            fontFamily: "'BundleFont', sans-serif",
            fontFaces: [
                MarkdownFontFace(
                    fontFamily: "BundleFont",
                    source: source
                )
            ]
        )
        let css = MarkdownWebView.css(for: style)
        XCTAssertFalse(css.contains("@font-face"))
    }

    func testQueueCoalescingBeforePageLoad() throws {
        let webView = MarkdownWebView()
        XCTAssertFalse(webView.pageLoaded)
        XCTAssertNil(webView.pendingContent)
        XCTAssertNil(webView.pendingStyle)
        XCTAssertNil(webView.pendingTheme)

        // 1. Multiple content updates should overwrite and keep only the latest
        webView.setContent("First content")
        XCTAssertEqual(webView.pendingContent, "First content")
        webView.setContent("Second content")
        XCTAssertEqual(webView.pendingContent, "Second content")

        // 2. Multiple style updates should overwrite
        let style1 = MarkdownStyle(padding: 10)
        let style2 = MarkdownStyle(padding: 20)
        webView.setMarkdownStyle(style1)
        XCTAssertEqual(webView.pendingStyle, style1)
        webView.setMarkdownStyle(style2)
        XCTAssertEqual(webView.pendingStyle, style2)

        // 3. Multiple theme updates should overwrite
        webView.setTheme(.light)
        XCTAssertEqual(webView.pendingTheme, .light)
        webView.setTheme(.dark)
        XCTAssertEqual(webView.pendingTheme, .dark)
    }

    func testBundleResourceLoadsFromRealBundle() throws {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkdownFonts-\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        try Data([0x00, 0x01, 0x02]).write(to: bundleURL.appendingPathComponent("BundledFont.ttf"))

        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let style = MarkdownStyle(
            fontFamily: "'BundledFont', sans-serif",
            fontFaces: [MarkdownFontFace(
                fontFamily: "BundledFont",
                source: .bundleResource(name: "BundledFont", fileExtension: "ttf", bundle: bundle)
            )]
        )

        let css = MarkdownWebView.css(for: style)
        XCTAssertTrue(css.contains("src: url('data:font/ttf;base64,AAEC') format('truetype');"))
    }

    /// An unresolvable bundle identifier must drop the face rather than quietly
    /// searching the main bundle, which could pick up an unrelated same-named font.
    func testUnresolvableBundleIdentifierProducesNoFontFace() throws {
        let style = MarkdownStyle(
            fontFamily: "'Decoy', sans-serif",
            fontFaces: [MarkdownFontFace(
                fontFamily: "Decoy",
                source: .appResource(
                    name: "Decoy",
                    fileExtension: "ttf",
                    bundleIdentifier: "com.example.bundle.that.is.not.loaded"
                )
            )]
        )

        XCTAssertFalse(MarkdownWebView.css(for: style).contains("@font-face"))
    }

    func testRootVariablesAndFontFacesAreBuiltSeparately() throws {
        let fontURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SplitFont-\(UUID().uuidString).ttf")
        try Data([0x00, 0x01]).write(to: fontURL)
        defer { try? FileManager.default.removeItem(at: fontURL) }

        let style = MarkdownStyle(
            fontFamily: "'SplitFont', sans-serif",
            fontSize: 20,
            fontFaces: [MarkdownFontFace(fontFamily: "SplitFont", source: .fileURL(fontURL))]
        )

        // The view injects these through two different paths, so neither half may
        // carry the other's payload.
        let faces = MarkdownWebView.fontFaceCSS(for: style.fontFaces)
        XCTAssertTrue(faces.contains("@font-face"))
        XCTAssertFalse(faces.contains(":root"))
        XCTAssertFalse(faces.contains("--markdown-"))

        let variables = MarkdownWebView.rootVariables(for: style)
        XCTAssertEqual(variables.first(where: { $0.name == "--markdown-font-size" })?.value, "20px")
        XCTAssertFalse(variables.contains { $0.value.contains("data:") })
    }

    /// Stale properties are cleared by name before each update, so a variable that
    /// rootVariables can emit but rootVariableNames does not list would stick
    /// around forever once set.
    func testEveryEmittedVariableIsAlsoCleared() throws {
        let style = MarkdownStyle(
            fontFamily: "Georgia, serif",
            fontSize: 18,
            lineHeight: 1.6,
            codeFontFamily: "Menlo, monospace"
        )

        let emitted = MarkdownWebView.rootVariables(for: style).map(\.name)
        XCTAssertEqual(Set(emitted).count, emitted.count, "duplicate variable names")
        for name in emitted {
            XCTAssertTrue(
                MarkdownWebView.rootVariableNames.contains(name),
                "\(name) is emitted but never cleared"
            )
        }
    }

    /// @font-face is built as CSS text, so a descriptor holding `;` or `}` could
    /// close the rule and append rules of its own. Verified to work before the
    /// sanitizer: the injected rule really did hide the page body.
    func testFontDescriptorsCannotInjectCSS() throws {
        let fontURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("InjectFont-\(UUID().uuidString).ttf")
        try Data([0x00, 0x01]).write(to: fontURL)
        defer { try? FileManager.default.removeItem(at: fontURL) }

        let style = MarkdownStyle(
            fontFamily: "'Inject', sans-serif",
            fontFaces: [MarkdownFontFace(
                fontFamily: "Inject",
                source: .fileURL(fontURL),
                fontWeight: "400; } body { display: none } @font-face { font-weight: 400",
                fontStyle: "italic"
            )]
        )

        let css = MarkdownWebView.css(for: style)

        XCTAssertEqual(css.components(separatedBy: "@font-face").count - 1, 1)
        XCTAssertFalse(css.contains("display: none"))
        XCTAssertFalse(css.contains("font-weight:"), "the unsafe descriptor should be dropped")
        XCTAssertTrue(css.contains("font-style: italic;"), "the safe one should survive")
    }

    func testValidFontDescriptorsSurvive() throws {
        let fontURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ValidFont-\(UUID().uuidString).ttf")
        try Data([0x00, 0x01]).write(to: fontURL)
        defer { try? FileManager.default.removeItem(at: fontURL) }

        // Everything CSS allows for these descriptors, including variable-font
        // ranges and an oblique angle.
        for (weight, fontStyle) in [("normal", "normal"), ("bold", "italic"),
                                    ("700", "oblique 14deg"), ("400 700", "normal")] {
            let style = MarkdownStyle(
                fontFamily: "'Valid', sans-serif",
                fontFaces: [MarkdownFontFace(
                    fontFamily: "Valid",
                    source: .fileURL(fontURL),
                    fontWeight: weight,
                    fontStyle: fontStyle
                )]
            )

            let css = MarkdownWebView.css(for: style)
            XCTAssertTrue(css.contains("font-weight: \(weight);"), "dropped weight \(weight)")
            XCTAssertTrue(css.contains("font-style: \(fontStyle);"), "dropped style \(fontStyle)")
        }
    }

    /// A family name carrying a quote must stay inside its CSS string. Counting
    /// "@font-face" in the text would prove nothing here, since the hostile value
    /// contains that literal itself — WebKit parses the result below into exactly
    /// one CSSFontFaceRule plus the :root rule, with body still displayed.
    func testFontFamilyQuotesAreEscaped() throws {
        let fontURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuoteFont-\(UUID().uuidString).ttf")
        try Data([0x00, 0x01]).write(to: fontURL)
        defer { try? FileManager.default.removeItem(at: fontURL) }

        let style = MarkdownStyle(
            fontFamily: "'Quote', sans-serif",
            fontFaces: [MarkdownFontFace(
                fontFamily: "Quote'; } body { display: none } @font-face { font-family: 'X",
                source: .fileURL(fontURL)
            )]
        )

        let css = MarkdownWebView.css(for: style)

        XCTAssertTrue(css.contains(#"font-family: 'Quote\';"#), "the quote should be escaped")
        XCTAssertFalse(css.contains(#"font-family: 'Quote';"#), "the string must not be closed early")
    }

    private func makeTemporaryFontFiles(_ files: [String: Data]) throws -> [String: URL] {
        var urls = [String: URL]()
        for (name, data) in files {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("MarkdownTestFont-\(name)-\(UUID().uuidString).ttf")
            try data.write(to: url)
            urls[name] = url
        }
        return urls
    }
}
