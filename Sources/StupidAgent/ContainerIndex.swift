// The app is iOS-only; the guard lets `swift test` build the package on macOS for the core tests.
#if os(iOS)
import Foundation
import Observation
import StupidAgentCore

/// Observable view-model over `SandboxContainers`' background index, for the Settings progress UI. It owns the
/// `SandboxContainers` the agent sessions use, so the index the user watches is the one the agent reads.
@MainActor @Observable
final class ContainerIndex {
    /// The access object passed to agent sessions.
    let access: SandboxContainers

    private(set) var status: ContainerIndexStatus = .ready
    private(set) var lastIndexed: Date?
    private(set) var errorMessage: String?

    init(access: SandboxContainers = SandboxContainers()) {
        self.access = access
        self.status = access.isAvailable ? .ready : .unavailable
        access.setProgressHandler { [weak self] progress in
            Task { @MainActor in self?.apply(progress) }
        }
    }

    var isAvailable: Bool { access.isAvailable }

    /// 0...1 while indexing (nil when the inode total isn't known yet or when not indexing).
    var fractionComplete: Double? {
        guard case let .indexing(_, scanned, total) = status, total > 0 else { return nil }
        return min(1, Double(scanned) / Double(total))
    }

    /// Containers found so far, for a count in the UI.
    var foundCount: Int {
        if case let .indexing(found, _, _) = status { return found }
        return 0
    }

    /// Starts indexing if it hasn't run yet (e.g. when the user turns the feature on).
    func start() { access.startIndexing() }

    /// Discards the cache and rescans from scratch.
    func reindex() { access.startIndexing(force: true) }

    private func apply(_ progress: SandboxContainers.Progress) {
        status = progress.status
        lastIndexed = progress.lastIndexed
        errorMessage = progress.error
    }
}

#endif
