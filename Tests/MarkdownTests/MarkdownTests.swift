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
}
