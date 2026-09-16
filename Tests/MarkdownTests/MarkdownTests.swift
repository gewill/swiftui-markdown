import XCTest
import SwiftUI
@testable import Markdown

final class MarkdownTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MarkdownWebView.clearFontCache()
    }

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
        let fontURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkdownTestFont-\(UUID().uuidString).ttf")
        try Data([0x00, 0x01, 0x02]).write(to: fontURL)
        defer { try? FileManager.default.removeItem(at: fontURL) }

        let style = MarkdownStyle(
            fontFamily: "'DemoFont', sans-serif",
            fontFaces: [
                MarkdownFontFace(
                    fontFamily: "DemoFont",
                    source: .fileURL(fontURL),
                    fontWeight: .normal,
                    fontStyle: .normal
                )
            ]
        )

        let css = MarkdownWebView.css(for: style)

        XCTAssertTrue(css.contains("@font-face"))
        XCTAssertTrue(css.contains("font-family: 'DemoFont';"))
        XCTAssertTrue(css.contains("src: url('data:font/ttf;base64,AAEC') format('truetype');"))
        XCTAssertTrue(css.contains("font-weight: normal;"))
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
                MarkdownFontFace(fontFamily: "Demo Serif", source: .fileURL(fontURLs["Regular"]!), fontWeight: .normal, fontStyle: .normal),
                MarkdownFontFace(fontFamily: "Demo Serif", source: .fileURL(fontURLs["Bold"]!), fontWeight: .bold, fontStyle: .normal),
                MarkdownFontFace(fontFamily: "Demo Serif", source: .fileURL(fontURLs["Italic"]!), fontWeight: .normal, fontStyle: .italic),
                MarkdownFontFace(fontFamily: "Demo Serif", source: .fileURL(fontURLs["BoldItalic"]!), fontWeight: .bold, fontStyle: .italic)
            ]
        )

        let css = MarkdownWebView.css(for: style)

        XCTAssertEqual(css.components(separatedBy: "@font-face").count - 1, 4)
        XCTAssertTrue(css.contains("--markdown-font-family: 'Demo Serif', Georgia, serif;"))
        XCTAssertTrue(css.contains("font-weight: normal; font-style: normal;"))
        XCTAssertTrue(css.contains("font-weight: bold; font-style: normal;"))
        XCTAssertTrue(css.contains("font-weight: normal; font-style: italic;"))
        XCTAssertTrue(css.contains("font-weight: bold; font-style: italic;"))
    }

    func testInvalidFileURLReturnsNil() throws {
        let remoteURL = URL(string: "https://example.com/font.ttf")!
        let style = MarkdownStyle(
            fontFamily: "'RemoteFont', sans-serif",
            fontFaces: [
                MarkdownFontFace(
                    fontFamily: "RemoteFont",
                    source: .fileURL(remoteURL),
                    fontWeight: .normal,
                    fontStyle: .normal
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
                    fontWeight: .normal,
                    fontStyle: .normal
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

    func testMissingBundleResourceProducesNoFontFace() throws {
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

    /// The injection this used to guard against is now unrepresentable: the
    /// descriptors are enums, so a value carrying `;` or `}` cannot be built at
    /// all. What is left is a numerically invalid value, which must be dropped
    /// rather than written into the rule for the parser to discard.
    func testOutOfRangeFontDescriptorsAreDropped() throws {
        let fontURL = try makeFontFile("Range")
        defer { try? FileManager.default.removeItem(at: fontURL) }

        let badWeights: [MarkdownFontWeight] = [.value(0), .value(1001), .range(700, 400), .range(0, 700)]
        for weight in badWeights {
            let css = MarkdownWebView.css(for: styleWithFace(fontURL, weight: weight, style: nil))
            XCTAssertTrue(css.contains("@font-face"), "the face itself should survive")
            XCTAssertFalse(css.contains("font-weight:"), "\(weight) should have been dropped")
        }

        let badStyles: [MarkdownFontStyle] = [.obliqueAngle(91), .obliqueAngle(-91), .obliqueAngle(.nan)]
        for style in badStyles {
            let css = MarkdownWebView.css(for: styleWithFace(fontURL, weight: nil, style: style))
            XCTAssertTrue(css.contains("@font-face"))
            XCTAssertFalse(css.contains("font-style:"), "\(style) should have been dropped")
        }
    }

    func testValidFontDescriptorsSurvive() throws {
        let fontURL = try makeFontFile("Valid")
        defer { try? FileManager.default.removeItem(at: fontURL) }

        let cases: [(MarkdownFontWeight, MarkdownFontStyle, String, String)] = [
            (.normal, .normal, "normal", "normal"),
            (.bold, .italic, "bold", "italic"),
            (.value(700), .oblique, "700", "oblique"),
            (.range(400, 700), .obliqueAngle(14), "400 700", "oblique 14deg"),
            (.value(1), .obliqueAngle(-12.5), "1", "oblique -12.5deg")
        ]

        for (weight, style, expectedWeight, expectedStyle) in cases {
            let css = MarkdownWebView.css(for: styleWithFace(fontURL, weight: weight, style: style))
            XCTAssertTrue(css.contains("font-weight: \(expectedWeight);"), "dropped \(weight)")
            XCTAssertTrue(css.contains("font-style: \(expectedStyle);"), "dropped \(style)")
        }
    }

    private func makeFontFile(_ label: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(label)Font-\(UUID().uuidString).ttf")
        try Data([0x00, 0x01]).write(to: url)
        return url
    }

    private func styleWithFace(
        _ url: URL,
        weight: MarkdownFontWeight?,
        style: MarkdownFontStyle?
    ) -> MarkdownStyle {
        MarkdownStyle(
            fontFamily: "'Probe', sans-serif",
            fontFaces: [MarkdownFontFace(
                fontFamily: "Probe",
                source: .fileURL(url),
                fontWeight: weight,
                fontStyle: style
            )]
        )
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

    // MARK: - JavaScript escaping

    /// This is the only thing standing between a Markdown style and arbitrary
    /// JavaScript, since the CSS it escapes is interpolated into an evaluated
    /// script. It had no tests at all.
    func testJavascriptStringLiteralEscaping() throws {
        let cases: [(input: String, mustContain: [String], mustNotContain: [String])] = [
            (#"plain"#, [#""plain""#], []),
            (#"with "quotes""#, [#"\""#], []),
            (#"back\slash"#, [#"\\"#], []),
            ("new\nline", [#"\n"#], ["\n"]),
            ("tab\there", [#"\t"#], ["\t"]),
            (#"'); alert(1); ('"#, [#"\'); alert(1); ('"#.replacingOccurrences(of: #"\"#, with: "")], [])
        ]

        for testCase in cases {
            let literal = MarkdownWebView.javascriptStringLiteral(testCase.input)
            XCTAssertTrue(literal.hasPrefix("\""), "not quoted: \(literal)")
            XCTAssertTrue(literal.hasSuffix("\""), "not quoted: \(literal)")
            for fragment in testCase.mustContain {
                XCTAssertTrue(literal.contains(fragment), "\(literal) is missing \(fragment)")
            }
            for fragment in testCase.mustNotContain {
                XCTAssertFalse(literal.contains(fragment), "\(literal) still holds a raw \(fragment)")
            }
        }
    }

    /// A literal that closed its own string would let the surrounding script run
    /// anything. The escaped form must never contain an unescaped quote.
    func testJavascriptStringLiteralCannotCloseItsOwnString() throws {
        let hostile = #"a"; document.body.remove(); var x = ""#
        let literal = MarkdownWebView.javascriptStringLiteral(hostile)

        let body = literal.dropFirst().dropLast()
        var previousWasBackslash = false
        for character in body {
            if character == "\"" {
                XCTAssertTrue(previousWasBackslash, "unescaped quote in \(literal)")
            }
            previousWasBackslash = (character == "\\") && !previousWasBackslash
        }
    }

    // MARK: - Reverting to the default style

    func testDefaultStyleProducesEmptyCSS() throws {
        let css = MarkdownWebView.css(for: MarkdownStyle(padding: 18))

        XCTAssertTrue(css.isEmpty, "a padding-only style should not emit any CSS")
        XCTAssertTrue(MarkdownWebView.rootVariables(for: MarkdownStyle(padding: 18)).isEmpty)
    }

    /// Going back to a style without fonts has to drop the faces, otherwise the
    /// previous family stays installed on the page.
    func testSwitchingBackToDefaultDropsFontFaces() throws {
        let fontURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RevertFont-\(UUID().uuidString).ttf")
        try Data([0x00, 0x01]).write(to: fontURL)
        defer { try? FileManager.default.removeItem(at: fontURL) }

        let webView = MarkdownWebView(frame: .zero)
        webView.flushPendingUpdates()
        XCTAssertTrue(webView.appliedFontFaces.isEmpty)

        let faces = [MarkdownFontFace(fontFamily: "Revert", source: .fileURL(fontURL))]
        webView.setMarkdownStyle(MarkdownStyle(fontFamily: "'Revert', sans-serif", fontFaces: faces))
        XCTAssertEqual(webView.appliedFontFaces, faces)

        webView.setMarkdownStyle(MarkdownStyle(padding: 18))
        XCTAssertTrue(webView.appliedFontFaces.isEmpty, "faces should be cleared on revert")
    }

    // MARK: - Replaying queued updates

    /// Theme and style must be replayed before the content, or the first frame
    /// renders with default styling.
    func testFlushAppliesAndClearsEveryQueuedUpdate() throws {
        let webView = MarkdownWebView(frame: .zero)
        let style = MarkdownStyle(padding: 42)

        webView.setTheme(.dark)
        webView.setMarkdownStyle(style)
        webView.setContent("queued")

        XCTAssertFalse(webView.pageLoaded)
        XCTAssertEqual(webView.pendingTheme, .dark)
        XCTAssertEqual(webView.pendingStyle, style)
        XCTAssertEqual(webView.pendingContent, "queued")

        webView.flushPendingUpdates()

        XCTAssertTrue(webView.pageLoaded)
        XCTAssertNil(webView.pendingTheme)
        XCTAssertNil(webView.pendingStyle)
        XCTAssertNil(webView.pendingContent)
    }

    /// After the flush, updates must go straight out instead of queueing again.
    func testUpdatesAfterFlushAreNotQueued() throws {
        let webView = MarkdownWebView(frame: .zero)
        webView.flushPendingUpdates()

        webView.setContent("live")
        webView.setTheme(.dark)
        webView.setMarkdownStyle(MarkdownStyle(padding: 7))

        XCTAssertNil(webView.pendingContent)
        XCTAssertNil(webView.pendingTheme)
        XCTAssertNil(webView.pendingStyle)
    }

    // MARK: - Style initialiser

    /// Changing only the size used to be impossible: fontFamily was required by
    /// every initialiser that took font settings.
    func testFontSizeAloneKeepsTheDefaultTypeface() throws {
        let style = MarkdownStyle(fontSize: 20)

        XCTAssertNil(style.fontFamily)
        XCTAssertEqual(style.padding, 18, "the default padding should still apply")

        let variables = MarkdownWebView.rootVariables(for: style)
        XCTAssertEqual(variables.count, 1)
        XCTAssertEqual(variables.first?.name, "--markdown-font-size")
        XCTAssertEqual(variables.first?.value, "20px")
    }

    /// A per-edge value must not wipe out the default on the other edges — the
    /// view applies padding first and each edge after it.
    func testPerEdgePaddingLeavesTheOtherEdgesDefaulted() throws {
        let style = MarkdownStyle(paddingTop: 10)

        XCTAssertEqual(style.padding, 18)
        XCTAssertEqual(style.paddingTop, 10)
        XCTAssertNil(style.paddingBottom)
        XCTAssertNil(style.paddingLeft)
        XCTAssertNil(style.paddingRight)
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
