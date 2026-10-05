import SwiftUI

/// Which build-animated elements are currently revealed while presenting.
struct BuildState: Equatable {
    var revealed: Set<UUID> = []
    var delays: [UUID: Double] = [:]
    var reduceMotion = false
}

/// Renders a slide at its logical size (e.g. 1920×1080). Used everywhere:
/// canvas, thumbnails, presenter and export.
struct SlideRenderer: View {
    let slide: Slide
    let theme: Theme
    let size: CGSize
    var hiddenTextID: UUID? = nil
    var buildState: BuildState? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            FillView(fill: slide.background ?? theme.background, theme: theme)
                .frame(width: size.width, height: size.height)
            ForEach(slide.elements) { e in
                if !e.isHidden {
                    ElementView(element: e, theme: theme, hideText: e.id == hiddenTextID)
                        .modifier(BuildModifier(
                            build: e.build,
                            shown: isShown(e),
                            delay: buildState?.delays[e.id] ?? 0,
                            slideSize: size,
                            reduceMotion: buildState?.reduceMotion ?? false))
                        .rotationEffect(.degrees(e.rotation))
                        .position(x: e.frame.midX, y: e.frame.midY)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func isShown(_ e: SlideElement) -> Bool {
        guard let buildState, e.build.effect != .none, slide.buildOrder.contains(e.id) else { return true }
        return buildState.revealed.contains(e.id)
    }
}

/// Applies the hidden/visible appearance of a build-in effect.
struct BuildModifier: ViewModifier {
    let build: BuildModel
    let shown: Bool
    let delay: Double
    let slideSize: CGSize
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let effect = reduceMotion && build.effect != .none ? BuildEffect.fade : build.effect
        let hidden = !shown
        content
            .opacity(hidden ? 0 : 1)
            .offset(hidden && effect == .moveIn ? offset : .zero)
            .scaleEffect(hidden && [.scale, .pop, .spin].contains(effect) ? 0.3 : 1)
            .rotationEffect(.degrees(hidden && effect == .spin ? -180 : 0))
            .blur(radius: hidden && effect == .blur ? 40 : 0)
            .animation(animation(effect).delay(delay), value: shown)
    }

    private var offset: CGSize {
        let dx = slideSize.width * 0.25, dy = slideSize.height * 0.25
        switch build.direction {
        case .up: return CGSize(width: 0, height: dy)
        case .down: return CGSize(width: 0, height: -dy)
        case .left: return CGSize(width: dx, height: 0)
        case .right: return CGSize(width: -dx, height: 0)
        }
    }

    private func animation(_ effect: BuildEffect) -> Animation {
        switch effect {
        case .appear: return .linear(duration: 0.01)
        case .pop: return .spring(duration: build.duration, bounce: 0.45)
        case .none: return .linear(duration: 0)
        default: return .easeOut(duration: build.duration)
        }
    }
}

/// A slide scaled to fit the available space.
struct SlideThumbnail: View {
    let slide: Slide
    let theme: Theme
    let size: CGSize

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / size.width, geo.size.height / size.height)
            SlideRenderer(slide: slide, theme: theme, size: size)
                .scaleEffect(s, anchor: .topLeading)
                .frame(width: size.width * s, height: size.height * s, alignment: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(size, contentMode: .fit)
        .allowsHitTesting(false)
    }
}
