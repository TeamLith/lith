import SwiftUI
import NativeNotes

struct RootView: View {
    private let title: String

    init(title: String = "NativeNotes") {
        self.title = title
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.largeTitle)
                    .bold()

                Text("Shared package wired")
                    .font(.headline)

                Text("Sample source: \(NoteSource.manual.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
