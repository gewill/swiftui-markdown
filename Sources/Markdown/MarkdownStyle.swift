//
//  SwiftUIView.swift
//  
//
//  Created by 王楚江 on 2022/3/11.
//

import Foundation
import SwiftUI

public enum MarkdownFontSource: Hashable {
    case fileURL(URL)
    case appResource(name: String, fileExtension: String?, bundleIdentifier: String?)
    case bundleResource(name: String, fileExtension: String?, bundle: Bundle)
}

/// The weight a bundled face covers, mirroring what `@font-face` accepts.
public enum MarkdownFontWeight: Hashable {
    case normal
    case bold
    /// A single weight, 1...1000.
    case value(Int)
    /// The span a variable font covers, e.g. `.range(400, 700)`.
    case range(Int, Int)
}

/// The style a bundled face covers, mirroring what `@font-face` accepts.
public enum MarkdownFontStyle: Hashable {
    case normal
    case italic
    case oblique
    /// `oblique` slanted by a specific angle, -90...90 degrees.
    case obliqueAngle(Double)
}

public struct MarkdownFontFace: Hashable {
    public var fontFamily: String
    public var source: MarkdownFontSource
    public var fontWeight: MarkdownFontWeight?
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

public struct MarkdownStyle: Hashable {
    public var padding: Int?
    public var paddingTop: Int?
    public var paddingRight: Int?
    public var paddingLeft: Int?
    public var paddingBottom: Int?
    public var fontFamily: String?
    public var fontSize: Int?
    public var lineHeight: Double?
    public var codeFontFamily: String?
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
