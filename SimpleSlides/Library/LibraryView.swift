import SwiftUI
import UniformTypeIdentifiers

enum DeckSort: String, CaseIterable, Identifiable {
    case edited, created, name
    var id: String { rawValue }
    var title: String {
        switch self {
        case .edited: return "Last Edited"
        case .created: return "Date Created"
        case .name: return "Name"
        }
    }
}

struct LibraryView: View {
    @Bindable var store: DeckStore
    @Binding var path: [UUID]

    @State private var search = ""
    @AppStorage("deckSort") private var sort: DeckSort = .edited
    @State private var showNew = false
    @State private var showSettings = false
    @State private var importing = false
    @State private var renaming: Deck?
    @State private var renameText = ""
    @State private var deleting: Deck?
    @State private var share: ShareItems?
    @State private var error: String?

    private var decks: [Deck] {
        var list = store.decks
        if !search.isEmpty {
            list = list.filter { deck in
                deck.title.localizedCaseInsensitiveContains(search) ||
                deck.slides.contains { s in
                    s.elements.contains { $0.isText && $0.textContent.text.localizedCaseInsensitiveContains(search) }
                }
            }
        }
        switch sort {
        case .edited: list.sort { $0.updatedAt > $1.updatedAt }
        case .created: list.sort { $0.createdAt > $1.createdAt }
        case .name: list.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
        return list
    }

    var body: some View {
        ScrollView {
            if decks.isEmpty {
                ContentUnavailableView {
                    Label(search.isEmpty ? "No Presentations" : "No Results", systemImage: "rectangle.on.rectangle")
                } description: {
                    Text(search.isEmpty ? "Tap + to create your first deck." : "Try a different search.")
                }
                .padding(.top, 80)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 280), spacing: 16)], spacing: 20) {
                ForEach(decks) { deck in
                    NavigationLink(value: deck.id) {
                        DeckCard(deck: deck)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { menu(for: deck) }
                }
            }
            .padding()
        }
        .navigationTitle("Presentations")
        .searchable(text: $search, prompt: "Search titles and slide text")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $sort) {
                        ForEach(DeckSort.allCases) { Text($0.title).tag($0) }
                    }
                    Button { importing = true } label: { Label("Import SimpleSlides File", systemImage: "square.and.arrow.down") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
                Button { showNew = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New Presentation")
            }
        }
        .sheet(isPresented: $showNew) {
            NewDeckSheet(store: store) { deck in
                path.append(deck.id)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(item: $share) { ShareSheet(items: $0.urls).ignoresSafeArea() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.simpleSlidesDeck, .json, .data]) { result in
            do {
                let deck = try store.importPackage(from: result.get())
                path.append(deck.id)
            } catch {
                self.error = "That file couldn't be opened as a SimpleSlides deck."
            }
        }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let d = renaming { store.rename(d.id, to: renameText) }
            }
        }
        .confirmationDialog("Delete “\(deleting?.title ?? "")”?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let d = deleting { store.delete(d.id) }
            }
        } message: {
            Text("This can't be undone.")
        }
        .alert("Error", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    @ViewBuilder
    private func menu(for deck: Deck) -> some View {
        Button {
            renameText = deck.title
            renaming = deck
        } label: { Label("Rename", systemImage: "pencil") }
        Button { store.duplicate(deck) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
        Button {
            if let url = try? store.exportPackage(deck) { share = ShareItems(urls: [url]) }
        } label: { Label("Share", systemImage: "square.and.arrow.up") }
        Divider()
        Button(role: .destructive) { deleting = deck } label: { Label("Delete", systemImage: "trash") }
    }
}

struct DeckCard: View {
    let deck: Deck

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let first = deck.slides.first {
                    SlideThumbnail(slide: first, theme: deck.theme, size: deck.size)
                } else {
                    Color.gray.opacity(0.2)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 10, contentMode: .fit)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.1)))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

            Text(deck.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("\(deck.slides.count) slide\(deck.slides.count == 1 ? "" : "s") · \(deck.updatedAt.formatted(.relative(presentation: .named)))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct NewDeckSheet: View {
    let store: DeckStore
    var onCreate: (Deck) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var aspect: AspectRatio = .wide
    @State private var theme: Theme = Theme.builtIn[0]

    private var allThemes: [Theme] { store.userThemes + Theme.builtIn }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("Presentation Title", text: $title)
                        .font(.title3)
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                    Picker("Aspect Ratio", selection: $aspect) {
                        ForEach(AspectRatio.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Text("Theme").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 14)], spacing: 14) {
                        ForEach(allThemes) { t in
                            let selected = t.id == theme.id
                            Button {
                                theme = t
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    SlideThumbnail(slide: preview(t), theme: t, size: aspect.size)
                                        .frame(height: 100)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8)
                                            .stroke(selected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: selected ? 3 : 1))
                                    Text(t.name).font(.subheadline.weight(selected ? .semibold : .regular))
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("New Presentation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let deck = store.create(title: title, theme: theme, aspect: aspect)
                        dismiss()
                        onCreate(deck)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func preview(_ t: Theme) -> Slide {
        var s = Layouts.make(.title, size: aspect.size, theme: t)
        if !title.isEmpty { s.elements[0].textContent.text = title }
        return s
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("snapping") private var snapping = true
    @AppStorage("showGrid") private var showGrid = false
    @AppStorage("gridSize") private var gridSize = 60.0
    @AppStorage("lockAspect") private var lockAspect = false
    @AppStorage("haptics") private var haptics = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Editing") {
                    Toggle("Smart Guides & Snapping", isOn: $snapping)
                    Toggle("Show Grid", isOn: $showGrid)
                    LabeledSlider(title: "Grid Size", value: $gridSize, range: 10...200, step: 10, suffix: "pt")
                    Toggle("Corner Handles Keep Aspect Ratio", isOn: $lockAspect)
                    Toggle("Haptics", isOn: $haptics)
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    Text("SimpleSlides — simple by default, deep on demand.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
