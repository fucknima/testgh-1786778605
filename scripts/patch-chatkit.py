#!/usr/bin/env python3
"""Patch two upstream stupid-chatkit Swift 6.2 type-checking bottlenecks.

Run only against the dependency's temporary SwiftPM checkout, never against
the user's source files. These are expression-only refactors, preserving output.
"""
from pathlib import Path

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
