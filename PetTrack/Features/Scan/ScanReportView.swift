import PhotosUI
import SwiftUI
import UIKit
import VisionKit

/// Scan → OCR → review flow that turns a vet report into a visit record.
struct ScanReportView: View {
    let pet: Pet

    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store

    @State private var showCamera = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var phase: Phase = .idle
    @State private var review: Review?

    private enum Phase: Equatable {
        case idle, processing, failed(String)
    }

    struct Review: Identifiable, Hashable {
        let id = UUID()
        let report: ParsedVetReport
        let attachment: Data?

        static func == (lhs: Review, rhs: Review) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                illustration
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scan a vet report")
                        .font(.display(30))
                        .foregroundStyle(Theme.ink)
                    Text("Works with reports, invoices and vaccination certificates in English, Spanish, German, French and Dutch. Text is recognized on your device and never uploaded.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                }

                switch phase {
                case .processing:
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Reading your report…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.ink)
                    }
                    .card()
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.danger)
                        .card()
                case .idle:
                    EmptyView()
                }

                VStack(spacing: 12) {
                    if VNDocumentCameraViewController.isSupported {
                        Button { showCamera = true } label: {
                            Label("Scan with camera", systemImage: "camera.viewfinder")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 5, matching: .images) {
                        Label("Choose from Photos", systemImage: "photo.on.rectangle")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    }
                }
                .disabled(phase == .processing)
            }
            .padding(22)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
        .fullScreenCover(isPresented: $showCamera) {
            DocumentScannerView { images in
                showCamera = false
                process(images)
            } onCancel: {
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                photoItems = []
                process(images)
            }
        }
        .navigationDestination(item: $review) { review in
            VetVisitEditorView(pet: pet, scanned: review.report, attachment: review.attachment) {
                dismiss()
            }
        }
        .onAppear {
            if !store.isPremium { dismiss() }
        }
    }

    private var illustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Theme.plum.opacity(0.22), Theme.sky.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(Theme.ink.opacity(index == 0 ? 0.5 : 0.15))
                        .frame(width: [150, 190, 120, 170, 90][index], height: index == 0 ? 10 : 7)
                }
            }
            .padding(22)
            .frame(width: 230, height: 150, alignment: .topLeading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .rotationEffect(.degrees(-4))
            .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
            Image(systemName: "viewfinder")
                .font(.system(size: 150, weight: .ultraLight))
                .foregroundStyle(Theme.plum)
        }
        .frame(height: 220)
    }

    private func process(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        phase = .processing
        Task {
            do {
                let report = try await ReportScanService.analyze(images: images)
                let attachment = images.first.flatMap { ImageResizer.jpegData(from: $0, maxDimension: 1800, quality: 0.75) }
                if report.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    phase = .failed(String(localized: "We couldn't find any text. Try again in good light with the whole page in view."))
                } else {
                    phase = .idle
                    review = Review(report: report, attachment: attachment)
                }
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}

/// VisionKit document camera with edge detection and perspective correction.
struct DocumentScannerView: UIViewControllerRepresentable {
    var onScan: ([UIImage]) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView

        init(parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            parent.onScan(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onCancel()
        }
    }
}
