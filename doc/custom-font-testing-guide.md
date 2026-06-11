# 自定义字体测试指南

## 目标

验证 Markdown 字体样式从 SwiftUI API 到 `WKWebView` CSS 的完整链路：

- 系统字体栈能正确写入 CSS variables。
- app 内嵌字体能通过 `@font-face` 注入并被 WebView 使用。
- 只传 Regular face 时保持兼容，传 4 个 static face 时匹配 Markdown
  常用的 normal、bold、italic、bold italic。
- 字体切换不会破坏 Markdown 渲染、代码块字体、KaTeX、暗色模式和跨平台构建。
- Example 能作为可视化验收入口。

## 测试范围

| 层级 | 覆盖内容 | 验收方式 |
| --- | --- | --- |
| API | `MarkdownStyle` 字体字段、`MarkdownFontFace`、`MarkdownFontSource` | 单元测试、编译检查 |
| CSS 生成 | CSS variables、`@font-face`、data URL、MIME type | 单元测试 |
| WebView 注入 | `__markdown_custom_style__` style tag、环境样式刷新 | Safari Develop 手工验证 |
| Example | 默认、系统字体、app 内嵌字体切换 | iOS/macOS 构建和视觉检查 |
| 资源 | app 字体文件复制、OFL 文本保留 | Xcode 构建日志、文件检查 |
| 回归 | Markdown、代码块、KaTeX、主题切换、链接 | 手工矩阵 |

## 自动化测试

### SwiftPM 单元测试

```sh
swift test
```

必须覆盖：

- `testStyleBuildsSystemFontCSS`
  - `--markdown-font-family`
  - `--markdown-font-size`
  - `--markdown-line-height`
  - `--markdown-code-font-family`
- `testStyleBuildsAppFontFaceDataURL`
  - `@font-face`
  - `font-family`
  - `src: url('data:font/ttf;base64,...')`
  - `font-weight`
  - `font-style`
- `testStyleBuildsStaticMarkdownFontFamilyFaces`
  - 同一 `fontFamily` 生成 4 个 `@font-face`
  - `400 normal`
  - `700 normal`
  - `400 italic`
  - `700 italic`

建议后续补充：

- `.otf`、`.woff`、`.woff2` MIME type 映射。
- 不存在字体文件时 `@font-face` 不生成，且不会崩溃。
- `fontFamily` 中包含单引号、反斜杠、换行时 CSS/JS 转义正确。
- 多个 `MarkdownFontFace` 同时注入时顺序稳定。

### Xcode 构建

macOS：

```sh
xcodebuild \
  -project Example/Example.xcodeproj \
  -scheme "Example (macOS)" \
  -destination 'platform=macOS' \
  build
```

iOS：

