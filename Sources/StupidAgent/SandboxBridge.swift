// The app is iOS-only; the guard lets `swift test` build the package on macOS for the core tests.
#if os(iOS)
import Darwin
import Foundation

/// A sandbox extension granted for a path outside the app's container.
struct SandboxGrant {
    let path: String
    let handle: Int64
}

enum SandboxBridgeError: LocalizedError {
    case groupUnavailable
    case libraryUnavailable
    case symbolsMissing(String)
    case targetMissing(String)
    case symlinkFailed(String)
    case queryCreationFailed
    case queryRejected(String)
    case tokenMissing
    case consumeFailed(Int64)

    var errorDescription: String? {
        switch self {
        case .groupUnavailable:
            "The app group container is unavailable. Check the App Groups entitlement and signing."
        case .libraryUnavailable:
            "Couldn't load the container manager library."
        case let .symbolsMissing(name):
            "Couldn't resolve the private symbol \(name). This iOS version may not be supported."
        case let .targetMissing(path):
            "Nothing exists at \(path). Turn off the existence check for a parent directory."
        case let .symlinkFailed(path):
            "Couldn't replace the app group's Caches directory with a symlink to \(path)."
        case .queryCreationFailed:
            "Couldn't create a container query."
        case let .queryRejected(path):
            "The container query for \(path) was rejected."
        case .tokenMissing:
            "The container manager issued no sandbox token."
        case let .consumeFailed(code):
            "Consuming the sandbox extension failed (\(code))."
        }
    }
}

/// Grants read/write access to paths outside the app sandbox by way of a container query and an App Group symlink.
/// This is a clean-room implementation of the technique described by worse_query; it shares no code with it.
///
/// It only works on the iOS versions the technique works on, and only for container paths the container manager
/// knows about. It never grants access to the rest of the filesystem.
final class SandboxBridge: @unchecked Sendable {
    static let shared = SandboxBridge()

    /// `RTLD_DEFAULT` is a cast expression, which Swift can't import from dlfcn.h.
    nonisolated(unsafe) private static let defaultSearch = UnsafeMutableRawPointer(bitPattern: -2)

    /// The App Group declared in App.entitlements and stupid-app.yml.
    static let groupIdentifier = "group.net.stupidtech.StupidAgent"

    /// An App Group query needs different flags on iOS 26 for shared App Group containers.
    private static let defaultFlags: UInt64 = 0x0000_0080_0000_0000
    private static let appGroupFlags26: UInt64 = 0x0000_0008_0000_0000

    private let lock = NSLock()
    private var handles: [String: Int64] = [:]

    private typealias QueryCreate = @convention(c) () -> UnsafeMutableRawPointer?
    private typealias QuerySetClass = @convention(c) (UnsafeMutableRawPointer?, UInt64) -> Void
    private typealias QuerySetIdentifiers = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    private typealias QuerySetFlags = @convention(c) (UnsafeMutableRawPointer?, UInt64) -> Void
    private typealias QuerySetPart = @convention(c) (UnsafeMutableRawPointer?, UInt64) -> Void
    private typealias QueryGetSingleResult = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
    private typealias QueryFree = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private typealias CopySandboxToken = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?
    private typealias ConsumeExtension = @convention(c) (UnsafePointer<CChar>?) -> Int64
    private typealias ReleaseExtension = @convention(c) (Int64) -> Int32
    private typealias XPCStringCreate = @convention(c) (UnsafePointer<CChar>?) -> UnsafeMutableRawPointer?
    private typealias XPCRelease = @convention(c) (UnsafeMutableRawPointer?) -> Void

    /// Grants access to `path` and caches the extension by path. The extension lasts for the process lifetime.
    func grant(_ path: String, checkTarget: Bool = true) throws -> SandboxGrant {
        lock.lock()
        defer { lock.unlock() }

        if let handle = handles[path] {
            return SandboxGrant(path: path, handle: handle)
        }

        if checkTarget {
            var status = stat()
            guard lstat(path, &status) == 0 else {
                throw SandboxBridgeError.targetMissing(path)
            }
        }

        guard let groupRoot = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.groupIdentifier
        ) else {
            throw SandboxBridgeError.groupUnavailable
        }

        let caches = groupRoot.appendingPathComponent("Library/Caches", isDirectory: true)

        guard let manager = dlopen("/usr/lib/system/libsystem_containermanager.dylib", RTLD_NOW | RTLD_LOCAL) else {
            throw SandboxBridgeError.libraryUnavailable
        }
        defer { dlclose(manager) }

