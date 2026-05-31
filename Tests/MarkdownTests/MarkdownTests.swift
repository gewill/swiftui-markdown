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
        XCTAssertTrue(css.contains("src: url('data:font/ttf;base64,AAEC');"))
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
