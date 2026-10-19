import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Compression

struct ArtifactField: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

struct ArtifactInspection: Identifiable {
    let id = UUID()
    let name: String
    let kind: String
    let fields: [ArtifactField]
    let note: String

    var shareText: String {
        ([name, kind] + fields.map { "\($0.title)：\($0.value)" } + [note]).joined(separator: "\n")
    }
}

enum ArtifactInspector {
    private static func field(_ name: String, _ value: Any?) -> ArtifactField? {
        guard let value else { return nil }
        let string = String(describing: value)
        guard !string.isEmpty else { return nil }
        return ArtifactField(title: name, value: string)
    }

    static func inspect(_ data: Data, name: String) throws -> ArtifactInspection {
        let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
        if ext == "ipa" {
            let contents = try ZIPArchiveReader(data: data)
            guard let entry = contents.entries.first(where: {
                $0.path.hasPrefix("Payload/") &&
                $0.path.hasSuffix(".app/Info.plist") &&
                $0.path.split(separator: "/").count == 3
            }) else {
                throw CDTKError.protocolMismatch("IPA 中没有找到 Payload/*.app/Info.plist")
            }
            let info = try contents.extract(entry)
            guard let dict = try PropertyListSerialization.propertyList(from: info, format: nil) as? [String: Any] else {
                throw CDTKError.protocolMismatch("IPA Info.plist 内容不是字典")
            }
            let fields = [
                field("显示名称", dict["CFBundleDisplayName"] ?? dict["CFBundleName"]),
                field("Bundle ID", dict["CFBundleIdentifier"]),
                field("版本", dict["CFBundleShortVersionString"]),
                field("Build", dict["CFBundleVersion"]),
                field("最低 iOS", dict["MinimumOSVersion"]),
                field("签名配置", dict["CFBundleSupportedPlatforms"]),
                field("包含文件数", contents.entries.count),
                field("包含扩展", contents.entries.filter { $0.path.contains(".appex/") }.count),
            ].compactMap { $0 }
            return ArtifactInspection(name: name, kind: "IPA 安装包结构检查", fields: fields,
                 note: "仅解析安装包元数据；不修改签名、不安装应用。签名是否有效需要额外的代码签名验证。")
        }
        if ext == "mobileprovision" || ext == "provisionprofile" {
            // CMS-wrapped provisioning profiles normally contain an embedded XML plist.
            // We inspect only public fields; no certificate or private-key bytes are shown.
            guard let xml = extractEmbeddedXML(data),
                  let dict = try PropertyListSerialization.propertyList(from: xml, format: nil) as? [String: Any] else {
                throw CDTKError.protocolMismatch("未找到可解析的配置 plist。该描述文件可能使用不支持的 CMS 编码。")
            }
            let ids = dict["ProvisionedDevices"] as? [String]
            let fields = [
                field("配置名称", dict["Name"]),
                field("团队标识", (dict["TeamIdentifier"] as? [String])?.joined(separator: ", ")),
                field("App ID", (dict["Entitlements"] as? [String: Any])?["application-identifier"]),
                field("有效期", dict["ExpirationDate"]),
                field("设备数", ids?.count),
                field("企业配置", dict["ProvisionsAllDevices"]),
                field("UUID", dict["UUID"])
            ].compactMap { $0 }
            return ArtifactInspection(name: name, kind: "签名描述文件检查", fields: fields,
                                      note: "离线解析配置内容，并不代表该配置文件一定受 Apple 信任。")
        }
        if ext == "mobileconfig" || ext == "plist" || ext == "json" {
            let object: Any
            if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) {
                object = plist
            } else {
                object = try JSONSerialization.jsonObject(with: data)
            }
            guard let dict = object as? [String: Any] else {
                throw CDTKError.protocolMismatch("文件内容不是字典。")
            }
            if dict["private_key"] != nil || dict["HostPrivateKey"] != nil {
                return ArtifactInspection(name: name, kind: "设备配对凭据",
                    fields: [ArtifactField(title: "状态", value: "识别到配对凭据，已隐藏私钥和证书内容")],
                    note: "请在「连接」页面导入。切勿上传配对文件到 GitHub 或公开网盘。")
            }
            let items = dict["PayloadContent"] as? [[String: Any]] ?? []
            let fields = [
                field("名称", dict["PayloadDisplayName"] ?? dict["Name"]),
                field("标识符", dict["PayloadIdentifier"] ?? dict["CFBundleIdentifier"]),
                field("类型", dict["PayloadType"]),
                field("组织", dict["PayloadOrganization"]),
                field("版本", dict["PayloadVersion"]),
                field("载荷数量", items.count),
                field("载荷类型", Array(Set(items.compactMap { $0["PayloadType"] as? String })).sorted().joined(separator: ", "))
            ].compactMap { $0 }
            return ArtifactInspection(name: name, kind: ext == "mobileconfig" ? "系统配置描述文件" : "属性列表 / JSON",
                    fields: fields, note: "仅执行本地读取与分析，不安装、不修改系统配置。")
        }
        if ext == "ips" || ext == "crash" {
            let report = CrashInspector.parse(data, fileName: name)
            return ArtifactInspection(name: name, kind: "崩溃报告",
                fields: [ArtifactField(title: "进程", value: report.process),
                         ArtifactField(title: "异常", value: report.exception),
                         ArtifactField(title: "时间", value: report.time),
                         ArtifactField(title: "终止原因", value: report.termination)],
                note: "离线解析，完整调用栈请使用「崩溃」页面。")
        }
        throw CDTKError.protocolMismatch("暂不支持 .\(ext) 文件。支持 ipa、plist、json、mobileconfig、mobileprovision、ips。")
    }

    private static func extractEmbeddedXML(_ data: Data) -> Data? {
        let start = Data("<plist".utf8), end = Data("</plist>".utf8)
        guard let first = data.range(of: start), let last = data.range(of: end, options: .backwards) else { return nil }
        let lastIndex = last.upperBound
        guard lastIndex > first.lowerBound, lastIndex - first.lowerBound <= 5_000_000 else { return nil }
        return Data(data[first.lowerBound..<lastIndex])
    }
}

