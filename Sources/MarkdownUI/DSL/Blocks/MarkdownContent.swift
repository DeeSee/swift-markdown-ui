import Foundation

/// A protocol that represents any Markdown content.
public protocol MarkdownContentProtocol {
  var _markdownContent: MarkdownContent { get }
}

/// A Markdown content value.
///
/// A Markdown content value consists of a sequence of blocks – structural elements like paragraphs, blockquotes, lists,
/// headings, thematic breaks, and code blocks. Some blocks, like blockquotes and list items, contain other blocks; others,
/// like headings and paragraphs, have inline text, links, emphasized text, etc.
///
/// You can create a Markdown content value by passing a Markdown-formatted string to ``init(_:)``.
///
/// ```swift
/// let content = MarkdownContent("You can try **CommonMark** [here](https://spec.commonmark.org/dingus/).")
/// ```
///
/// Alternatively, you can build a Markdown content value using a domain-specific language for blocks and inline text.
///
/// ```swift
/// let content = MarkdownContent {
///   Paragraph {
///     "You can try "
///     Strong("CommonMark")
///     SoftBreak()
///     InlineLink("here", destination: URL(string: "https://spec.commonmark.org/dingus/")!)
///     "."
///   }
/// }
/// ```
///
/// Once you have created a Markdown content value, you can display it using a ``Markdown`` view.
///
/// ```swift
/// var body: some View {
///   Markdown(self.content)
/// }
/// ```
///
/// A Markdown view also offers initializers that take a Markdown-formatted string ``Markdown/init(_:baseURL:imageBaseURL:)-63py1``,
/// or a Markdown content builder ``Markdown/init(baseURL:imageBaseURL:content:)``, so you don't need to create a
/// Markdown content value before displaying it.
///
/// ```swift
/// var body: some View {
///   VStack {
///     Markdown("You can try **CommonMark** [here](https://spec.commonmark.org/dingus/).")
///     Markdown {
///       Paragraph {
///         "You can try "
///         Strong("CommonMark")
///         SoftBreak()
///         InlineLink("here", destination: URL(string: "https://spec.commonmark.org/dingus/")!)
///         "."
///       }
///     }
///   }
/// }
/// ```
public struct MarkdownContent: Hashable, MarkdownContentProtocol, Sendable {
  /// Returns a Markdown content value with the sum of the contents of all the container blocks
  /// present in this content.
  ///
  /// You can use this property to access the contents of a blockquote or a list. Returns `nil` if
  /// there are no container blocks.
  public var childContent: MarkdownContent? {
    let children = self.blocks.map(\.children).flatMap { $0 }
    return children.isEmpty ? nil : .init(identifiedBlocks: children)
  }

  struct IdentifiedBlockNode: Hashable {
    var id: UUID?
    var value: BlockNode

    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.value == rhs.value
    }
  }

  public var _markdownContent: MarkdownContent { self }
  let identifiedBlocks: [IdentifiedBlockNode]
  var blocks: [BlockNode] { identifiedBlocks.map(\.value) }

  public var isEmpty: Bool { blocks.isEmpty }

  public func commonPrefix(other: Self) -> (prefix: Self, leftover: Self) {
    let prefix = Array(zip(blocks, other.blocks).prefix {
      $0 == $1
    }.map { $0.0 })
    return (MarkdownContent(blocks: prefix), MarkdownContent(blocks: Array(other.blocks.suffix(from: prefix.count))))
  }

  init(blocks: [BlockNode]) {
    self.identifiedBlocks = blocks.map { IdentifiedBlockNode(id: nil, value: $0) }
  }

  init(identifiedBlocks: [IdentifiedBlockNode] = []) {
    self.identifiedBlocks = identifiedBlocks
  }

  init(block: BlockNode) {
    self.init(blocks: [block])
  }

  init(_ components: [MarkdownContentProtocol]) {
    self.init(blocks: components.map(\._markdownContent).flatMap(\.blocks))
  }

  /// Creates a Markdown content value from a Markdown-formatted string.
  /// - Parameter markdown: A Markdown-formatted string.
  public init(_ markdown: String, extensions: [CmarkExtension] = []) {
    self.init(blocks: .init(markdown: markdown, extensions: extensions))
  }

  /// Creates a Markdown content value composed of any number of blocks.
  /// - Parameter content: A Markdown content builder that returns the blocks that form the Markdown content.
  public init(@MarkdownContentBuilder content: () -> MarkdownContent) {
    self.init(blocks: content().blocks)
  }

  /// Renders this Markdown content value as a Markdown-formatted text.
  public func renderMarkdown() -> String {
    let result = self.blocks.renderMarkdown()
    return result.hasSuffix("\n") ? String(result.dropLast()) : result
  }

  /// Renders this Markdown content value as plain text.
  public func renderPlainText() -> String {
    let result = self.blocks.renderPlainText()
    return result.hasSuffix("\n") ? String(result.dropLast()) : result
  }

  /// Renders this Markdown content value as HTML code.
  public func renderHTML() -> String {
    self.blocks.renderHTML()
  }

  public func reduceOpacity(by diff: CGFloat, forContentExcludingPrefix prefix: MarkdownContent) -> Self {
    .init(blocks: blocks.reduceOpacity(by: diff, forContentExcludingPrefix: prefix.blocks))
  }

  public func reuseIDs(from other: Self) -> Self {
    .init(identifiedBlocks: identifiedBlocks.reuseIDs(from: other.identifiedBlocks))
  }

  public func generateMissingIDs() -> Self {
    .init(identifiedBlocks: identifiedBlocks.map { $0.generateMissingIDs() })
  }
}

