import SwiftUI
import UIKit

// MARK: - Color

struct RGBA: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double = 1

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(hex: String, alpha: Double = 1) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        r = Double((value >> 16) & 0xFF) / 255
        g = Double((value >> 8) & 0xFF) / 255
        b = Double(value & 0xFF) / 255
        a = alpha
    }

    init(_ color: Color) {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.r = Double(r); self.g = Double(g); self.b = Double(b); self.a = Double(a)
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    var hex: String {
        func c(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }

    /// WCAG relative luminance.
    var luminance: Double {
        func ch(_ v: Double) -> Double {
            let v = min(max(v, 0), 1)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)
    }

    static func contrast(_ a: RGBA, _ b: RGBA) -> Double {
        let l1 = max(a.luminance, b.luminance), l2 = min(a.luminance, b.luminance)
        return (l1 + 0.05) / (l2 + 0.05)
    }

    static let white = RGBA(r: 1, g: 1, b: 1)
    static let black = RGBA(r: 0, g: 0, b: 0)
    static let clear = RGBA(r: 0, g: 0, b: 0, a: 0)
}

enum ThemeColorSlot: String, Codable, CaseIterable, Identifiable {
    case background, surface, primary, secondary, accent, text
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ColorRef: Codable, Hashable {
    case theme(ThemeColorSlot)
    case custom(RGBA)
}

// MARK: - Fill

enum GradientKind: String, Codable, CaseIterable, Identifiable {
    case linear, radial, angular
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct GradientStop: Codable, Hashable, Identifiable {
    var id = UUID()
    var color: ColorRef
    var location: Double
}

struct GradientFill: Codable, Hashable {
    var kind: GradientKind = .linear
    var stops: [GradientStop]
    var angle: Double = 90

    static func between(_ a: ColorRef, _ b: ColorRef) -> GradientFill {
        GradientFill(stops: [GradientStop(color: a, location: 0), GradientStop(color: b, location: 1)])
    }
}

enum ImageFillMode: String, Codable, CaseIterable, Identifiable {
    case fill, fit, stretch
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct ImageFill: Codable, Hashable {
    var assetID: UUID
    var mode: ImageFillMode = .fill
    var blur: Double = 0
    var tint: ColorRef? = nil
    var tintOpacity: Double = 0.35
}

enum Fill: Codable, Hashable {
    case none
    case solid(ColorRef)
    case gradient(GradientFill)
    case image(ImageFill)

    enum Kind: String, CaseIterable, Identifiable {
        case none, solid, gradient, image
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    var kind: Kind {
        switch self {
        case .none: return .none
        case .solid: return .solid
        case .gradient: return .gradient
        case .image: return .image
        }
    }
}

// MARK: - Typography

enum FontWeightOption: String, Codable, CaseIterable, Identifiable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ultraLight: return "Ultra Light"
        default: return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
    var weight: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}

enum TextStyleKind: String, Codable, CaseIterable, Identifiable {
    case title, heading, body, caption
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct TextStyle: Codable, Hashable {
    var fontName: String = FontCatalog.system
    var size: Double
    var weight: FontWeightOption = .regular
    var color: ColorRef = .theme(.text)
    var lineSpacing: Double = 0
    var letterSpacing: Double = 0
}

enum TextAlign: String, Codable, CaseIterable, Identifiable {
    case leading, center, trailing
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .leading: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .trailing: return "text.alignright"
        }
    }
    var textAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

enum VerticalAlign: String, Codable, CaseIterable, Identifiable {
    case top, middle, bottom
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .top: return "arrow.up.to.line"
        case .middle: return "arrow.up.and.down"
        case .bottom: return "arrow.down.to.line"
        }
    }
    var vertical: VerticalAlignment {
        switch self {
        case .top: return .top
        case .middle: return .center
        case .bottom: return .bottom
        }
    }
}

enum TextCaseOption: String, Codable, CaseIterable, Identifiable {
    case none, upper, lower
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "Aa"
        case .upper: return "AA"
        case .lower: return "aa"
        }
    }
}

enum ListStyleOption: String, Codable, CaseIterable, Identifiable {
    case none, bullet, dash, numbered
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .none: return "text.justify.left"
        case .bullet: return "list.bullet"
        case .dash: return "list.dash"
        case .numbered: return "list.number"
        }
    }
}

