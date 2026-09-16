//
//  SwiftUIView.swift
//  
//
//  Created by 王楚江 on 2022/3/11.
//

import Foundation
import SwiftUI

/// Where a font file comes from.
///
/// The file is read and embedded into the preview as a data URL, so the web
/// view never has to reach across bundle boundaries to load it. Only local
/// files are supported; a remote URL is ignored.
public enum MarkdownFontSource: Hashable {
    /// A file on disk, for example one the app downloaded or generated.
    case fileURL(URL)
    /// A resource in the main bundle, or in the bundle with the given
    /// identifier.
    ///
    /// The identifier must belong to a bundle that is already loaded. One that
    /// does not resolve drops the face rather than falling back to the main
    /// bundle, where an unrelated font with the same name could be picked up.
    case appResource(name: String, fileExtension: String?, bundleIdentifier: String?)
    /// A resource in a bundle you hand over directly, such as `.main` or, from
    /// inside a Swift package, `.module`.
    case bundleResource(name: String, fileExtension: String?, bundle: Bundle)
}

/// The weight a bundled face covers, mirroring what `@font-face` accepts.
///
/// A value CSS would reject — a weight outside `1...1000`, or a range whose
/// bounds are inverted — is dropped with a log rather than written into the
/// rule.
public enum MarkdownFontWeight: Hashable {
    /// Equivalent to a weight of 400.
    case normal
    /// Equivalent to a weight of 700.
    case bold
    /// A single weight, 1...1000.
    case value(Int)
    /// The span a variable font covers, e.g. `.range(400, 700)`.
    case range(Int, Int)
}

/// The style a bundled face covers, mirroring what `@font-face` accepts.
///
/// An angle outside `-90...90` is dropped with a log rather than written into
/// the rule.
public enum MarkdownFontStyle: Hashable {
    /// An upright face.
    case normal
    /// A true italic face, with its own letterforms.
    case italic
    /// A slanted face, without separate italic letterforms.
    case oblique
    /// `oblique` slanted by a specific angle, -90...90 degrees.
    case obliqueAngle(Double)
}

/// One font file to install in the preview, becoming a single `@font-face`
/// rule.
///
/// Give every file of a family the same ``fontFamily`` and describe what each
/// one covers, so the preview picks the right file for bold and italic text
/// instead of letting WebKit synthesise them:
///
/// ```swift
/// MarkdownFontFace(
///     fontFamily: "Merriweather",
///     source: .appResource(name: "Merriweather-Bold", fileExtension: "woff2", bundleIdentifier: nil),
///     fontWeight: .bold,
///     fontStyle: .normal
/// )
/// ```
///
/// To actually use the family, name it in ``MarkdownStyle/fontFamily`` as well.
public struct MarkdownFontFace: Hashable {
    /// The name this face is registered under, and the name to use in a font
    /// stack.
    public var fontFamily: String
    /// The file backing this face.
    public var source: MarkdownFontSource
    /// The weight this file covers. Defaults to `normal` when omitted, as CSS
    /// does.
    public var fontWeight: MarkdownFontWeight?
    /// The style this file covers. Defaults to `normal` when omitted, as CSS
    /// does.
    public var fontStyle: MarkdownFontStyle?

    public init(
        fontFamily: String,
        source: MarkdownFontSource,
        fontWeight: MarkdownFontWeight? = nil,
        fontStyle: MarkdownFontStyle? = nil
    ) {
        self.fontFamily = fontFamily
        self.source = source
        self.fontWeight = fontWeight
        self.fontStyle = fontStyle
    }
}

/// Padding, typography and bundled fonts for a Markdown preview.
///
/// Apply one with ``SwiftUI/View/markdownStyle(_:)``. Every field stands on its
/// own, so changing a single thing leaves the rest at its default:
///
/// ```swift
/// Markdown(content: $text)
///     .markdownStyle(MarkdownStyle(fontSize: 20))
/// ```
///
/// Font stacks use CSS syntax, which lets you list fallbacks:
///
/// ```swift
/// MarkdownStyle(
///     fontFamily: "\"Avenir Next\", -apple-system, sans-serif",
///     fontSize: 17,
///     lineHeight: 1.6
/// )
/// ```
///
/// Changing the style on a preview that is already on screen updates it in
/// place.
public struct MarkdownStyle: Hashable {
    /// Padding on all four edges, in points.
    public var padding: Int?
    /// Top padding, overriding ``padding`` for that edge.
    public var paddingTop: Int?
    /// Trailing padding, overriding ``padding`` for that edge.
    public var paddingRight: Int?
    /// Leading padding, overriding ``padding`` for that edge.
    public var paddingLeft: Int?
    /// Bottom padding, overriding ``padding`` for that edge.
    public var paddingBottom: Int?
    /// The body font stack, in CSS `font-family` syntax.
    public var fontFamily: String?
    /// The body font size, in points.
    public var fontSize: Int?
    /// The body line height, as a multiple of the font size.
    public var lineHeight: Double?
    /// The font stack for code, in CSS `font-family` syntax.
    ///
    /// When this is not set, inline code inherits ``fontFamily`` while fenced
    /// code blocks keep their monospace stack, so column alignment inside a
    /// block survives a proportional body font.
    public var codeFontFamily: String?
    /// Font files to install in the preview.
    ///
    /// Name the family in ``fontFamily`` as well, otherwise nothing uses it.
    public var fontFaces: [MarkdownFontFace] = []

    /// Per-edge values win over `padding`, so passing only `paddingTop` keeps the
    /// default on the other three edges.
    public init(
        padding: Int = 18,
        paddingTop: Int? = nil,
        paddingBottom: Int? = nil,
        paddingLeft: Int? = nil,
        paddingRight: Int? = nil,
        fontFamily: String? = nil,
        fontSize: Int? = nil,
        lineHeight: Double? = nil,
        codeFontFamily: String? = nil,
        fontFaces: [MarkdownFontFace] = []
    ) {
        self.padding = padding
        self.paddingTop = paddingTop
        self.paddingBottom = paddingBottom
        self.paddingLeft = paddingLeft
        self.paddingRight = paddingRight
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.codeFontFamily = codeFontFamily
        self.fontFaces = fontFaces
    }
}

// MARK: - CSS representation

extension MarkdownFontWeight {
    /// `nil` for a value CSS would reject, so the descriptor is dropped rather
    /// than written out as something the parser will discard anyway.
    var cssValue: String? {
        switch self {
        case .normal:
            return "normal"
        case .bold:
            return "bold"
        case .value(let weight):
            guard Self.allowedValues.contains(weight) else { return nil }
            return "\(weight)"
        case .range(let lower, let upper):
            guard Self.allowedValues.contains(lower),
                  Self.allowedValues.contains(upper),
                  lower <= upper else { return nil }
            return "\(lower) \(upper)"
        }
    }

    private static let allowedValues = 1...1000
}

extension MarkdownFontStyle {
    var cssValue: String? {
        switch self {
        case .normal:
            return "normal"
        case .italic:
            return "italic"
        case .oblique:
            return "oblique"
        case .obliqueAngle(let degrees):
            guard degrees.isFinite, (-90...90).contains(degrees) else { return nil }
            return "oblique \(Self.formatted(degrees))deg"
        }
    }

    private static func formatted(_ degrees: Double) -> String {
        degrees == degrees.rounded() ? String(Int(degrees)) : String(degrees)
    }
}