extension BlockNode {
  func generateMissingIDs() -> Self {
    switch self {
    case .blockquote(let children):
      return .blockquote(children: children.map { $0.generateMissingIDs() })
    case .bulletedList(isTight: let isTight, items: let items):
      return .bulletedList(isTight: isTight, items: items.map { $0.generateMissingIDs() })
    case .numberedList(isTight: let isTight, start: let start, items: let items):
      return .numberedList(isTight: isTight, start: start, items: items.map { $0.generateMissingIDs() })
    case .taskList(isTight: let isTight, items: let items):
      return .taskList(isTight: isTight, items: items.map { $0.generateMissingIDs() })
    case .codeBlock(fenceInfo: let fenceInfo, content: let content):
      return .codeBlock(fenceInfo: fenceInfo, content: content)
    case .htmlBlock(content: let content):
      return .htmlBlock(content: content)
    case .paragraph(content: let content):
      return .paragraph(content: content)
    case .heading(level: let level, content: let content):
      return .heading(level: level, content: content)
    case .table(columnAlignments: let columnAlignments, rows: let rows):
      return .table(columnAlignments: columnAlignments, rows: rows)
    case .thematicBreak:
      return .thematicBreak
    }
  }

  func reduceOpacity(by diff: CGFloat, forContentExcludingPrefix prefix: BlockNode) -> Self {
    switch (self, prefix) {
    case (.blockquote(let myChildren), .blockquote(let otherChildren)):
      return .blockquote(children: myChildren.reduceOpacity(by: diff, forContentExcludingPrefix: otherChildren))
    case (.bulletedList(isTight: let isTight, items: let items), .bulletedList(isTight: let otherIsTight, items: let otherItems)):
      return .bulletedList(isTight: isTight, items: items.reduceOpacity(by: diff, forContentExcludingPrefix: otherItems))
    case (.numberedList(isTight: let isTight, start: let start, items: let items), .numberedList(isTight: let otherIsTight, start: let otherStart, items: let otherItems)):
      return .numberedList(isTight: isTight, start: start, items: items.reduceOpacity(by: diff, forContentExcludingPrefix: otherItems))
    case (.taskList(isTight: let isTight, items: let items), .taskList(isTight: let otherIsTight, items: let otherItems)):
      return .taskList(isTight: isTight, items: items.reduceOpacity(by: diff, forContentExcludingPrefix: otherItems))
    case (.codeBlock(fenceInfo: let fenceInfo, content: let content), .codeBlock(fenceInfo: let otherFenceInfo, content: let otherContent)):
      return .codeBlock(fenceInfo: fenceInfo, content: content) // TODO: Support
    case (.htmlBlock(content: let content), .htmlBlock(content: let otherContent)):
      return .htmlBlock(content: content) // TODO: Support
    case (.paragraph(content: let content), .paragraph(content: let otherContent)):
      return .paragraph(content: content.reduceOpacity(by: diff, forContentExcludingPrefix: otherContent))
    case (.heading(level: let level, content: let content), .heading(level: let otherLevel, content: let otherContent)):
      return .heading(level: level, content: content.reduceOpacity(by: diff, forContentExcludingPrefix: otherContent))
    case (.table(columnAlignments: let columnAlignments, rows: let rows), .table(columnAlignments: let otherColumnAlignments, rows: let otherRows)):
      return .table(columnAlignments: columnAlignments, rows: rows.reduceOpacity(by: diff, forContentExcludingPrefix: otherRows))
    case (.thematicBreak, .thematicBreak):
      return .thematicBreak
    case (.blockquote, _),
        (.bulletedList, _),
        (.numberedList, _),
        (.taskList, _),
        (.codeBlock, _),
        (.htmlBlock, _),
        (.paragraph, _),
        (.heading, _),
        (.table, _),
        (.thematicBreak, _):
      return self
    }
  }