struct TextContent: Codable, Hashable {
    var text: String = ""
    var role: TextStyleKind = .body
    // Overrides — nil means "use the theme's style for `role`".
    var fontName: String? = nil
    var size: Double? = nil
    var weight: FontWeightOption? = nil
    var color: ColorRef? = nil
    var lineSpacing: Double? = nil
    var letterSpacing: Double? = nil
    var gradient: GradientFill? = nil

    var italic = false
    var underline = false
    var strikethrough = false
    var alignment: TextAlign = .leading
    var verticalAlignment: VerticalAlign = .top
    var textCase: TextCaseOption = .none
    var listStyle: ListStyleOption = .none
    var padding: Double = 12
    var autoShrink = true

    func resolved(in theme: Theme) -> TextStyle {
        var s = theme.typography[role]
        if let fontName { s.fontName = fontName }
        if let size { s.size = size }
        if let weight { s.weight = weight }
        if let color { s.color = color }
        if let lineSpacing { s.lineSpacing = lineSpacing }
        if let letterSpacing { s.letterSpacing = letterSpacing }
        return s
    }

    var hasOverrides: Bool {
        fontName != nil || size != nil || weight != nil || color != nil
            || lineSpacing != nil || letterSpacing != nil || gradient != nil
    }

    mutating func clearOverrides() {
        fontName = nil; size = nil; weight = nil; color = nil
        lineSpacing = nil; letterSpacing = nil; gradient = nil
    }

    var displayText: String {
        var t = text
        switch textCase {
        case .none: break
        case .upper: t = t.uppercased()
        case .lower: t = t.lowercased()
        }
        guard listStyle != .none else { return t }
        var n = 0
        return t.components(separatedBy: "\n").map { line in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return line }
            n += 1
            switch listStyle {
            case .bullet: return "•  " + line
            case .dash: return "–  " + line
            case .numbered: return "\(n).  " + line
            case .none: return line
            }
        }.joined(separator: "\n")
    }
}

// MARK: - Shapes, images, icons

enum ShapeKind: String, Codable, CaseIterable, Identifiable {
    case rectangle, ellipse, triangle, diamond, star, polygon, arrow, line
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .triangle: return "triangle"
        case .diamond: return "diamond"
        case .star: return "star"
        case .polygon: return "hexagon"
        case .arrow: return "arrow.right"
        case .line: return "line.diagonal"
        }
    }
}

struct ShapeContent: Codable, Hashable {
    var kind: ShapeKind = .rectangle
    var points: Int = 5          // star points / polygon sides
    var innerRatio: Double = 0.45 // star inner radius
    var text: String = ""
}

struct ImageContent: Codable, Hashable {
    var assetID: UUID? = nil
    var mode: ImageFillMode = .fill
    var brightness: Double = 0
    var contrast: Double = 1
    var saturation: Double = 1
    var blur: Double = 0
    var grayscale = false
    var altText: String = ""
}

enum SymbolRenderingOption: String, Codable, CaseIterable, Identifiable {
    case monochrome, hierarchical, multicolor
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct IconContent: Codable, Hashable {
    var symbol: String = "star.fill"
    var color: ColorRef = .theme(.accent)
    var weight: FontWeightOption = .regular
    var rendering: SymbolRenderingOption = .monochrome
}

enum ElementKind: Codable, Hashable {
    case text(TextContent)
    case shape(ShapeContent)
    case image(ImageContent)
    case icon(IconContent)

    var title: String {
        switch self {
        case .text: return "Text"
        case .shape(let s): return s.kind.title
        case .image: return "Image"
        case .icon: return "Icon"
        }
    }

