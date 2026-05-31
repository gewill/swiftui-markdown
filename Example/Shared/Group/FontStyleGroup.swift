//
//  FontStyleGroup.swift
//  Example
//
//  Created by Codex on 2026/5/31.
//

import Markdown
import SwiftUI

struct FontStyleGroup: View {
    @State private var selectedFont = FontDemo.default
    @State private var mdStr = """
    # Markdown Font Preview

    The quick brown fox jumps over the lazy dog.

    ## Reading rhythm

    Custom fonts should keep headings, body copy, lists, and code blocks
    visually distinct while preserving the Markdown layout.

    - System stack: uses fonts already available to WebKit.
    - App bundled font: loads a font file copied into the example app bundle.
    - Code font: can use an independent monospace stack.

    ```swift
    Markdown(content: $mdStr)
        .markdownStyle(style)
    ```
    """

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            Markdown(content: $mdStr)
                .markdownStyle(selectedFont.style)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Font", selection: $selectedFont) {
                ForEach(FontDemo.allCases) { font in
                    Text(font.title).tag(font)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 10) {
                Text(selectedFont.title)
                    .font(.headline)
                Text(selectedFont.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}

private enum FontDemo: String, CaseIterable, Identifiable {
    case `default`
    case systemSerif
    case systemRounded
    case systemMono
    case appAtkinson
    case appMerriweather

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default:
            return "Default"
        case .systemSerif:
            return "System Serif"
        case .systemRounded:
            return "System Rounded"
        case .systemMono:
            return "System Mono"
        case .appAtkinson:
            return "App Atkinson"
        case .appMerriweather:
            return "App Merriweather"
        }
    }

    var detail: String {
        switch self {
        case .default:
            return "GitHub-style Markdown defaults"
        case .systemSerif:
            return "Georgia with Menlo code"
        case .systemRounded:
            return "Avenir Next with SF Mono code"
        case .systemMono:
            return "Menlo for body and code"
        case .appAtkinson:
            return "Atkinson Hyperlegible loaded from Bundle.main"
        case .appMerriweather:
            return "Merriweather loaded from Bundle.main"
        }
    }

    var style: MarkdownStyle {
        switch self {
        case .default:
            return MarkdownStyle(padding: 24)
        case .systemSerif:
            return MarkdownStyle(
                padding: 24,
                fontFamily: "Georgia, 'Times New Roman', serif",
                fontSize: 17,
                lineHeight: 1.7,
                codeFontFamily: "Menlo, monospace"
            )
        case .systemRounded:
            return MarkdownStyle(
                padding: 24,
                fontFamily: "\"Avenir Next\", -apple-system, sans-serif",
                fontSize: 17,
                lineHeight: 1.65,
                codeFontFamily: "\"SF Mono\", Menlo, monospace"
            )
        case .systemMono:
            return MarkdownStyle(
                padding: 24,
                fontFamily: "Menlo, Monaco, monospace",
                fontSize: 16,
                lineHeight: 1.7,
                codeFontFamily: "Menlo, Monaco, monospace"
            )
        case .appAtkinson:
            return MarkdownStyle(
                padding: 24,
                fontFamily: "'Atkinson Hyperlegible Demo', -apple-system, sans-serif",
                fontSize: 17,
                lineHeight: 1.65,
                codeFontFamily: "\"SF Mono\", Menlo, monospace",
                fontFaces: [
                    MarkdownFontFace(
                        fontFamily: "Atkinson Hyperlegible Demo",
                        source: .appResource(
                            name: "AtkinsonHyperlegible-Regular",
                            fileExtension: "ttf",
                            bundleIdentifier: nil
                        ),
                        fontWeight: "400",
                        fontStyle: "normal"
                    )
                ]
            )
        case .appMerriweather:
            return MarkdownStyle(
                padding: 24,
                fontFamily: "'Merriweather Demo', Georgia, serif",
                fontSize: 17,
                lineHeight: 1.75,
                codeFontFamily: "\"SF Mono\", Menlo, monospace",
                fontFaces: [
                    MarkdownFontFace(
                        fontFamily: "Merriweather Demo",
                        source: .appResource(
                            name: "Merriweather-Regular",
                            fileExtension: "ttf",
                            bundleIdentifier: nil
                        ),
                        fontWeight: "400",
                        fontStyle: "normal"
                    )
                ]
            )
        }
    }
}

struct FontStyleGroup_Previews: PreviewProvider {
    static var previews: some View {
        FontStyleGroup()
    }
}