private struct ZIPEntry {
    let path: String
    let method: Int
    let compressedSize: Int
    let originalSize: Int
    let localHeader: Int
}

private struct ZIPArchiveReader {
    let data: Data
    let entries: [ZIPEntry]

    init(data: Data) throws {
        self.data = data
        guard data.count >= 22 else { throw CDTKError.protocolMismatch("ZIP/IPA 文件太短") }
        func u16(_ offset: Int) -> Int {
            Int(data[offset]) | (Int(data[offset + 1]) << 8)
        }
        func u32(_ offset: Int) -> Int {
            u16(offset) | (u16(offset + 2) << 16)
        }
        // Locate the end of central directory; account for the optional ZIP comment.
        let lower = max(0, data.count - 65557)
        var eocd: Int?
        for i in stride(from: data.count - 22, through: lower, by: -1) {
            if data[i] == 0x50 && data[i + 1] == 0x4b && data[i + 2] == 5 && data[i + 3] == 6 {
                eocd = i; break
            }
        }
        guard let eocd else { throw CDTKError.protocolMismatch("找不到 ZIP 中央目录") }
        let total = u16(eocd + 10)
        let offset = u32(eocd + 16)
        guard total <= 100_000 && offset < data.count else { throw CDTKError.protocolMismatch("ZIP 目录超出限制") }
        var cursor = offset
        var found = [ZIPEntry]()
        for _ in 0..<total {
            guard cursor + 46 <= data.count, u32(cursor) == 0x02014b50 else {
                throw CDTKError.protocolMismatch("ZIP 中央目录损坏")
            }
            let method = u16(cursor + 10)
            let size = u32(cursor + 20)
            let original = u32(cursor + 24)
            let nameLength = u16(cursor + 28)
            let extraLength = u16(cursor + 30)
            let commentLength = u16(cursor + 32)
            let local = u32(cursor + 42)
            let next = cursor + 46 + nameLength + extraLength + commentLength
            guard next <= data.count else { throw CDTKError.protocolMismatch("ZIP 文件名超出范围") }
            let nameData = Data(data[(cursor + 46)..<(cursor + 46 + nameLength)])
            let name = String(data: nameData, encoding: .utf8) ?? "未知文件"
            found.append(ZIPEntry(path: name, method: method, compressedSize: size,
                                  originalSize: original, localHeader: local))
            cursor = next
        }
        entries = found
    }

