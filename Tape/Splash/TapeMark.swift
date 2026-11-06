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
//  At 140 pt wide one grid unit is 0.7 px on a 3× screen, so every edge that
//  isn't round sits on a multiple of 10 units: a whole pixel. The icon's
//  blade top, hook and ticks are nudged up to 4 units onto that grid so they
//  render sharp instead of half a pixel soft.
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
    static let bladeTop: CGFloat = 360
    /// Where the blade ends at rest, under the hook.
    static let bladeRestRight: CGFloat = 580
    static let hookLeft: CGFloat = 560
    static let hookTop: CGFloat = 330
    static let hookRadius: CGFloat = 10
    static let hub = CGPoint(x: 230, y: 210)
    static let ringRadius: CGFloat = 118
    static let discRadius: CGFloat = 80
    static let pinRadius: CGFloat = 28
    /// The gap in the ring, so a spinning hub reads as spinning.
    static let notchWidth: CGFloat = 24

    static let tickWidth: CGFloat = 10
    static let tickStep: CGFloat = 30
    static let longTick: CGFloat = 50
    static let shortTick: CGFloat = 30
    /// The two ticks showing at rest, as on the icon: a long one, then a short one.
    static let restTicks: [CGFloat] = [480, 510]
    /// Ticks only show past here, the case's edge, so they slide out from under
    /// it as the blade comes out.
    static let tickClipX: CGFloat = 460

    /// Maps the 600 × 460 grid onto `rect`.
    static func transform(into rect: CGRect) -> CGAffineTransform {
        CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / gridSize.width, y: rect.height / gridSize.height)
    }

    /// Every tick on the blade at rest, before clipping: the two that show,
    /// and the rest of the tape still wound inside the case. A long one every
    /// fourth, counting from the first one that shows.
    static let tapeTicks: [CGRect] = (-80...1).map { k in
        CGRect(x: restTicks[0] + CGFloat(k) * tickStep, y: bladeTop,
               width: tickWidth, height: k.isMultiple(of: 4) ? longTick : shortTick)
    }

    /// The ticks you can see with the blade pulled `reach` grid units past rest.
    static func visibleTicks(reach: CGFloat) -> [CGRect] {
        tapeTicks.compactMap { tick in
            let moved = tick.offsetBy(dx: reach, dy: 0)
            let left = max(moved.minX, tickClipX)
            guard moved.maxX > left else { return nil }
            return CGRect(x: left, y: moved.minY, width: moved.maxX - left, height: moved.height)
        }
    }

    nonisolated struct Case: Shape {
        func path(in rect: CGRect) -> Path {
            // Circular, like the SVG's rx and the icon: continuous corners
            // would bulge past the launch image's by up to 3 px.
            Path(roundedRect: CGRect(x: 0, y: 0, width: caseSide, height: caseSide),
                 cornerRadius: caseRadius, style: .circular)
                .applying(TapeMark.transform(into: rect))
        }
    }

    /// The navy blade at rest, with the rest of its length still inside the
    /// case. It moves with an offset; `BladeWindow` hides what's left of the case.
    nonisolated struct Blade: Shape {
        func path(in rect: CGRect) -> Path {
            Path(CGRect(x: bladeRestRight - 3000, y: bladeTop, width: 3000, height: caseSide - bladeTop))
                .applying(TapeMark.transform(into: rect))
        }
    }

    /// Where the blade can show: right of its slot under the case.
    nonisolated struct BladeWindow: Shape {
        func path(in rect: CGRect) -> Path {
            Path(CGRect(x: bladeLeft, y: 0, width: 4000, height: gridSize.height))
                .applying(TapeMark.transform(into: rect))
        }
    }

    nonisolated struct Ticks: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in p.addRects(TapeMark.tapeTicks) }
                .applying(TapeMark.transform(into: rect))
        }
    }

    /// Where ticks can show: right of the case's edge.
    nonisolated struct TickWindow: Shape {
        func path(in rect: CGRect) -> Path {
            Path(CGRect(x: tickClipX, y: 0, width: 4000, height: gridSize.height))
                .applying(TapeMark.transform(into: rect))
        }
    }

    /// The hook at rest. It moves with the blade's offset.
    nonisolated struct Hook: Shape {
        func path(in rect: CGRect) -> Path {
            Path(roundedRect: CGRect(x: hookLeft, y: hookTop, width: gridSize.width - hookLeft, height: caseSide - hookTop),
                 cornerRadius: hookRadius, style: .circular)
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

/// The white tape measure on blue. `reach` pulls the blade out, in points, and
/// `hubAngle` turns the ring. Blade, ticks and hook are one rigid piece that
/// only translates; the windows they show through stay still.
struct TapeMarkView: View {
    var reach: CGFloat = 0
    var hubAngle: Angle = .zero

    var body: some View {
        let size = SplashLogic.markSize
        ZStack {
            TapeMark.Blade().fill(TapeMark.navy)
                .offset(x: reach)
                .clipShape(TapeMark.BladeWindow())
            TapeMark.Case().fill(.white)
            TapeMark.Ticks().fill(TapeMark.blue)
                .offset(x: reach)
                .clipShape(TapeMark.TickWindow())
            TapeMark.Hook().fill(TapeMark.navy)
                .offset(x: reach)
            TapeMark.Disc(radius: TapeMark.ringRadius).fill(TapeMark.blue)
            TapeMark.Disc(radius: TapeMark.discRadius).fill(.white)
            TapeMark.Notch().fill(.white)
                .rotationEffect(hubAngle, anchor: TapeMark.hubAnchor)
            TapeMark.Disc(radius: TapeMark.pinRadius).fill(TapeMark.navy)
        }
        .frame(width: size.width, height: size.height)
    }
}
