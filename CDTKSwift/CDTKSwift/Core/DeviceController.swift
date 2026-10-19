import Foundation
import Combine
import UIKit

@MainActor
final class DeviceController: ObservableObject {
    enum ConnectionStage: String {
        case idle = "未连接"
        case probing = "测试中"
        case portReady = "端口可达"
        case tunnelHandshake = "隧道握手已完成"
        case failed = "连接失败"
    }

    @Published var pairingIdentity: String = "未导入"
    @Published var stage: ConnectionStage = .idle
    @Published var activityLog: [String] = []
    @Published var tunnelResult: TunnelHandshake?
    @Published var isBusy = false
    @Published var lastError: String?
    @Published var importFeedback: String?
    @Published var host = "10.7.0.1"
    @Published var portText = "49152"

    init() { refreshPairing() }

    func refreshPairing() {
        do { pairingIdentity = try PairingVault.shared.load()?.identifier ?? "未导入" }
        catch { pairingIdentity = "配对文件无效"; lastError = error.localizedDescription }
    }

    func importPairing(at url: URL) {
        // UIDocumentPicker can return security-scoped and iCloud provider URLs.
        // Access must stay open throughout coordinated read; never persist a bookmark for secrets.
        let accessible = url.startAccessingSecurityScopedResource()
        defer { if accessible { url.stopAccessingSecurityScopedResource() } }
        do {
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinateError: NSError?
            var readResult: Result<Data, Error>?
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinateError) { actualURL in
                readResult = Result { try Data(contentsOf: actualURL, options: .mappedIfSafe) }
            }
            if let error = coordinateError { throw error }
            guard let readResult else {
                throw CDTKError.invalidPairing("文件提供器没有交付内容。请先将文件保存至「我的 iPhone」再选择。")
            }
            let data = try readResult.get()
            guard !data.isEmpty && data.count < 4_000_000 else {
                throw CDTKError.invalidPairing("配对文件为空或超过 4 MB")
            }
            try PairingVault.shared.save(data)
            refreshPairing()
            importFeedback = "已导入：\(url.lastPathComponent)"
            addLog("配对记录导入成功：\(url.lastPathComponent)。私钥仅保存于本机钥匙串。")
            lastError = nil
        } catch {
            importFeedback = nil
            lastError = "导入 \(url.lastPathComponent) 失败：\(error.localizedDescription)"
            addLog("导入失败：\(error.localizedDescription)")
        }
    }

    func removePairing() {
        PairingVault.shared.remove()
        pairingIdentity = "未导入"
        tunnelResult = nil
        stage = .idle
        addLog("已删除本机配对凭据。")
    }

    func probePort() {
        guard !isBusy else { return }
        guard let port = UInt16(portText), port > 0 else { lastError = "无效端口号"; return }
        isBusy = true; stage = .probing; lastError = nil; tunnelResult = nil
        addLog("检测 TCP 连通性 \(host):\(port)")
        Task {
            do {
                try await CoreDeviceClient(host: host, pairingPort: port).checkPort()
                stage = .portReady
                addLog("TCP 端口可达（不代表配对认证成功）。")
            } catch {
                stage = .failed
                lastError = error.localizedDescription
                addLog("TCP 检测失败：\(error.localizedDescription)")
            }
            isBusy = false
        }
    }

    func connect() {
        guard !isBusy else { return }
        guard let port = UInt16(portText), port > 0 else { lastError = "无效端口号"; return }
        do {
            guard let record = try PairingVault.shared.load() else {
                lastError = "请先导入 Remote Pairing 配对 plist"; return
            }
            isBusy = true; stage = .probing; lastError = nil; tunnelResult = nil
            activityLog = []
            let targetHost = host
            Task {
                do {
                    let result = try await CoreDeviceClient(host: targetHost, pairingPort: port)
                        .handshake(record: record) { [weak self] progress in
                            Task { @MainActor in self?.addLog(progress) }
                        }
                    tunnelResult = result
                    stage = .tunnelHandshake
                } catch {
                    lastError = error.localizedDescription
                    stage = .failed
                    addLog("协议握手失败：\(error.localizedDescription)")
                }
                isBusy = false
            }
        } catch { lastError = error.localizedDescription }
    }

    private func addLog(_ line: String) {
        activityLog.append("\(Date().formatted(date: .omitted, time: .standard))  \(line)")
        if activityLog.count > 120 { activityLog.removeFirst(activityLog.count - 120) }
    }
}
