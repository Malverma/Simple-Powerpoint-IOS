import SwiftUI
import UIKit

enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf, images, video, native
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pdf: return "PDF"
        case .images: return "Images"
        case .video: return "Video"
        case .native: return "SimpleSlides File"
        }
    }
    var icon: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .images: return "photo.stack"
        case .video: return "film"
        case .native: return "doc.zipper"
        }
    }
}

struct ShareItems: Identifiable {
    let id = UUID()
    let urls: [URL]
}

struct ExportView: View {
    let deck: Deck
    var store: DeckStore? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var format: ExportFormat = .pdf
    @State private var includeSkipped = false
    @State private var imageScale: Double = 1
    @State private var jpeg = false
    @State private var videoHeight = 1080
    @State private var secondsPerSlide: Double = 4
    @State private var working = false
    @State private var progress: Double = 0
    @State private var share: ShareItems?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Format", selection: $format) {
                        ForEach(ExportFormat.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Options") {
                    switch format {
                    case .pdf:
                        Toggle("Include Skipped Slides", isOn: $includeSkipped)
                    case .images:
                        Picker("Format", selection: $jpeg) {
                            Text("PNG").tag(false)
                            Text("JPEG").tag(true)
                        }
                        .pickerStyle(.segmented)
                        Picker("Resolution", selection: $imageScale) {
                            Text("\(Int(deck.size.width))px").tag(1.0)
                            Text("\(Int(deck.size.width * 2))px").tag(2.0)
                        }
                        Toggle("Include Skipped Slides", isOn: $includeSkipped)
                    case .video:
                        Picker("Quality", selection: $videoHeight) {
                            Text("720p").tag(720)
                            Text("1080p").tag(1080)
                            Text("4K").tag(2160)
                        }
                        .pickerStyle(.segmented)
                        LabeledSlider(title: "Seconds per Slide", value: $secondsPerSlide, range: 1...15, step: 0.5, format: "%.1f", suffix: "s")
                        Toggle("Include Skipped Slides", isOn: $includeSkipped)
                    case .native:
                        Text("A single file with all slides, images and theme. Open it in SimpleSlides on any iPhone or iPad.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        Task { await run() }
                    } label: {
                        HStack {
                            Spacer()
                            if working {
                                if format == .video {
                                    ProgressView(value: progress).frame(width: 120)
                                } else {
                                    ProgressView()
                                }
                            } else {
                                Text("Export \(format.title)").fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(working)
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .sheet(item: $share) { items in
                ShareSheet(items: items.urls)
                    .ignoresSafeArea()
            }
            .alert("Export Failed", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
        }
    }

    @MainActor
    private func run() async {
        working = true
        progress = 0
        defer { working = false }
        do {
            let urls: [URL]
            switch format {
            case .pdf:
                urls = [try Exporter.pdf(deck, includeSkipped: includeSkipped)]
            case .images:
                urls = try Exporter.images(deck, includeSkipped: includeSkipped, scale: imageScale, jpeg: jpeg)
            case .video:
                urls = [try await Exporter.video(deck, includeSkipped: includeSkipped, height: videoHeight,
                                                 secondsPerSlide: secondsPerSlide) { p in
                    Task { @MainActor in progress = p }
                }]
            case .native:
                urls = [try (store ?? DeckStore.shared).exportPackage(deck)]
            }
            share = ShareItems(urls: urls)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