  func reduceOpacity(by diff: CGFloat) -> Self {
    switch self {
    case .blockquote(let children):
      return .blockquote(children: children.map { $0.reduceOpacity(by: diff) })
    case .bulletedList(isTight: let isTight, items: let items):
      return .bulletedList(isTight: isTight, items: items.map { $0.reduceOpacity(by: diff) })
    case .numberedList(isTight: let isTight, start: let start, items: let items):
      return .numberedList(isTight: isTight, start: start, items: items.map { $0.reduceOpacity(by: diff) })
    case .taskList(isTight: let isTight, items: let items):
      return .taskList(isTight: isTight, items: items.map { $0.reduceOpacity(by: diff) })
    case .codeBlock(fenceInfo: let fenceInfo, content: let content):
      return .codeBlock(fenceInfo: fenceInfo, content: content)
    case .htmlBlock(content: let content):
      return .htmlBlock(content: content)
    case .paragraph(content: let content):
      return .paragraph(content: content.map { $0.reduceOpacity(by: diff) })
    case .heading(level: let level, content: let content):
      return .heading(level: level, content: content.map { $0.reduceOpacity(by: diff) })
    case .table(columnAlignments: let columnAlignments, rows: let rows):
      return .table(columnAlignments: columnAlignments, rows: rows.map { $0.reduceOpacity(by: diff) })
    case .thematicBreak:
      return .thematicBreak
    }
  }

  func reuseIDs(from other: Self) -> Self {
    switch (self, other) {
    case (.blockquote(let children), .blockquote(let otherChildren)):
      return .blockquote(children: children.reuseIDs(from: otherChildren))
    case (.bulletedList(isTight: let isTight, items: let items), .bulletedList(isTight: let otherIsTight, items: let otherItems)):
      return .bulletedList(isTight: isTight, items: items.reuseIDs(from: otherItems))
    case (.numberedList(isTight: let isTight, start: let start, items: let items), .numberedList(isTight: let otherIsTight, start: let otherStart, items: let otherItems)):
      return .numberedList(isTight: isTight, start: start, items: items.reuseIDs(from: otherItems))
    case (.taskList(isTight: let isTight, items: let items), .taskList(isTight: let otherIsTight, items: let otherItems)):
      return .taskList(isTight: isTight, items: items.reuseIDs(from: otherItems))
    case (.codeBlock(fenceInfo: let fenceInfo, content: let content), .codeBlock(fenceInfo: let otherFenceInfo, content: let otherContent)):
      return .codeBlock(fenceInfo: fenceInfo, content: content)
    case (.htmlBlock(content: let content), .htmlBlock(content: let otherContent)):
      return .htmlBlock(content: content)
    case (.paragraph(content: let content), .paragraph(content: let otherContent)):
      return .paragraph(content: content)
    case (.heading(level: let level, content: let content), .heading(level: let otherLevel, content: let otherContent)):
      return .heading(level: level, content: content)
    case (.table(columnAlignments: let columnAlignments, rows: let rows), .table(columnAlignments: let otherColumnAlignments, rows: let otherRows)):
      return self
    case (.thematicBreak, .thematicBreak):
      return .thematicBreak
    case (.blockquote, _),
        (.bulletedList, _),
        (.numberedList, _),
        (.taskList, _),
        (.codeBlock, _),
        (.htmlBlock, _),
        (.paragraph, _),
        (.heading, _),
        (.table, _),
        (.thematicBreak, _):
      return self
    }
  }
}

extension [MarkdownContent.IdentifiedBlockNode] {
  func reduceOpacity(by diff: CGFloat, forContentExcludingPrefix prefix: Self) -> [Element] {
    map(\.value)
      .reduceOpacity(by: diff, forContentExcludingPrefix: prefix.map(\.value))
      .map(\.nonIdentified)
  }

