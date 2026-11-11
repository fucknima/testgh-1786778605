#!/usr/bin/env python3
"""Patch two upstream stupid-chatkit Swift 6.2 type-checking bottlenecks.

Run only against the dependency's temporary SwiftPM checkout, never against
the user's source files. These are expression-only refactors, preserving output.
"""
from pathlib import Path
import stat
import subprocess
import json
import hashlib

root = Path(".build/stupid-app/scratch/arm64-apple-ios/StupidAgent/checkouts/stupid-chatkit/Sources/StupidChatKit")

def patch(relative_path: str, old: str, new: str) -> None:
    path = root / relative_path
    if not path.is_file():
        raise SystemExit(f"Missing dependency checkout: {path}")
    source = path.read_text(encoding="utf-8")
    if new in source:
        print(f"Already patched: {relative_path}")
        return
    if source.count(old) != 1:
        raise SystemExit(f"Expected expression not found exactly once in {relative_path}")
    path.chmod(path.stat().st_mode | stat.S_IWUSR)
    path.write_text(source.replace(old, new, 1), encoding="utf-8")
    print(f"Patched {relative_path}")

patch(
    "Models/ChatReactionGrid.swift",
    '''        var words: [String] {
            description.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
                + aliases.flatMap { $0.lowercased().split(separator: "_").map(String.init) }
                + tags.map { $0.lowercased() }
        }''',
    '''        var words: [String] {
            let descriptionWords: [String] = description.lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map { String($0) }
            let aliasWords: [String] = aliases.flatMap { alias -> [String] in
                alias.lowercased().split(separator: "_").map { String($0) }
            }
            let tagWords: [String] = tags.map { $0.lowercased() }
            return descriptionWords + aliasWords + tagWords
        }'''
)
patch(
    "Stickers/LottieRenderer.swift",
    '''        let premultiplied = stops.map { stop -> [Double] in
            let (r, g, b, a) = rlottieColor(stop.color, alpha: stop.alpha)
            let alpha = int(Double(a) * opacity)
            let word = UInt32(bitPattern: alpha << 24 | ((Int32(r) &* alpha) / 255) << 16 | ((Int32(g) &* alpha) / 255) << 8 | (Int32(b) &* alpha) / 255)
            return [word >> 16 & 0xFF, word >> 8 & 0xFF, word & 0xFF, word >> 24].map { Double($0) / 255 }
        }''',
    '''        let premultiplied: [[Double]] = stops.map { stop -> [Double] in
            let (r, g, b, a) = rlottieColor(stop.color, alpha: stop.alpha)
            let alpha: Int32 = int(Double(a) * opacity)
            let red: Int32 = (Int32(r) &* alpha) / 255
            let green: Int32 = (Int32(g) &* alpha) / 255
            let blue: Int32 = (Int32(b) &* alpha) / 255
            let packed: Int32 = (alpha << 24) | (red << 16) | (green << 8) | blue
            let word = UInt32(bitPattern: packed)
            let channelR = Double((word >> 16) & 0xFF) / 255.0
            let channelG = Double((word >> 8) & 0xFF) / 255.0
            let channelB = Double(word & 0xFF) / 255.0
            let channelA = Double(word >> 24) / 255.0
            return [channelR, channelG, channelB, channelA]
        }'''
)

patch(
    "Views/ChatUIKitView.swift",
    '''import UIKit
import UniformTypeIdentifiers

/// UIKit chat shared by every network''',
    '''import UIKit
import UniformTypeIdentifiers

/// NSItemProvider supports background loading, though it has no Sendable annotation.
private struct SendableItemProvider: @unchecked Sendable {
    let provider: NSItemProvider
}

/// UIKit chat shared by every network'''
)
patch(
    "Views/ChatUIKitView.swift",
    '''                    // NSItemProvider loads on its own queues; it's only handed over here.
                    nonisolated(unsafe) let provider = provider
                    group.addTask { await (index, Self.imageAttachment(from: provider)) }''',
    '''                    // Loading is concurrent. The explicit unchecked wrapper crosses the
                    // task-group boundary without leaking MainActor state into child tasks.
                    let boxed = SendableItemProvider(provider: provider)
                    group.addTask { [boxed] in
                        let attachment = await Self.imageAttachment(from: boxed.provider)
                        return (index, attachment)
                    }'''
)

# 本地化只修改此构建的临时依赖，保留上游仓库版本和业务逻辑。
from zh_kit import localize_chatkit
localize_chatkit(root)

# stupid-app 0.0.27 writes its package-layout marker *only after* a successful
# build. If the first build fails, its second invocation deletes the entire
# scratch directory (including the modified package checkout). Reconstruct the
# exact same marker using the public SwiftPM package graph so it is preserved.
def command_json(arguments: list[str]) -> dict:
    result = subprocess.run(arguments, capture_output=True, text=True, check=True)
    content = result.stdout
    return json.loads(content[content.index("{"):])

def field(mapping: dict, camel: str, snake: str):
    return mapping.get(camel, mapping.get(snake))

def package_layout(package_path: Path) -> str:
    dump = command_json(["swift", "package", "--package-path", str(package_path), "describe", "--type", "json"])
    chunks: list[str] = []
    for t in sorted(dump.get("targets") or [], key=lambda entry: entry["name"]):
        chunks.extend((
            "target:" + t["name"],
            "module:" + str(field(t, "moduleType", "module_type")),
            "path:" + (t.get("path") or ""),
        ))
        chunks.extend("source:" + value for value in sorted(t.get("sources") or []))
        chunks.extend("resource:" + item["path"] for item in sorted(t.get("resources") or [], key=lambda item: item["path"]))
        chunks.extend("target-dependency:" + value for value in sorted(field(t, "targetDependencies", "target_dependencies") or []))
        chunks.extend("product-dependency:" + value for value in sorted(field(t, "productDependencies", "product_dependencies") or []))
    return hashlib.sha256("\0".join(chunks).encode("utf-8")).hexdigest()

project = Path.cwd()
graph = command_json(["swift", "package", "--package-path", str(project), "show-dependencies", "--format", "json"])
packages: dict[str, Path] = {}
def walk(node: dict) -> None:
    identity = node["identity"]
    if identity in packages:
        return
    packages[identity] = Path(node["path"])
    for dependency in node.get("dependencies") or []:
        walk(dependency)
walk(graph)
if len(packages) <= 1:
    graph_hash = package_layout(next(iter(packages.values())))
else:
    segments = [identity + ":" + package_layout(packages[identity]) for identity in sorted(packages)]
    resolved_hash = hashlib.sha256((project / "Package.resolved").read_bytes()).hexdigest()
    segments.append("resolved:" + resolved_hash)
    graph_hash = hashlib.sha256("\0".join(segments).encode("utf-8")).hexdigest()
# root: <scratch>/checkouts/stupid-chatkit/Sources/StupidChatKit
# parents[0]=Sources, [1]=stupid-chatkit, [2]=checkouts => need parents[3]=scratch
marker = root.parents[3] / ".stupid-app-package-layout"
marker.write_text(graph_hash + ":const-values-v2", encoding="utf-8")
print(f"Preserved patched SwiftPM checkout with layout marker {marker}")
