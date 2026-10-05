import SwiftUI

enum Layouts {
    static func text(_ string: String, role: TextStyleKind, frame: CGRect,
                     align: TextAlign = .leading, vAlign: VerticalAlign = .top,
                     list: ListStyleOption = .none, name: String = "") -> SlideElement {
        var t = TextContent(text: string, role: role)
        t.alignment = align
        t.verticalAlignment = vAlign
        t.listStyle = list
        return SlideElement(name: name, kind: .text(t), frame: frame)
    }

    static func shape(_ kind: ShapeKind, frame: CGRect, fill: Fill, corner: Double = 0) -> SlideElement {
        var e = SlideElement(kind: .shape(ShapeContent(kind: kind)), frame: frame)
        e.style.fill = fill
        e.style.cornerRadius = corner
        if kind == .line || kind == .arrow {
            e.style.fill = .none
            e.style.stroke = StrokeModel(color: .theme(.primary), width: 8)
        }
        return e
    }

    static func imagePlaceholder(frame: CGRect, corner: Double = 0) -> SlideElement {
        var e = SlideElement(name: "Image", kind: .image(ImageContent()), frame: frame)
        e.style.cornerRadius = corner
        return e
    }

    /// Builds a new slide for `layout`, positioned relative to the slide size.
    static func make(_ layout: SlideLayout, size: CGSize, theme: Theme) -> Slide {
        let w = size.width, h = size.height
        let m = min(w, h) * 0.08 // margin
        let portrait = h > w
        var els: [SlideElement] = []

        switch layout {
        case .title:
            els.append(text("Presentation Title", role: .title,
                             frame: CGRect(x: m, y: h * 0.30, width: w - m * 2, height: h * 0.26),
                             align: .center, vAlign: .bottom, name: "Title"))
            els.append(text("Subtitle goes here", role: .heading,
                             frame: CGRect(x: m, y: h * 0.58, width: w - m * 2, height: h * 0.14),
                             align: .center, name: "Subtitle"))
            els[1].textContent.size = theme.typography.heading.size * 0.6
            els[1].textContent.color = .theme(.secondary)
            els[1].textContent.weight = .medium

        case .titleBody:
            els.append(text("Slide Title", role: .heading,
                             frame: CGRect(x: m, y: m, width: w - m * 2, height: h * 0.16),
                             vAlign: .bottom, name: "Title"))
            els.append(text("First point\nSecond point\nThird point", role: .body,
                             frame: CGRect(x: m, y: m + h * 0.2, width: w - m * 2, height: h - m * 2 - h * 0.2),
                             list: .bullet, name: "Body"))

        case .twoColumn:
            let colW = portrait ? w - m * 2 : (w - m * 3) / 2
            let colH = portrait ? (h - m * 3 - h * 0.2) / 2 : h - m * 2 - h * 0.2
            els.append(text("Compare", role: .heading,
                             frame: CGRect(x: m, y: m, width: w - m * 2, height: h * 0.16),
                             vAlign: .bottom, name: "Title"))
            els.append(text("Left column\nKey idea\nDetail", role: .body,
                             frame: CGRect(x: m, y: m + h * 0.2, width: colW, height: colH),
                             list: .bullet, name: "Left"))
            els.append(text("Right column\nKey idea\nDetail", role: .body,
                             frame: portrait
                                ? CGRect(x: m, y: m * 2 + h * 0.2 + colH, width: colW, height: colH)
                                : CGRect(x: m * 2 + colW, y: m + h * 0.2, width: colW, height: colH),
                             list: .bullet, name: "Right"))

        case .section:
            els.append(shape(.rectangle, frame: CGRect(x: m, y: h * 0.5 - 6, width: min(w, h) * 0.12, height: 12),
                             fill: .solid(.theme(.accent)), corner: 6))
            els.append(text("Section", role: .title,
                             frame: CGRect(x: m, y: h * 0.5 + m * 0.4, width: w - m * 2, height: h * 0.25),
                             name: "Section Title"))
            els.append(text("01", role: .caption,
                             frame: CGRect(x: m, y: h * 0.5 - m * 1.6, width: w * 0.4, height: m),
                             vAlign: .bottom, name: "Number"))

        case .quote:
            var mark = text("“", role: .title, frame: CGRect(x: m, y: m * 0.5, width: h * 0.3, height: h * 0.3), name: "Quote Mark")
            mark.textContent.size = h * 0.3
            mark.textContent.color = .theme(.accent)
            els.append(mark)
            var q = text("A great quote that captures the idea of this slide.", role: .heading,
                         frame: CGRect(x: m * 2, y: h * 0.28, width: w - m * 4, height: h * 0.4),
                         align: .center, vAlign: .middle, name: "Quote")
            q.textContent.italic = true
            q.textContent.weight = .medium
            els.append(q)
            els.append(text("— Author Name", role: .caption,
                             frame: CGRect(x: m * 2, y: h * 0.72, width: w - m * 4, height: h * 0.08),
                             align: .center, name: "Attribution"))

        case .imageFull:
            els.append(imagePlaceholder(frame: CGRect(origin: .zero, size: size)))
            var cap = text("Caption", role: .heading,
                           frame: CGRect(x: m, y: h - m - h * 0.16, width: w - m * 2, height: h * 0.16),
                           vAlign: .bottom, name: "Caption")
            cap.textContent.color = .custom(.white)
            cap.style.shadow = ShadowModel(enabled: true, color: RGBA(r: 0, g: 0, b: 0, a: 0.5), radius: 20, x: 0, y: 4)
            els.append(cap)

        case .imageCaption:
            if portrait {
                els.append(imagePlaceholder(frame: CGRect(x: m, y: m, width: w - m * 2, height: h * 0.5), corner: 32))
                els.append(text("Headline", role: .heading,
                                 frame: CGRect(x: m, y: h * 0.5 + m * 1.5, width: w - m * 2, height: h * 0.12), name: "Headline"))
                els.append(text("Supporting description text.", role: .body,
                                 frame: CGRect(x: m, y: h * 0.62 + m * 1.5, width: w - m * 2, height: h * 0.2), name: "Description"))
            } else {
                els.append(imagePlaceholder(frame: CGRect(x: m, y: m, width: w * 0.5 - m, height: h - m * 2), corner: 32))
                els.append(text("Headline", role: .heading,
                                 frame: CGRect(x: w * 0.5 + m * 0.5, y: h * 0.25, width: w * 0.5 - m * 1.5, height: h * 0.2),
                                 vAlign: .bottom, name: "Headline"))
                els.append(text("Supporting description text.", role: .body,
                                 frame: CGRect(x: w * 0.5 + m * 0.5, y: h * 0.48, width: w * 0.5 - m * 1.5, height: h * 0.3),
                                 name: "Description"))
            }

        case .blank:
            break
        }

        return Slide(layout: layout, elements: els)
    }
}

