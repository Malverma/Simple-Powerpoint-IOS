import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let simpleSlidesDeck = UTType(exportedAs: "com.malverma.simpleslides.deck")
}

/// Portable single-file deck: the deck plus every image and font it uses.
struct DeckPackage: Codable {
    var version = 1
    var deck: Deck
    var assets: [UUID: Data]
}

/// Loads and persists decks as JSON files in the app's Documents folder.
@Observable
final class DeckStore {
    static let shared = DeckStore()

    private(set) var decks: [Deck] = []
    var userThemes: [Theme] = []

    private let decksDirectory: URL
    private let themesURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        decksDirectory = URL.documentsDirectory.appending(path: "Decks", directoryHint: .isDirectory)
        themesURL = URL.documentsDirectory.appending(path: "themes.json")
        try? FileManager.default.createDirectory(at: decksDirectory, withIntermediateDirectories: true)
        load()
    }

    private func load() {
        let files = (try? FileManager.default.contentsOfDirectory(at: decksDirectory, includingPropertiesForKeys: nil)) ?? []
        decks = files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(Deck.self, from: Data(contentsOf: $0)) }
            .sorted { $0.updatedAt > $1.updatedAt }
        if let data = try? Data(contentsOf: themesURL),
           let themes = try? decoder.decode([Theme].self, from: data) {
            userThemes = themes
        }
        if decks.isEmpty {
            save(SampleDeck.make())
        }
    }

    private func url(for id: UUID) -> URL {
        decksDirectory.appending(path: "\(id.uuidString).json")
    }

    func deck(_ id: UUID) -> Deck? { decks.first { $0.id == id } }

    func save(_ deck: Deck) {
        if let i = decks.firstIndex(where: { $0.id == deck.id }) {
            decks[i] = deck
        } else {
            decks.insert(deck, at: 0)
        }
        let data = try? encoder.encode(deck)
        let url = url(for: deck.id)
        DispatchQueue.global(qos: .utility).async {
            try? data?.write(to: url, options: .atomic)
        }
    }

    @discardableResult
    func create(title: String, theme: Theme, aspect: AspectRatio) -> Deck {
        var deck = Deck(title: title.isEmpty ? "Untitled" : title, aspect: aspect, theme: theme)
        deck.slides = [Layouts.make(.title, size: aspect.size, theme: theme)]
        save(deck)
        return deck
    }

    @discardableResult
    func duplicate(_ deck: Deck) -> Deck {
        var copy = deck
        copy.id = UUID()
        copy.title = deck.title + " Copy"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        save(copy)
        return copy
    }

    func rename(_ id: UUID, to title: String) {
        guard var d = deck(id) else { return }
        d.title = title
        d.updatedAt = Date()
        save(d)
    }

    func delete(_ id: UUID) {
        decks.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: url(for: id))
        collectGarbage()
    }

    /// Removes image assets no longer referenced by any deck.
    private func collectGarbage() {
        let used = decks.reduce(into: Set<UUID>()) { $0.formUnion($1.assetIDs) }
            .union(userThemes.compactMap { (t: Theme) -> UUID? in
                if case .image(let i) = t.background { return i.assetID }
                return nil
            })
        let dir = AssetStore.shared.directory
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for f in files {
            if let id = UUID(uuidString: f.lastPathComponent), !used.contains(id) {
                AssetStore.shared.remove(id)
            }
        }
    }

    // MARK: Themes

    func saveTheme(_ theme: Theme) {
        var t = theme
        if let i = userThemes.firstIndex(where: { $0.id == t.id }) {
            userThemes[i] = t
        } else {
            if Theme.builtIn.contains(where: { $0.id == t.id }) { t.id = UUID() }
            userThemes.append(t)
        }
        persistThemes()
    }

    func deleteTheme(_ id: UUID) {
        userThemes.removeAll { $0.id == id }
        persistThemes()
    }

    private func persistThemes() {
        if let data = try? encoder.encode(userThemes) {
            try? data.write(to: themesURL, options: .atomic)
        }
    }

    // MARK: Packages

    func exportPackage(_ deck: Deck) throws -> URL {
        var assets: [UUID: Data] = [:]
        for id in deck.assetIDs {
            if let d = AssetStore.shared.data(id) { assets[id] = d }
        }
        let data = try encoder.encode(DeckPackage(deck: deck, assets: assets))
        let url = FileManager.default.temporaryDirectory
            .appending(path: "\(deck.title.sanitizedFileName).simpleslides")
        try data.write(to: url, options: .atomic)
        return url
    }

    @discardableResult
    func importPackage(from url: URL) throws -> Deck {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let pkg = try decoder.decode(DeckPackage.self, from: Data(contentsOf: url))
        for (id, data) in pkg.assets {
            AssetStore.shared.add(data: data, id: id)
        }
        var deck = pkg.deck
        if decks.contains(where: { $0.id == deck.id }) {
            deck.id = UUID()
            deck.title += " (Imported)"
        }
        deck.updatedAt = Date()
        save(deck)
        return deck
    }
}

extension String {
    var sanitizedFileName: String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Untitled" : cleaned
    }
}
