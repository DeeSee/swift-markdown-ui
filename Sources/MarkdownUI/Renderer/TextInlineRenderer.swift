import SwiftUI

extension Sequence where Element == InlineNode {
  func renderText(
    baseURL: URL?,
    textStyles: InlineTextStyles,
    images: [String: Image],
    customInlines: [String: Text],
    softBreakMode: SoftBreak.Mode,
    attributes: AttributeContainer,
    favicons: Favicons?,
    fetchedFavicons: [String: Text],
  ) -> Text {
    var renderer = TextInlineRenderer(
      baseURL: baseURL,
      textStyles: textStyles,
      images: images,
      customInlines: customInlines,
      softBreakMode: softBreakMode,
      attributes: attributes,
      favicons: favicons,
      fetchedFavicons: fetchedFavicons,
    )
    renderer.render(self)
    return renderer.result
  }
}

private struct TextInlineRenderer {
  var result = Text("")

  private let baseURL: URL?
  private let textStyles: InlineTextStyles
  private let images: [String: Image]
  private let customInlines: [String: Text]
  private let softBreakMode: SoftBreak.Mode
  private let attributes: AttributeContainer
  private let favicons: Favicons?
  private let fetchedFavicons: [String: Text]
  private var shouldSkipNextWhitespace = false

  init(
    baseURL: URL?,
    textStyles: InlineTextStyles,
    images: [String: Image],
    customInlines: [String: Text],
    softBreakMode: SoftBreak.Mode,
    attributes: AttributeContainer,
    favicons: Favicons?,
    fetchedFavicons: [String: Text],
  ) {
    self.baseURL = baseURL
    self.textStyles = textStyles
    self.images = images
    self.customInlines = customInlines
    self.softBreakMode = softBreakMode
    self.attributes = attributes
    self.favicons = favicons
    self.fetchedFavicons = fetchedFavicons
  }

  mutating func render(_ inlines: some Sequence<InlineNode>) {
    for inline in inlines {
      self.render(inline)
    }
  }

  private mutating func render(_ inline: InlineNode) {
    switch inline {
    case .text(let content, let opacity):
      self.renderText(content, opacityRegions: opacity)
    case .softBreak:
      self.renderSoftBreak()
    case .html(let content, _):
      self.renderHTML(content)
    case .image(let source, _):
      self.renderImage(source, opacity: 1)
    case .link(let source, let label):
      if label.first?.allowFavicon ?? true,
         let favicon = self.fetchedFavicons[source]
          ?? self.favicons?.cached(source)
          ?? self.favicons?.placeholder {
        self.result = self.result + favicon + Text("\u{00A0}")
      }
      self.defaultRender(inline)
    case .custom(let value, let opacity):
      self.result = self.result + (self.customInlines[value.id] ?? value.renderSync()).foregroundColor(.primary.opacity(opacity))
    default:
      self.defaultRender(inline)
    }
  }

  private mutating func renderText(_ text: String, opacityRegions: [Range<Int>: CGFloat]) {
    var text = text

    if self.shouldSkipNextWhitespace {
      self.shouldSkipNextWhitespace = false
      text = text.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
    }

    self.defaultRender(.text(text, opacityRegions: opacityRegions))
  }

  private mutating func renderSoftBreak() {
    switch self.softBreakMode {
    case .space where self.shouldSkipNextWhitespace:
      self.shouldSkipNextWhitespace = false
    case .space:
      self.defaultRender(.softBreak)
    case .lineBreak:
      self.shouldSkipNextWhitespace = true
      self.defaultRender(.lineBreak)
    }
  }

  private mutating func renderHTML(_ html: String) {
    let tag = HTMLTag(html)

    switch tag?.name.lowercased() {
    case "br":
      self.defaultRender(.lineBreak)
      self.shouldSkipNextWhitespace = true
    default:
      self.defaultRender(.html(html))
    }
  }

  private mutating func renderImage(_ source: String, opacity: CGFloat) {
    if let image = self.images[source] {
      self.result = self.result + Text(image).foregroundColor(Color.primary.opacity(opacity))
    }
  }

  private func makeText(_ inline: InlineNode) -> Text {
    Text(
      inline.renderAttributedString(
        baseURL: self.baseURL,
        textStyles: self.textStyles,
        softBreakMode: self.softBreakMode,
        attributes: self.attributes
      )
    )
  }

  private mutating func defaultRender(_ inline: InlineNode) {
    self.result = self.result + makeText(inline)
  }
}

extension InlineNode {
  fileprivate var allowFavicon: Bool {
    switch self {
    case .text, .softBreak, .lineBreak, .code, .html: true
    case .emphasis(children: let children),
        .strong(children: let children),
        .strikethrough(children: let children),
        .link(destination: _, children: let children):
      children.first?.allowFavicon ?? true
    case .image, .custom:
      false
    }
  }
}
