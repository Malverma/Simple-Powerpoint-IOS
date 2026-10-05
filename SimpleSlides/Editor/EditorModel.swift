import SwiftUI

/// Owns the open deck, the current selection and undo history. Every edit flows through `mutate`.
@Observable
final class EditorModel {
    private(set) var deck: Deck
    var currentSlideID: UUID
    var selectedElementID: UUID?
    var editingTextID: UUID?

    // Clipboard
    var copiedElement: SlideElement?
    var copiedStyle: ElementStyle?

    // Undo
    private var undoStack: [Deck] = []
    private var redoStack: [Deck] = []
    private var lastCoalesceKey: String?
    private var lastMutation = Date.distantPast
    private var interactionActive = false

    let store: DeckStore
    @ObservationIgnored private var saveWork: DispatchWorkItem?

    init(deck: Deck, store: DeckStore) {
        var d = deck
        if d.slides.isEmpty { d.slides = [Layouts.make(.title, size: d.size, theme: d.theme)] }
        self.deck = d
        self.store = store
        self.currentSlideID = d.slides[0].id
    }

    // MARK: Accessors

    var theme: Theme { deck.theme }
    var slideSize: CGSize { deck.size }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var currentIndex: Int { deck.slideIndex(currentSlideID) ?? 0 }
    var currentSlide: Slide { deck.slides[currentIndex] }

    var selectedElement: SlideElement? {
        guard let id = selectedElementID else { return nil }
        return currentSlide.element(id)
    }

    // MARK: Mutation & undo

    /// Applies a change. Changes with the same `coalesce` key within a short window
    /// (e.g. slider drags) collapse into a single undo step.
    func mutate(coalesce key: String? = nil, _ change: (inout Deck) -> Void) {
        var copy = deck
        change(&copy)
        guard copy != deck else { return }
        let now = Date()
        let coalesced = interactionActive
            || (key != nil && key == lastCoalesceKey && now.timeIntervalSince(lastMutation) < 1.0)
        if !coalesced {
            undoStack.append(deck)
            if undoStack.count > 200 { undoStack.removeFirst() }
            redoStack.removeAll()
        }
        lastCoalesceKey = key
        lastMutation = now
        copy.updatedAt = now
        deck = copy
        scheduleSave()
    }

    /// Starts a continuous gesture; all changes until `endInteraction` form one undo step.
    func beginInteraction() {
        guard !interactionActive else { return }
        undoStack.append(deck)
        redoStack.removeAll()
        interactionActive = true
    }

    func endInteraction() {
        interactionActive = false
        lastCoalesceKey = nil
        if let last = undoStack.last, last == deck { undoStack.removeLast() }
    }

