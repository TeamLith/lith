import SwiftUI
import Lith

@main
struct LithmacOSApp: App {
    private let dependencies: AppDependencyContainer

    init() {
        self.dependencies = Self.makeDependencies()
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .frame(minWidth: 700, minHeight: 460)
        }
    }

    private static func makeDependencies() -> AppDependencyContainer {
        do {
            return try AppDependencyContainer(mode: .live)
        } catch {
            preconditionFailure("Failed to bootstrap Lith macOS dependencies: \(error)")
        }
    }
}
