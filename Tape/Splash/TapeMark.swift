//
//  TapeMark.swift
//  Tape
//
//  The tape measure from the app icon (scripts/make-icon.py), redrawn for the
//  baby-blue splash: white case, blue hub ring, navy pin, blade and hook. It
//  uses the icon's own units in a 600 × 460 grid, with the blade at a short
//  rest length. The launch screen image (Assets/LaunchTape.svg) draws the same
//  shapes, so the splash starts on exactly the picture iOS was showing.
//

import SwiftUI

nonisolated enum TapeMark {
    static let gridSize = CGSize(width: 600, height: 460)

    /// The splash ground, #8FD3FF, in light and dark mode alike.
    static let blue = Color(red: 0x8F / 255, green: 0xD3 / 255, blue: 1)
    /// The icon's navy, #0B2A40 (also the chip text).
    static let navy = Color(red: 0x0B / 255, green: 0x2A / 255, blue: 0x40 / 255)

    // The icon's measurements, in grid units.
    static let caseSide: CGFloat = 460
    static let caseRadius: CGFloat = 132
    /// The blade starts under the case so it fills the case's bottom-right corner.
    static let bladeLeft: CGFloat = 320
    static let bladeTop: CGFloat = 364
    /// Where the blade ends at rest: 112 past the case.
    static let bladeRestRight: CGFloat = 572
    static let hookTop: CGFloat = 334
    static let hub = CGPoint(x: 230, y: 210)
    static let ringRadius: CGFloat = 118
    static let discRadius: CGFloat = 80
    static let pinRadius: CGFloat = 28
    /// The gap in the ring, so a spinning hub reads as spinning.
    static let notchWidth: CGFloat = 24

    static let tickWidth: CGFloat = 10
    static let tickStep: CGFloat = 30
    /// The first tick at rest sits 24 past the case, as on the icon.
    static let firstTickX: CGFloat = 484
    /// Ticks only show past here, so one coming out from under the case never
    /// peeks out beside it at rest.
    static let tickClipX: CGFloat = 464

    /// Maps the 600 × 460 grid onto `rect`.
    static func transform(into rect: CGRect) -> CGAffineTransform {
        CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / gridSize.width, y: rect.height / gridSize.height)
    }

    /// The tick rectangles for a blade pulled `reach` grid units past rest.
    /// They travel with the blade and appear from under the case; a long one
    /// every fourth, as on the icon.
    static func ticks(reach e: CGFloat) -> [CGRect] {
        let bladeRight = bladeRestRight + e
        let first = Int(((tickClipX - tickWidth - firstTickX - e) / tickStep).rounded(.up))
        var rects: [CGRect] = []
        var k = first
        while true {
            let x = firstTickX + CGFloat(k) * tickStep + e
            guard x + tickWidth <= bladeRight - 20 else { break }
            let left = max(x, tickClipX)
            if x + tickWidth > left {
                let length: CGFloat = ((k % 4) + 4) % 4 == 0 ? 52 : 30
                rects.append(CGRect(x: left, y: bladeTop, width: x + tickWidth - left, height: length))
            }
            k += 1
        }
        return rects
    }

    nonisolated struct Case: Shape {
        func path(in rect: CGRect) -> Path {
            Path(roundedRect: CGRect(x: 0, y: 0, width: caseSide, height: caseSide), cornerRadius: caseRadius)
                .applying(TapeMark.transform(into: rect))
        }
    }

    /// The navy blade, `reach` grid units longer than at rest.
    nonisolated struct Blade: Shape {
        var reach: CGFloat = 0
        func path(in rect: CGRect) -> Path {
            Path(CGRect(x: bladeLeft, y: bladeTop, width: bladeRestRight + reach - bladeLeft, height: caseSide - bladeTop))
                .applying(TapeMark.transform(into: rect))
        }
    }

    nonisolated struct Ticks: Shape {
        var reach: CGFloat = 0
        func path(in rect: CGRect) -> Path {
            Path { p in p.addRects(TapeMark.ticks(reach: reach)) }
                .applying(TapeMark.transform(into: rect))
        }
    }

    /// The hook at rest. Move it out with an offset.
    nonisolated struct Hook: Shape {
        func path(in rect: CGRect) -> Path {
            Path(roundedRect: CGRect(x: bladeRestRight - 12, y: hookTop, width: 40, height: caseSide - hookTop), cornerRadius: 10)
                .applying(TapeMark.transform(into: rect))
        }
    }

    nonisolated struct Disc: Shape {
        let radius: CGFloat
        func path(in rect: CGRect) -> Path {
            Path(ellipseIn: CGRect(x: hub.x - radius, y: hub.y - radius, width: radius * 2, height: radius * 2))
                .applying(TapeMark.transform(into: rect))
        }
    }

    /// The gap at the top of the ring. Rotate it about `hubAnchor` to spin the hub.
    nonisolated struct Notch: Shape {
        func path(in rect: CGRect) -> Path {
            Path(CGRect(x: hub.x - notchWidth / 2, y: hub.y - ringRadius - 1, width: notchWidth, height: ringRadius - discRadius + 2))
                .applying(TapeMark.transform(into: rect))
        }
    }

    static let hubAnchor = UnitPoint(x: hub.x / gridSize.width, y: hub.y / gridSize.height)
}

/// The white tape measure on blue. `reach` pulls the blade out (in grid
/// units) and `hubAngle` turns the ring.
struct TapeMarkView: View {
    var reach: CGFloat = 0
    var hubAngle: Angle = .zero

    var body: some View {
        let size = SplashLogic.markSize
        ZStack {
            TapeMark.Blade(reach: reach).fill(TapeMark.navy)
            TapeMark.Case().fill(.white)
            TapeMark.Ticks(reach: reach).fill(TapeMark.blue)
            TapeMark.Hook().fill(TapeMark.navy)
                .offset(x: reach * SplashLogic.pointsPerUnit)
            TapeMark.Disc(radius: TapeMark.ringRadius).fill(TapeMark.blue)
            TapeMark.Disc(radius: TapeMark.discRadius).fill(.white)
            TapeMark.Notch().fill(.white)
                .rotationEffect(hubAngle, anchor: TapeMark.hubAnchor)
            TapeMark.Disc(radius: TapeMark.pinRadius).fill(TapeMark.navy)
        }
        .frame(width: size.width, height: size.height)
    }
}
