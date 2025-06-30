import Foundation

enum BlockNode: Hashable {
  case blockquote(children: [MarkdownContent.IdentifiedBlockNode])
  case bulletedList(isTight: Bool, items: [RawListItem])
  case numberedList(isTight: Bool, start: Int, items: [RawListItem])
  case taskList(isTight: Bool, items: [RawTaskListItem])
  case codeBlock(fenceInfo: String?, content: String)  // TODO: opacity
  case htmlBlock(content: String) // TODO: opacity
  case paragraph(content: [InlineNode])
  case heading(level: Int, content: [InlineNode])
  case table(columnAlignments: [RawTableColumnAlignment], rows: [RawTableRow])
  case thematicBreak
}

extension BlockNode {
  var children: [MarkdownContent.IdentifiedBlockNode] {
    switch self {
    case .blockquote(let children):
      return children
    case .bulletedList(_, let items):
      return items.map(\.children).flatMap { $0 }
    case .numberedList(_, _, let items):
      return items.map(\.children).flatMap { $0 }
    case .taskList(_, let items):
      return items.map(\.children).flatMap { $0 }
    default:
      return []
    }
  }

  var isParagraph: Bool {
    guard case .paragraph = self else { return false }
    return true
  }
}

struct RawListItem: Hashable {
  let children: [MarkdownContent.IdentifiedBlockNode]
}

struct RawTaskListItem: Hashable {
  let isCompleted: Bool
  let children: [MarkdownContent.IdentifiedBlockNode]
}

enum RawTableColumnAlignment: Character {
  case none = "\0"
  case left = "l"
  case center = "c"
  case right = "r"
}

struct RawTableRow: Hashable {
  let cells: [RawTableCell]
}

struct RawTableCell: Hashable {
  let content: [InlineNode]
}
