import SwiftUI
import Lith

struct RootView: View {
    private let title: String
    private let dependencies: AppDependencyContainer

    init(
        title: String = "Lith",
        dependencies: AppDependencyContainer
    ) {
        self.title = title
        self.dependencies = dependencies
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

                Text("Persistence bootstrap: \(dependencies.persistentContainer.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
