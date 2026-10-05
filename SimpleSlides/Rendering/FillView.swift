import SwiftUI
import UIKit

extension GradientFill {
    func swiftUIStops(_ theme: Theme) -> [Gradient.Stop] {
        stops.sorted { $0.location < $1.location }
            .map { Gradient.Stop(color: theme.color($0.color), location: $0.location) }
    }

    var unitPoints: (UnitPoint, UnitPoint) {
        let rad = angle * .pi / 180
        let dx = cos(rad) / 2, dy = sin(rad) / 2
        return (UnitPoint(x: 0.5 - dx, y: 0.5 - dy), UnitPoint(x: 0.5 + dx, y: 0.5 + dy))
    }

    func shapeStyle(_ theme: Theme) -> AnyShapeStyle {
        let gradient = Gradient(stops: swiftUIStops(theme))
        switch kind {
        case .linear:
            let (s, e) = unitPoints
            return AnyShapeStyle(LinearGradient(gradient: gradient, startPoint: s, endPoint: e))
        case .radial:
            return AnyShapeStyle(EllipticalGradient(gradient: gradient, center: .center))
        case .angular:
            return AnyShapeStyle(AngularGradient(gradient: gradient, center: .center, angle: .degrees(angle)))
        }
    }
}

/// Renders a `Fill` to fill its frame.
struct FillView: View {
    let fill: Fill
    let theme: Theme

    var body: some View {
        switch fill {
        case .none:
            Color.clear
        case .solid(let c):
            Rectangle().fill(theme.color(c))
        case .gradient(let g):
            Rectangle().fill(g.shapeStyle(theme))
        case .image(let img):
            ImageFillView(fill: img, theme: theme)
        }
    }
}

struct ImageFillView: View {
    let fill: ImageFill
    let theme: Theme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let ui = AssetStore.shared.image(fill.assetID) {
                    switch fill.mode {
                    case .fill:
                        Image(uiImage: ui).resizable().scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height).clipped()
                    case .fit:
                        Image(uiImage: ui).resizable().scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                    case .stretch:
                        Image(uiImage: ui).resizable()
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                } else {
                    Color.gray.opacity(0.2)
                }
                if let tint = fill.tint {
                    theme.color(tint).opacity(fill.tintOpacity)
                }
            }
            .blur(radius: fill.blur, opaque: true)
            .clipped()
        }
    }
}
