import Foundation
import UIKit

struct Metric: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let symbol: String
}

enum LocalDiagnostics {
    static func snapshot() -> [Metric] {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let battery = UIDevice.current.batteryLevel
        let batteryLabel = battery >= 0 ? "\(Int((battery * 100).rounded()))%" : "系统未提供"
        let capacity = (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())) ?? [:]
        let total = (capacity[.systemSize] as? NSNumber)?.int64Value ?? 0
        let free = (capacity[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        let memory = ProcessInfo.processInfo.physicalMemory
        return [
            Metric(name: "设备", value: UIDevice.current.model, symbol: "iphone"),
            Metric(name: "系统版本", value: UIDevice.current.systemVersion, symbol: "gearshape.2"),
            Metric(name: "电量", value: batteryLabel, symbol: "battery.100percent"),
            Metric(name: "运行内存", value: ByteCountFormatter.string(fromByteCount: Int64(memory), countStyle: .memory), symbol: "memorychip"),
            Metric(name: "存储总量", value: total > 0 ? ByteCountFormatter.string(fromByteCount: total, countStyle: .file) : "未知", symbol: "internaldrive"),
            Metric(name: "剩余空间", value: free > 0 ? ByteCountFormatter.string(fromByteCount: free, countStyle: .file) : "未知", symbol: "externaldrive"),
        ]
    }
}

struct CrashReport: Identifiable {
    let id = UUID()
    let fileName: String
    let process: String
    let time: String
    let exception: String
    let termination: String
    let details: String
}

enum CrashInspector {
    static func parse(_ data: Data, fileName: String) -> CrashReport {
        let raw = String(decoding: data, as: UTF8.self)
        // .ips 通常为头 JSON + 正文 JSON；旧格式 .crash 为纯文本。
        let lines = raw.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let header = parseJSON(String(lines.first ?? ""))
        let body = lines.count > 1 ? parseJSON(String(lines[1])) : (parseJSON(raw))
        let process = (body["procName"] as? String) ?? (header["app_name"] as? String)
                      ?? (body["name"] as? String) ?? legacyField(raw, "Process:") ?? "未知进程"
        let time = (body["captureTime"] as? String) ?? (header["timestamp"] as? String)
                   ?? legacyField(raw, "Date/Time:") ?? "未知"
        let exceptionObj = body["exception"] as? [String: Any] ?? [:]
        let terminationObj = body["termination"] as? [String: Any] ?? [:]
        let exception = (exceptionObj["type"] as? String) ?? (body["exceptionType"] as? String)
                        ?? legacyField(raw, "Exception Type:") ?? "未提供"
        let termination = (terminationObj["namespace"] as? String)
                          ?? legacyField(raw, "Termination Reason:") ?? "未提供"
        return CrashReport(fileName: fileName, process: process, time: time,
                           exception: exception, termination: termination, details: raw)
    }

    private static func parseJSON(_ string: String) -> [String: Any] {
        guard let data = string.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return result
    }

    private static func legacyField(_ report: String, _ prefix: String) -> String? {
        guard let line = report.split(separator: "\n").first(where: {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix)
        }) else { return nil }
        let value = String(line).replacingOccurrences(of: prefix, with: "")
            .trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
}