    func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(deck)
        deck = prev
        lastCoalesceKey = nil
        fixSelection()
        scheduleSave()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(deck)
        deck = next
        lastCoalesceKey = nil
        fixSelection()
        scheduleSave()
    }

    private func fixSelection() {
        if deck.slideIndex(currentSlideID) == nil { currentSlideID = deck.slides[0].id }
        if let id = selectedElementID, currentSlide.element(id) == nil { selectedElementID = nil }
        editingTextID = nil
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.store.save(self.deck)
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        store.save(deck)
    }

    // MARK: Bindings

    func slideBinding(coalesce key: String = "slide") -> Binding<Slide> {
        let id = currentSlideID
        return Binding(
            get: { [weak self] in
                guard let self, let i = self.deck.slideIndex(id) else { return Slide() }
                return self.deck.slides[i]
            },
            set: { [weak self] newValue in
                self?.mutate(coalesce: "\(key)-\(id)") { d in
                    guard let i = d.slideIndex(id) else { return }
                    d.slides[i] = newValue
                    d.slides[i].syncBuildOrder()
                }
            })
    }

    func elementBinding(_ elementID: UUID, coalesce key: String = "element") -> Binding<SlideElement> {
        let slideID = currentSlideID
        let fallback = selectedElement ?? SlideElement(kind: .shape(ShapeContent()), frame: .zero)
        return Binding(
            get: { [weak self] in
                guard let self, let si = self.deck.slideIndex(slideID),
                      let e = self.deck.slides[si].element(elementID) else { return fallback }
                return e
            },
            set: { [weak self] newValue in
                self?.mutate(coalesce: "\(key)-\(elementID)") { d in
                    guard let si = d.slideIndex(slideID),
                          let ei = d.slides[si].elements.firstIndex(where: { $0.id == elementID }) else { return }
                    d.slides[si].elements[ei] = newValue
                    d.slides[si].syncBuildOrder()
                }
            })
    }

    func deckBinding<T: Equatable>(_ keyPath: WritableKeyPath<Deck, T>, coalesce key: String) -> Binding<T> {
        Binding(
            get: { [weak self] in self?.deck[keyPath: keyPath] ?? Deck()[keyPath: keyPath] },
            set: { [weak self] v in self?.mutate(coalesce: key) { $0[keyPath: keyPath] = v } })
    }

    // MARK: Element editing

    func updateElement(_ id: UUID, coalesce key: String? = nil, _ change: (inout SlideElement) -> Void) {
        let slideID = currentSlideID
        mutate(coalesce: key) { d in
            guard let si = d.slideIndex(slideID),
                  let ei = d.slides[si].elements.firstIndex(where: { $0.id == id }) else { return }
            change(&d.slides[si].elements[ei])
        }
    }

    func setFrame(_ id: UUID, _ frame: CGRect) {
        updateElement(id) { $0.frame = frame.integralish }
    }

    func setRotation(_ id: UUID, _ degrees: Double) {
        updateElement(id) { $0.rotation = degrees }
    }

    func insert(_ element: SlideElement) {
        var e = element
        if e.frame.width > slideSize.width || e.frame.height > slideSize.height {
            let s = min(slideSize.width / e.frame.width, slideSize.height / e.frame.height) * 0.8
            e.frame.size = CGSize(width: e.frame.width * s, height: e.frame.height * s)
        }
        if e.frame.origin == .zero && e.frame.size != slideSize {
            e.frame.origin = CGPoint(x: (slideSize.width - e.frame.width) / 2, y: (slideSize.height - e.frame.height) / 2)
        }
        let slideID = currentSlideID
        mutate { d in
            guard let si = d.slideIndex(slideID) else { return }
            d.slides[si].elements.append(e)
        }
        selectedElementID = e.id
    }

    func insertText(_ role: TextStyleKind) {
        let style = theme.typography[role]
        let h = style.size * 1.6 + 24
        let w = min(slideSize.width * 0.7, max(style.size * 10, 500))
        let placeholder: String
        switch role {
        case .title: placeholder = "Title"
        case .heading: placeholder = "Heading"
        case .body: placeholder = "Body text"
        case .caption: placeholder = "Caption"
        }
        var e = SlideElement(kind: .text(TextContent(text: placeholder, role: role)),
                             frame: CGRect(x: 0, y: 0, width: w, height: h))
        e.textContent.alignment = .center
        e.textContent.verticalAlignment = .middle
        insert(e)
        editingTextID = e.id
    }

    func insertShape(_ kind: ShapeKind) {
        let side = min(slideSize.width, slideSize.height) * 0.35
        var frame = CGRect(x: 0, y: 0, width: side, height: side)
        if kind == .line || kind == .arrow { frame.size = CGSize(width: side * 1.6, height: 60) }
        var e = Layouts.shape(kind, frame: frame, fill: .solid(.theme(.primary)),
                              corner: kind == .rectangle ? theme.shapeCornerRadius : 0)
        if kind == .star { e.style.fill = .solid(.theme(.accent)) }
        insert(e)
    }

    func insertImage(data: Data) {
        guard let added = AssetStore.shared.add(imageData: data) else { return }
        let (id, px) = added
        // Fill an empty placeholder if one is selected.
        if let sel = selectedElement, sel.isImage, sel.imageContent.assetID == nil {
            updateElement(sel.id) { $0.imageContent.assetID = id }
            return
        }
        let maxW = slideSize.width * 0.6, maxH = slideSize.height * 0.6
        let s = min(maxW / px.width, maxH / px.height)
        insert(SlideElement(kind: .image(ImageContent(assetID: id)),
                            frame: CGRect(x: 0, y: 0, width: px.width * s, height: px.height * s)))
    }

    func replaceImage(_ elementID: UUID, data: Data) {
        guard let id = AssetStore.shared.add(imageData: data)?.0 else { return }
        updateElement(elementID) { $0.imageContent.assetID = id }
    }

    func insertIcon(_ symbol: String) {
        let side = min(slideSize.width, slideSize.height) * 0.25
        insert(SlideElement(kind: .icon(IconContent(symbol: symbol)), frame: CGRect(x: 0, y: 0, width: side, height: side)))
    }

    func deleteSelected() {
        guard let id = selectedElementID else { return }
        let slideID = currentSlideID
        mutate { d in
            guard let si = d.slideIndex(slideID) else { return }
            d.slides[si].elements.removeAll { $0.id == id }
            d.slides[si].syncBuildOrder()
        }
        selectedElementID = nil
        editingTextID = nil
    }

    func duplicateSelected() {
        guard let e = selectedElement else { return }
        insert(e.copy(offset: 40))
    }

    func copySelected() { copiedElement = selectedElement }

    func cutSelected() {
        copySelected()
        deleteSelected()
    }

    func paste() {
        guard let e = copiedElement else { return }
        insert(e.copy(offset: currentSlide.element(e.id) == nil ? 0 : 40))
    }

    func copyStyle() { copiedStyle = selectedElement?.style }

    func pasteStyle() {
        guard let id = selectedElementID, let style = copiedStyle else { return }
        updateElement(id) { $0.style = style }
    }

    enum LayerMove { case front, forward, backward, back }

    func moveLayer(_ move: LayerMove) {
        guard let id = selectedElementID else { return }
        let slideID = currentSlideID
        mutate { d in
            guard let si = d.slideIndex(slideID),
                  let i = d.slides[si].elements.firstIndex(where: { $0.id == id }) else { return }
            var els = d.slides[si].elements
            let e = els.remove(at: i)
            switch move {
            case .front: els.append(e)
            case .back: els.insert(e, at: 0)
            case .forward: els.insert(e, at: min(i + 1, els.count))
            case .backward: els.insert(e, at: max(i - 1, 0))
            }
            d.slides[si].elements = els
        }
    }

    func moveLayers(from: IndexSet, to: Int) {
        // The layer list shows topmost first, so indices are reversed.
        let slideID = currentSlideID
        mutate { d in
            guard let si = d.slideIndex(slideID) else { return }
            var reversed = Array(d.slides[si].elements.reversed())
            reversed.move(fromOffsets: from, toOffset: to)
            d.slides[si].elements = reversed.reversed()
        }
    }

    enum AlignTarget { case left, hCenter, right, top, vCenter, bottom }

    func align(_ target: AlignTarget) {
        guard let e = selectedElement else { return }
        var f = e.frame
        switch target {
        case .left: f.origin.x = 0
        case .hCenter: f.origin.x = (slideSize.width - f.width) / 2
        case .right: f.origin.x = slideSize.width - f.width
        case .top: f.origin.y = 0
        case .vCenter: f.origin.y = (slideSize.height - f.height) / 2
        case .bottom: f.origin.y = slideSize.height - f.height
        }
        setFrame(e.id, f)
    }

    func nudge(dx: CGFloat, dy: CGFloat) {
        guard let e = selectedElement, !e.isLocked else { return }
        updateElement(e.id, coalesce: "nudge") { $0.frame = $0.frame.offsetBy(dx: dx, dy: dy) }
    }

    // MARK: Slides

    func select(slide id: UUID) {
        currentSlideID = id
        selectedElementID = nil
        editingTextID = nil
    }

    func addSlide(_ layout: SlideLayout) {
        let slide = Layouts.make(layout, size: slideSize, theme: theme)
        let at = currentIndex + 1
        mutate { $0.slides.insert(slide, at: min(at, $0.slides.count)) }
        select(slide: slide.id)
    }

    func duplicateSlide(_ id: UUID) {
        guard let i = deck.slideIndex(id) else { return }
        var copy = deck.slides[i]
        copy.id = UUID()
        // Keep element IDs so the copy can be animated against the original later.
        mutate { $0.slides.insert(copy, at: i + 1) }
        select(slide: copy.id)
    }

    func deleteSlide(_ id: UUID) {
        guard deck.slides.count > 1, let i = deck.slideIndex(id) else { return }
        mutate { $0.slides.remove(at: i) }
        if currentSlideID == id {
            select(slide: deck.slides[min(i, deck.slides.count - 1)].id)
        }
    }

    func moveSlide(_ id: UUID, to target: Int) {
        guard let i = deck.slideIndex(id) else { return }
        mutate { d in
            let s = d.slides.remove(at: i)
            d.slides.insert(s, at: min(max(target, 0), d.slides.count))
        }
    }

    func toggleSkip(_ id: UUID) {
        mutate { d in
            guard let i = d.slideIndex(id) else { return }
            d.slides[i].isSkipped.toggle()
        }
    }

    // MARK: Theme

    func applyTheme(_ theme: Theme) {
        mutate { $0.theme = theme }
    }

    func setDeckTitle(_ title: String) {
        mutate(coalesce: "title") { $0.title = title }
    }
}

extension CGRect {
    /// Rounds to whole points to keep stored values tidy.
    var integralish: CGRect {
        CGRect(x: origin.x.rounded(), y: origin.y.rounded(), width: size.width.rounded(), height: size.height.rounded())
    }
}
