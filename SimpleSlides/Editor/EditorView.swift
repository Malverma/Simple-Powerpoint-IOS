import SwiftUI
import PhotosUI

struct EditorView: View {
    @State private var model: EditorModel
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.dismiss) private var dismiss

    @State private var showInspector = false
    @State private var presenting = false
    @State private var presentFromStart = false
    @State private var showPhotos = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photoTarget: UUID?
    @State private var showIcons = false
    @State private var showExport = false
    @State private var showThemes = false
    @AppStorage("snapping") private var snapping = true
    @AppStorage("showGrid") private var showGrid = false

    init(deck: Deck, store: DeckStore) {
        _model = State(initialValue: EditorModel(deck: deck, store: store))
    }

    var body: some View {
        // The inspector sits outside the NavigationStack so it gets its own full-height
        // column and toolbar instead of merging its items into the editor's bar.
        NavigationStack {
            editor
                .navigationTitle(model.deckBinding(\.title, coalesce: "title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarRole(.editor)
                .navigationBarBackButtonHidden(true)
                .toolbar { toolbarContent }
        }
        .inspector(isPresented: $showInspector) {
            InspectorView(model: model, onPickImage: { id in
                photoTarget = id
                showPhotos = true
            })
            .inspectorColumnWidth(min: 300, ideal: 350, max: 440)
            .presentationDetents([.fraction(0.45), .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.45)))
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            let target = photoTarget
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        if let target, target == ImagePickTarget.background {
                            model.setSlideBackgroundImage(data: data)
                        } else if let target, target != ImagePickTarget.none {
                            model.replaceImage(target, data: data)
                        } else {
                            model.insertImage(data: data)
                        }
                    }
                }
                photoItem = nil
                photoTarget = nil
            }
        }
        .sheet(isPresented: $showIcons) {
            IconPickerView { model.insertIcon($0) }
        }
        .sheet(isPresented: $showExport) {
            ExportView(deck: model.deck)
        }
        .sheet(isPresented: $showThemes) {
            ThemeGalleryView(model: model)
        }
        .fullScreenCover(isPresented: $presenting) {
            PresenterView(deck: model.deck,
                          startIndex: presentFromStart ? 0 : model.currentIndex)
        }
        .onDisappear { model.saveNow() }
        .background(keyboardShortcuts)
    }

    private var editor: some View {
        Group {
            if hSize == .regular {
                HStack(spacing: 0) {
                    SlideStrip(model: model, vertical: true)
                        .frame(width: 170)
                    Divider()
                    center
                }
            } else {
                VStack(spacing: 0) {
                    center
                    Divider()
                    SlideStrip(model: model, vertical: false)
                        .frame(height: 86)
                }
            }
        }
    }

    private var center: some View {
        CanvasView(model: model, onRequestImage: { id in
            photoTarget = id
            showPhotos = true
        })
        .overlay(alignment: .top) {
            ElementActionBar(model: model, onReplaceImage: { id in
                photoTarget = id
                showPhotos = true
            })
            .padding(.top, 8)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                model.saveNow()
                dismiss()
            } label: {
                Label("Presentations", systemImage: "chevron.backward")
            }
            .accessibilityLabel("Presentations")
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Button { presentFromStart = false; presenting = true } label: {
                    Label("Play from Current Slide", systemImage: "play")
                }
                Button { presentFromStart = true; presenting = true } label: {
                    Label("Play from Start", systemImage: "backward.end")
                }
            } label: {
                Image(systemName: "play.fill")
            } primaryAction: {
                presentFromStart = false
                presenting = true
            }
            .accessibilityLabel("Play")

            Menu {
                Button { showThemes = true } label: { Label("Themes", systemImage: "paintpalette") }
                Button { showExport = true } label: { Label("Export & Share", systemImage: "square.and.arrow.up") }
                Divider()
                Toggle(isOn: $snapping) { Label("Smart Guides", systemImage: "align.horizontal.center") }
                Toggle(isOn: $showGrid) { Label("Grid", systemImage: "grid") }
                Divider()
                Picker(selection: model.deckBinding(\.aspect, coalesce: "aspect")) {
                    ForEach(AspectRatio.allCases) { Text($0.title).tag($0) }
                } label: {
                    Label("Aspect Ratio", systemImage: "aspectratio")
                }
                .pickerStyle(.menu)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More")
        }

        ToolbarItemGroup(placement: .bottomBar) {
            Menu {
                Section("Text") {
                    ForEach(TextStyleKind.allCases) { role in
                        Button(role.title) { model.insertText(role) }
                    }
                }
                Menu {
                    ForEach(ShapeKind.allCases) { kind in
                        Button { model.insertShape(kind) } label: { Label(kind.title, systemImage: kind.icon) }
                    }
                } label: {
                    Label("Shape", systemImage: "square.on.circle")
                }
                Button {
                    photoTarget = nil
                    showPhotos = true
                } label: {
                    Label("Image", systemImage: "photo")
                }
                Button { showIcons = true } label: { Label("Icon", systemImage: "star.square") }
            } label: {
                Label("Insert", systemImage: "plus.circle.fill")
                    .labelStyle(.titleAndIcon)
            }

            Button {
                showInspector.toggle()
            } label: {
                Label("Format", systemImage: "paintbrush.pointed.fill")
                    .labelStyle(.titleAndIcon)
            }

            Spacer()

            Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!model.canUndo)
                .keyboardShortcut("z", modifiers: .command)
                .accessibilityLabel("Undo")
            Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!model.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .accessibilityLabel("Redo")
        }
    }

    /// Hardware keyboard shortcuts (iPad / Magic Keyboard).
    @ViewBuilder
    private var keyboardShortcuts: some View {
        if model.selectedElementID != nil && model.editingTextID == nil {
            ZStack {
                Button("") { model.nudge(dx: -1, dy: 0) }.keyboardShortcut(.leftArrow, modifiers: [])
                Button("") { model.nudge(dx: 1, dy: 0) }.keyboardShortcut(.rightArrow, modifiers: [])
                Button("") { model.nudge(dx: 0, dy: -1) }.keyboardShortcut(.upArrow, modifiers: [])
                Button("") { model.nudge(dx: 0, dy: 1) }.keyboardShortcut(.downArrow, modifiers: [])
                Button("") { model.nudge(dx: -10, dy: 0) }.keyboardShortcut(.leftArrow, modifiers: .shift)
                Button("") { model.nudge(dx: 10, dy: 0) }.keyboardShortcut(.rightArrow, modifiers: .shift)
                Button("") { model.nudge(dx: 0, dy: -10) }.keyboardShortcut(.upArrow, modifiers: .shift)
                Button("") { model.nudge(dx: 0, dy: 10) }.keyboardShortcut(.downArrow, modifiers: .shift)
                Button("") { model.deleteSelected() }.keyboardShortcut(.delete, modifiers: [])
                Button("") { model.duplicateSelected() }.keyboardShortcut("d", modifiers: .command)
                Button("") { model.copySelected() }.keyboardShortcut("c", modifiers: .command)
                Button("") { model.cutSelected() }.keyboardShortcut("x", modifiers: .command)
            }
            .opacity(0)
            .accessibilityHidden(true)
        } else if model.editingTextID == nil {
            Button("") { model.paste() }
                .keyboardShortcut("v", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }
}

/// Sentinel targets for the shared photo picker.
enum ImagePickTarget {
    static let none = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    static let background = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}

extension EditorModel {
    func setSlideBackgroundImage(data: Data) {
        guard let id = AssetStore.shared.add(imageData: data)?.0 else { return }
        let slideID = currentSlideID
        mutate { d in
            guard let i = d.slideIndex(slideID) else { return }
            d.slides[i].background = .image(ImageFill(assetID: id))
        }
    }
}

// MARK: - Floating action bar

struct ElementActionBar: View {
    @Bindable var model: EditorModel
    var onReplaceImage: (UUID) -> Void

    var body: some View {
        Group {
            if model.editingTextID != nil {
                HStack {
                    Button {
                        model.editingTextID = nil
                    } label: {
                        Label("Done", systemImage: "checkmark")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
            } else if let e = model.selectedElement {
                HStack(spacing: 18) {
                    if e.isText && !e.isLocked {
                        bar("pencil", "Edit Text") { model.editingTextID = e.id }
                    }
                    if e.isImage && !e.isLocked {
                        bar("photo.badge.plus", "Replace Image") { onReplaceImage(e.id) }
                    }
                    bar("plus.square.on.square", "Duplicate") { model.duplicateSelected() }
                    Menu {
                        Button { model.moveLayer(.front) } label: { Label("Bring to Front", systemImage: "square.3.layers.3d.top.filled") }
                        Button { model.moveLayer(.forward) } label: { Label("Bring Forward", systemImage: "square.2.layers.3d.top.filled") }
                        Button { model.moveLayer(.backward) } label: { Label("Send Backward", systemImage: "square.2.layers.3d.bottom.filled") }
                        Button { model.moveLayer(.back) } label: { Label("Send to Back", systemImage: "square.3.layers.3d.bottom.filled") }
                    } label: {
                        Image(systemName: "square.3.layers.3d")
                    }
                    .accessibilityLabel("Arrange")
                    Menu {
                        Button { model.cutSelected() } label: { Label("Cut", systemImage: "scissors") }
                        Button { model.copySelected() } label: { Label("Copy", systemImage: "doc.on.doc") }
                        Button { model.paste() } label: { Label("Paste", systemImage: "doc.on.clipboard") }
                            .disabled(model.copiedElement == nil)
                        Divider()
                        Button { model.copyStyle() } label: { Label("Copy Style", systemImage: "paintbrush") }
                        Button { model.pasteStyle() } label: { Label("Paste Style", systemImage: "paintbrush.fill") }
                            .disabled(model.copiedStyle == nil)
                        Divider()
                        Button {
                            model.updateElement(e.id) { $0.isLocked.toggle() }
                        } label: {
                            Label(e.isLocked ? "Unlock" : "Lock", systemImage: e.isLocked ? "lock.open" : "lock")
                        }
                        Button {
                            model.updateElement(e.id) { $0.isHidden = true }
                            model.selectedElementID = nil
                        } label: {
                            Label("Hide", systemImage: "eye.slash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 22, height: 22)
                    }
                    .accessibilityLabel("More Actions")
                    bar("trash", "Delete", role: .destructive) { model.deleteSelected() }
                }
                .font(.system(size: 17))
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            } else if model.copiedElement != nil {
                Button {
                    model.paste()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
            }
        }
        .animation(.snappy(duration: 0.2), value: model.selectedElementID)
    }

    private func bar(_ icon: String, _ label: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Image(systemName: icon)
        }
        .tint(role == .destructive ? .red : .accentColor)
        .accessibilityLabel(label)
    }
}

// MARK: - Slide strip

struct SlideStrip: View {
    @Bindable var model: EditorModel
    let vertical: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(vertical ? .vertical : .horizontal, showsIndicators: false) {
                let layout = vertical
                    ? AnyLayout(VStackLayout(spacing: 14))
                    : AnyLayout(HStackLayout(spacing: 10))
                layout {
                    ForEach(Array(model.deck.slides.enumerated()), id: \.element.id) { index, slide in
                        thumbnail(index: index, slide: slide)
                            .id(slide.id)
                    }
                    addButton
                }
                .padding(vertical ? 14 : 10)
            }
            .onChange(of: model.currentSlideID) { _, id in
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .background(Color(.systemBackground))
    }

    private var thumbWidth: CGFloat { vertical ? 130 : 96 }

    private func thumbnail(index: Int, slide: Slide) -> some View {
        let selected = slide.id == model.currentSlideID
        let aspect = model.slideSize.width / model.slideSize.height
        let content = HStack(alignment: .top, spacing: 6) {
            if vertical {
                Text("\(index + 1)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 16, alignment: .trailing)
            }
            SlideThumbnail(slide: slide, theme: model.theme, size: model.slideSize)
                .frame(width: thumbWidth, height: thumbWidth / aspect)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: selected ? 3 : 1)
                )
                .overlay(alignment: .bottomTrailing) {
                    if slide.isSkipped {
                        Image(systemName: "eye.slash.fill")
                            .font(.caption2)
                            .padding(4)
                            .background(.thinMaterial, in: Circle())
                            .padding(4)
                    }
                }
                .opacity(slide.isSkipped ? 0.5 : 1)
        }

        return content
            .contentShape(Rectangle())
            .onTapGesture { model.select(slide: slide.id) }
            .contextMenu {
                Button { model.duplicateSlide(slide.id) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                Button { model.toggleSkip(slide.id) } label: {
                    Label(slide.isSkipped ? "Don't Skip" : "Skip Slide", systemImage: slide.isSkipped ? "eye" : "eye.slash")
                }
                Button { model.moveSlide(slide.id, to: index - 1) } label: {
                    Label(vertical ? "Move Up" : "Move Left", systemImage: vertical ? "arrow.up" : "arrow.left")
                }
                .disabled(index == 0)
                Button { model.moveSlide(slide.id, to: index + 1) } label: {
                    Label(vertical ? "Move Down" : "Move Right", systemImage: vertical ? "arrow.down" : "arrow.right")
                }
                .disabled(index == model.deck.slides.count - 1)
                Divider()
                Button(role: .destructive) { model.deleteSlide(slide.id) } label: { Label("Delete", systemImage: "trash") }
                    .disabled(model.deck.slides.count <= 1)
            }
            .draggable(slide.id.uuidString) {
                SlideThumbnail(slide: slide, theme: model.theme, size: model.slideSize)
                    .frame(width: 120, height: 120 / aspect)
            }
            .dropDestination(for: String.self) { items, _ in
                guard let s = items.first, let id = UUID(uuidString: s), id != slide.id else { return false }
                model.moveSlide(id, to: index)
                return true
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Slide \(index + 1)\(slide.isSkipped ? ", skipped" : "")")
            .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private var addButton: some View {
        let aspect = model.slideSize.width / model.slideSize.height
        return Menu {
            ForEach(SlideLayout.allCases) { layout in
                Button(layout.title) { model.addSlide(layout) }
            }
        } label: {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundStyle(.secondary)
                .overlay(Image(systemName: "plus").font(.title3).foregroundStyle(.secondary))
                .frame(width: thumbWidth, height: thumbWidth / aspect)
                .padding(.leading, vertical ? 22 : 0)
        }
        .accessibilityLabel("Add Slide")
    }
}
