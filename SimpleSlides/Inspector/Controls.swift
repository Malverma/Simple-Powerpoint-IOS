import SwiftUI

// MARK: - Binding helpers

extension Binding where Value == Fill {
    var solidColor: Binding<ColorRef> {
        Binding<ColorRef>(
            get: { if case .solid(let c) = wrappedValue { return c } else { return .theme(.primary) } },
            set: { wrappedValue = .solid($0) })
    }

    var gradient: Binding<GradientFill> {
        Binding<GradientFill>(
            get: { if case .gradient(let g) = wrappedValue { return g } else { return .between(.theme(.primary), .theme(.accent)) } },
            set: { wrappedValue = .gradient($0) })
    }

    var imageFill: Binding<ImageFill>? {
        guard case .image(let img) = wrappedValue else { return nil }
        return Binding<ImageFill>(
            get: { if case .image(let i) = wrappedValue { return i } else { return img } },
            set: { wrappedValue = .image($0) })
    }
}

extension Binding where Value == CGFloat {
    var double: Binding<Double> {
        Binding<Double>(get: { Double(wrappedValue) }, set: { wrappedValue = CGFloat($0) })
    }
}

extension Binding {
    /// Maps an optional override to a concrete value, writing back on change.
    init(_ source: Binding<Value?>, fallback: Value) {
        self.init(get: { source.wrappedValue ?? fallback }, set: { source.wrappedValue = $0 })
    }
}

// MARK: - Labeled slider

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil
    var format: String = "%.0f"
    var suffix: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value) + suffix)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let step {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Color

/// Picks a theme colour slot or any custom colour (with opacity).
struct ColorRefPicker: View {
    let title: String
    @Binding var ref: ColorRef
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            HStack(spacing: 8) {
                ForEach(ThemeColorSlot.allCases) { slot in
                    let selected = ref == .theme(slot)
                    Circle()
                        .fill(theme.palette[slot].color)
                        .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                        .frame(width: 26, height: 26)
                        .padding(3)
                        .overlay(Circle().stroke(selected ? Color.accentColor : .clear, lineWidth: 2.5))
                        .onTapGesture { ref = .theme(slot) }
                        .accessibilityLabel("Theme \(slot.title)")
                        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
                }
                Divider().frame(height: 24)
                ColorPicker(title, selection: Binding(
                    get: { theme.color(ref) },
                    set: { ref = .custom(RGBA($0)) }), supportsOpacity: true)
                    .labelsHidden()
                    .overlay(alignment: .topTrailing) {
                        if case .custom = ref {
                            Circle().fill(Color.accentColor).frame(width: 8, height: 8).offset(x: 2, y: -2)
                        }
                    }
            }
        }
    }
}

struct RGBAPicker: View {
    let title: String
    @Binding var rgba: RGBA

    var body: some View {
        ColorPicker(title, selection: Binding(get: { rgba.color }, set: { rgba = RGBA($0) }), supportsOpacity: true)
    }
}

// MARK: - Fill & gradient

struct FillEditor: View {
    @Binding var fill: Fill
    let theme: Theme
    var allowImage = false
    var onPickImage: (() -> Void)? = nil

    private var kinds: [Fill.Kind] { allowImage ? Fill.Kind.allCases : [.none, .solid, .gradient] }

    var body: some View {
        Picker("Fill", selection: Binding(
            get: { fill.kind },
            set: { kind in
                switch kind {
                case .none: fill = .none
                case .solid: fill = .solid(.theme(.primary))
                case .gradient: fill = .gradient(.between(.theme(.primary), .theme(.accent)))
                case .image: onPickImage?()
                }
            })) {
            ForEach(kinds) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)

        switch fill {
        case .none:
            EmptyView()
        case .solid:
            ColorRefPicker(title: "Color", ref: $fill.solidColor, theme: theme)
        case .gradient:
            GradientEditor(gradient: $fill.gradient, theme: theme)
        case .image:
            if let img = $fill.imageFill {
                Button {
                    onPickImage?()
                } label: {
                    Label("Choose Image…", systemImage: "photo")
                }
                Picker("Mode", selection: img.mode) {
                    ForEach(ImageFillMode.allCases) { Text($0.title).tag($0) }
                }
                LabeledSlider(title: "Blur", value: img.blur, range: 0...60)
                Toggle("Tint", isOn: Binding(
                    get: { img.wrappedValue.tint != nil },
                    set: { img.wrappedValue.tint = $0 ? .theme(.background) : nil }))
                if img.wrappedValue.tint != nil {
                    ColorRefPicker(title: "Tint Color", ref: Binding(
                        get: { img.wrappedValue.tint ?? .theme(.background) },
                        set: { img.wrappedValue.tint = $0 }), theme: theme)
                    LabeledSlider(title: "Tint Strength", value: img.tintOpacity, range: 0...1, format: "%.2f")
                }
            }
        }
    }
}

struct GradientEditor: View {
    @Binding var gradient: GradientFill
    let theme: Theme

    var body: some View {
        Rectangle()
            .fill(gradient.shapeStyle(theme))
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.15)))

        Picker("Type", selection: $gradient.kind) {
            ForEach(GradientKind.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)

        if gradient.kind != .radial {
            LabeledSlider(title: "Angle", value: $gradient.angle, range: 0...360, suffix: "°")
        }

        ForEach($gradient.stops) { $stop in
            VStack(alignment: .leading) {
                ColorRefPicker(title: "Stop", ref: $stop.color, theme: theme)
                HStack {
                    Slider(value: $stop.location, in: 0...1)
                    Text("\(Int(stop.location * 100))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 40)
                    if gradient.stops.count > 2 {
                        Button(role: .destructive) {
                            gradient.stops.removeAll { $0.id == stop.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }

        Button {
            gradient.stops.append(GradientStop(color: .theme(.secondary), location: 0.5))
        } label: {
            Label("Add Color Stop", systemImage: "plus")
        }
    }
}

// MARK: - Transition

struct TransitionEditor: View {
    @Binding var transition: TransitionModel

    var body: some View {
        Picker("Effect", selection: $transition.kind) {
            ForEach(TransitionKind.allCases) { Text($0.title).tag($0) }
        }
        if transition.kind != .none {
            if [.push, .slide, .flip].contains(transition.kind) {
                Picker("Direction", selection: $transition.direction) {
                    ForEach(MoveDirection.allCases) { Text($0.title).tag($0) }
                }
            }
            LabeledSlider(title: "Duration", value: $transition.duration, range: 0.1...3, format: "%.1f", suffix: "s")
            Picker("Easing", selection: $transition.easing) {
                ForEach(EasingOption.allCases) { Text($0.title).tag($0) }
            }
        }
    }
}
