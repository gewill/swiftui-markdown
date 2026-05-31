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
}

public struct MarkdownFontFace: Hashable {
    public var fontFamily: String
    public var source: MarkdownFontSource
    public var fontWeight: String?
    public var fontStyle: String?

    public init(
        fontFamily: String,
        source: MarkdownFontSource,
        fontWeight: String? = nil,
        fontStyle: String? = nil
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

    public init(padding: Int = 18) {
        self.padding = padding
    }

    public init(paddingTop: Int = 18, paddingBottom: Int = 18, paddingLeft: Int = 18, paddingRight: Int = 18) {
        self.paddingTop = paddingTop
        self.paddingBottom = paddingBottom
        self.paddingLeft = paddingLeft
        self.paddingRight = paddingRight
    }
    public init(padding: Int = 18, paddingTop: Int = 18, paddingBottom: Int = 18, paddingLeft: Int = 18, paddingRight: Int = 18) {
        self.padding = padding
        self.paddingTop = paddingTop
        self.paddingBottom = paddingBottom
        self.paddingLeft = paddingLeft
        self.paddingRight = paddingRight
    }

    public init(
        padding: Int = 18,
        fontFamily: String,
        fontSize: Int? = nil,
        lineHeight: Double? = nil,
        codeFontFamily: String? = nil,
        fontFaces: [MarkdownFontFace] = []
    ) {
        self.padding = padding
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.codeFontFamily = codeFontFamily
        self.fontFaces = fontFaces
    }

    public init(
        paddingTop: Int = 18,
        paddingBottom: Int = 18,
        paddingLeft: Int = 18,
        paddingRight: Int = 18,
        fontFamily: String,
        fontSize: Int? = nil,
        lineHeight: Double? = nil,
        codeFontFamily: String? = nil,
        fontFaces: [MarkdownFontFace] = []
    ) {
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
