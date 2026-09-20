import Foundation

/// Serializes cross-context local mutations so parent deletion and child writes
/// cannot pass independent existence checks at the same time. Never await inside.
enum LithStoreWriteLock {
    private static let lock = NSRecursiveLock()
    static func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}
