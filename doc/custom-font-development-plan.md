# 自定义字体开发进度表

## 目标

让 Markdown 渲染同时支持系统内置字体和宿主 app 导入的字体。

## 进度

| 阶段 | 范围 | 状态 |
| --- | --- | --- |
| 1 | 梳理现有 `MarkdownStyle` 和 WebView CSS 渲染链路 | 已完成 |
| 2 | 增加系统字体栈的公开样式 API | 已完成 |
| 3 | 通过 `@font-face` 支持 app 导入字体 | 已完成 |
| 4 | 让 SwiftUI 环境样式变化能同步刷新 WebView | 已完成 |
| 5 | 在 README 补系统字体和 app 字体用法 | 已完成 |
| 6 | 增加 CSS 生成单元测试 | 已完成 |
| 7 | 运行包构建和测试验证 | 已完成 |
| 8 | 增加真实字体视觉示例 | 已完成 |
| 9 | 整理高覆盖测试文档 | 已完成 |
| 10 | 支持 Markdown 常用 4-face static 字体族示例和测试 | 已完成 |

## API 形态

系统字体使用 CSS `font-family` 语法：

```swift
MarkdownStyle(
    fontFamily: "\"Avenir Next\", -apple-system, sans-serif",
    fontSize: 18,
    lineHeight: 1.6,
    codeFontFamily: "\"SF Mono\", Menlo, monospace"
)
```

app 导入字体使用 `MarkdownFontFace`。WebView 会把字体注入为 data URL，
不依赖 CSS 跨 bundle 读取字体文件。

```swift
MarkdownStyle(
    fontFamily: "'LXGW WenKai', -apple-system, sans-serif",
    fontFaces: [
        MarkdownFontFace(
            fontFamily: "LXGW WenKai",
            source: .appResource(
                name: "LXGWWenKai-Regular",
                fileExtension: "ttf",
                bundleIdentifier: nil
            )
        )
    ]
)
```

只提供 Regular face 是有效配置。缺少 Bold、Italic 或 BoldItalic 时，
WebKit 会按 CSS fallback 规则合成或回退；提供 4 个 face 时，Markdown
的粗体、斜体、粗斜体会匹配真实字体文件。

```swift
MarkdownStyle(
    fontFamily: "'Merriweather', Georgia, serif",
    fontFaces: [
        MarkdownFontFace(
            fontFamily: "Merriweather",
            source: .appResource(name: "Merriweather-Regular", fileExtension: "ttf", bundleIdentifier: nil),
            fontWeight: "400",
            fontStyle: "normal"
        ),
        MarkdownFontFace(
            fontFamily: "Merriweather",
            source: .appResource(name: "Merriweather-Bold", fileExtension: "ttf", bundleIdentifier: nil),
            fontWeight: "700",
            fontStyle: "normal"
        ),
        MarkdownFontFace(
            fontFamily: "Merriweather",
            source: .appResource(name: "Merriweather-Italic", fileExtension: "ttf", bundleIdentifier: nil),
            fontWeight: "400",
            fontStyle: "italic"
        ),
        MarkdownFontFace(
            fontFamily: "Merriweather",
            source: .appResource(name: "Merriweather-BoldItalic", fileExtension: "ttf", bundleIdentifier: nil),
            fontWeight: "700",
            fontStyle: "italic"
        )
    ]
)
```

`bundleIdentifier: nil` 表示使用 `Bundle.main`。字体放在 framework bundle
时传入对应 bundle identifier。

## 剩余工作

- 如果 raw CSS 字符串容易误用，再考虑为常见 Apple 系统字体栈增加类型化包装。

## 示例字体

- 系统字体：Georgia、Avenir Next、Menlo，用来展示 Serif、Rounded Sans 和 Mono
  三类辨识度明显的系统字体栈。
- app 内嵌字体：Atkinson Hyperlegible、Merriweather。示例提供
  Regular、Bold、Italic、BoldItalic 四个 static face，字体文件和对应 OFL
  文本位于 `Example/Shared/Fonts/`。
