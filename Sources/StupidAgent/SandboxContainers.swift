// The app is iOS-only; the guard lets `swift test` build the package on macOS for the core tests.
#if os(iOS)
import Darwin
import Foundation
import os
import PiTools
import StupidAgentCore

/// Log for container indexing. View in Console or `log stream --predicate 'subsystem == "net.stupidtech.StupidAgent"'`.
private let discoveryLog = Logger(subsystem: "net.stupidtech.StupidAgent", category: "SandboxContainers")

/// Other apps' data containers and shared App Groups, reached through `SandboxBridge`.
///
/// Container directories can't be listed from inside the sandbox (except App Groups on iOS 27), so the Application
/// containers are found by resolving the volume's inodes to paths with `fsgetpath` — a slow, kernel-serialized scan
/// of tens of millions of inodes. It runs as a background index: `startIndexing()` kicks it off, progress is reported
/// through a handler for the Settings UI, and `containers()` returns whatever is resolved so far. The result is cached
/// across launches (see the scan cache), so the full scan only happens once.
final class SandboxContainers: AppContainerAccess, @unchecked Sendable {
    /// The App Group declared in App.entitlements and stupid-app.yml.
    static let groupIdentifier = SandboxBridge.groupIdentifier

    /// The directory each kind of container lives in.
    private static let appRoot = "/var/mobile/Containers/Data/Application"
    private static let groupRoot = "/var/mobile/Containers/Shared/AppGroup"

    /// A safety ceiling on the inode scan, so a pathologically high inode can't turn it into a multi-hour scan. Real
    /// devices sit far below this (~1.7e8 observed); the scan normally stops at the newest inode well under it.
    private static let maximumInode: UInt64 = 1_000_000_000

    /// A progress snapshot for the UI.
    struct Progress: Sendable {
        var status: ContainerIndexStatus
        var lastIndexed: Date?
        var error: String?
    }

    private let lock = NSLock()
    private var resolved: [AppContainer] = []
    private var indexing = false
    private var scanned: UInt64 = 0
    private var total: UInt64 = 0
    private var lastIndexed: Date?
    private var lastError: String?
    private var indexTask: Task<Void, Never>?
    private var progressHandler: (@Sendable (Progress) -> Void)?