```sh
xcodebuild \
  -project Example/Example.xcodeproj \
  -scheme "Example (iOS)" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

验收点：

- 两个 target 都能编译通过。
- 构建日志中复制 `AtkinsonHyperlegible-Regular.ttf`。
- 构建日志中复制 `AtkinsonHyperlegible-Bold.ttf`。
- 构建日志中复制 `AtkinsonHyperlegible-Italic.ttf`。
- 构建日志中复制 `AtkinsonHyperlegible-BoldItalic.ttf`。
- 构建日志中复制 `Merriweather-Regular.ttf`。
- 构建日志中复制 `Merriweather-Bold.ttf`。
- 构建日志中复制 `Merriweather-Italic.ttf`。
- 构建日志中复制 `Merriweather-BoldItalic.ttf`。
- 构建日志中没有复制旧的 `KaTeX_Typewriter-Regular.ttf` 到 Example app。

### 格式检查

```sh
git diff --check
```

验收点：

- 无 trailing whitespace。
- 无 patch 格式错误。

## Safari Develop 验证

### 准备

1. Safari 打开 `Settings > Advanced > Show features for web developers`。
2. 运行 Example app。
3. 进入 `API > Fonts`。
4. 如 `Develop` 菜单中看不到 WebView，给 `WKWebView` 临时开启：

```swift
if #available(iOS 16.4, macOS 13.3, *) {
    webView.isInspectable = true
}
```

### 检查 DOM 和 CSS

在 Safari 中打开：

```text
Develop > My Mac 或 Simulator > Example > Markdown Preview
```

选中：

```html
<div id="__markdown_preview__" class="markdown-body">
```

检查 `Computed`：

```js
getComputedStyle(document.querySelector('.markdown-body')).fontFamily
```

各选项预期：

| Example 选项 | 预期 `fontFamily` 包含 |
| --- | --- |
| Default | `-apple-system` 或 WebKit 默认 fallback |
| System Serif | `Georgia` |
| System Rounded | `Avenir Next` |
| System Mono | `Menlo` |
| App Atkinson | `Atkinson Hyperlegible Demo` |
| App Merriweather | `Merriweather Demo` |

检查自定义 style tag：

```js
document.getElementById('__markdown_custom_style__')?.textContent
```

app 字体选项预期包含：

```css
@font-face
src: url('data:font/ttf;base64,
```

4-face app 字体选项还应包含：

```css
font-weight: 400; font-style: normal;
font-weight: 700; font-style: normal;
font-weight: 400; font-style: italic;
font-weight: 700; font-style: italic;
```

系统字体选项预期不包含 `@font-face`。

## 手工视觉矩阵

### 字体切换

| 用例 | 操作 | 预期 |
| --- | --- | --- |
| 默认样式 | 选择 `Default` | 与原 GitHub-style Markdown 视觉一致 |
| 系统 Serif | 选择 `System Serif` | 正文为 serif，代码块为 Menlo |
| 系统 Rounded | 选择 `System Rounded` | 正文更圆润，代码块保持 monospace |
| 系统 Mono | 选择 `System Mono` | 正文和代码块都呈 monospace |
| App Atkinson | 选择 `App Atkinson` | 字形与系统字体明显不同，字母辨识度高 |
| App Merriweather | 选择 `App Merriweather` | 正文呈屏幕阅读 serif 风格 |
| App 4-face | 查看 normal/bold/italic/bold italic 示例句 | 粗体、斜体、粗斜体都有真实 face 匹配 |

### Markdown 内容

| 内容 | 预期 |
| --- | --- |
| `#` / `##` 标题 | 字体切换后标题层级仍明显 |
| 段落 | 行高生效，阅读节奏稳定 |
| 列表 | marker 对齐，无重叠 |
| fenced code block | 未设置 `codeFontFamily` 时继承 `fontFamily`；设置后使用 `codeFontFamily` |
| inline code | 未设置 `codeFontFamily` 时继承 `fontFamily`；设置后使用 `codeFontFamily` |
| 链接 | 颜色和点击行为不受字体样式影响 |
| 粗体/斜体 | 系统 fallback 可接受，不出现空白文字 |

### 平台和主题

| 场景 | 预期 |
| --- | --- |
| macOS Light | 字体切换即时生效，无白屏 |
| macOS Dark | 字体切换即时生效，颜色变量正常 |
| iOS Light | 字体切换即时生效，无布局跳动 |
| iOS Dark | 字体切换即时生效，颜色变量正常 |
| 窗口缩放/旋转 | WebView 尺寸正确，文字不被裁切 |

### 回归边界

| 场景 | 预期 |
| --- | --- |
| KaTeX 页面 | 数学公式仍使用 KaTeX 自带字体 |
| Code Block 页面 | 复制按钮仍显示，代码块布局不变 |
| Base Markdown 页面 | 默认样式无行为变化 |
| List 页面 | 任务列表、普通列表不受字体 API 影响 |
| 内容更新 | 修改 `content` 后新内容沿用当前字体样式 |
| 样式更新 | 只切换 `MarkdownStyle` 时 WebView 不需要重建也能刷新 |

## 资源和授权检查

确认文件存在：

```sh
find Example/Shared/Fonts -maxdepth 1 -type f -print | sort
```

必须包含：

- `AtkinsonHyperlegible-Regular.ttf`
- `AtkinsonHyperlegible-Bold.ttf`
- `AtkinsonHyperlegible-Italic.ttf`
- `AtkinsonHyperlegible-BoldItalic.ttf`
- `AtkinsonHyperlegible-OFL.txt`
- `Merriweather-Regular.ttf`
- `Merriweather-Bold.ttf`
- `Merriweather-Italic.ttf`
- `Merriweather-BoldItalic.ttf`
- `Merriweather-OFL.txt`

授权验收：

- `AtkinsonHyperlegible-OFL.txt` 包含 `SIL Open Font License, Version 1.1`。
- `Merriweather-OFL.txt` 包含 `SIL Open Font License, Version 1.1`。
- 不把字体文件单独销售。
- 修改字体文件名或字体内部命名时遵守 OFL Reserved Font Name 条款。

## 建议覆盖率目标

| 类型 | 目标 |
| --- | --- |
| 单元测试 | 覆盖所有 CSS 生成分支和文件 MIME type |
| 构建测试 | 每次字体链路改动都跑 macOS 和 iOS Example |
| 手工视觉 | 每次改 CSS、WebView 注入、Example 字体资源都跑完整字体切换矩阵 |
| 授权检查 | 每次替换 app 内嵌字体都保留 license 文本和来源记录 |

## 发布前验收清单

- [ ] `swift test` 通过。
- [ ] `xcodebuild` macOS Example 通过。
- [ ] `xcodebuild` iOS Example 通过。
- [ ] `git diff --check` 通过。
- [ ] Safari Develop 可看到 `__markdown_custom_style__`。
- [ ] `App Atkinson` computed font 包含 `Atkinson Hyperlegible Demo`。
- [ ] `App Merriweather` computed font 包含 `Merriweather Demo`。
- [ ] 系统字体选项不生成 `@font-face`。
- [ ] app 字体选项生成 data URL `@font-face`。
- [ ] app 字体选项生成 4 个 face：`400 normal`、`700 normal`、`400 italic`、`700 italic`。
- [ ] KaTeX 页面公式渲染正常。
- [ ] OFL 文本随字体文件保留。
