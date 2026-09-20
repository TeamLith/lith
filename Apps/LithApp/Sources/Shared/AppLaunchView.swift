import SwiftUI
import Lith

/// Debug-only launch argument selects an isolated, deterministic library for XCTest.
@MainActor
enum UITestSupport {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        false
        #endif
    }
    static func seed(_ dependencies: AppDependencyContainer) async throws {
        let note = Note(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                        title: "UI Test Note", bodyMarkdown: "Isolated navigation fixture", tags: ["uitest"])
        try await dependencies.noteRepository.upsert(note)
        let feed = RSSFeed(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                           title: "UI Test Feed", feedURL: URL(string: "https://example.invalid/feed")!)
        try await dependencies.rssRepository.addFeed(feed)
        try await dependencies.rssRepository.upsertItems([
            RSSItem(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, feedID: feed.id,
                    title: "UI Test Article", content: "Review this article before saving.", linkURL: URL(string: "https://example.invalid/article")!)
        ])
    }
}

struct AppLaunchView: View {
    let dependencies: AppDependencyContainer
    @State private var ready = !UITestSupport.isEnabled
    @State private var failure: String?
    var body: some View {
        Group {
            if ready { RootView(dependencies: dependencies) }
            else if let failure { Text("UI test setup failed: \(failure)").accessibilityIdentifier("ui-test-setup-error") }
            else { ProgressView("Preparing test library") }
        }
        .task {
            guard !ready, UITestSupport.isEnabled else { return }
            do { try await UITestSupport.seed(dependencies); ready = true }
            catch { failure = error.localizedDescription }
        }
    }
}