    var isAvailable: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 else { return false }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.groupIdentifier) != nil
        #endif
    }

    // MARK: - AppContainerAccess

    var indexStatus: ContainerIndexStatus {
        lock.lock()
        defer { lock.unlock() }
        return statusLocked()
    }

    /// The containers resolved so far, starting the index if it hasn't run yet. Returns partial results while indexing.
    func containers() async throws -> [AppContainer] {
        startIndexing()
        return withLock { resolved }
    }

    /// Scoped locking usable from async contexts (`NSLock.lock`/`unlock` are not).
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    func root(for container: AppContainer) async throws -> URL {
        _ = try SandboxBridge.shared.grant(container.path)
        return URL(fileURLWithPath: container.path).resolvingSymlinksInPath()
    }

    // MARK: - Indexing control

    /// Installs the progress handler and delivers the current state at once. The handler is called on an arbitrary
    /// thread; hop to the main actor inside it.
    func setProgressHandler(_ handler: @escaping @Sendable (Progress) -> Void) {
        lock.lock()
        progressHandler = handler
        lock.unlock()
        emitProgress()
    }

    /// Starts the background index if it isn't already running. `force` discards the cache and rescans from scratch.
    func startIndexing(force: Bool = false) {
        guard isAvailable else { return }
        lock.lock()
        if force {
            indexTask?.cancel()
            indexTask = nil
            indexing = false
            resolved = []
            Self.clearCache()
        }
        guard indexTask == nil else {
            lock.unlock()
            return
        }
        indexing = true
        scanned = 0
        total = 0
        lastError = nil
        let task = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.runIndex()
        }
        indexTask = task
        lock.unlock()
        emitProgress()
    }

    // MARK: - Indexing

    private func runIndex() async {
        let start = DispatchTime.now()
        discoveryLog.log("index: begin")
        var result: [AppContainer] = []

        // App Groups list directly on iOS 27 — fast, no scan.
        if let listed = try? listedChildren(of: Self.groupRoot) {
            for path in listed {
                if Task.isCancelled { break }
                if let container = try? container(kind: .group, path: path) { result.append(container) }
            }
            publish(result)
        } else {
            discoveryLog.log("index: group root not listable; skipping app groups")
        }

        // Application containers need the inode scan, reported as progress.
        do {
            try scanAppContainers(into: &result)
        } catch {
            discoveryLog.log("index: failed: \(String(describing: error), privacy: .public)")
            finish(result: result, error: error)
            return
        }

        discoveryLog.log("index: done, \(result.count) containers in \(elapsedMillis(since: start), format: .fixed(precision: 1))ms")
        finish(result: result, error: nil)
    }

    /// Resolves the Application containers into `result`, reporting scan progress and publishing each container as it
    /// is found. Scans only the inodes above the cached high-water mark, reusing cached paths below it.
    private func scanAppContainers(into result: inout [AppContainer]) throws {
        let root = Self.appRoot
        let bounds = try Self.scanBounds(on: root)
        let cache = Self.loadCache(for: root)
        let scanFrom = cache.map { $0.highWater + 1 } ?? 1
        let toScan = scanFrom <= bounds.limit ? bounds.limit - scanFrom + 1 : 0

        // Cached paths that still exist resolve first, so a warm launch has the list almost immediately.
        var foundPaths = (cache?.paths ?? []).filter { Self.exists($0) }
        for path in foundPaths {
            if Task.isCancelled { return }
            if let container = try? container(kind: .app, path: path) { result.append(container) }
        }
        setScanTotal(toScan)
        publish(result)
        discoveryLog.log("index: scanning inodes \(scanFrom)...\(bounds.limit) (\(toScan) inodes, \(foundPaths.count) cached)")

        if scanFrom <= bounds.limit {
            var seen = Set(foundPaths)
            var fileSystem = bounds.fileSystem
            var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
            var sinceReport: UInt64 = 0

            for inode in scanFrom ... bounds.limit {
                if inode % 10_000 == 0, Task.isCancelled { break }
                sinceReport += 1
                if sinceReport >= 200_000 {
                    addScanned(sinceReport)
                    sinceReport = 0
                }
                let length = fsgetpath(&buffer, buffer.count, &fileSystem, inode)
                guard length > 0 else { continue }
                let path = String(decoding: buffer.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
                // fsgetpath reports /private/var as often as /var.
                let candidates = [path, path.hasPrefix("/private") ? String(path.dropFirst("/private".count)) : path]
                guard let match = candidates.first(where: { Self.isDirectChild($0, of: root) }), seen.insert(match).inserted
                else { continue }
                foundPaths.append(match)
                if let container = try? container(kind: .app, path: match) {
                    result.append(container)
                    publish(result)
                }
            }
            addScanned(sinceReport)
        }

        // Store the newest inode (not the padded limit) so the next launch re-covers the slack window cheaply.
        Self.saveCache(for: root, highWater: bounds.newest, paths: foundPaths)
    }

    // MARK: - State updates

    private func statusLocked() -> ContainerIndexStatus {
        if indexing { return .indexing(found: resolved.count, scanned: scanned, total: total) }
        return isAvailable ? .ready : .unavailable
    }

    private func publish(_ result: [AppContainer]) {
        lock.lock()
        resolved = Self.sorted(result)
        lock.unlock()
        emitProgress()
    }

    private func setScanTotal(_ value: UInt64) {
        lock.lock()
        total = value
        lock.unlock()
        emitProgress()
    }

    private func addScanned(_ delta: UInt64) {
        guard delta > 0 else { return }
        lock.lock()
        scanned += delta
        lock.unlock()
        emitProgress()
    }

    private func finish(result: [AppContainer], error: Error?) {
        lock.lock()
        resolved = Self.sorted(result)
        indexing = false
        indexTask = nil
        if let error { lastError = String(describing: error) } else { lastIndexed = Date() }
        lock.unlock()
        emitProgress()
    }

    private func emitProgress() {
        lock.lock()
        let handler = progressHandler
        let snapshot = Progress(status: statusLocked(), lastIndexed: lastIndexed, error: lastError)
        lock.unlock()
        handler?(snapshot)
    }

    private static func sorted(_ containers: [AppContainer]) -> [AppContainer] {
        containers.sorted { left, right in
            left.kind == right.kind
                ? left.identifier.localizedStandardCompare(right.identifier) == .orderedAscending
                : left.kind.rawValue < right.kind.rawValue
        }
    }

    // MARK: - Filesystem

    private func listedChildren(of root: String) throws -> [String] {
        let grant = try SandboxBridge.shared.grant(root, checkTarget: false)
        defer { SandboxBridge.shared.release(grant) }
        return try FileManager.default.contentsOfDirectory(atPath: root).map { (root as NSString).appendingPathComponent($0) }
    }

    /// The container at a path, with its grant kept. Paths without an identifier xattr aren't containers.
    private func container(kind: AppContainer.Kind, path: String) throws -> AppContainer? {
        let grant = try SandboxBridge.shared.grant(path)
        guard let identifier = Self.identifier(at: path) else {
            SandboxBridge.shared.release(grant)
            return nil
        }
        return AppContainer(kind: kind, identifier: identifier, path: path)
    }

    private static func identifier(at path: String) -> String? {
        var buffer = [CChar](repeating: 0, count: 512)
        let length = getxattr(path, "com.apple.containermanager.identifier", &buffer, 511, 0, 0)
        guard length > 0 else { return nil }
        return SandboxBridge.string(from: buffer, length: length)
    }

    private static func exists(_ path: String) -> Bool {
        var status = stat()
        return lstat(path, &status) == 0
    }

    private static func isDirectChild(_ path: String, of root: String) -> Bool {
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard path.hasPrefix(prefix) else { return false }
        return !path.dropFirst(prefix.count).contains("/")
    }

    /// The volume id for `fsgetpath`, the newest inode (a bound on anything that already exists), and the scan ceiling.
    /// A file this app creates in its own temporary directory gives the newest inode: APFS allocates them in increasing
    /// order, so nothing older is above it. `limit` adds slack for inodes allocated between the probe and the scan,
    /// capped by `maximumInode` as a safety valve.
    private static func scanBounds(on root: String) throws -> (fileSystem: fsid_t, newest: UInt64, limit: UInt64) {
        var volume = statfs()
        guard statfs(root, &volume) == 0 else {
            throw WorkspaceError("Couldn't scan \(root) for containers.")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(".inode-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data().write(to: url)
        var status = stat()
        guard lstat(url.path, &status) == 0 else {
            throw WorkspaceError("Couldn't create a file to bound the container scan.")
        }
        let newest = UInt64(status.st_ino)
        return (volume.f_fsid, newest, min(newest &+ 65_536, maximumInode))
    }

    // MARK: - Scan cache

    private struct ScanCache {
        let highWater: UInt64
        let paths: [String]
    }

    /// The cache is a speed-up only: a wrong or stale entry costs at most a re-scan or a dropped path, so it lives in
    /// the app's own `UserDefaults` keyed by root.
    private static func cacheKey(for root: String) -> String { "SandboxContainers.scan:\(root)" }

    private static func loadCache(for root: String) -> ScanCache? {
        guard let stored = UserDefaults.standard.dictionary(forKey: cacheKey(for: root)),
              let highWater = (stored["highWater"] as? NSNumber)?.uint64Value,
              let paths = stored["paths"] as? [String]
        else { return nil }
        return ScanCache(highWater: highWater, paths: paths)
    }

    private static func saveCache(for root: String, highWater: UInt64, paths: [String]) {
        UserDefaults.standard.set(
            ["highWater": NSNumber(value: highWater), "paths": paths],
            forKey: cacheKey(for: root)
        )
    }

    private static func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey(for: appRoot))
        UserDefaults.standard.removeObject(forKey: cacheKey(for: groupRoot))
    }
}

/// Milliseconds elapsed since `start`, for log messages.
private func elapsedMillis(since start: DispatchTime) -> Double {
    Double(DispatchTime.now().uptimeNanoseconds &- start.uptimeNanoseconds) / 1_000_000
}

#endif