    var icon: String {
        switch self {
        case .text: return "textformat"
        case .shape(let s): return s.kind.icon
        case .image: return "photo"
        case .icon: return "star.square"
        }
    }
}

// MARK: - Style

enum DashStyle: String, Codable, CaseIterable, Identifiable {
    case solid, dashed, dotted
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    func pattern(width: Double) -> [CGFloat] {
        switch self {
        case .solid: return []
        case .dashed: return [CGFloat(width * 3), CGFloat(width * 2)]
        case .dotted: return [0.1, CGFloat(width * 2)]
        }
    }
}

struct StrokeModel: Codable, Hashable {
    var color: ColorRef = .theme(.text)
    var width: Double = 0
    var dash: DashStyle = .solid
}

struct ShadowModel: Codable, Hashable {
    var enabled = false
    var color: RGBA = RGBA(r: 0, g: 0, b: 0, a: 0.35)
    var radius: Double = 24
    var x: Double = 0
    var y: Double = 12
}

enum BlendModeOption: String, Codable, CaseIterable, Identifiable {
    case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight, difference, exclusion
    var id: String { rawValue }
    var title: String {
        switch self {
        case .colorDodge: return "Color Dodge"
        case .colorBurn: return "Color Burn"
        case .softLight: return "Soft Light"
        case .hardLight: return "Hard Light"
        default: return rawValue.capitalized
        }
    }
    var mode: BlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .darken: return .darken
        case .lighten: return .lighten
        case .colorDodge: return .colorDodge
        case .colorBurn: return .colorBurn
        case .softLight: return .softLight
        case .hardLight: return .hardLight
        case .difference: return .difference
        case .exclusion: return .exclusion
        }
    }
}

struct ElementStyle: Codable, Hashable {
    var fill: Fill = .none
    var stroke = StrokeModel()
    var cornerRadius: Double = 0
    var opacity: Double = 1
    var shadow = ShadowModel()
    var blendMode: BlendModeOption = .normal
    var blur: Double = 0
    var flipH = false
    var flipV = false
}

// MARK: - Animation

enum BuildEffect: String, Codable, CaseIterable, Identifiable {
    case none, appear, fade, moveIn, scale, pop, blur, spin
    var id: String { rawValue }
    var title: String {
        switch self {
        case .moveIn: return "Move In"
        default: return rawValue.capitalized
        }
    }
}

enum BuildTrigger: String, Codable, CaseIterable, Identifiable {
    case onTap, withPrevious, afterPrevious
    var id: String { rawValue }
    var title: String {
        switch self {
        case .onTap: return "On Tap"
        case .withPrevious: return "With Previous"
        case .afterPrevious: return "After Previous"
        }
    }
}

enum MoveDirection: String, Codable, CaseIterable, Identifiable {
    case left, right, up, down
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var reversed: MoveDirection {
        switch self {
        case .left: return .right
        case .right: return .left
        case .up: return .down
        case .down: return .up
        }
    }
}

struct BuildModel: Codable, Hashable {
    var effect: BuildEffect = .none
    var trigger: BuildTrigger = .onTap
    var direction: MoveDirection = .up
    var duration: Double = 0.5
    var delay: Double = 0
}

enum TransitionKind: String, Codable, CaseIterable, Identifiable {
    case none, fade, push, slide, zoom, flip, blur
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum EasingOption: String, Codable, CaseIterable, Identifiable {
    case easeInOut, easeOut, linear, spring
    var id: String { rawValue }
    var title: String {
        switch self {
        case .easeInOut: return "Ease In Out"
        case .easeOut: return "Ease Out"
        case .linear: return "Linear"
        case .spring: return "Spring"
        }
    }
    func animation(duration: Double) -> Animation {
        switch self {
        case .easeInOut: return .easeInOut(duration: duration)
        case .easeOut: return .easeOut(duration: duration)
        case .linear: return .linear(duration: duration)
        case .spring: return .spring(duration: duration, bounce: 0.3)
        }
    }
}

struct TransitionModel: Codable, Hashable {
    var kind: TransitionKind = .fade
    var direction: MoveDirection = .left
    var duration: Double = 0.5
    var easing: EasingOption = .easeInOut
}

// MARK: - Element / Slide / Deck

struct SlideElement: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String = ""
    var kind: ElementKind
    var frame: CGRect
    var rotation: Double = 0
    var style = ElementStyle()
    var build = BuildModel()
    var isLocked = false
    var isHidden = false

    var displayName: String {
        if !name.isEmpty { return name }
        if case .text(let t) = kind, !t.text.isEmpty {
            return String(t.text.prefix(24)).replacingOccurrences(of: "\n", with: " ")
        }
        return kind.title
    }

