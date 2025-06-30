import SwiftUI

struct BlockquoteView: View {
  @Environment(\.theme.blockquote) private var blockquote

  private let children: [MarkdownContent.IdentifiedBlockNode]

  init(children: [MarkdownContent.IdentifiedBlockNode]) {
    self.children = children
  }

  var body: some View {
    self.blockquote.makeBody(
      configuration: .init(
        label: .init(BlockSequence(self.children)),
        content: .init(block: .blockquote(children: self.children))
      )
    )
  }
}
