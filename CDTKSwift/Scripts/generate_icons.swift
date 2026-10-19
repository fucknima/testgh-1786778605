import AppKit
import Foundation

// 构建前生成矢量绘制的双外观图标。无脚本解释器依赖，使用 macOS Swift。
let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("CDTKSwift/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)

for mode in ["Light", "Dark"] {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024,
                                       pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
                                       hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                       bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw NSError(domain: "CDTKIcon", code: 1) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let rect = NSRect(x: 0, y: 0, width: 1024, height: 1024)
    let bg = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)
    let colors: [NSColor] = mode == "Light"
        ? [NSColor(calibratedRed: 0.09, green: 0.34, blue: 0.91, alpha: 1), NSColor(calibratedRed: 0.02, green: 0.73, blue: 0.72, alpha: 1)]
        : [NSColor(calibratedRed: 0.04, green: 0.11, blue: 0.27, alpha: 1), NSColor(calibratedRed: 0.04, green: 0.37, blue: 0.42, alpha: 1)]
    NSGradient(starting: colors[0], ending: colors[1])!.draw(in: bg, angle: -50)
    let box = NSBezierPath(roundedRect: NSRect(x: 245, y: 245, width: 534, height: 534), xRadius: 100, yRadius: 100)
    NSColor.white.withAlphaComponent(0.13).setFill(); box.fill()
    box.lineWidth = 20; NSColor.white.withAlphaComponent(0.85).setStroke(); box.stroke()
    for i in 0..<4 {
        let y = CGFloat(325 + i * 125)
        NSBezierPath(rect: NSRect(x: 172, y: y, width: 73, height: 22)).fill()
        NSBezierPath(rect: NSRect(x: 779, y: y, width: 73, height: 22)).fill()
        let x = CGFloat(325 + i * 125)
        NSBezierPath(rect: NSRect(x: x, y: 172, width: 22, height: 73)).fill()
        NSBezierPath(rect: NSRect(x: x, y: 779, width: 22, height: 73)).fill()
    }
    let title = "CD" as NSString
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 235, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    let size = title.size(withAttributes: attributes)
    title.draw(at: NSPoint(x: (1024 - size.width) / 2, y: (1024 - size.height) / 2), withAttributes: attributes)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let bytes = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "CDTKIcon", code: 2) }
    try bytes.write(to: path.appendingPathComponent("Icon\(mode).png"), options: .atomic)
}
print("双外观 App 图标已生成")
