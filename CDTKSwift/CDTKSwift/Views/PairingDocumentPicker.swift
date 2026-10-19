import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Copy-mode picker for arbitrary file providers (including Files extensions).
/// Explicit data and property-list UTTypes prevent silent selection failures
/// caused by filtering on the overly generic public.item type.
struct NativeDocumentPicker: UIViewControllerRepresentable {
    let multiple: Bool
    let didPick: ([URL]) -> Void
    let didCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supported: [UTType] = [
            .data, .content, .propertyList, .xmlPropertyList,
            .binaryPropertyList, .json, .plainText
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supported, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = multiple
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ picker: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(didPick: didPick, didCancel: didCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let didPick: ([URL]) -> Void
        private let didCancel: () -> Void

        init(didPick: @escaping ([URL]) -> Void, didCancel: @escaping () -> Void) {
            self.didPick = didPick
            self.didCancel = didCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if urls.isEmpty {
                didCancel()
            } else {
                // Import immediately, while the copy supplied by Files is still accessible.
                didPick(urls)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            didCancel()
        }
    }
}

struct PairingDocumentPicker: View {
    let didPick: (URL) -> Void
    let didCancel: () -> Void

    var body: some View {
        NativeDocumentPicker(multiple: false, didPick: { urls in
            if let first = urls.first { didPick(first) } else { didCancel() }
        }, didCancel: didCancel)
    }
}
