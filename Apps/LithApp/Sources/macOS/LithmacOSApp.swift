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
            AppLaunchView(dependencies: dependencies)
                .frame(minWidth: 700, minHeight: 460)
        }
    }

    private static func makeDependencies() -> AppDependencyContainer {
        do {
            return try AppDependencyContainer(mode: UITestSupport.isEnabled ? .inMemory : .live)
        } catch {
            preconditionFailure("Failed to bootstrap Lith macOS dependencies: \(error)")
        }
    }
}
