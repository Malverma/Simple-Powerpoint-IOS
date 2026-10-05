import SwiftUI

struct TriangleShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct DiamondShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}

struct StarShape: Shape {
    var points: Int
    var innerRatio: Double

    func path(in r: CGRect) -> Path {
        let n = max(points, 3)
        let c = CGPoint(x: r.midX, y: r.midY)
        let rx = r.width / 2, ry = r.height / 2
        var p = Path()
        for i in 0..<(n * 2) {
            let angle = Double(i) * .pi / Double(n) - .pi / 2
            let k = i.isMultiple(of: 2) ? 1.0 : innerRatio
            let pt = CGPoint(x: c.x + CGFloat(cos(angle) * k) * rx, y: c.y + CGFloat(sin(angle) * k) * ry)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct PolygonShape: Shape {
    var sides: Int

    func path(in r: CGRect) -> Path {
        let n = max(sides, 3)
        let c = CGPoint(x: r.midX, y: r.midY)
        var p = Path()
        for i in 0..<n {
            let angle = Double(i) * 2 * .pi / Double(n) - .pi / 2
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * r.width / 2, y: c.y + CGFloat(sin(angle)) * r.height / 2)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// Horizontal line through the middle of the frame.
struct LineShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return p
    }
}

/// Line with an arrow head on the right.
struct ArrowShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let head = min(r.height / 2, r.width * 0.3)
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.move(to: CGPoint(x: r.maxX - head, y: r.midY - head))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX - head, y: r.midY + head))
        return p
    }
}

extension ShapeContent {
    func shape(cornerRadius: Double) -> AnyShape {
        switch kind {
        case .rectangle: return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        case .ellipse: return AnyShape(Ellipse())
        case .triangle: return AnyShape(TriangleShape())
        case .diamond: return AnyShape(DiamondShape())
        case .star: return AnyShape(StarShape(points: points, innerRatio: innerRatio))
        case .polygon: return AnyShape(PolygonShape(sides: points))
        case .arrow: return AnyShape(ArrowShape())
        case .line: return AnyShape(LineShape())
        }
    }

    var isOpenPath: Bool { kind == .line || kind == .arrow }
}
