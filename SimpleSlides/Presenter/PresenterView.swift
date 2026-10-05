import SwiftUI
import UIKit

/// Full-screen presentation with slide transitions, element builds, notes and a timer.
struct PresenterView: View {
    let deck: Deck
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var slides: [Slide] = []
    @State private var index = 0
    @State private var step = 0
    @State private var forward = true
    @State private var activeTransition: TransitionModel?
    @State private var showControls = true
    @State private var showNotes = false
    @State private var startDate = Date()
    @State private var autoTask: Task<Void, Never>?
    @State private var laser: CGPoint?
    @State private var hideTask: Task<Void, Never>?

    init(deck: Deck, startIndex: Int) {
        self.deck = deck
        self.startIndex = startIndex
    }

    private var slide: Slide? { slides.indices.contains(index) ? slides[index] : nil }

    /// Groups of builds; each group starts with an "On Tap" build.
    private func buildGroups(_ slide: Slide) -> [[SlideElement]] {
        var groups: [[SlideElement]] = []
        for e in slide.activeBuilds {
            if e.build.trigger == .onTap || groups.isEmpty {
                groups.append([e])
            } else {
                groups[groups.count - 1].append(e)
            }
        }
        return groups
    }

    private func buildState(for slide: Slide, step: Int) -> BuildState {
        var state = BuildState(reduceMotion: reduceMotion)
        let groups = buildGroups(slide)
        for (gi, group) in groups.enumerated() where gi < step {
            var t: Double = 0
            for (i, e) in group.enumerated() {
                if i > 0 && e.build.trigger == .afterPrevious {
                    t += group[i - 1].build.duration
                }
                state.revealed.insert(e.id)
                // Only the most recent group animates with delays.
                state.delays[e.id] = gi == step - 1 ? t + e.build.delay : 0
            }
        }
        return state
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let slide {
                    let size = deck.size
                    let s = min(geo.size.width / size.width, geo.size.height / size.height)
                    SlideRenderer(slide: slide, theme: deck.theme, size: size,
                                  buildState: buildState(for: slide, step: step))
                        .scaleEffect(s)
                        .frame(width: size.width * s, height: size.height * s)
                        .id(slide.id)
                        .transition(transition(for: slide))
                        .overlay {
                            if let laser {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 18, height: 18)
                                    .shadow(color: .red, radius: 10)
                                    .position(laser)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                HStack(spacing: 0) {
                    Color.clear.contentShape(Rectangle())
                        .frame(width: geo.size.width * 0.3)
                        .onTapGesture { back() }
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { advance() }
                }
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { v in
                            if v.translation.width < -40 { advance() }
                            else if v.translation.width > 40 { back() }
                            else if v.translation.height > 80 { dismiss() }
                        }
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.35)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onChanged { value in
                            if case .second(true, let drag?) = value {
                                laser = drag.location
                            }
                        }
                        .onEnded { _ in laser = nil }
                )

                if showControls { controls }
                if showNotes, let slide { notesPanel(slide) }
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            slides = deck.slides.filter { !$0.isSkipped }
            if slides.isEmpty { slides = deck.slides }
            let target = deck.slides.indices.contains(startIndex) ? deck.slides[startIndex].id : nil
            index = slides.firstIndex { $0.id == target } ?? 0
            startDate = Date()
            UIApplication.shared.isIdleTimerDisabled = true
            scheduleHide()
            scheduleAuto()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            autoTask?.cancel()
            hideTask?.cancel()
        }
    }

    // MARK: Navigation

    private func advance() {
        guard let slide else { return }
        revealControls()
        if step < buildGroups(slide).count {
            step += 1
            scheduleAuto()
        } else if index < slides.count - 1 {
            go(to: index + 1, forward: true)
        } else if deck.loopPresentation {
            go(to: 0, forward: true)
        } else {
            dismiss()
        }
    }

    private func back() {
        revealControls()
        if step > 0 {
            step -= 1
        } else if index > 0 {
            go(to: index - 1, forward: false, revealAll: true)
        }
    }

    private func go(to newIndex: Int, forward: Bool, revealAll: Bool = false) {
        let target = slides[newIndex]
        let t = target.transition ?? deck.theme.transition
        self.forward = forward
        activeTransition = t
        // Let the transition direction settle before the change animates.
        DispatchQueue.main.async {
            withAnimation(t.kind == .none ? nil : t.easing.animation(duration: t.duration)) {
                index = newIndex
                step = revealAll ? buildGroups(target).count : 0
            }
            scheduleAuto()
        }
    }

    private func scheduleAuto() {
        autoTask?.cancel()
        guard let slide, let secs = slide.autoAdvance else { return }
        autoTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(secs))
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    // MARK: Transitions

    private func transition(for slide: Slide) -> AnyTransition {
        let t = activeTransition ?? slide.transition ?? deck.theme.transition
        if reduceMotion && t.kind != .none { return .opacity }
        let dir = forward ? t.direction : t.direction.reversed
        switch t.kind {
        case .none: return .identity
        case .fade: return .opacity
        case .push:
            return .asymmetric(insertion: .move(edge: dir.incomingEdge), removal: .move(edge: dir.outgoingEdge))
        case .slide:
            return .asymmetric(insertion: .move(edge: dir.incomingEdge), removal: .opacity)
        case .zoom:
            return .asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity),
                               removal: .scale(scale: 1.3).combined(with: .opacity))
        case .flip:
            return .asymmetric(insertion: .modifier(active: FlipModifier(angle: dir == .left || dir == .up ? -90 : 90), identity: FlipModifier(angle: 0)),
                               removal: .modifier(active: FlipModifier(angle: dir == .left || dir == .up ? 90 : -90), identity: FlipModifier(angle: 0)))
        case .blur:
            return .modifier(active: BlurFadeModifier(amount: 1), identity: BlurFadeModifier(amount: 0))
        }
    }

    // MARK: Chrome

    private func revealControls() {
        if !showControls { withAnimation { showControls = true } }
        scheduleHide()
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, !showNotes else { return }
            withAnimation { showControls = false }
        }
    }

    private var controls: some View {
        VStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("End Presentation")
                Spacer()
                TimelineView(.periodic(from: startDate, by: 1)) { ctx in
                    let secs = Int(ctx.date.timeIntervalSince(startDate))
                    Text(String(format: "%d:%02d", secs / 60, secs % 60))
                        .font(.subheadline.monospacedDigit())
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                Spacer()
                Button { withAnimation { showNotes.toggle() } } label: {
                    Image(systemName: showNotes ? "note.text.badge.plus" : "note.text")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Speaker Notes")
            }
            Spacer()
            HStack(spacing: 24) {
                Button { back() } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous")
                Text("\(index + 1) / \(slides.count)")
                    .font(.subheadline.monospacedDigit())
                Button { advance() } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Next")
            }
            .font(.headline)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .foregroundStyle(.white)
        .padding()
        .environment(\.colorScheme, .dark)
        .transition(.opacity)
    }

    private func notesPanel(_ slide: Slide) -> some View {
        VStack {
            Spacer()
            ScrollView {
                Text(slide.notes.isEmpty ? "No notes for this slide." : slide.notes)
                    .font(.body)
                    .foregroundStyle(slide.notes.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxHeight: 200)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.bottom, 70)
        }
        .environment(\.colorScheme, .dark)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

extension MoveDirection {
    /// Edge the incoming slide enters from when content moves in this direction.
    var incomingEdge: Edge {
        switch self {
        case .left: return .trailing
        case .right: return .leading
        case .up: return .bottom
        case .down: return .top
        }
    }

    var outgoingEdge: Edge {
        switch self {
        case .left: return .leading
        case .right: return .trailing
        case .up: return .top
        case .down: return .bottom
        }
    }
}

struct FlipModifier: ViewModifier {
    let angle: Double
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .opacity(abs(angle) >= 90 ? 0 : 1)
    }
}

struct BlurFadeModifier: ViewModifier {
    let amount: Double
    func body(content: Content) -> some View {
        content.blur(radius: 40 * amount).opacity(1 - amount)
    }
}
