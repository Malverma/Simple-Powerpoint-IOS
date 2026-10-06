import SwiftUI

@main
struct SimpleSlidesApp: App {
    @State private var store = DeckStore.shared
    @State private var openDeck: DeckRef?

    init() {
        FontCatalog.registerImportedFonts()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                LibraryView(store: store, openDeck: $openDeck)
            }
            // The editor is presented full screen (with its own NavigationStack) rather than pushed:
            // its `.inspector` inside a pushed destination blanks the view and crashes
            // SwiftUI's navigation path handling on iPad.
            .fullScreenCover(item: $openDeck) { ref in
                if let deck = store.deck(ref.id) {
                    EditorView(deck: deck, store: store)
                        .id(ref.id)
                } else {
                    NavigationStack {
                        ContentUnavailableView("Deck Not Found", systemImage: "questionmark.folder")
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Close") { openDeck = nil }
                                }
                            }
                    }
                }
            }
            .onOpenURL { url in
                if let deck = try? store.importPackage(from: url) {
                    openDeck = DeckRef(id: deck.id)
                }
            }
        }
    }
}

/// Identifies the deck open in the editor.
struct DeckRef: Identifiable, Hashable {
    let id: UUID
}
