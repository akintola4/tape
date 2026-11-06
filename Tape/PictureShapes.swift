//
//  PictureShapes.swift
//  Tape
//
//  Flat silhouettes for the "Picture it" drawings. Each one fills the rect
//  it's given. `.detail` is the markings (windows, pitch lines, handle
//  holes), drawn on top in the card's colour so they read as cut-outs.
//

import SwiftUI

struct ObjectShape: Shape {
    enum Layer { case body, detail }

    let object: PictureObject
    var layer: Layer = .body

    func path(in r: CGRect) -> Path {
        var body = Path()
        var detail = Path()
        let w = r.width, h = r.height
        func frame(_ x: Double, _ y: Double, _ rw: Double, _ rh: Double) -> CGRect {
            CGRect(x: r.minX + x * w, y: r.minY + y * h, width: rw * w, height: rh * h)
        }
        func rounded(_ path: inout Path, _ rect: CGRect, _ radius: Double = 0) {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        }
        func circle(_ path: inout Path, _ cx: Double, _ cy: Double, _ radius: Double) {
            path.addEllipse(in: CGRect(x: r.minX + cx * w - radius, y: r.minY + cy * h - radius, width: radius * 2, height: radius * 2))
        }
        func line(_ path: inout Path, _ points: [(Double, Double)]) {
            path.addLines(points.map { CGPoint(x: r.minX + $0.0 * w, y: r.minY + $0.1 * h) })
            path.closeSubpath()
        }
        let small = min(w, h)

        switch object {
        case .plot, .tile:
            rounded(&body, r, min(4, small * 0.08))
        case .bedroom:
            rounded(&body, r, min(4, small * 0.08))
            rounded(&detail, frame(0.58, 0.9, 0.26, 0.1))
        case .pitch, .pitchLength:
            rounded(&body, r, min(3, small * 0.08))
            let stroke = max(1, small * 0.035)
            let radius = h * 0.18
            detail = Path(ellipseIn: CGRect(x: r.midX - radius, y: r.midY - radius, width: radius * 2, height: radius * 2))
                .strokedPath(StrokeStyle(lineWidth: stroke))
                .union(Path(CGRect(x: r.midX - stroke / 2, y: r.minY + stroke * 2, width: stroke, height: h - stroke * 4)))
        case .maggiCube:
            rounded(&body, r, small * 0.2)
            rounded(&detail, frame(0.15, 0.42, 0.7, 0.16), 1)
        case .egg:
            body.move(to: CGPoint(x: r.midX, y: r.minY))
            body.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.62),
                          control1: CGPoint(x: r.minX + w * 0.82, y: r.minY),
                          control2: CGPoint(x: r.maxX, y: r.minY + h * 0.36))
            body.addCurve(to: CGPoint(x: r.midX, y: r.maxY),
                          control1: CGPoint(x: r.maxX, y: r.minY + h * 0.86),
                          control2: CGPoint(x: r.minX + w * 0.78, y: r.maxY))
            body.addCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.62),
                          control1: CGPoint(x: r.minX + w * 0.22, y: r.maxY),
                          control2: CGPoint(x: r.minX, y: r.minY + h * 0.86))
            body.addCurve(to: CGPoint(x: r.midX, y: r.minY),
                          control1: CGPoint(x: r.minX, y: r.minY + h * 0.36),
                          control2: CGPoint(x: r.minX + w * 0.18, y: r.minY))
            body.closeSubpath()
        case .eggCrate:
            rounded(&body, r, small * 0.08)
            for row in 0..<5 {
                for column in 0..<6 {
                    circle(&detail, (Double(column) + 0.5) / 6, (Double(row) + 0.5) / 5, min(w / 6, h / 5) * 0.3)
                }
            }
        case .riceBag:
            line(&body, [(0.12, 0), (0.88, 0), (0.78, 0.12), (0.92, 0.24), (1, 0.9), (0.94, 1),
                         (0.06, 1), (0, 0.9), (0.08, 0.24), (0.22, 0.12)])
            rounded(&detail, frame(0.2, 0.11, 0.6, 0.03))
        case .car:
            rounded(&body, frame(0, 0.38, 1, 0.44), h * 0.14)
            line(&body, [(0.2, 0.4), (0.32, 0.06), (0.7, 0.06), (0.84, 0.4)])
            rounded(&detail, frame(0.35, 0.16, 0.15, 0.2), 2)
            rounded(&detail, frame(0.53, 0.16, 0.15, 0.2), 2)
            circle(&body, 0.24, 0.82, h * 0.18)
            circle(&body, 0.76, 0.82, h * 0.18)
            circle(&detail, 0.24, 0.82, h * 0.07)
            circle(&detail, 0.76, 0.82, h * 0.07)
        case .phone:
            rounded(&body, r, h * 0.2)
            // The camera, at the top of a phone lying on its side.
            circle(&detail, 0.9, 0.5, h * 0.07)
        case .danfo:
            rounded(&body, frame(0, 0, 1, 0.82), h * 0.12)
            for column in 0..<4 {
                rounded(&detail, frame(0.06 + Double(column) * 0.2, 0.12, 0.15, 0.28), 2)
            }
            circle(&body, 0.2, 0.82, h * 0.16)
            circle(&body, 0.8, 0.82, h * 0.16)
            circle(&detail, 0.2, 0.82, h * 0.06)
            circle(&detail, 0.8, 0.82, h * 0.06)
        case .bridge:
            rounded(&body, frame(0, 0, 1, 0.3), 2)
            for pier in 0..<6 {
                rounded(&body, frame(0.06 + Double(pier) * 0.176, 0.28, 0.03, 0.72))
            }
        case .teaspoon, .tablespoon:
            body.addEllipse(in: frame(0, 0, 0.4, 1))
            rounded(&body, frame(0.36, 0.4, 0.64, 0.2), h * 0.1)
        case .cup:
            rounded(&body, frame(0, 0, 0.78, 1), small * 0.14)
            let ring = frame(0.6, 0.2, 0.4, 0.5)
            rounded(&body, ring, ring.width / 2)
            rounded(&detail, ring.insetBy(dx: ring.width * 0.3, dy: ring.width * 0.3).offsetBy(dx: ring.width * 0.1, dy: 0), ring.width / 5)
        case .bottle:
            rounded(&body, frame(0.32, 0, 0.36, 0.08), 2)
            line(&body, [(0.36, 0.07), (0.64, 0.07), (1, 0.27), (0, 0.27)])
            rounded(&body, frame(0, 0.25, 1, 0.75), w * 0.2)
            rounded(&detail, frame(0, 0.5, 1, 0.03))
        case .jerrycan:
            rounded(&body, frame(0, 0.12, 1, 0.88), small * 0.1)
            rounded(&body, frame(0.06, 0, 0.2, 0.16), 2)
            rounded(&detail, frame(0.46, 0.2, 0.4, 0.1), h * 0.04)
        }
        return layer == .body ? body : detail
    }
}

