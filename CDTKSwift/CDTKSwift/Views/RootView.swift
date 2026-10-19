import SwiftUI
import UniformTypeIdentifiers

private enum Theme {
    static let blue = Color(red: 0.21, green: 0.48, blue: 0.98)
    static let teal = Color(red: 0.08, green: 0.76, blue: 0.73)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let canvas = Color(uiColor: .systemGroupedBackground)
}

struct RootView: View {
    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("总览", systemImage: "square.grid.2x2.fill") }
            PairingView()
                .tabItem { Label("连接", systemImage: "point.3.connected.trianglepath.dotted") }
            ToolsetView()
                .tabItem { Label("工具", systemImage: "wrench.and.screwdriver.fill") }
            CrashView()
                .tabItem { Label("崩溃", systemImage: "waveform.path.ecg.rectangle.fill") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .tint(Theme.blue)
        .onOpenURL { fileURL in
            // "Open in CoreDevice" from Files / third-party file providers.
            guard fileURL.isFileURL else {
                // Avoid displaying private URL query parameters to the user.
                return
            }
            controller.importPairing(at: fileURL)
        }
    }
}

struct Panel<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct ScreenTitle: View {
    let heading: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(heading).font(.largeTitle.weight(.bold))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }
}

struct OverviewView: View {
    @EnvironmentObject var controller: DeviceController
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle(heading: "CoreDevice", subtitle: "原生 Swift · iPhone 设备工具箱")
                    Panel {
                        HStack(spacing: 14) {
                            Image(systemName: "iphone.gen3")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 62, height: 62)
                                .background(LinearGradient(colors: [Theme.blue, Theme.teal], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 17))
                            VStack(alignment: .leading, spacing: 5) {
                                Text("本机 CoreDevice")
                                    .font(.headline)
                                Text(controller.stage.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(controller.stage == .tunnelHandshake ? .green : .secondary)
                                Text("配对：\(controller.pairingIdentity == "未导入" ? "未配置" : "已配置")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    Text("设备概况").font(.headline).padding(.top, 6)
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                        ForEach(LocalDiagnostics.snapshot()) { item in
                            Panel {
                                Image(systemName: item.symbol)
                                    .font(.title3).foregroundStyle(Theme.blue)
                                    .padding(.bottom, 8)
                                Text(item.value).font(.system(.headline, design: .rounded)).lineLimit(2).minimumScaleFactor(0.8)
                                Text(item.name).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Panel {
                        Label("实现范围说明", systemImage: "checkmark.shield")
                            .font(.headline)
                        Text("已实现原生配对文件校验、安全存储、TCP 诊断、Pair Verify、Listener 与 CDTunnel 握手，以及本机状态和 .ips 日志解析。")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("应用安装、进程控制、沙盒及描述文件操作需要完整 IPv6/TCP + RemoteXPC 适配，目前不会提供虚假的操作结果。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .background(Theme.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct PairingView: View {
    @EnvironmentObject var controller: DeviceController
    @State private var showImporter = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle(heading: "本机连接", subtitle: "Remote Pairing · CoreDevice RSD")
                    Panel {
                        HStack {
                            Label("连接状态", systemImage: "circle.dotted.circle.fill")
                                .font(.headline)
                            Spacer()
                            Text(controller.stage.rawValue)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(controller.stage == .tunnelHandshake ? .green : .secondary)
                        }
                        Divider().padding(.vertical, 5)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("配对身份").font(.caption).foregroundStyle(.secondary)
                            Text(controller.pairingIdentity).font(.subheadline.monospaced()).textSelection(.enabled)
                                .lineLimit(2).minimumScaleFactor(0.8)
                        }
                        if let feedback = controller.importFeedback {
                            Label(feedback, systemImage: controller.importSucceeded ? "checkmark.circle.fill" : "exclamationmark.triangle")
                                .font(.footnote).foregroundStyle(controller.importSucceeded ? .green : .red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Button {
                            showImporter = true
                        } label: {
                            Label("导入配对 plist", systemImage: "doc.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                        Text("若当前文件提供器仍无法点选，可在「文件」中长按 pairingFile.plist → 共享 → 在其他 App 中打开 → CoreDevice 工具箱。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Panel {
                        Text("连接目标").font(.headline)
                        HStack {
                            TextField("回环 IP", text: $controller.host)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.numbersAndPunctuation)
                            Divider()
                            TextField("端口", text: $controller.portText)
                                .frame(width: 78)
                                .keyboardType(.numberPad)
                        }
                        .textFieldStyle(.roundedBorder)
                        HStack(spacing: 10) {
                            Button("检测端口") { controller.probePort() }
                                .buttonStyle(.bordered)
                                .disabled(controller.isBusy)
                            Button("验证配对与隧道") { controller.connect() }
                                .buttonStyle(.borderedProminent)
                                .disabled(controller.isBusy)
                        }
                        if controller.isBusy { ProgressView().frame(maxWidth: .infinity).padding(.top, 5) }
                        Text("默认使用 Surge IP Rewrite 的 10.7.0.1:49152。端口可达不表示已获系统服务权限。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let result = controller.tunnelResult {
                        Panel {
                            Label("CDTunnel 握手结果", systemImage: "checkmark.circle.fill")
                                .font(.headline).foregroundStyle(.green)
                            resultRow("分配 IPv6", result.sourceAddress)
                            resultRow("服务 IPv6", result.serverAddress)
                            resultRow("RSD 端口", String(result.rsdPort))
                            resultRow("MTU", String(result.mtu))
                            Text("仅代表握手完成；尚不能直接调用 RSD 服务。")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    if let error = controller.lastError {
                        Panel {
                            Label("执行失败", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline).foregroundStyle(.orange)
                            Text(error).font(.subheadline).textSelection(.enabled)
                        }
                    }
                    Panel {
                        HStack {
                            Text("执行日志").font(.headline)
                            Spacer()
                            if !controller.activityLog.isEmpty {
                                ShareLink(item: controller.activityLog.joined(separator: "\n")) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                        }
                        if controller.activityLog.isEmpty {
                            Text("暂无执行记录").font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(controller.activityLog.enumerated()), id: \.offset) { _, line in
                                Text(line).font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary).textSelection(.enabled)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showImporter) {
                PairingDocumentPicker {
                    controller.importPairing(at: $0)
                    showImporter = false
                } didCancel: {
                    showImporter = false
                }
            }
        }
    }

    @ViewBuilder private func resultRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key).foregroundStyle(.secondary).frame(width: 85, alignment: .leading)
            Text(value).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline.monospaced())
    }
}

private struct Feature: Identifiable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
    let isReady: Bool
}

struct ToolsetView: View {
    @EnvironmentObject var controller: DeviceController
    private let features: [Feature] = [
        .init(id: "network", name: "CoreDevice 通信", detail: "TCP / Pair Verify / CDTunnel 握手", symbol: "network", isReady: true),
        .init(id: "battery", name: "设备与电量", detail: "系统公开的本机硬件状态", symbol: "battery.100percent", isReady: true),
        .init(id: "crash", name: "崩溃日志解析", detail: "导入并解析 .ips 文件", symbol: "waveform.path.ecg", isReady: true),
        .init(id: "install", name: "应用安装 / 卸载", detail: "待实现 RemoteXPC / installation_proxy", symbol: "square.stack.3d.up", isReady: false),
        .init(id: "control", name: "应用与进程控制", detail: "待实现 appservice / HID", symbol: "play.rectangle.on.rectangle", isReady: false),
        .init(id: "files", name: "应用沙盒与媒体", detail: "待实现 AFC / house_arrest", symbol: "folder", isReady: false),
        .init(id: "profile", name: "描述文件管理", detail: "待实现 MCInstall 服务", symbol: "checkmark.shield", isReady: false),
        .init(id: "inspect", name: "WebKit 页面调试", detail: "待实现 webinspector 服务", symbol: "safari", isReady: false),
        .init(id: "springboard", name: "主屏布局", detail: "待实现 springboard 服务", symbol: "square.grid.3x3", isReady: false)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenTitle(heading: "工具模块", subtitle: "真实实现与规划功能分开展示")
                    NavigationLink {
                        LocalArtifactToolsView()
                    } label: {
                        Panel {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.title3).foregroundStyle(Theme.blue)
                                    .frame(width: 40, height: 40)
                                    .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("IPA / 证书与配置检查").font(.headline)
                                    Text("原生离线解析安装包、mobileconfig 和签名配置").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        LocalWorkspaceView()
                    } label: {
                        Panel {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.badge.gearshape")
                                    .font(.title3).foregroundStyle(Theme.blue)
                                    .frame(width: 40, height: 40)
                                    .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("本地文件管理").font(.headline)
                                    Text("导入、分享与删除本 App 沙盒中的文件").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    ForEach(features) { feature in
                        Panel {
                            HStack(spacing: 12) {
                                Image(systemName: feature.symbol)
                                    .font(.title3).foregroundStyle(feature.isReady ? Theme.blue : .secondary)
                                    .frame(width: 40, height: 40)
                                    .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(feature.name).font(.headline)
                                    Text(feature.detail).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                if feature.isReady {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                } else {
                                    Image(systemName: "clock").foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct CrashView: View {
    @State private var reports: [CrashReport] = []
    @State private var isImporterPresented = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenTitle(heading: "崩溃透视", subtitle: "原生解析 iOS .ips 诊断日志")
                    Button { isImporterPresented = true } label: {
                        Label("导入崩溃日志", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity).padding(.vertical, 5)
                    }
                    .buttonStyle(.borderedProminent)
                    if let error = importError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    if reports.isEmpty {
                        Panel {
                            Image(systemName: "waveform.path.ecg.rectangle")
                                .font(.largeTitle).foregroundStyle(Theme.blue)
                            Text("还没有日志").font(.headline)
                            Text("从「文件」导入 .ips；此版本支持离线解析，不声称直接读取系统受保护的崩溃目录。")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(reports) { report in
                        NavigationLink {
                            CrashDetailView(report: report)
                        } label: {
                            Panel {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(.orange)
                                    Text(report.process).font(.headline)
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }
                                Text(report.exception).font(.subheadline.monospaced())
                                Text(report.time).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Theme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isImporterPresented) {
                NativeDocumentPicker(multiple: true, didPick: { urls in
                    do {
                        for url in urls {
                            let scoped = url.startAccessingSecurityScopedResource()
                            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                            let data = try Data(contentsOf: url)
                            guard data.count <= 40_000_000 else { throw CDTKError.protocolMismatch("日志文件超过 40 MB") }
                            reports.insert(CrashInspector.parse(data, fileName: url.lastPathComponent), at: 0)
                        }
                        importError = nil
                    } catch { importError = error.localizedDescription }
                    isImporterPresented = false
                }, didCancel: {
                    isImporterPresented = false
                })
            }
        }
    }
}

struct CrashDetailView: View {
    let report: CrashReport
    var body: some View {
        List {
            Section("基本信息") {
                LabeledContent("进程", value: report.process)
                LabeledContent("时间", value: report.time)
                LabeledContent("异常", value: report.exception)
                LabeledContent("终止命名空间", value: report.termination)
            }
            Section("原始报告") {
                Text(report.details)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(report.fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ShareLink(item: report.details) { Image(systemName: "square.and.arrow.up") }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var controller: DeviceController
    @State private var confirmRemoval = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle(heading: "设置", subtitle: "凭据保护、运行条件与说明")
                    Panel {
                        Label("安全存储", systemImage: "lock.shield.fill")
                            .font(.headline)
                        Text("配对 plist 的原始内容保存在 Keychain，使用 ThisDeviceOnly + 设备解锁时可读。不会上传到服务器，也不会写入日志。")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button(role: .destructive) { confirmRemoval = true } label: {
                            Label("删除配对凭据", systemImage: "trash")
                        }
                        .disabled(controller.pairingIdentity == "未导入")
                    }
                    Panel {
                        Label("运行条件", systemImage: "checklist")
                            .font(.headline)
                        Text("• iOS 17+，建议 iOS 18 及以上真机\n• 设置中开启开发者模式\n• 有效的 Remote Pairing plist\n• Surge 配置 IP Rewrite 回环\n• 设备允许本地网络连接")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("[IP Rewrite] 10.7.0.1 = reflect\n[General] tun-included-routes = 10.7.0.1/32")
                            .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    }
                    Panel {
                        Label("版本", systemImage: "info.circle.fill")
                            .font(.headline)
                        Text("Swift Native Preview 0.2.0")
                            .font(.subheadline)
                        Text("仅参考 OpenMinis 的 CoreDevice Toolkit 协议思路；不使用 Python、Node.js 或内嵌 Web UI。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .background(Theme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog("确定删除设备配对凭据？", isPresented: $confirmRemoval, titleVisibility: .visible) {
                Button("删除配对凭据", role: .destructive) { controller.removePairing() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("只清除本 App 钥匙串中的配对记录，不会解除系统与电脑的配对。")
            }
        }
    }
}
