import BlockInputKit
import SwiftUI

struct DemoSwiftUIPreview: View {
    private let store = BlockInputMemoryDocumentStore(document: DemoData.swiftUIDocument())
    @State private var isEditorFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button("Focus") {
                    isEditorFocused = true
                }
                Button("Resign") {
                    isEditorFocused = false
                }
                Text(isEditorFocused ? "Focused" : "Not focused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            BlockInputEditor(
                configuration: BlockInputConfiguration(
                    documentStore: store,
                    allowsBlockReordering: false
                ),
                isFocused: $isEditorFocused
            )
            .frame(minHeight: 120)
        }
        .padding(.vertical, 4)
    }
}
