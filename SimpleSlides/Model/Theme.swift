import SwiftUI

struct ThemePalette: Codable, Hashable {
    var background: RGBA
    var surface: RGBA
    var primary: RGBA
    var secondary: RGBA
    var accent: RGBA
    var text: RGBA

    subscript(slot: ThemeColorSlot) -> RGBA {
        get {
            switch slot {
            case .background: return background
            case .surface: return surface
            case .primary: return primary
            case .secondary: return secondary
            case .accent: return accent
            case .text: return text
            }
        }
        set {
            switch slot {
            case .background: background = newValue
            case .surface: surface = newValue
            case .primary: primary = newValue
            case .secondary: secondary = newValue
            case .accent: accent = newValue
            case .text: text = newValue
            }
        }
    }
}

struct ThemeTypography: Codable, Hashable {
    var title: TextStyle
    var heading: TextStyle
    var body: TextStyle
    var caption: TextStyle

    subscript(kind: TextStyleKind) -> TextStyle {
        get {
            switch kind {
            case .title: return title
            case .heading: return heading
            case .body: return body
            case .caption: return caption
            }
        }
        set {
            switch kind {
            case .title: title = newValue
            case .heading: heading = newValue
            case .body: body = newValue
            case .caption: caption = newValue
            }
        }
    }
}

struct Theme: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var palette: ThemePalette
    var typography: ThemeTypography
    var background: Fill = .solid(.theme(.background))
    var transition = TransitionModel()
    var swatches: [RGBA] = []
    var shapeCornerRadius: Double = 24

    func rgba(_ ref: ColorRef) -> RGBA {
        switch ref {
        case .theme(let slot): return palette[slot]
        case .custom(let c): return c
        }
    }

    func color(_ ref: ColorRef) -> Color { rgba(ref).color }

    /// Best-effort solid colour for a fill (used for contrast checks).
    func approximateColor(_ fill: Fill) -> RGBA? {
        switch fill {
        case .none: return nil
        case .solid(let c): return rgba(c)
        case .gradient(let g): return g.stops.first.map { rgba($0.color) }
        case .image: return nil
        }
    }
}

// MARK: - Built-in themes

extension Theme {
    private static func make(
        _ name: String,
        bg: String, surface: String, primary: String, secondary: String, accent: String, text: String,
        titleFont: String = FontCatalog.system, bodyFont: String = FontCatalog.system,
        titleWeight: FontWeightOption = .bold,
        background: Fill? = nil,
        transition: TransitionKind = .fade
    ) -> Theme {
        let palette = ThemePalette(
            background: RGBA(hex: bg), surface: RGBA(hex: surface), primary: RGBA(hex: primary),
            secondary: RGBA(hex: secondary), accent: RGBA(hex: accent), text: RGBA(hex: text))
        let typography = ThemeTypography(
            title: TextStyle(fontName: titleFont, size: 120, weight: titleWeight, letterSpacing: -1),
            heading: TextStyle(fontName: titleFont, size: 72, weight: titleWeight),
            body: TextStyle(fontName: bodyFont, size: 44, weight: .regular, lineSpacing: 10),
            caption: TextStyle(fontName: bodyFont, size: 30, weight: .medium, color: .theme(.secondary)))
        var t = Theme(name: name, palette: palette, typography: typography)
        if let background { t.background = background }
        t.transition.kind = transition
        return t
    }

    static let builtIn: [Theme] = [
        make("Minimal", bg: "#FFFFFF", surface: "#F2F2F5", primary: "#1C1C1E", secondary: "#8E8E93", accent: "#0A84FF", text: "#1C1C1E"),
        make("Midnight", bg: "#0B0D17", surface: "#1A1D2E", primary: "#7C83FD", secondary: "#9BA3C7", accent: "#FF6B9A", text: "#F5F6FA",
             background: .gradient(GradientFill(kind: .linear, stops: [
                GradientStop(color: .custom(RGBA(hex: "#0B0D17")), location: 0),
                GradientStop(color: .custom(RGBA(hex: "#1B1F3B")), location: 1)], angle: 120))),
        make("Ocean", bg: "#E8F4F8", surface: "#FFFFFF", primary: "#006D77", secondary: "#5C8A92", accent: "#E29578", text: "#0B3C49",
             titleFont: FontCatalog.systemRounded, bodyFont: FontCatalog.systemRounded),
        make("Sunset", bg: "#FFF4EC", surface: "#FFE3D3", primary: "#E85D04", secondary: "#9C6644", accent: "#D00000", text: "#370617",
             background: .gradient(GradientFill(kind: .linear, stops: [
                GradientStop(color: .custom(RGBA(hex: "#FFF4EC")), location: 0),
                GradientStop(color: .custom(RGBA(hex: "#FFD6BA")), location: 1)], angle: 90)),
             transition: .push),
        make("Forest", bg: "#1E2A22", surface: "#2C3B31", primary: "#A3C9A8", secondary: "#84A98C", accent: "#F2CC8F", text: "#EEF2EC",
             titleFont: FontCatalog.systemSerif),
        make("Paper", bg: "#FAF7F0", surface: "#EFE9DD", primary: "#2B2A28", secondary: "#7A746A", accent: "#B5482E", text: "#2B2A28",
             titleFont: "Georgia", bodyFont: FontCatalog.systemSerif, titleWeight: .regular),
        make("Mono", bg: "#111111", surface: "#222222", primary: "#FFFFFF", secondary: "#9A9A9A", accent: "#FFD60A", text: "#FFFFFF",
             titleFont: FontCatalog.systemMono, bodyFont: FontCatalog.systemMono, titleWeight: .semibold, transition: .none),
        make("Candy", bg: "#FFF0F6", surface: "#FFFFFF", primary: "#D6336C", secondary: "#AE3EC9", accent: "#4C6EF5", text: "#2B1B2E",
             titleFont: FontCatalog.systemRounded, bodyFont: FontCatalog.systemRounded, titleWeight: .heavy,
             transition: .zoom),
    ]
}
