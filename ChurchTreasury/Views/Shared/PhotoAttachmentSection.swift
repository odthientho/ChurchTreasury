import SwiftUI
import PhotosUI
import VisionKit

/// A reusable Form section for attaching a single photo: shows the attached
/// image with a Remove button when present, otherwise offers Take Photo /
/// Choose from Library. Reports the chosen `UIImage` (or nil on removal) back
/// to the parent, which is responsible for compressing and persisting it.
///
/// Presentation modifiers are anchored on the concrete Button / PhotosPicker
/// leaf views (not the Section) so they present reliably inside a Form.
struct PhotoAttachmentSection: View {
    let titleKey: String
    @Binding var image: UIImage?
    /// Called whenever the attachment changes — a `UIImage` when one is
    /// picked/captured, or nil when the user removes it.
    var onChange: (UIImage?) -> Void

    @State private var showingCamera = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var loadFailed = false

    var body: some View {
        Section(String(localized: String.LocalizationValue(titleKey))) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button(role: .destructive) {
                    self.image = nil
                    onChange(nil)
                } label: {
                    Label(String(localized: "attachment.remove"), systemImage: "trash")
                }
            } else {
                if VNDocumentCameraViewController.isSupported {
                    Button {
                        showingCamera = true
                    } label: {
                        Label(String(localized: "scan.takePhoto"), systemImage: "doc.viewfinder")
                    }
                    .fullScreenCover(isPresented: $showingCamera) {
                        DocumentScannerView(
                            onCapture: { captured in
                                showingCamera = false
                                set(captured)
                            },
                            onCancel: { showingCamera = false }
                        )
                        .ignoresSafeArea()
                    }
                }

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(String(localized: "scan.chooseLibrary"), systemImage: "photo.on.rectangle")
                }
                .onChange(of: pickerItem) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let picked = UIImage(data: data) {
                            set(picked)
                        } else {
                            loadFailed = true
                        }
                        pickerItem = nil
                    }
                }
                .alert(
                    String(localized: "scan.photoLoadFailedTitle"),
                    isPresented: $loadFailed
                ) {
                    Button(String(localized: "action.done"), role: .cancel) {}
                } message: {
                    Text(String(localized: "scan.photoLoadFailed"))
                }
            }
        }
    }

    private func set(_ picked: UIImage) {
        image = picked
        onChange(picked)
    }
}
