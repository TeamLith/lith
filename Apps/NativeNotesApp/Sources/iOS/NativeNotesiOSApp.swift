import SwiftUI
import NativeNotes

@main
struct NativeNotesiOSApp: App {
    private let dependencies: AppDependencyContainer

    init() {
        self.dependencies = Self.makeDependencies()
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
    }

    private static func makeDependencies() -> AppDependencyContainer {
        do {
            return try AppDependencyContainer(mode: .live)
        } catch {
            preconditionFailure("Failed to bootstrap NativeNotes iOS dependencies: \(error)")
        }
    }
}
