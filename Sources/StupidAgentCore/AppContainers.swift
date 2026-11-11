import Foundation
import PiAgent
import PiAI
import PiTools

/// A container the agent can reach outside its own sandbox: another app's data container, or a shared App Group.
public struct AppContainer: Identifiable, Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case app
        case group
    }

    public let kind: Kind
    /// The bundle identifier for an app, the group identifier for a shared container.
    public let identifier: String
    /// The container's directory, as the platform reports it.
    public let path: String

    public var id: String { "\(kind.rawValue):\(identifier)" }

    /// The virtual path the agent uses for the container, such as `/apps/com.example.app`.
    public var pathPrefix: String {
        switch kind {
        case .app: "/apps/\(identifier)"
        case .group: "/app-groups/\(identifier)"
        }
    }

    public init(kind: Kind, identifier: String, path: String) {
        self.kind = kind
        self.identifier = identifier
        self.path = path
    }
}

/// Where a container index stands. Discovery of other apps' containers can take minutes on the first run, so it runs
/// in the background and callers see partial results while it builds.
public enum ContainerIndexStatus: Sendable, Equatable {
    /// This build or OS can't reach other containers.
    case unavailable
    /// Indexing is in progress. `found` containers are available so far; `scanned`/`total` drive a progress bar
    /// (`total == 0` means the step isn't countable yet).
    case indexing(found: Int, scanned: UInt64, total: UInt64)
    /// The index is complete (the result may still be empty).
    case ready
}

/// Access to containers outside the app's own sandbox. The app supplies a platform implementation; tests use a fake.
public protocol AppContainerAccess: Sendable {
    /// Whether this build and OS can reach other containers at all.
    var isAvailable: Bool { get }
    /// Where the background index stands. `containers()` returns whatever is resolved so far.
    var indexStatus: ContainerIndexStatus { get }
    /// Every container the agent may use so far, sorted by kind and identifier. Returns partial results while the
    /// index is still building.
    func containers() async throws -> [AppContainer]
    /// Grants access to a container and returns its directory. The grant lasts for the process lifetime.
    func root(for container: AppContainer) async throws -> URL
}

public extension AppContainerAccess {
    /// Implementations that resolve everything synchronously (such as test fakes) are always ready.
    var indexStatus: ContainerIndexStatus { .ready }
}

/// A path in the agent's virtual filesystem that points outside the workspace.
public struct ContainerPath: Equatable, Sendable {
    public let kind: AppContainer.Kind
    public let identifier: String
    /// The path inside the container, relative to its root. `.` is the container itself.
    public let relativePath: String

    /// Parses `/apps/<bundle id>[/path]` or `/app-groups/<group id>[/path]`, with or without the leading slash.
    public static func parse(_ raw: String) -> ContainerPath? {
        var path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while path.hasPrefix("/") { path.removeFirst() }
        var components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard components.count >= 2 else { return nil }
        let kind: AppContainer.Kind
        switch components.removeFirst() {
        case "apps": kind = .app
        case "app-groups": kind = .group
        default: return nil
        }
        let identifier = components.removeFirst()
        guard !identifier.isEmpty, identifier != ".", identifier != ".." else { return nil }
        let relative = components.joined(separator: "/")
        return ContainerPath(kind: kind, identifier: identifier, relativePath: relative.isEmpty ? "." : relative)
    }
}

/// The file tools plus the containers outside the workspace, when the user allows it.
///
/// Paths that start with `/apps/` or `/app-groups/` resolve against a container; every other path stays in the
/// workspace, so its containment rules are unchanged. The container is granted before the tool runs, then the same
/// swift-pi tool is used with the container as its root.
public func agentFileTools(workspace: Workspace, containers: (any AppContainerAccess)?) -> [AgentTool] {
    var tools = fileTools(workspace: workspace) + [sqliteTool(workspace: workspace)]
    guard let containers, containers.isAvailable else { return tools }
    tools = tools.map { containerTool($0, containers: containers) }
    tools.append(appsTool(containers: containers))
    return tools
}

/// The tool that lists the containers the agent can use.
public func appsTool(containers: any AppContainerAccess) -> AgentTool {
    AgentTool(
        name: "apps",
        label: "List apps",
        description: "List the other apps' file containers you can read and write. Containers appear as /apps/<bundle id> and /app-groups/<group id>; pass those paths to read, write, edit, ls, find and grep.",
        parameters: ["type": "object", "properties": .object([:]), "required": .array([])]
    ) { _, _, _ in
        let status = containers.indexStatus
        let list = try await containers.containers()
        let apps = list.filter { $0.kind == .app }.map(\.pathPrefix)
        let groups = list.filter { $0.kind == .group }.map(\.pathPrefix)

        var sections: [String] = []
        if case let .indexing(_, scanned, total) = status {
            let percent = total > 0 ? Int(Double(scanned) / Double(total) * 100) : 0
            sections.append("Still indexing other apps (\(percent)% done); \(list.count) found so far. Call apps again later for the rest.")
        }
        if !apps.isEmpty { sections.append("Apps:\n" + apps.joined(separator: "\n")) }
        if !groups.isEmpty { sections.append("App groups:\n" + groups.joined(separator: "\n")) }
        guard !sections.isEmpty else { return AgentToolResult(text: "No other app containers are visible.") }
        return AgentToolResult(text: sections.joined(separator: "\n\n"))
    }
}

/// One of the workspace file tools, with container paths routed to the container's root.
private func containerTool(_ tool: AgentTool, containers: any AppContainerAccess) -> AgentTool {
    var tool = tool
    let toolName = tool.name
    let execute = tool.execute
    tool.description += " Paths may also start with /apps/<bundle id> or /app-groups/<group id> to work with another app's files; list them with the apps tool. ls and find report paths relative to that container's root, so add the prefix before using them in another call."
    tool.execute = { toolCallId, arguments, onUpdate in
        guard let rawPath = arguments["path"]?.stringValue, let path = ContainerPath.parse(rawPath) else {
            return try await execute(toolCallId, arguments, onUpdate)
        }
        let all = try await containers.containers()
        guard let container = all.first(where: { $0.kind == path.kind && $0.identifier == path.identifier }) else {
            let kind = path.kind == .app ? "app" : "app group"
            throw WorkspaceError("No \(kind) container named \(path.identifier). Use the apps tool to list the containers you can use.")
        }
        let root = try await containers.root(for: container)
        var arguments = arguments
        arguments["path"] = .string(path.relativePath)
        let rooted = try rootedTool(named: toolName, root: root)
        return try await rooted.execute(toolCallId, arguments, onUpdate)
    }
    return tool
}

/// The same tool, rooted at another directory.
private func rootedTool(named name: String, root: URL) throws -> AgentTool {
    let workspace = Workspace(root: root)
    switch name {
    case "read": return readTool(workspace: workspace)
    case "write": return writeTool(workspace: workspace)
    case "edit": return editTool(workspace: workspace)
    case "ls": return lsTool(workspace: workspace)
    case "find": return findTool(workspace: workspace)
    case "grep": return grepTool(workspace: workspace)
    case "sqlite": return sqliteTool(workspace: workspace)
    default: throw WorkspaceError("\(name) can't be used outside the workspace.")
    }
}