        guard let queryCreate = load(manager, "container_query_create", as: QueryCreate.self) else {
            throw SandboxBridgeError.symbolsMissing("container_query_create")
        }
        guard let querySetClass = load(manager, "container_query_set_class", as: QuerySetClass.self) else {
            throw SandboxBridgeError.symbolsMissing("container_query_set_class")
        }
        guard let querySetIdentifiers = load(manager, "container_query_set_group_identifiers", as: QuerySetIdentifiers.self) else {
            throw SandboxBridgeError.symbolsMissing("container_query_set_group_identifiers")
        }
        guard let querySetFlags = load(manager, "container_query_operation_set_flags", as: QuerySetFlags.self) else {
            throw SandboxBridgeError.symbolsMissing("container_query_operation_set_flags")
        }
        guard let querySetPart = load(manager, "container_query_operation_set_part", as: QuerySetPart.self) else {
            throw SandboxBridgeError.symbolsMissing("container_query_operation_set_part")
        }
        guard let queryGetSingleResult = load(manager, "container_query_get_single_result", as: QueryGetSingleResult.self) else {
            throw SandboxBridgeError.symbolsMissing("container_query_get_single_result")
        }
        guard let queryFree = load(manager, "container_query_free", as: QueryFree.self) else {
            throw SandboxBridgeError.symbolsMissing("container_query_free")
        }
        guard let copySandboxToken = load(manager, "container_copy_sandbox_token", as: CopySandboxToken.self) else {
            throw SandboxBridgeError.symbolsMissing("container_copy_sandbox_token")
        }
        guard let consumeExtension = load(Self.defaultSearch, "sandbox_extension_consume", as: ConsumeExtension.self) else {
            throw SandboxBridgeError.symbolsMissing("sandbox_extension_consume")
        }
        guard let xpcStringCreate = load(Self.defaultSearch, "xpc_string_create", as: XPCStringCreate.self) else {
            throw SandboxBridgeError.symbolsMissing("xpc_string_create")
        }
        guard let xpcRelease = load(Self.defaultSearch, "xpc_release", as: XPCRelease.self) else {
            throw SandboxBridgeError.symbolsMissing("xpc_release")
        }

        // The container manager resolves the App Group's Caches path, so pointing that path at the target makes it
        // issue an extension for the target instead.
        try? FileManager.default.createDirectory(
            at: caches.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: caches)
        do {
            try FileManager.default.createSymbolicLink(atPath: caches.path, withDestinationPath: path)
        } catch {
            throw SandboxBridgeError.symlinkFailed(path)
        }
        defer { restoreCaches(caches) }

        guard let query = queryCreate() else {
            throw SandboxBridgeError.queryCreationFailed
        }
        defer { queryFree(query) }

        querySetClass(query, 7)
        let identifier = xpcStringCreate(Self.groupIdentifier)
        querySetIdentifiers(query, identifier)
        if let identifier { xpcRelease(identifier) }
        querySetPart(query, 3)
        querySetFlags(query, flags(for: path))

        guard let result = queryGetSingleResult(query) else {
            throw SandboxBridgeError.queryRejected(path)
        }
        guard let token = copySandboxToken(result) else {
            throw SandboxBridgeError.tokenMissing
        }
        defer { free(token) }

        let handle = consumeExtension(token)
        guard handle >= 0 else {
            throw SandboxBridgeError.consumeFailed(handle)
        }
        handles[path] = handle
        return SandboxGrant(path: path, handle: handle)
    }

    func release(_ grant: SandboxGrant) {
        lock.lock()
        defer { lock.unlock() }
        handles[grant.path] = nil
        releaseHandle(grant.handle)
    }

    func releaseAll() {
        lock.lock()
        defer { lock.unlock() }
        for handle in handles.values { releaseHandle(handle) }
        handles.removeAll()
    }

    private func releaseHandle(_ handle: Int64) {
        guard handle >= 0 else { return }
        guard let release = load(Self.defaultSearch, "sandbox_extension_release", as: ReleaseExtension.self) else { return }
        _ = release(handle)
    }

    private func flags(for path: String) -> UInt64 {
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let isAppGroup = path.contains("/var/mobile/Containers/Shared/AppGroup")
        return major == 26 && isAppGroup ? Self.appGroupFlags26 : Self.defaultFlags
    }

    private func restoreCaches(_ caches: URL) {
        try? FileManager.default.removeItem(at: caches)
        try? FileManager.default.createDirectory(at: caches, withIntermediateDirectories: false)
    }

    private func load<T>(_ handle: UnsafeMutableRawPointer?, _ name: String, as type: T.Type) -> T? {
        guard let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }

    /// A string from a C buffer with a known length.
    static func string(from buffer: [CChar], length: Int) -> String {
        String(decoding: buffer.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

/// Lists container directories under a granted root, with the owning bundle identifier when the container has one.
struct ContainerEntry: Identifiable, Hashable {
    let path: String
    let identifier: String?

    var id: String { path }
    var name: String { identifier ?? URL(fileURLWithPath: path).lastPathComponent }
}

enum ContainerInventory {
    static let applicationRoot = "/var/mobile/Containers/Data/Application"
    static let appGroupRoot = "/var/mobile/Containers/Shared/AppGroup"
    static let daemonRoot = "/var/mobile/Containers/Data/InternalDaemon"
    static let pluginRoot = "/var/mobile/Containers/Data/PluginKitPlugin"

    static func entries(in root: String) throws -> [ContainerEntry] {
        let grant = try SandboxBridge.shared.grant(root, checkTarget: false)
        defer { SandboxBridge.shared.release(grant) }

        let paths = try FileManager.default.contentsOfDirectory(atPath: root)
        return paths.compactMap { name in
            let path = (root as NSString).appendingPathComponent(name)
            return ContainerEntry(path: path, identifier: containerIdentifier(at: path))
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func containerIdentifier(at path: String) -> String? {
        var buffer = [CChar](repeating: 0, count: 512)
        let length = getxattr(path, "com.apple.containermanager.identifier", &buffer, 511, 0, 0)
        guard length > 0 else { return nil }
        return SandboxBridge.string(from: buffer, length: length)
    }
}

#endif