    var isText: Bool { if case .text = kind { return true } else { return false } }
    var isShape: Bool { if case .shape = kind { return true } else { return false } }
    var isImage: Bool { if case .image = kind { return true } else { return false } }
    var isIcon: Bool { if case .icon = kind { return true } else { return false } }

    var textContent: TextContent {
        get { if case .text(let t) = kind { return t } else { return TextContent() } }
        set { kind = .text(newValue) }
    }
    var shapeContent: ShapeContent {
        get { if case .shape(let s) = kind { return s } else { return ShapeContent() } }
        set { kind = .shape(newValue) }
    }
    var imageContent: ImageContent {
        get { if case .image(let i) = kind { return i } else { return ImageContent() } }
        set { kind = .image(newValue) }
    }
    var iconContent: IconContent {
        get { if case .icon(let i) = kind { return i } else { return IconContent() } }
        set { kind = .icon(newValue) }
    }

    /// A duplicate with a fresh identity.
    func copy(offset: CGFloat = 0) -> SlideElement {
        var e = self
        e.id = UUID()
        e.frame = frame.offsetBy(dx: offset, dy: offset)
        return e
    }
}

enum SlideLayout: String, Codable, CaseIterable, Identifiable {
    case title, titleBody, twoColumn, section, quote, imageFull, imageCaption, blank
    var id: String { rawValue }
    var title: String {
        switch self {
        case .title: return "Title"
        case .titleBody: return "Title & Body"
        case .twoColumn: return "Two Column"
        case .section: return "Section"
        case .quote: return "Quote"
        case .imageFull: return "Full Image"
        case .imageCaption: return "Image & Caption"
        case .blank: return "Blank"
        }
    }
}

struct Slide: Codable, Equatable, Identifiable {
    var id = UUID()
    var layout: SlideLayout = .blank
    var background: Fill? = nil          // nil → theme background
    var transition: TransitionModel? = nil // nil → theme default
    var notes: String = ""
    var isSkipped = false
    var autoAdvance: Double? = nil
    var elements: [SlideElement] = []
    var buildOrder: [UUID] = []

    func element(_ id: UUID) -> SlideElement? { elements.first { $0.id == id } }

    /// Builds that currently refer to existing, animated elements.
    var activeBuilds: [SlideElement] {
        buildOrder.compactMap { id in elements.first { $0.id == id && $0.build.effect != .none } }
    }

    mutating func syncBuildOrder() {
        let animated = Set(elements.filter { $0.build.effect != .none }.map(\.id))
        buildOrder.removeAll { !animated.contains($0) }
        for e in elements where animated.contains(e.id) && !buildOrder.contains(e.id) {
            buildOrder.append(e.id)
        }
    }
}

enum AspectRatio: String, Codable, CaseIterable, Identifiable {
    case wide, standard, square, story
    var id: String { rawValue }
    var title: String {
        switch self {
        case .wide: return "16:9"
        case .standard: return "4:3"
        case .square: return "1:1"
        case .story: return "9:16"
        }
    }
    var size: CGSize {
        switch self {
        case .wide: return CGSize(width: 1920, height: 1080)
        case .standard: return CGSize(width: 1440, height: 1080)
        case .square: return CGSize(width: 1080, height: 1080)
        case .story: return CGSize(width: 1080, height: 1920)
        }
    }
}

struct Deck: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String = "Untitled"
    var createdAt = Date()
    var updatedAt = Date()
    var aspect: AspectRatio = .wide
    var theme: Theme = Theme.builtIn[0]
    var slides: [Slide] = []
    var loopPresentation = false

    var size: CGSize { aspect.size }

    func slideIndex(_ id: UUID) -> Int? { slides.firstIndex { $0.id == id } }

    /// Every asset referenced anywhere in the deck.
    var assetIDs: Set<UUID> {
        var ids = Set<UUID>()
        func add(_ fill: Fill?) { if case .image(let i)? = fill { ids.insert(i.assetID) } }
        add(theme.background)
        for s in slides {
            add(s.background)
            for e in s.elements {
                add(e.style.fill)
                if case .image(let i) = e.kind, let a = i.assetID { ids.insert(a) }
            }
        }
        return ids
    }
}
