import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Files imported by the user, inside this app's sandbox only.
/// This does not grant access to other apps' Documents/Library containers.
struct LocalWorkspaceView: View {
    @State private var imported: [URL] = []
    @State private var showImporter = false
    @State private var errorText: String?
    @State private var pendingDelete: URL?

    private var folder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CDTKFiles", isDirectory: true)
    }

    var body: some View {
        List {
            Section {
                Button {
                    showImporter = true
                } label: {
                    Label("从「文件」导入", systemImage: "square.and.arrow.down")
                }
                if let errorText {
                    Text(errorText).font(.footnote).foregroundStyle(.red).textSelection(.enabled)
                }
                Text("只管理你主动导入到本 App 的文件，不会读取其他 App 的私有沙盒。导入后可分享、导出和删除。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if imported.isEmpty {
                Section {
                    ContentUnavailableView("文件夹为空", systemImage: "folder",
                                           description: Text("导入文件后可在这里管理。"))
                }
            } else {
                Section("文件（\(imported.count)）") {
                    ForEach(imported, id: \.path) { file in
                        HStack(spacing: 12) {
                            Image(systemName: "doc.fill").foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(file.lastPathComponent).lineLimit(2)
                                Text(fileSize(file)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            ShareLink(item: file) { Image(systemName: "square.and.arrow.up") }
                                .labelStyle(.iconOnly)
                            Button(role: .destructive) { pendingDelete = file } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("删除 \(file.lastPathComponent)")
                        }
                    }
                }
            }
        }
        .navigationTitle("本地文件")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .sheet(isPresented: $showImporter) {
            NativeDocumentPicker(multiple: true, didPick: { files in
                do {
                    guard !files.isEmpty else {
                        throw CDTKError.protocolMismatch("文件选择器未返回文件")
                    }
                    for url in files { try copySafely(url) }
                    errorText = nil
                    reload()
                } catch {
                    errorText = error.localizedDescription
                    reload()
                }
                showImporter = false
            }, didCancel: {
                showImporter = false
            })
        }
        .confirmationDialog(
            "确认删除此 App 内的文件？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ), titleVisibility: .visible
        ) {
            if let candidate = pendingDelete {
                Button("删除 \(candidate.lastPathComponent)", role: .destructive) {
                    do {
                        try FileManager.default.removeItem(at: candidate)
                        errorText = nil
                    } catch { errorText = error.localizedDescription }
                    pendingDelete = nil
                    reload()
                }
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("仅删除本工具箱文件夹中的副本，不会删除原始文件。")
        }
    }

    private func reload() {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            imported = try FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ).filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
             .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        } catch { errorText = error.localizedDescription }
    }

    private func fileSize(_ url: URL) -> String {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func copySafely(_ source: URL) throws {
        let granted = source.startAccessingSecurityScopedResource()
        defer { if granted { source.stopAccessingSecurityScopedResource() } }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let original = source.lastPathComponent
        guard !original.isEmpty && original != "." && original != ".." else {
            throw CDTKError.protocolMismatch("源文件名称无效")
        }
        let ext = (original as NSString).pathExtension
        let stem = (original as NSString).deletingPathExtension
        var destination = folder.appendingPathComponent(original, isDirectory: false)
        var n = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            let candidate = ext.isEmpty ? "\(stem) (\(n))" : "\(stem) (\(n)).\(ext)"
            destination = folder.appendingPathComponent(candidate, isDirectory: false)
            n += 1
            if n > 1000 { throw CDTKError.protocolMismatch("文件名冲突次数过多") }
        }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinateError: NSError?
        var operationError: Error?
        coordinator.coordinate(readingItemAt: source, options: [], error: &coordinateError) { available in
            do { try FileManager.default.copyItem(at: available, to: destination) }
            catch { operationError = error }
        }
        if let coordinateError { throw coordinateError }
        if let operationError { throw operationError }
        guard FileManager.default.fileExists(atPath: destination.path) else {
            throw CDTKError.connection("文件提供器没有返回可复制的文件")
        }
    }
}
