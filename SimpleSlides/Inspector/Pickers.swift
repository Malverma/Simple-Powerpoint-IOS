import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct FontPickerView: View {
    @Binding var selection: String
    @State private var search = ""
    @State private var importing = false
    @State private var importError: String?
    @State private var families = FontCatalog.installedFamilies
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if search.isEmpty {
                Section("System") {
                    ForEach(FontCatalog.systemFamilies, id: \.self) { row($0) }
                }
            }
            Section("All Fonts") {
                ForEach(filtered, id: \.self) { row($0) }
            }
        }
        .searchable(text: $search, prompt: "Search fonts")
        .navigationTitle("Font")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    importing = true
                } label: {
                    Label("Import Font", systemImage: "plus")
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.font], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                if let family = try FontCatalog.importFont(from: url) {
                    families = FontCatalog.installedFamilies
                    selection = family
                }
            } catch {
                importError = error.localizedDescription
            }
        }
        .alert("Couldn't Import Font", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    private var filtered: [String] {
        search.isEmpty ? families : families.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    private func row(_ name: String) -> some View {
        Button {
            selection = name
            dismiss()
        } label: {
            HStack {
                Text(name)
                    .font(FontCatalog.font(name: name, size: 18, weight: .regular))
                    .foregroundStyle(.primary)
                Spacer()
                if selection == name {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}

struct IconPickerView: View {
    var onPick: (String) -> Void
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss

    static let symbols: [String] = [
        "star.fill", "heart.fill", "bolt.fill", "flame.fill", "leaf.fill", "drop.fill", "sun.max.fill", "moon.fill",
        "cloud.fill", "snowflake", "sparkles", "wand.and.stars", "lightbulb.fill", "brain.head.profile", "graduationcap.fill",
        "book.fill", "bookmark.fill", "pencil", "paintbrush.fill", "paintpalette.fill", "camera.fill", "photo.fill",
        "music.note", "mic.fill", "headphones", "play.fill", "film.fill", "tv.fill", "gamecontroller.fill",
        "person.fill", "person.2.fill", "person.3.fill", "figure.walk", "figure.run", "hand.thumbsup.fill", "hand.wave.fill",
        "message.fill", "bubble.left.and.bubble.right.fill", "envelope.fill", "phone.fill", "paperplane.fill", "bell.fill",
        "house.fill", "building.2.fill", "map.fill", "mappin.and.ellipse", "location.fill", "globe.americas.fill", "airplane",
        "car.fill", "bicycle", "tram.fill", "ferry.fill", "cart.fill", "bag.fill", "creditcard.fill", "dollarsign.circle.fill",
        "chart.bar.fill", "chart.pie.fill", "chart.line.uptrend.xyaxis", "chart.xyaxis.line", "target", "flag.fill",
        "trophy.fill", "medal.fill", "crown.fill", "gift.fill", "tag.fill", "calendar", "clock.fill", "alarm.fill",
        "hourglass", "timer", "checkmark.circle.fill", "xmark.circle.fill", "exclamationmark.triangle.fill",
        "questionmark.circle.fill", "info.circle.fill", "plus.circle.fill", "minus.circle.fill", "arrow.right.circle.fill",
        "arrow.up.right", "arrow.triangle.2.circlepath", "arrow.clockwise", "lock.fill", "key.fill", "shield.fill",
        "gearshape.fill", "wrench.and.screwdriver.fill", "hammer.fill", "cpu", "desktopcomputer", "laptopcomputer",
        "iphone", "applewatch", "server.rack", "network", "wifi", "antenna.radiowaves.left.and.right", "link",
        "doc.fill", "folder.fill", "tray.full.fill", "archivebox.fill", "magnifyingglass", "eye.fill", "quote.opening",
        "list.bullet", "checklist", "square.grid.2x2.fill", "circle.hexagongrid.fill", "atom", "function", "infinity",
        "pawprint.fill", "tortoise.fill", "hare.fill", "fish.fill", "bird.fill", "tree.fill", "mountain.2.fill",
        "cup.and.saucer.fill", "fork.knife", "birthday.cake.fill", "stethoscope", "cross.case.fill", "pills.fill",
        "dumbbell.fill", "sportscourt.fill", "soccerball", "basketball.fill", "tennis.racket", "rocket.fill",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 12)], spacing: 12) {
                    if !search.isEmpty, UIImage(systemName: search.lowercased()) != nil, !filtered.contains(search.lowercased()) {
                        cell(search.lowercased())
                    }
                    ForEach(filtered, id: \.self) { cell($0) }
                }
                .padding()
            }
            .searchable(text: $search, prompt: "Search or type any SF Symbol name")
            .navigationTitle("Icons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var filtered: [String] {
        let q = search.lowercased().trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? Self.symbols : Self.symbols.filter { $0.contains(q) }
    }

    private func cell(_ name: String) -> some View {
        Button {
            onPick(name)
            dismiss()
        } label: {
            Image(systemName: name)
                .font(.title2)
                .frame(width: 56, height: 56)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name.replacingOccurrences(of: ".", with: " "))
    }
}