enum SampleDeck {
    static func make() -> Deck {
        let theme = Theme.builtIn[1]
        var deck = Deck(title: "Welcome to SimpleSlides", aspect: .wide, theme: theme)
        let size = deck.size

        var s1 = Layouts.make(.title, size: size, theme: theme)
        s1.elements[0].textContent.text = "SimpleSlides"
        s1.elements[1].textContent.text = "Simple by default. Deep on demand."

        var s2 = Layouts.make(.titleBody, size: size, theme: theme)
        s2.elements[0].textContent.text = "How it works"
        s2.elements[1].textContent.text = "Tap anything to select it\nDrag to move, use handles to resize & rotate\nDouble-tap text to edit\nTap the paintbrush to customise everything"
        for i in s2.elements.indices {
            s2.elements[i].build = BuildModel(effect: i == 0 ? .none : .moveIn, trigger: .onTap, direction: .up, duration: 0.6)
        }
        s2.syncBuildOrder()

        var s3 = Layouts.make(.section, size: size, theme: theme)
        s3.elements[1].textContent.text = "Make it yours"
        s3.elements[2].textContent.text = "02"
        s3.transition = TransitionModel(kind: .push, direction: .left, duration: 0.6, easing: .easeInOut)

        deck.slides = [s1, s2, s3]
        return deck
    }
}
