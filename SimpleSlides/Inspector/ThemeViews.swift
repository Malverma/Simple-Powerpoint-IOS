import SwiftUI

/// Pick a theme for the deck; previews the current slide in each theme.
struct ThemeGalleryView: View {
    @Bindable var model: EditorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !model.store.userThemes.isEmpty {
                        Text("My Themes").font(.headline).padding(.horizontal)
                        grid(model.store.userThemes, deletable: true)
                    }
                    Text("Built-in").font(.headline).padding(.horizontal)
                    grid(Theme.builtIn, deletable: false)
                }
                .padding(.vertical)
            }
            .navigationTitle("Themes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("Edit Current") {
                        ThemeEditorView(theme: model.deckBinding(\.theme, coalesce: "theme"), store: model.store)
                    }
                }
            }
        }
    }

    private func grid(_ themes: [Theme], deletable: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
            ForEach(themes) { theme in
                let selected = theme.id == model.theme.id
                Button {
                    model.applyTheme(theme)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        SlideThumbnail(slide: model.currentSlide, theme: theme, size: model.slideSize)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(selected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: selected ? 3 : 1))
                        HStack(spacing: 4) {
                            Text(theme.name).font(.subheadline.weight(.medium))
                            Spacer()
                            ForEach([ThemeColorSlot.primary, .accent, .text], id: \.self) { slot in
                                Circle().fill(theme.palette[slot].color).frame(width: 10, height: 10)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if deletable {
                        Button(role: .destructive) { model.store.deleteTheme(theme.id) } label: {
                            Label("Delete Theme", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

/// Full theme editor: palette, typography, background, defaults.
struct ThemeEditorView: View {
    @Binding var theme: Theme
    let store: DeckStore
    @State private var saved = false

    var body: some View {
        Form {
            Section("Name") {
                TextField("Theme Name", text: $theme.name)
            }
            Section("Colors") {
                ForEach(ThemeColorSlot.allCases) { slot in
                    RGBAPicker(title: slot.title, rgba: $theme.palette[slot])
                }
            }
            Section("Text Styles") {
                ForEach(TextStyleKind.allCases) { kind in
                    NavigationLink {
                        TextStyleEditor(style: $theme.typography[kind], theme: theme, title: kind.title)
                    } label: {
                        let s = theme.typography[kind]
                        HStack {
                            Text(kind.title)
                                .font(FontCatalog.font(name: s.fontName, size: 18, weight: s.weight))
                            Spacer()
                            Text("\(s.fontName) · \(Int(s.size))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Default Background") {
                FillEditor(fill: $theme.background, theme: theme)
            }
            Section("Default Transition") {
                TransitionEditor(transition: $theme.transition)
            }
            Section("Shapes") {
                LabeledSlider(title: "Rectangle Corner Radius", value: $theme.shapeCornerRadius, range: 0...200)
            }
            Section {
                Button {
                    store.saveTheme(theme)
                    saved = true
                } label: {
                    Label(saved ? "Saved to My Themes" : "Save to My Themes", systemImage: saved ? "checkmark" : "square.and.arrow.down")
                }
            } footer: {
                Text("Changes apply to every element that uses theme colors and text styles. Elements with their own overrides keep them.")
            }
        }
        .navigationTitle("Edit Theme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TextStyleEditor: View {
    @Binding var style: TextStyle
    let theme: Theme
    let title: String

    var body: some View {
        Form {
            Section {
                Text("The quick brown fox")
                    .font(FontCatalog.font(name: style.fontName, size: min(style.size * 0.35, 40), weight: style.weight))
                    .kerning(style.letterSpacing * 0.35)
                    .foregroundStyle(theme.color(style.color))
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(theme.palette.background.color, in: RoundedRectangle(cornerRadius: 8))
            }
            Section {
                NavigationLink {
                    FontPickerView(selection: $style.fontName)
                } label: {
                    LabeledContent("Font", value: style.fontName)
                }
                LabeledSlider(title: "Size", value: $style.size, range: 8...400)
                Picker("Weight", selection: $style.weight) {
                    ForEach(FontWeightOption.allCases) { Text($0.title).tag($0) }
                }
                ColorRefPicker(title: "Color", ref: $style.color, theme: theme)
                LabeledSlider(title: "Letter Spacing", value: $style.letterSpacing, range: -10...40, format: "%.1f")
                LabeledSlider(title: "Line Spacing", value: $style.lineSpacing, range: 0...120)
            }
        }
        .navigationTitle(title)
    }
}
