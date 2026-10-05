import SwiftUI

enum InspectorTab: String, CaseIterable, Identifiable {
    case slide, text, image, style, arrange, animate
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct InspectorView: View {
    @Bindable var model: EditorModel
    var onPickImage: (UUID) -> Void

    @State private var tab: InspectorTab = .style
    @Environment(\.dismiss) private var dismiss

    private var available: [InspectorTab] {
        guard let e = model.selectedElement else { return [.slide] }
        switch e.kind {
        case .text: return [.text, .style, .arrange, .animate]
        case .image: return [.image, .style, .arrange, .animate]
        case .shape, .icon: return [.style, .arrange, .animate]
        }
    }

    private var effectiveTab: InspectorTab {
        available.contains(tab) ? tab : available[0]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if available.count > 1 {
                    Picker("Section", selection: Binding(get: { effectiveTab }, set: { tab = $0 })) {
                        ForEach(available) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                Form {
                    if let id = model.selectedElementID, model.selectedElement != nil {
                        let element = model.elementBinding(id)
                        switch effectiveTab {
                        case .text: TextInspector(element: element, model: model)
                        case .image: ImageInspector(element: element, theme: model.theme, onReplace: { onPickImage(id) })
                        case .style: StyleInspector(element: element, theme: model.theme)
                        case .arrange: ArrangeInspector(element: element, model: model)
                        case .animate: AnimateInspector(element: element, model: model)
                        case .slide: EmptyView()
                        }
                    } else {
                        SlideInspector(model: model, onPickBackground: { onPickImage(ImagePickTarget.background) })
                    }
                }
                .formStyle(.grouped)
            }
            .navigationTitle(model.selectedElement?.displayName ?? "Slide \(model.currentIndex + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Text

struct TextInspector: View {
    @Binding var element: SlideElement
    let model: EditorModel
    @State private var showFonts = false

    private var theme: Theme { model.theme }

    var body: some View {
        let content = $element.textContent
        let resolved = element.textContent.resolved(in: theme)

        Section {
            TextField("Text", text: content.text, axis: .vertical)
                .lineLimit(2...8)
            Picker("Style", selection: content.role) {
                ForEach(TextStyleKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }

        Section("Font") {
            NavigationLink {
                FontPickerView(selection: Binding(content.fontName, fallback: resolved.fontName))
            } label: {
                LabeledContent("Font") {
                    Text(resolved.fontName)
                        .font(FontCatalog.font(name: resolved.fontName, size: 17, weight: .regular))
                }
            }
            HStack {
                Text("Size")
                Spacer()
                TextField("Size", value: Binding(content.size, fallback: resolved.size), format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                Stepper("Size", value: Binding(content.size, fallback: resolved.size), in: 6...800, step: 2)
                    .labelsHidden()
            }
            ColorRefPicker(title: "Color", ref: Binding(content.color, fallback: resolved.color), theme: theme)
            contrastWarning(resolved)

            HStack {
                formatToggle("bold", isOn: Binding(
                    get: { resolved.weight.rawValue == "bold" || resolved.weight == .heavy || resolved.weight == .black },
                    set: { content.weight.wrappedValue = $0 ? .bold : .regular }))
                formatToggle("italic", isOn: content.italic)
                formatToggle("underline", isOn: content.underline)
                formatToggle("strikethrough", isOn: content.strikethrough)
                Spacer()
                Picker("Case", selection: content.textCase) {
                    ForEach(TextCaseOption.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
            }
        }

        Section("Paragraph") {
            Picker("Alignment", selection: content.alignment) {
                ForEach(TextAlign.allCases) { Image(systemName: $0.icon).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Vertical", selection: content.verticalAlignment) {
                ForEach(VerticalAlign.allCases) { Image(systemName: $0.icon).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("List", selection: content.listStyle) {
                ForEach(ListStyleOption.allCases) { Image(systemName: $0.icon).tag($0) }
            }
            .pickerStyle(.segmented)
        }

        Section {
            DisclosureGroup("More Text Options") {
                Picker("Weight", selection: Binding(content.weight, fallback: resolved.weight)) {
                    ForEach(FontWeightOption.allCases) { Text($0.title).tag($0) }
                }
                LabeledSlider(title: "Letter Spacing", value: Binding(content.letterSpacing, fallback: resolved.letterSpacing), range: -10...40, format: "%.1f")
                LabeledSlider(title: "Line Spacing", value: Binding(content.lineSpacing, fallback: resolved.lineSpacing), range: 0...120)
                LabeledSlider(title: "Padding", value: content.padding, range: 0...160)
                Toggle("Shrink Text to Fit", isOn: content.autoShrink)
                Toggle("Gradient Text", isOn: Binding(
                    get: { element.textContent.gradient != nil },
                    set: { element.textContent.gradient = $0 ? .between(.theme(.primary), .theme(.accent)) : nil }))
                if element.textContent.gradient != nil {
                    GradientEditor(gradient: Binding(
                        get: { element.textContent.gradient ?? .between(.theme(.primary), .theme(.accent)) },
                        set: { element.textContent.gradient = $0 }), theme: theme)
                }
            }
            if element.textContent.hasOverrides {
                Button("Reset to Theme Style") { element.textContent.clearOverrides() }
            }
        }
    }

    private func formatToggle(_ icon: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Image(systemName: icon)
                .frame(width: 34, height: 30)
                .background(isOn.wrappedValue ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(icon.capitalized)
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
    }

    @ViewBuilder
    private func contrastWarning(_ style: TextStyle) -> some View {
        let bgFill = element.style.fill != .none ? element.style.fill : (model.currentSlide.background ?? theme.background)
        if element.textContent.gradient == nil, let bg = theme.approximateColor(bgFill) {
            let ratio = RGBA.contrast(theme.rgba(style.color), bg)
            if ratio < 3 {
                Label("Low contrast (\(String(format: "%.1f", ratio)):1). Text may be hard to read.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Image

struct ImageInspector: View {
    @Binding var element: SlideElement
    let theme: Theme
    var onReplace: () -> Void

    var body: some View {
        let img = $element.imageContent
        Section {
            Button {
                onReplace()
            } label: {
                Label(element.imageContent.assetID == nil ? "Choose Image…" : "Replace Image…", systemImage: "photo.badge.plus")
            }
            Picker("Scaling", selection: img.mode) {
                ForEach(ImageFillMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        Section("Adjust") {
            LabeledSlider(title: "Brightness", value: img.brightness, range: -0.5...0.5, format: "%.2f")
            LabeledSlider(title: "Contrast", value: img.contrast, range: 0.3...2, format: "%.2f")
            LabeledSlider(title: "Saturation", value: img.saturation, range: 0...2, format: "%.2f")
            LabeledSlider(title: "Blur", value: img.blur, range: 0...40)
            Toggle("Black & White", isOn: img.grayscale)
            Button("Reset Adjustments") {
                element.imageContent.brightness = 0
                element.imageContent.contrast = 1
                element.imageContent.saturation = 1
                element.imageContent.blur = 0
                element.imageContent.grayscale = false
            }
        }
        Section("Accessibility") {
            TextField("Describe this image", text: img.altText, axis: .vertical)
        }
    }
}

// MARK: - Style

struct StyleInspector: View {
    @Binding var element: SlideElement
    let theme: Theme
    @State private var showIcons = false

    var body: some View {
        if element.isShape {
            shapeSection
        }
        if element.isIcon {
            iconSection
        }

        let openPath = element.isShape && element.shapeContent.isOpenPath
        if !openPath {
            Section("Fill") {
                FillEditor(fill: $element.style.fill, theme: theme)
            }
        }

        Section(openPath ? "Line" : "Border") {
            LabeledSlider(title: "Width", value: $element.style.stroke.width, range: 0...60)
            if element.style.stroke.width > 0 {
                ColorRefPicker(title: "Color", ref: $element.style.stroke.color, theme: theme)
                Picker("Style", selection: $element.style.stroke.dash) {
                    ForEach(DashStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }

        Section("Appearance") {
            if !element.isShape || element.shapeContent.kind == .rectangle {
                LabeledSlider(title: "Corner Radius", value: $element.style.cornerRadius,
                              range: 0...max(Double(min(element.frame.width, element.frame.height)) / 2, 1))
            }
            LabeledSlider(title: "Opacity", value: Binding(
                get: { element.style.opacity * 100 },
                set: { element.style.opacity = $0 / 100 }), range: 0...100, suffix: "%")
        }

        Section("Effects") {
            Toggle("Shadow", isOn: $element.style.shadow.enabled)
            if element.style.shadow.enabled {
                RGBAPicker(title: "Shadow Color", rgba: $element.style.shadow.color)
                LabeledSlider(title: "Blur", value: $element.style.shadow.radius, range: 0...120)
                LabeledSlider(title: "Offset X", value: $element.style.shadow.x, range: -100...100)
                LabeledSlider(title: "Offset Y", value: $element.style.shadow.y, range: -100...100)
            }
            DisclosureGroup("More Effects") {
                LabeledSlider(title: "Layer Blur", value: $element.style.blur, range: 0...60)
                Picker("Blend Mode", selection: $element.style.blendMode) {
                    ForEach(BlendModeOption.allCases) { Text($0.title).tag($0) }
                }
            }
        }
    }

    @ViewBuilder
    private var shapeSection: some View {
        let shape = $element.shapeContent
        Section("Shape") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ShapeKind.allCases) { kind in
                        let selected = element.shapeContent.kind == kind
                        Button {
                            let wasOpen = element.shapeContent.isOpenPath
                            element.shapeContent.kind = kind
                            let isOpen = element.shapeContent.isOpenPath
                            if isOpen && element.style.stroke.width == 0 {
                                element.style.stroke = StrokeModel(color: .theme(.primary), width: 8)
                            }
                            if wasOpen && !isOpen && element.style.fill == .none {
                                element.style.fill = .solid(.theme(.primary))
                            }
                        } label: {
                            Image(systemName: kind.icon)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .background(selected ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemFill),
                                            in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(kind.title)
                    }
                }
            }
            if element.shapeContent.kind == .star || element.shapeContent.kind == .polygon {
                Stepper("\(element.shapeContent.kind == .star ? "Points" : "Sides"): \(element.shapeContent.points)",
                        value: shape.points, in: 3...24)
            }
            if element.shapeContent.kind == .star {
                LabeledSlider(title: "Inner Radius", value: shape.innerRatio, range: 0.1...0.95, format: "%.2f")
            }
            if !element.shapeContent.isOpenPath {
                TextField("Label (optional)", text: shape.text)
            }
        }
    }

    @ViewBuilder
    private var iconSection: some View {
        let icon = $element.iconContent
        Section("Icon") {
            Button {
                showIcons = true
            } label: {
                LabeledContent("Symbol") {
                    Image(systemName: element.iconContent.symbol)
                }
            }
            .sheet(isPresented: $showIcons) {
                IconPickerView { element.iconContent.symbol = $0 }
            }
            ColorRefPicker(title: "Color", ref: icon.color, theme: theme)
            Picker("Weight", selection: icon.weight) {
                ForEach(FontWeightOption.allCases) { Text($0.title).tag($0) }
            }
            Picker("Rendering", selection: icon.rendering) {
                ForEach(SymbolRenderingOption.allCases) { Text($0.title).tag($0) }
            }
        }
    }
}

// MARK: - Arrange

struct ArrangeInspector: View {
    @Binding var element: SlideElement
    let model: EditorModel
    @AppStorage("lockAspect") private var lockAspect = false

    var body: some View {
        Section("Position & Size") {
            HStack {
                numberField("X", $element.frame.origin.x.double)
                numberField("Y", $element.frame.origin.y.double)
            }
            HStack {
                numberField("W", Binding(
                    get: { Double(element.frame.width) },
                    set: { resize(width: $0, height: nil) }))
                numberField("H", Binding(
                    get: { Double(element.frame.height) },
                    set: { resize(width: nil, height: $0) }))
            }
            Toggle("Lock Aspect Ratio", isOn: $lockAspect)
            LabeledSlider(title: "Rotation", value: $element.rotation, range: -180...180, suffix: "°")
            HStack {
                Button("Flip Horizontal") { element.style.flipH.toggle() }
                Spacer()
                Button("Flip Vertical") { element.style.flipV.toggle() }
            }
            .buttonStyle(.borderless)
        }

        Section("Align to Slide") {
            HStack {
                alignButton("align.horizontal.left", .left)
                alignButton("align.horizontal.center", .hCenter)
                alignButton("align.horizontal.right", .right)
                Divider()
                alignButton("align.vertical.top", .top)
                alignButton("align.vertical.center", .vCenter)
                alignButton("align.vertical.bottom", .bottom)
            }
        }

        Section {
            TextField("Name", text: $element.name, prompt: Text(element.kind.title))
            Toggle("Locked", isOn: $element.isLocked)
        }

        Section {
            ForEach(Array(model.currentSlide.elements.reversed())) { e in
                HStack {
                    Image(systemName: e.kind.icon)
                        .frame(width: 24)
                        .foregroundStyle(.secondary)
                    Text(e.displayName)
                        .lineLimit(1)
                        .fontWeight(e.id == element.id ? .semibold : .regular)
                    Spacer()
                    Button {
                        model.updateElement(e.id) { $0.isHidden.toggle() }
                    } label: {
                        Image(systemName: e.isHidden ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(e.isHidden ? "Show" : "Hide")
                    Button {
                        model.updateElement(e.id) { $0.isLocked.toggle() }
                    } label: {
                        Image(systemName: e.isLocked ? "lock.fill" : "lock.open")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(e.isLocked ? "Unlock" : "Lock")
                }
                .contentShape(Rectangle())
                .onTapGesture { model.selectedElementID = e.id }
            }
            .onMove { model.moveLayers(from: $0, to: $1) }
        } header: {
            HStack {
                Text("Layers")
                Spacer()
                EditButton().font(.caption)
            }
        }
    }

    private func resize(width: Double?, height: Double?) {
        var f = element.frame
        let ratio = f.width / max(f.height, 1)
        if let width {
            f.size.width = max(CGFloat(width), 1)
            if lockAspect { f.size.height = f.width / ratio }
        }
        if let height {
            f.size.height = max(CGFloat(height), 1)
            if lockAspect { f.size.width = f.height * ratio }
        }
        element.frame = f
    }

    private func numberField(_ label: String, _ value: Binding<Double>) -> some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(.secondary).frame(width: 18)
            TextField(label, value: value, format: .number.precision(.fractionLength(0)))
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func alignButton(_ icon: String, _ target: EditorModel.AlignTarget) -> some View {
        Button {
            model.align(target)
        } label: {
            Image(systemName: icon).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - Animate

struct AnimateInspector: View {
    @Binding var element: SlideElement
    let model: EditorModel

    var body: some View {
        Section("Build In") {
            Picker("Effect", selection: $element.build.effect) {
                ForEach(BuildEffect.allCases) { Text($0.title).tag($0) }
            }
            if element.build.effect != .none {
                Picker("Start", selection: $element.build.trigger) {
                    ForEach(BuildTrigger.allCases) { Text($0.title).tag($0) }
                }
                if element.build.effect == .moveIn {
                    Picker("From", selection: Binding(
                        get: { element.build.direction },
                        set: { element.build.direction = $0 })) {
                        ForEach(MoveDirection.allCases) { Text(fromTitle($0)).tag($0) }
                    }
                }
                LabeledSlider(title: "Duration", value: $element.build.duration, range: 0.1...3, format: "%.1f", suffix: "s")
                LabeledSlider(title: "Delay", value: $element.build.delay, range: 0...5, format: "%.1f", suffix: "s")
            }
        }

        let builds = model.currentSlide.activeBuilds
        if !builds.isEmpty {
            Section {
                ForEach(Array(builds.enumerated()), id: \.element.id) { i, e in
                    HStack {
                        Text("\(i + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(e.displayName).lineLimit(1)
                            .fontWeight(e.id == element.id ? .semibold : .regular)
                        Spacer()
                        Text(e.build.effect.title).foregroundStyle(.secondary).font(.caption)
                    }
                }
                .onMove { from, to in
                    var order = model.currentSlide.activeBuilds.map(\.id)
                    order.move(fromOffsets: from, toOffset: to)
                    let slideID = model.currentSlideID
                    model.mutate { d in
                        guard let i = d.slideIndex(slideID) else { return }
                        d.slides[i].buildOrder = order
                    }
                }
            } header: {
                HStack {
                    Text("Build Order")
                    Spacer()
                    EditButton().font(.caption)
                }
            }
        }
    }

    /// Direction names describe where the element moves *towards*; show where it comes from.
    private func fromTitle(_ d: MoveDirection) -> String {
        switch d {
        case .up: return "Bottom"
        case .down: return "Top"
        case .left: return "Right"
        case .right: return "Left"
        }
    }
}

// MARK: - Slide

struct SlideInspector: View {
    @Bindable var model: EditorModel
    var onPickBackground: () -> Void
    @State private var showThemes = false

    var body: some View {
        let slide = model.slideBinding()

        Section("Background") {
            Toggle("Use Theme Background", isOn: Binding(
                get: { slide.wrappedValue.background == nil },
                set: { slide.wrappedValue.background = $0 ? nil : model.theme.background }))
            if slide.wrappedValue.background != nil {
                FillEditor(fill: Binding(
                    get: { slide.wrappedValue.background ?? model.theme.background },
                    set: { slide.wrappedValue.background = $0 }),
                           theme: model.theme, allowImage: true, onPickImage: onPickBackground)
            }
        }

        Section("Transition") {
            Toggle("Use Theme Transition", isOn: Binding(
                get: { slide.wrappedValue.transition == nil },
                set: { slide.wrappedValue.transition = $0 ? nil : model.theme.transition }))
            if slide.wrappedValue.transition != nil {
                TransitionEditor(transition: Binding(
                    get: { slide.wrappedValue.transition ?? model.theme.transition },
                    set: { slide.wrappedValue.transition = $0 }))
            }
        }

        Section("Playback") {
            Toggle("Skip Slide", isOn: slide.isSkipped)
            Toggle("Auto-Advance", isOn: Binding(
                get: { slide.wrappedValue.autoAdvance != nil },
                set: { slide.wrappedValue.autoAdvance = $0 ? 5 : nil }))
            if let secs = slide.wrappedValue.autoAdvance {
                LabeledSlider(title: "After", value: Binding(
                    get: { secs },
                    set: { slide.wrappedValue.autoAdvance = $0 }), range: 1...60, step: 1, suffix: "s")
            }
        }

        Section("Speaker Notes") {
            TextField("Notes for this slide", text: slide.notes, axis: .vertical)
                .lineLimit(3...12)
        }

        Section("Deck") {
            Button {
                showThemes = true
            } label: {
                LabeledContent("Theme", value: model.theme.name)
            }
            .sheet(isPresented: $showThemes) { ThemeGalleryView(model: model) }
            NavigationLink("Edit Theme") {
                ThemeEditorView(theme: model.deckBinding(\.theme, coalesce: "theme"), store: model.store)
            }
            Toggle("Loop Presentation", isOn: model.deckBinding(\.loopPresentation, coalesce: "loop"))
        }
    }
}
