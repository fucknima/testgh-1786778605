import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// UIKit file picker in copy mode, avoiding ambiguous public.item filtering.
/// Explicit property-list UTTypes keep .plist selectable in Files providers.
struct PairingDocumentPicker: UIViewControllerRepresentable {
    let didPick: (URL) -> Void
    let didCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [
            .propertyList, .xmlPropertyList, .binaryPropertyList,
            .json, .data, .plainText
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ picker: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(didPick: didPick, didCancel: didCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let didPick: (URL) -> Void
        let didCancel: () -> Void

        init(didPick: @escaping (URL) -> Void, didCancel: @escaping () -> Void) {
            self.didPick = didPick
            self.didCancel = didCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let selected = urls.first else {
                didCancel()
                return
            }
            // Import synchronously while the temporary copy remains accessible.
            didPick(selected)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            didCancel()
        }
    }
}