  func reuseIDs(from other: Self) -> [Element] {
    withCommonPrefix(
      other,
      by: { $0.value == $1.value },
      head: { $0.reuseIDs(from: $1) },
      firstDiff: { $0.reuseIDs(from: $1) },
      tail: { $0 }
    )
  }
}

extension MarkdownContent.IdentifiedBlockNode {
  func reduceOpacity(by diff: CGFloat) -> Self {
    Self(value: value.reduceOpacity(by: diff))
  }

  func reuseIDs(from other: Self) -> Self {
    Self(
      id: value == other.value ? other.id : nil,
      value: value.reuseIDs(from: other.value)
    )
  }

  func generateMissingIDs() -> Self {
    Self(id: id ?? UUID(), value: value.generateMissingIDs())
  }
}

extension RawListItem {
  func reduceOpacity(by diff: CGFloat) -> Self {
    RawListItem(children: children.map { $0.reduceOpacity(by: diff) })
  }

  func reduceOpacity(by diff: CGFloat, forContentExcludingPrefix prefix: RawListItem) -> Self {
    RawListItem(children: children.reduceOpacity(by: diff, forContentExcludingPrefix: prefix.children))
  }

  func reuseIDs(from other: Self) -> Self {
    RawListItem(children: children.reuseIDs(from: other.children))
  }

  func generateMissingIDs() -> Self {
    RawListItem(children: children.map { $0.generateMissingIDs() })
  }
}

extension RawTaskListItem {
  func reduceOpacity(by diff: CGFloat) -> Self {
    RawTaskListItem(isCompleted: isCompleted, children: children.map { $0.reduceOpacity(by: diff) })
  }

  func reduceOpacity(by diff: CGFloat, forContentExcludingPrefix prefix: RawTaskListItem) -> Self {
    RawTaskListItem(isCompleted: isCompleted, children: children.reduceOpacity(by: diff, forContentExcludingPrefix: prefix.children))
  }

  func reuseIDs(from other: Self) -> Self {
    RawTaskListItem(isCompleted: isCompleted, children: children.reuseIDs(from: other.children))
  }

  func generateMissingIDs() -> Self {
    RawTaskListItem(isCompleted: isCompleted, children: children.map { $0.generateMissingIDs() })
  }
}

extension RawTableCell {
  func reduceOpacity(by diff: CGFloat) -> Self {
    RawTableCell(content: content.map { $0.reduceOpacity(by: diff) })
  }

  func reduceOpacity(by diff: CGFloat, forContentExcludingPrefix prefix: RawTableCell) -> Self {
    RawTableCell(content: content.reduceOpacity(by: diff, forContentExcludingPrefix: prefix.content))
  }
}

extension RawTableRow {
  func reduceOpacity(by diff: CGFloat) -> Self {
    RawTableRow(cells: cells.map { $0.reduceOpacity(by: diff) })
  }

  func reduceOpacity(by diff: CGFloat, forContentExcludingPrefix prefix: RawTableRow) -> Self {
    RawTableRow(cells: cells.reduceOpacity(by: diff, forContentExcludingPrefix: prefix.cells))
  }
}

extension [Range<Int>: CGFloat] {
  fileprivate func reduceOpacity(by diff: CGFloat, prefixEnd: Int) -> [Range<Int>: CGFloat] {
    let prefixRanges = filter {
      !$0.key.isEmpty && $0.key.upperBound <= prefixEnd
    }
    let tailRanges = filter {
      !$0.key.isEmpty && $0.key.lowerBound >= prefixEnd
    }.map { ($0.key, $0.value - diff) }
    let splitRanges = filter {
      $0.key.lowerBound <= prefixEnd && $0.key.upperBound >= prefixEnd
    }.flatMap {
      [
        (key: ($0.key.lowerBound..<prefixEnd), value: $0.value),
        (key: (prefixEnd..<$0.key.upperBound), value: $0.value - diff),
      ]
    }.filter {
      !$0.key.isEmpty
    }
    return Dictionary(prefixRanges + tailRanges + splitRanges, uniquingKeysWith: {
      assert($0 == $1)
      return Swift.min($0, $1)
    })
  }
}

