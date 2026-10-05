import SwiftUI

@main
struct SimpleSlidesApp: App {
    @State private var store = DeckStore.shared
    @State private var path: [UUID] = []

    init() {
        FontCatalog.registerImportedFonts()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                LibraryView(store: store, path: $path)
                    .navigationDestination(for: UUID.self) { id in
                        if let deck = store.deck(id) {
                            EditorView(deck: deck, store: store)
                                .id(id)
                        } else {
                            ContentUnavailableView("Deck Not Found", systemImage: "questionmark.folder")
                        }
                    }
            }
            .onOpenURL { url in
                if let deck = try? store.importPackage(from: url) {
                    path = [deck.id]
                }
            }
        }
    }
}
