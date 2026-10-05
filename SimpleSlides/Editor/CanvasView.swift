import SwiftUI

/// The interactive slide editor surface: selection, move, resize, rotate, snap and inline text editing.
struct CanvasView: View {
    @Bindable var model: EditorModel
    var onRequestImage: (UUID) -> Void

    @AppStorage("snapping") private var snapping = true
    @AppStorage("showGrid") private var showGrid = false
    @AppStorage("gridSize") private var gridSize = 60.0

    @State private var dragStart: CGRect?
    @State private var guides: [Guide] = []
    @State private var rotating = false
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    private let space = "canvas"

    var body: some View {
        GeometryReader { geo in
            let size = model.slideSize
            let pad: CGFloat = 24
            let fit = min((geo.size.width - pad * 2) / size.width, (geo.size.height - pad * 2) / size.height)
            let s = max(fit * zoom * pinch, 0.01)
            let canvas = CGSize(width: size.width * s, height: size.height * s)

            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                slideSurface(scale: s, canvas: canvas)
                    .frame(width: max(canvas.width + pad * 2, geo.size.width),
                           height: max(canvas.height + pad * 2, geo.size.height))
                    .background {
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { deselect() }
                    }
            }
            .scrollDisabled(zoom <= 1.001)
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($pinch) { v, state, _ in state = v.magnification }
                    .onEnded { v in
                        zoom = min(max(zoom * v.magnification, 1), 4)
                        if zoom < 1.08 { zoom = 1 }
                    }
            )
        }
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .bottomTrailing) {
            if zoom > 1 {
                Button {
                    withAnimation(.snappy) { zoom = 1 }
                } label: {
                    Text("\(Int(zoom * 100))%")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(12)
            }
        }
    }

    // MARK: Surface

    @ViewBuilder
    private func slideSurface(scale s: CGFloat, canvas: CGSize) -> some View {
        let slide = model.currentSlide
        ZStack(alignment: .topLeading) {
            SlideRenderer(slide: slide, theme: model.theme, size: model.slideSize, hiddenTextID: model.editingTextID)
                .scaleEffect(s, anchor: .topLeading)
                .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
                .allowsHitTesting(false)

            Color.clear.contentShape(Rectangle())
                .frame(width: canvas.width, height: canvas.height)
                .onTapGesture { deselect() }

            if showGrid {
                GridOverlay(spacing: gridSize * s, size: canvas)
                    .allowsHitTesting(false)
            }

            ForEach(slide.elements.filter { !$0.isHidden }) { e in
                hitTarget(e, scale: s)
            }

            ForEach(guides, id: \.self) { g in
                Rectangle()
                    .fill(Color.pink)
                    .frame(width: g.vertical ? 1 : canvas.width, height: g.vertical ? canvas.height : 1)
                    .position(x: g.vertical ? g.position * s : canvas.width / 2,
                              y: g.vertical ? canvas.height / 2 : g.position * s)
                    .allowsHitTesting(false)
            }

            if let sel = model.selectedElement, model.editingTextID != sel.id {
                selectionOverlay(sel, scale: s)
            }

            if let id = model.editingTextID, let e = slide.element(id) {
                TextEditingOverlay(model: model, element: e, scale: s)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .coordinateSpace(name: space)
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }

    private func deselect() {
        endEditing()
        model.selectedElementID = nil
    }

    private func endEditing() {
        guard let id = model.editingTextID else { return }
        model.editingTextID = nil
        if let e = model.currentSlide.element(id), e.isText,
           e.textContent.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model.selectedElementID = id
            model.deleteSelected()
        }
    }

    // MARK: Hit targets

    private func hitTarget(_ e: SlideElement, scale s: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.001))
            .frame(width: max(e.frame.width * s, 24), height: max(e.frame.height * s, 24))
            .rotationEffect(.degrees(e.rotation))
            .position(x: e.frame.midX * s, y: e.frame.midY * s)
            .onTapGesture(count: 2) { doubleTap(e) }
            .onTapGesture {
                if model.editingTextID != e.id { endEditing() }
                model.selectedElementID = e.id
            }
            .gesture(moveGesture(e, scale: s))
            .accessibilityElement()
            .accessibilityLabel("\(e.displayName), \(e.kind.title)")
            .accessibilityAddTraits(model.selectedElementID == e.id ? [.isSelected, .isButton] : .isButton)
            .accessibilityAction { model.selectedElementID = e.id }
    }

    private func doubleTap(_ e: SlideElement) {
        guard !e.isLocked else { return }
        model.selectedElementID = e.id
        switch e.kind {
        case .text:
            model.editingTextID = e.id
        case .image:
            onRequestImage(e.id)
        case .shape, .icon:
            break
        }
    }

    private func moveGesture(_ e: SlideElement, scale s: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(space))
            .onChanged { v in
                guard !e.isLocked, model.editingTextID != e.id else { return }
                if dragStart == nil {
                    endEditing()
                    model.selectedElementID = e.id
                    model.beginInteraction()
                    dragStart = model.currentSlide.element(e.id)?.frame ?? e.frame
                }
                guard let start = dragStart else { return }
                var f = start.offsetBy(dx: v.translation.width / s, dy: v.translation.height / s)
                if snapping {
                    let others = model.currentSlide.elements
                        .filter { $0.id != e.id && !$0.isHidden }
                        .map(\.frame)
                    let (snapped, g) = Snapper.snap(f, others: others, bounds: model.slideSize,
                                                    threshold: 8 / s, grid: showGrid ? gridSize : nil)
                    if Set(g) != Set(guides), !g.isEmpty { Haptics.tick() }
                    f = snapped
                    guides = g
                }
                model.setFrame(e.id, f)
            }
            .onEnded { _ in
                if dragStart != nil { model.endInteraction() }
                dragStart = nil
                guides = []
            }
    }

    // MARK: Selection handles

    private func selectionOverlay(_ e: SlideElement, scale s: CGFloat) -> some View {
        let c = CGPoint(x: e.frame.midX * s, y: e.frame.midY * s)
        let w = e.frame.width * s, h = e.frame.height * s
        let handles: [(Int, Int)] = [(-1, -1), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0)]
        let tint = e.isLocked ? Color.orange : Color.accentColor

        return ZStack {
            Rectangle()
                .stroke(tint, lineWidth: 1.5)
                .frame(width: w, height: h)
                .rotationEffect(.degrees(e.rotation))
                .position(c)
                .allowsHitTesting(false)

            if !e.isLocked {
                // Rotation handle
                let rp = c + CGPoint(x: 0, y: -h / 2 - 34).rotated(by: e.rotation)
                Path { p in
                    p.move(to: c + CGPoint(x: 0, y: -h / 2).rotated(by: e.rotation))
                    p.addLine(to: rp)
                }
                .stroke(tint, lineWidth: 1.5)
                .allowsHitTesting(false)

                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(tint))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .position(rp)
                    .gesture(rotateGesture(e, center: c))
                    .accessibilityLabel("Rotate")

                ForEach(handles.indices, id: \.self) { i in
                    let hx = handles[i].0
                    let hy = handles[i].1
                    let isEdge = hx == 0 || hy == 0
                    if !(isEdge && (hx == 0 ? w < 50 : h < 50)) {
                        let p = c + CGPoint(x: CGFloat(hx) * w / 2, y: CGFloat(hy) * h / 2).rotated(by: e.rotation)
                        handle(isEdge: isEdge, tint: tint, rotation: e.rotation, horizontal: hy == 0)
                            .position(p)
                            .gesture(resizeGesture(e, hx: hx, hy: hy, scale: s))
                    }
                }
            }
        }
    }

    private func handle(isEdge: Bool, tint: Color, rotation: Double, horizontal: Bool) -> some View {
        Group {
            if isEdge {
                Capsule()
                    .fill(.white)
                    .overlay(Capsule().stroke(tint, lineWidth: 1.5))
                    .frame(width: horizontal ? 7 : 18, height: horizontal ? 18 : 7)
                    .rotationEffect(.degrees(rotation))
            } else {
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(tint, lineWidth: 1.5))
                    .frame(width: 14, height: 14)
            }
        }
        .frame(width: 40, height: 40)
        .contentShape(Rectangle())
    }

    private func resizeGesture(_ e: SlideElement, hx: Int, hy: Int, scale s: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
            .onChanged { v in
                if dragStart == nil {
                    model.beginInteraction()
                    dragStart = model.currentSlide.element(e.id)?.frame ?? e.frame
                }
                guard let start = dragStart else { return }
                let t = CGPoint(x: v.translation.width / s, y: v.translation.height / s)
                let d = t.rotated(by: -e.rotation)
                let minSize: CGFloat = 16
                var newW = hx == 0 ? start.width : max(minSize, start.width + CGFloat(hx) * d.x)
                var newH = hy == 0 ? start.height : max(minSize, start.height + CGFloat(hy) * d.y)

                let keepAspect = hx != 0 && hy != 0 && (e.isImage || e.isIcon || lockAspect)
                if keepAspect, start.width > 0, start.height > 0 {
                    let k = max((newW / start.width + newH / start.height) / 2, minSize / min(start.width, start.height))
                    newW = start.width * k
                    newH = start.height * k
                }

                let local = CGPoint(x: (newW - start.width) / 2 * CGFloat(hx), y: (newH - start.height) / 2 * CGFloat(hy))
                let shift = local.rotated(by: e.rotation)
                let center = CGPoint(x: start.midX + shift.x, y: start.midY + shift.y)
                model.setFrame(e.id, CGRect(x: center.x - newW / 2, y: center.y - newH / 2, width: newW, height: newH))
            }
            .onEnded { _ in
                model.endInteraction()
                dragStart = nil
            }
    }

    @AppStorage("lockAspect") private var lockAspect = false

    private func rotateGesture(_ e: SlideElement, center c: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
            .onChanged { v in
                if !rotating {
                    rotating = true
                    model.beginInteraction()
                }
                var angle = atan2(v.location.y - c.y, v.location.x - c.x) * 180 / .pi + 90
                if angle > 180 { angle -= 360 }
                let snapped = (angle / 15).rounded() * 15
                if abs(snapped - angle) < 4 {
                    if (model.selectedElement?.rotation ?? 0) != snapped { Haptics.tick() }
                    angle = snapped
                }
                model.setRotation(e.id, angle.rounded())
            }
            .onEnded { _ in
                rotating = false
                model.endInteraction()
            }
    }
}