extension InlineNode {
  func reduceOpacity(by diff: CGFloat, forContentExcludingPrefix prefix: InlineNode) -> Self {
    switch (self, prefix) {
    case (.text(let text, let opacity), .text(let otherText, _)):
      let prefixEnd = zip(text, otherText).prefix { $0 == $1 }.count

      return .text(text, opacityRegions: (opacity.isEmpty ? [(0..<text.count): 1] : opacity).reduceOpacity(by: diff, prefixEnd: prefixEnd))
    case (.html(let html, let opacity), .html(let otherHtml, _)):
      let prefixEnd = zip(html, otherHtml).prefix { $0 == $1 }.count
      return .html(html, opacityRegions: (opacity.isEmpty ? [(0..<html.count): 1] : opacity).reduceOpacity(by: diff, prefixEnd: prefixEnd))
    case (.image(let source, let children), .image(let otherSource, let otherChildren)):
      return .image(source: source, children: children.reduceOpacity(by: diff, forContentExcludingPrefix: otherChildren))
    case (.code(let code, let opacity), .code(let otherCode, _)):
      let prefixEnd = zip(code, otherCode).prefix { $0 == $1 }.count
      return .code(code, opacityRegions: (opacity.isEmpty ? [(0..<code.count): 1] : opacity).reduceOpacity(by: diff, prefixEnd: prefixEnd))
    case (.emphasis(let children), .emphasis(let otherChildren)):
      return .emphasis(children: children.reduceOpacity(by: diff, forContentExcludingPrefix: otherChildren))
    case (.strong(let children), .strong(let otherChildren)):
      return .strong(children: children.reduceOpacity(by: diff, forContentExcludingPrefix: otherChildren))
    case (.strikethrough(let children), .strikethrough(let otherChildren)):
      return .strikethrough(children: children.reduceOpacity(by: diff, forContentExcludingPrefix: otherChildren))
    case (.custom(let custom, let opacity), .custom(let otherCustom, _)):
      return .custom(custom, opacity: custom.id == otherCustom.id ? opacity : opacity - diff)
    case (.softBreak, _),
        (.lineBreak, _),
        (.custom, _),
        (.text, _),
        (.html, _),
        (.code, _),
        (.emphasis, _),
        (.strong, _),
        (.strikethrough, _),
        (.image, _),
        (.link, _),
        (.custom, _),
        (.softBreak, _),
        (.lineBreak, _):
      return reduceOpacity(by: diff)
    }
  }

  func reduceOpacity(by diff: CGFloat) -> Self {
    switch self {
    case .text(let text, let opacity):
      return .text(text, opacityRegions: (opacity.isEmpty ? [(0..<text.count): 1] : opacity).mapValues { $0 - diff })
    case .html(let html, let opacity):
      return .html(html, opacityRegions: (opacity.isEmpty ? [(0..<html.count): 1] : opacity).mapValues { $0 - diff })
    case .code(let code, let opacity):
      return .code(code, opacityRegions: (opacity.isEmpty ? [(0..<code.count): 1] : opacity).mapValues { $0 - diff })
    case .emphasis(let children):
      return .emphasis(children: children.map { $0.reduceOpacity(by: diff) })
    case .strong(let children):
      return .strong(children: children.map { $0.reduceOpacity(by: diff) })
    case .strikethrough(let children):
      return .strikethrough(children: children.map { $0.reduceOpacity(by: diff) })
    case .image(let source, let children):
      return .image(source: source, children: children.map { $0.reduceOpacity(by: diff) })
    case .link(let destination, let children):
      return .link(destination: destination, children: children.map { $0.reduceOpacity(by: diff) })
    case .custom(let custom, let opacity):
      return .custom(custom, opacity: opacity - diff)
    case .softBreak:
      return .softBreak
    case .lineBreak:
      return .lineBreak
    }
  }
}

extension Array {
  func withCommonPrefix(
    _ other: [Element],
    by: (Element, Element) -> Bool,
    head: (Element, Element) -> Element,
    firstDiff: (Element, Element) -> Element,
    tail: (Element) -> Element,
  ) -> [Element] {
    let prefix = zip(self, other).prefix { by($0, $1) }
    let prefixLength = prefix.count
    var result = Array(prefix.map(head))
    if prefixLength < count {
      if prefixLength < other.count {
        result.append(firstDiff(self[prefixLength], other[prefixLength]))
      } else {
        result.append(tail(self[prefixLength]))
      }
    }
    if prefixLength + 1 < count {
      result.append(contentsOf: self[(prefixLength + 1)...].map { tail($0) })
    }
    return result
  }
}

extension Array where Element: Equatable {
  func keepCommonPrefix(_ prefix: [Element], firstDiff: (Element, Element) -> Element, tail: (Element) -> Element) -> [Element] {
    withCommonPrefix(prefix, by: ==, head: { me, _ in me }, firstDiff: firstDiff, tail: tail)
  }