/// A person filling its rect's height.
struct PersonShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let h = r.height, x = r.midX
        let head = h * 0.095
        p.addEllipse(in: CGRect(x: x - head, y: r.minY, width: head * 2, height: head * 2))
        let torso = h * 0.26
        p.addRoundedRect(in: CGRect(x: x - torso / 2, y: r.minY + h * 0.22, width: torso, height: h * 0.42),
                         cornerSize: CGSize(width: torso * 0.45, height: torso * 0.45))
        let leg = h * 0.1
        for offset in [-leg - h * 0.012, h * 0.012] {
            p.addRoundedRect(in: CGRect(x: x + offset, y: r.minY + h * 0.58, width: leg, height: h * 0.42),
                             cornerSize: CGSize(width: leg / 2, height: leg / 2))
        }
        return p
    }
}

/// The tube and bulb of a thermometer, as one outline. The bulb is the rect's width.
struct ThermometerShape: Shape {
    func path(in r: CGRect) -> Path {
        let bulb = r.width
        let tube = bulb * 0.5
        let tubeRect = CGRect(x: r.midX - tube / 2, y: r.minY, width: tube, height: r.height - bulb / 2)
        return Path(roundedRect: tubeRect, cornerRadius: tube / 2)
            .union(Path(ellipseIn: CGRect(x: r.minX, y: r.maxY - bulb, width: bulb, height: bulb)))
    }
}