    func extract(_ item: ZIPEntry) throws -> Data {
        let offset = item.localHeader
        guard offset >= 0, offset + 30 <= data.count,
              data[offset] == 0x50, data[offset+1] == 0x4b,
              data[offset+2] == 3, data[offset+3] == 4
        else { throw CDTKError.protocolMismatch("ZIP 文件头损坏") }
        func u16(_ i: Int) -> Int { Int(data[i]) | (Int(data[i + 1]) << 8) }
        let position = offset + 30 + u16(offset + 26) + u16(offset + 28)
        guard item.originalSize <= 4_000_000, item.compressedSize <= 4_000_000,
              position <= data.count, item.compressedSize <= data.count - position else {
            throw CDTKError.protocolMismatch("Info.plist 文件超过限制或 ZIP 大小错误")
        }
        let compressed = Data(data[position..<(position + item.compressedSize)])
        if item.method == 0 { return compressed }
        guard item.method == 8 else { throw CDTKError.protocolMismatch("IPA 使用了不支持的压缩算法（\(item.method)）") }
        if item.originalSize == 0 { return Data() }
        var decoded = [UInt8](repeating: 0, count: item.originalSize)
        let result = decoded.withUnsafeMutableBufferPointer { destination in
            compressed.withUnsafeBytes { source -> Int in
                guard let dst = destination.baseAddress,
                      let src = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(dst, destination.count, src, compressed.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard result == item.originalSize else { throw CDTKError.protocolMismatch("IPA Info.plist 解压失败（\(result)/\(item.originalSize)）") }
        return Data(decoded)
    }
}

struct LocalArtifactToolsView: View {
    @State private var reports: [ArtifactInspection] = []
    @State private var showPicker = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("原生文件检查").font(.title2.bold())
                Text("离线解析 IPA、mobileconfig、mobileprovision、plist 与崩溃报告。不上传到任何服务器。")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button { showPicker = true } label: {
                    Label("选择文件进行检查", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                if let errorText {
                    Text(errorText).font(.footnote).foregroundStyle(.red).textSelection(.enabled)
                }
                if reports.isEmpty {
                    ContentUnavailableView("没有检查记录", systemImage: "doc.text.magnifyingglass",
                                           description: Text("请选择本机文件进行静态分析。"))
                }
                ForEach(reports) { report in
                    NavigationLink {
                        List {
                            Section("文件") {
                                LabeledContent("名称", value: report.name)
                                LabeledContent("类型", value: report.kind)
                            }
                            Section("属性") {
                                ForEach(report.fields) { item in
                                    LabeledContent(item.title, value: item.value)
                                }
                            }
                            Section("限制与说明") { Text(report.note) }
                        }
                        .navigationTitle("检查结果")
                        .toolbar { ShareLink(item: report.shareText) { Image(systemName: "square.and.arrow.up") } }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass").foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(report.name).lineLimit(1)
                                Text(report.kind).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("文件检查")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            do {
                let urls = try result.get()
                for url in urls {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    let coordinator = NSFileCoordinator(filePresenter: nil)
                    var coordinatorError: NSError?
                    var bytes: Data?
                    var readError: Error?
                    coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { safeURL in
                        do { bytes = try Data(contentsOf: safeURL, options: .mappedIfSafe) }
                        catch { readError = error }
                    }
                    if let coordinatorError { throw coordinatorError }
                    if let readError { throw readError }
                    guard let bytes, bytes.count <= 300_000_000 else {
                        throw CDTKError.protocolMismatch("无法读取文件或文件超过 300 MB")
                    }
                    reports.insert(try ArtifactInspector.inspect(bytes, name: url.lastPathComponent), at: 0)
                }
                errorText = nil
            } catch { errorText = error.localizedDescription }
        }
    }
}
