import SwiftUI

struct BlockSequence<Data, ID: Hashable, Content>: View
where
  Data: Sequence,
  Content: View
{
  @Environment(\.multilineTextAlignment) private var textAlignment
  @Environment(\.tightSpacingEnabled) private var tightSpacingEnabled

  @State private var blockMargins: [IdentifiableIndexed<ID, Data.Element>.ID: BlockMargin] = [:]

  private let data: [IdentifiableIndexed<ID, Data.Element>]
  private let id: (Data.Element) -> ID
  private let content: (Int, Data.Element) -> Content

  init(
    _ data: Data,
    id: @escaping (Data.Element) -> ID,
    @ViewBuilder content: @escaping (_ index: Int, _ element: Data.Element) -> Content
  ) {
    self.data = data.enumerated().map { IdentifiableIndexed(index: $0.offset, value: $0.element, valueID: id) }
    self.id = id
    self.content = content
  }

  var body: some View {
    VStack(alignment: self.textAlignment.alignment.horizontal, spacing: 0) {
      ForEach(self.data) { element in
        self.content(element.index, element.value)
          .onPreferenceChange(BlockMarginsPreference.self) { value in
            self.blockMargins[element.id] = value
          }
          .padding(.top, self.topPaddingLength(for: element))
      }
    }
  }

  private func topPaddingLength(for element: IdentifiableIndexed<ID, Data.Element>) -> CGFloat? {
    guard element.index > 0 else {
      return 0
    }

    let topSpacing = self.blockMargins[element.id]?.top
    let predecessor = self.data[element.index - 1]
    let predecessorBottomSpacing =
      self.tightSpacingEnabled ? 0 : self.blockMargins[predecessor.id]?.bottom

    return [topSpacing, predecessorBottomSpacing]
      .compactMap { $0 }
      .max()
  }
}


private struct IdentifiableIndexed<ValueID: Hashable, Value>: Identifiable {
  struct ID: Hashable {
    let valueID: ValueID
    let index: Int
  }

  var id: ID { ID(valueID: valueID(value), index: index) }
  let index: Int
  let value: Value
  let valueID: (Value) -> ValueID
}

extension BlockSequence where Data == [MarkdownContent.IdentifiedBlockNode], Content == BlockNode, ID == OptimizedBlockID {
  init(_ blocks: [MarkdownContent.IdentifiedBlockNode]) {
    self.init(blocks, id: \.optimizedID) { $1.value }
  }
}

extension BlockNode {
  var nonIdentified: MarkdownContent.IdentifiedBlockNode {
    MarkdownContent.IdentifiedBlockNode(value: self)
  }
}

extension MarkdownContent.IdentifiedBlockNode {
  var optimizedID: OptimizedBlockID {
    if let id {
      OptimizedBlockID.id(id)
    } else {
      OptimizedBlockID.content(value)
    }
  }
}

enum OptimizedBlockID: Hashable {
  case id(UUID)
  case content(BlockNode)
}

extension TextAlignment {
  fileprivate var alignment: Alignment {
    switch self {
    case .leading:
      return .leading
    case .center:
      return .center
    case .trailing:
      return .trailing
    }
  }
}