/// Inline text editor drawn on top of the slide while a text element is being edited.
struct TextEditingOverlay: View {
    let model: EditorModel
    let element: SlideElement
    let scale: CGFloat
    @FocusState private var focused: Bool

    var body: some View {
        let content = element.textContent
        let style = content.resolved(in: model.theme)
        let binding = model.elementBinding(element.id, coalesce: "text").textContent.text
        TextField("Text", text: binding, axis: .vertical)
            .font(FontCatalog.font(name: style.fontName, size: style.size * scale, weight: style.weight, italic: content.italic))
            .kerning(style.letterSpacing * scale)
            .lineSpacing(style.lineSpacing * scale)
            .multilineTextAlignment(content.alignment.textAlignment)
            .foregroundStyle(model.theme.color(style.color))
            .textInputAutocapitalization(.sentences)
            .focused($focused)
            .padding(content.padding * scale)
            .frame(width: element.frame.width * scale, height: element.frame.height * scale,
                   alignment: Alignment(horizontal: content.alignment.horizontal, vertical: content.verticalAlignment.vertical))
            .background(Color.accentColor.opacity(0.06))
            .overlay(Rectangle().stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            .rotationEffect(.degrees(element.rotation))
            .position(x: element.frame.midX * scale, y: element.frame.midY * scale)
            .onAppear { focused = true }
    }
}

struct GridOverlay: View {
    let spacing: CGFloat
    let size: CGSize

    var body: some View {
        Path { p in
            guard spacing > 4 else { return }
            var x: CGFloat = 0
            while x <= size.width {
                p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
        }
        .stroke(Color.accentColor.opacity(0.18), lineWidth: 0.5)
        .frame(width: size.width, height: size.height)
    }
}
