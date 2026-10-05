import SwiftUI
import UIKit

struct Guide: Hashable {
    var vertical: Bool
    var position: CGFloat
}

enum Snapper {
    /// Snaps a moving frame's edges/centres to the slide and other elements.
    static func snap(_ frame: CGRect, others: [CGRect], bounds: CGSize, threshold: CGFloat,
                     grid: CGFloat?) -> (CGRect, [Guide]) {
        var xs: [CGFloat] = [0, bounds.width / 2, bounds.width]
        var ys: [CGFloat] = [0, bounds.height / 2, bounds.height]
        for o in others {
            xs += [o.minX, o.midX, o.maxX]
            ys += [o.minY, o.midY, o.maxY]
        }
        var out = frame
        var guides: [Guide] = []

        if let hit = best([frame.minX, frame.midX, frame.maxX], xs, threshold) {
            out.origin.x += hit.0
            guides.append(Guide(vertical: true, position: hit.1))
        } else if let grid, grid > 0 {
            out.origin.x = (frame.origin.x / grid).rounded() * grid
        }
        if let hit = best([frame.minY, frame.midY, frame.maxY], ys, threshold) {
            out.origin.y += hit.0
            guides.append(Guide(vertical: false, position: hit.1))
        } else if let grid, grid > 0 {
            out.origin.y = (frame.origin.y / grid).rounded() * grid
        }
        return (out, guides)
    }

    private static func best(_ candidates: [CGFloat], _ targets: [CGFloat], _ threshold: CGFloat) -> (CGFloat, CGFloat)? {
        var result: (CGFloat, CGFloat)?
        for c in candidates {
            for t in targets {
                let d = t - c
                if abs(d) <= threshold, abs(d) < abs(result?.0 ?? .infinity) {
                    result = (d, t)
                }
            }
        }
        return result
    }
}

enum Haptics {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true }

    static func tick() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

extension CGPoint {
    func rotated(by degrees: Double) -> CGPoint {
        let r = degrees * .pi / 180
        let c = CGFloat(cos(r)), s = CGFloat(sin(r))
        return CGPoint(x: x * c - y * s, y: x * s + y * c)
    }

    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
}