  func keepCommonPrefix(_ prefix: [Element], firstDiff: (Element, Element) -> [Element], tail: (Element) -> Element) -> [Element] {
    let prefixLength = zip(self, prefix).prefix { $0 == $1 }.count
    var result = Array(self.prefix(prefixLength))
    if prefixLength < count {
      if prefixLength < prefix.count {
        result.append(contentsOf: firstDiff(self[prefixLength], prefix[prefixLength]))
      } else {
        result.append(tail(self[prefixLength]))
      }
    }
    if prefixLength + 1 < count {
      result.append(contentsOf: self[(prefixLength + 1)...].map { tail($0) })
    }
    return result
  }
}

extension [InlineNode] {
  func reduceOpacity(by diff: CGFloat, forContentExcludingPrefix prefix: [InlineNode]) -> [InlineNode] {
    keepCommonPrefix(
      prefix,
      firstDiff: { $0.reduceOpacity(by: diff, forContentExcludingPrefix: $1) },
      tail: { $0.reduceOpacity(by: diff) }
    )
  }
}

extension [BlockNode] {
  func reduceOpacity(by diff: CGFloat, forContentExcludingPrefix prefix: [BlockNode]) -> [BlockNode] {
    keepCommonPrefix(
      prefix,
      firstDiff: { $0.reduceOpacity(by: diff, forContentExcludingPrefix: $1) },
      tail: { $0.reduceOpacity(by: diff) }
    )
  }

  func reuseIDs(from other: [BlockNode]) -> [BlockNode] {
    withCommonPrefix(
      other,
      by: { $0 == $1 },
      head: { $0.reuseIDs(from: $1) },
      firstDiff: { $0.reuseIDs(from: $1) },
      tail: { $0 }
    )
  }
}

extension [RawListItem] {
  func reduceOpacity(by diff: CGFloat, forContentExcludingPrefix prefix: [RawListItem]) -> [RawListItem] {
    keepCommonPrefix(
      prefix,
      firstDiff: { $0.reduceOpacity(by: diff, forContentExcludingPrefix: $1) },
      tail: { $0.reduceOpacity(by: diff) }
    )
  }

  func reuseIDs(from other: [RawListItem]) -> [RawListItem] {
    withCommonPrefix(
      other,
      by: { $0 == $1 },
      head: { $0.reuseIDs(from: $1) },
      firstDiff: { $0.reuseIDs(from: $1) },
      tail: { $0 }
    )
  }
}

extension [RawTaskListItem] {
  func reduceOpacity(by diff: CGFloat, forContentExcludingPrefix prefix: [RawTaskListItem]) -> [RawTaskListItem] {
    keepCommonPrefix(
      prefix,
      firstDiff: { $0.reduceOpacity(by: diff, forContentExcludingPrefix: $1) },
      tail: { $0.reduceOpacity(by: diff) }
    )
  }

  func reuseIDs(from other: [RawTaskListItem]) -> [RawTaskListItem] {
    withCommonPrefix(
      other,
      by: { $0 == $1 },
      head: { $0.reuseIDs(from: $1) },
      firstDiff: { $0.reuseIDs(from: $1) },
      tail: { $0 }
    )
  }
}

extension [RawTableCell] {
  func reduceOpacity(by diff: CGFloat, forContentExcludingPrefix prefix: [RawTableCell]) -> [RawTableCell] {
    keepCommonPrefix(
      prefix,
      firstDiff: { $0.reduceOpacity(by: diff, forContentExcludingPrefix: $1) },
      tail: { $0.reduceOpacity(by: diff) }
    )
  }
}

extension [RawTableRow] {
  func reduceOpacity(by diff: CGFloat, forContentExcludingPrefix prefix: [RawTableRow]) -> [RawTableRow] {
    keepCommonPrefix(
      prefix,
      firstDiff: { $0.reduceOpacity(by: diff, forContentExcludingPrefix: $1) },
      tail: { $0.reduceOpacity(by: diff) }
    )
  }
}
import SwiftUI

private struct TextKey: EnvironmentKey {
  static let defaultValue: AttributedString? = nil
}

extension EnvironmentValues {
  var tail: AttributedString? {
    get { self[TextKey.self] }
    set { self[TextKey.self] = newValue }
  }
}

extension View {
  public func markdownTail(_ tail: AttributedString?) -> some View {
    environment(\.tail, tail)
  }
}
