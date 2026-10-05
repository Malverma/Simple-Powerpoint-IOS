import SwiftUI
import UIKit

/// Draws one element at its logical size (no positioning).
struct ElementView: View {
    let element: SlideElement
    let theme: Theme
    var hideText = false

    var body: some View {
        content
            .frame(width: max(element.frame.width, 1), height: max(element.frame.height, 1))
            .scaleEffect(x: element.style.flipH ? -1 : 1, y: element.style.flipV ? -1 : 1)
            .compositingGroup()
            .shadow(color: element.style.shadow.enabled ? element.style.shadow.color.color : .clear,
                    radius: element.style.shadow.enabled ? element.style.shadow.radius / 2 : 0,
                    x: element.style.shadow.x, y: element.style.shadow.y)
            .blur(radius: element.style.blur)
            .opacity(element.style.opacity)
            .blendMode(element.style.blendMode.mode)
    }

    private var corner: Double { element.style.cornerRadius }

    private var containerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
    }

    private var strokeStyle: StrokeStyle {
        let s = element.style.stroke
        return StrokeStyle(lineWidth: s.width, lineCap: .round, lineJoin: .round, dash: s.dash.pattern(width: s.width))
    }

    @ViewBuilder
    private var content: some View {
        switch element.kind {
        case .text(let t):
            ZStack {
                FillView(fill: element.style.fill, theme: theme)
                    .clipShape(containerShape)
                if !hideText {
                    TextBody(content: t, theme: theme)
                }
            }
            .overlay {
                if element.style.stroke.width > 0 {
                    containerShape.stroke(theme.color(element.style.stroke.color), style: strokeStyle)
                }
            }

        case .shape(let s):
            let shape = s.shape(cornerRadius: corner)
            ZStack {
                if !s.isOpenPath {
                    FillView(fill: element.style.fill, theme: theme)
                        .clipShape(shape)
                }
                if element.style.stroke.width > 0 {
                    shape.stroke(theme.color(element.style.stroke.color), style: strokeStyle)
                }
                if !s.text.isEmpty && !hideText {
                    TextBody(content: shapeLabel(s.text), theme: theme)
                }
            }

        case .image(let img):
            ZStack {
                if let id = img.assetID, let ui = AssetStore.shared.image(id) {
                    GeometryReader { geo in
                        imageView(ui, mode: img.mode, size: geo.size)
                            .brightness(img.brightness)
                            .contrast(img.contrast)
                            .saturation(img.saturation)
                            .grayscale(img.grayscale ? 1 : 0)
                            .blur(radius: img.blur)
                    }
                } else {
                    ZStack {
                        theme.color(.theme(.surface))
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: min(element.frame.width, element.frame.height) * 0.18))
                            Text("Double-tap to add image")
                                .font(.system(size: max(min(element.frame.width, element.frame.height) * 0.05, 14)))
                        }
                        .foregroundStyle(theme.color(.theme(.secondary)))
                    }
                }
            }
            .clipShape(containerShape)
            .overlay {
                if element.style.stroke.width > 0 {
                    containerShape.stroke(theme.color(element.style.stroke.color), style: strokeStyle)
                }
            }
            .accessibilityLabel(img.altText)

        case .icon(let ic):
            ZStack {
                FillView(fill: element.style.fill, theme: theme).clipShape(containerShape)
                Image(systemName: ic.symbol)
                    .resizable()
                    .scaledToFit()
                    .fontWeight(ic.weight.weight)
                    .symbolRenderingMode(ic.rendering.mode)
                    .foregroundStyle(theme.color(ic.color))
                    .padding(min(element.frame.width, element.frame.height) * 0.08)
            }
            .overlay {
                if element.style.stroke.width > 0 {
                    containerShape.stroke(theme.color(element.style.stroke.color), style: strokeStyle)
                }
            }
        }
    }

    private func shapeLabel(_ text: String) -> TextContent {
        var t = TextContent(text: text, role: .body)
        t.alignment = .center
        t.verticalAlignment = .middle
        return t
    }

    @ViewBuilder
    private func imageView(_ ui: UIImage, mode: ImageFillMode, size: CGSize) -> some View {
        switch mode {
        case .fill:
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: size.width, height: size.height).clipped()
        case .fit:
            Image(uiImage: ui).resizable().scaledToFit()
                .frame(width: size.width, height: size.height)
        case .stretch:
            Image(uiImage: ui).resizable().frame(width: size.width, height: size.height)
        }
    }
}

extension SymbolRenderingOption {
    var mode: SymbolRenderingMode {
        switch self {
        case .monochrome: return .monochrome
        case .hierarchical: return .hierarchical
        case .multicolor: return .multicolor
        }
    }
}

/// Text content laid out inside its element frame.
struct TextBody: View {
    let content: TextContent
    let theme: Theme

    var body: some View {
        let style = content.resolved(in: theme)
        Text(content.displayText)
            .font(FontCatalog.font(name: style.fontName, size: style.size, weight: style.weight, italic: content.italic))
            .underline(content.underline)
            .strikethrough(content.strikethrough)
            .kerning(style.letterSpacing)
            .lineSpacing(style.lineSpacing)
            .multilineTextAlignment(content.alignment.textAlignment)
            .foregroundStyle(foreground(style))
            .minimumScaleFactor(content.autoShrink ? 0.1 : 1)
            .padding(content.padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: Alignment(horizontal: content.alignment.horizontal, vertical: content.verticalAlignment.vertical))
    }

    private func foreground(_ style: TextStyle) -> AnyShapeStyle {
        if let g = content.gradient { return g.shapeStyle(theme) }
        return AnyShapeStyle(theme.color(style.color))
    }
}
