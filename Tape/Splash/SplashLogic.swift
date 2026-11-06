//
//  SplashLogic.swift
//  Tape
//
//  Sizes, timings and motion curves for the opening animation, as plain
//  functions of time so they can be tuned in one place and tested.
//
//  The blade pulls out to the screen edge while a counter above it reads
//  0.00 → 1.20 m, holds, whips back in and bounces into the case, and the
//  case kicks and settles. Then a dive into the app.
//

import SwiftUI

nonisolated enum SplashLogic {
    /// The tape measure's size on screen. Must match LaunchTape.svg
    /// (140 × 107.333) or the hand-off from the launch screen jumps.
    static let markSize = CGSize(width: 140, height: 140 * 460.0 / 600)
    static let pointsPerUnit = markSize.width / TapeMark.gridSize.width

    /// The counter above the blade reads 0 → this many metres.
    static let counterMax = 1.2
    /// Points between the counter's digits and the top of the blade.
    static let counterGap: CGFloat = 8
    /// How far the hook bounces back into the case when the blade snaps home.
    static let snapOvershoot: CGFloat = 3
    /// The case's kick when the blade hits it, at its peak: degrees and points.
    static let kickDegrees = 7.0
    static let kickShift: CGFloat = 3

    /// Phase lengths in seconds, at normal speed.
    struct Timeline: Equatable {
        /// The blade pulling out.
        var pull = 0.55
        /// The beat the hook holds at the screen edge.
        var hold = 0.22
        /// The blade whipping back in.
        var snap = 0.16
        /// The hook's bounce and the case's kick.
        var settle = 0.3
        /// The dive into the app.
        var dive = 0.45

        /// The same timeline stretched by `factor`, for watching it in slow motion.
        func slowed(by factor: Double) -> Timeline {
            Timeline(pull: pull * factor, hold: hold * factor, snap: snap * factor,
                     settle: settle * factor, dive: dive * factor)
        }

        var snapStarts: Double { pull + hold }
        /// When the blade is home and the case takes the hit. The haptic fires here.
        var snapEnds: Double { snapStarts + snap }
        var diveStarts: Double { snapEnds + settle }
        var total: Double { diveStarts + dive }
    }

    // MARK: - The blade

    /// How far the blade has pulled out past rest, in points. The hook runs to
    /// the screen edge, holds, whips back in, bounces once into the case and
    /// comes to rest.
    static func bladeReach(at t: Double, in timeline: Timeline, screen: CGSize) -> CGFloat {
        let full = pullReach(screen: screen)
        if t < timeline.snapStarts {
            return full * CGFloat(pullCurve.value(at: progress(t, over: timeline.pull)))
        }
        if t < timeline.snapEnds {
            let p = progress(t - timeline.snapStarts, over: timeline.snap)
            return full * CGFloat(1 - p * p * p)              // ease-in: it whips in
        }
        // Still travelling inward when it lands, so it carries on a few points
        // into the case and eases back out to rest: s(1 - s)², peak 4/27 at s = 1/3.
        let s = progress(t - timeline.snapEnds, over: timeline.settle * bounceShare)
        return -snapOvershoot * 27 / 4 * CGFloat(s * (1 - s) * (1 - s))
    }

    /// The part of the settle the hook's bounce takes; the case keeps swinging after.
    static let bounceShare = 0.4

    /// Hook from rest to the right edge of the screen, the mark centred.
    static func pullReach(screen: CGSize) -> CGFloat {
        screen.width / 2 - markSize.width / 2
    }

    /// The hub turns as the blade unwinds: counter-clockwise when it comes out
    /// along the bottom.
    static func hubAngle(at t: Double, in timeline: Timeline, screen: CGSize) -> Angle {
        let units = bladeReach(at: t, in: timeline, screen: screen) / pointsPerUnit
        return .radians(-Double(units / TapeMark.ringRadius))
    }

    /// `points` rounded to whole device pixels. The tape moves as one piece by
    /// this, so its ticks land on the same pixels every frame instead of
    /// shimmering between them.
    static func snapped(_ points: CGFloat, scale: CGFloat) -> CGFloat {
        guard scale > 0 else { return points }
        return (points * scale).rounded() / scale
    }

    // MARK: - Counter

    /// The counter above the blade, 0 → 1.2 m as the blade comes out. It keeps
    /// its reading while the blade whips back and it fades.
    static func counterValue(at t: Double, in timeline: Timeline, screen: CGSize) -> Double {
        let full = pullReach(screen: screen)
        guard full > 0 else { return 0 }
        let reach = bladeReach(at: min(t, timeline.snapStarts), in: timeline, screen: screen)
        return counterMax * min(max(Double(reach / full), 0), 1)
    }

    /// The counter's centre, across from the mark's left edge: the middle of the
    /// blade that's showing. It stays put once the blade whips back.
    static func counterX(at t: Double, in timeline: Timeline, screen: CGSize) -> CGFloat {
        let reach = bladeReach(at: min(t, timeline.snapStarts), in: timeline, screen: screen)
        return (TapeMark.caseSide * pointsPerUnit + markSize.width + reach) / 2
    }

    /// In as the blade starts to move, out quickly once it snaps.
    static func counterOpacity(at t: Double, in timeline: Timeline) -> Double {
        min(progress(t, over: timeline.pull * 0.2), 1 - progress(t - timeline.snapStarts, over: timeline.snap * 0.6))
    }

    // MARK: - The case

    /// The case's kick from the blade hitting home, as a damped swing: clockwise,
    /// a smaller swing back, then rest. Zero, and still, when the dive starts.
    static func kick(at t: Double, in timeline: Timeline) -> Double {
        guard t >= timeline.snapEnds else { return 0 }
        let u = progress(t - timeline.snapEnds, over: timeline.settle)
        return sin(3 * .pi * u) * (1 - u) * (1 - u)
    }

    /// The kick also shoves the case back a few points, away from the blade.
    static func markOffset(at t: Double, in timeline: Timeline) -> CGFloat {
        -kickShift * CGFloat(kick(at: t, in: timeline))
    }

    // MARK: - Dive

    /// 0 → 1 across the dive, on a fast-start curve. Drives the blue clearing,
    /// the blur and the app.
    static func diveProgress(at t: Double, in timeline: Timeline) -> Double {
        diveCurve.value(at: progress(t - timeline.diveStarts, over: timeline.dive))
    }

    /// The mark during the dive: a small dip so the push reads as a push, then
    /// it grows past you.
    static func diveScale(at t: Double, in timeline: Timeline) -> CGFloat {
        let local = progress(t - timeline.diveStarts, over: timeline.dive)
        let dip = 0.15
        if local < dip {
            return 1 - 0.06 * CGFloat(sin(local / dip * .pi / 2))
        }
        let p = diveCurve.value(at: (local - dip) / (1 - dip))
        return 0.94 + (6 - 0.94) * CGFloat(p)
    }

    /// The app behind the splash settles from 0.94 to full size as the blue
    /// clears, on the same clock.
    static func appScale(at t: Double, in timeline: Timeline) -> CGFloat {
        0.94 + 0.06 * CGFloat(diveProgress(at: t, in: timeline))
    }

    /// The "Made by" credit: fades in with the pull, out with the dive.
    static func creditOpacity(at t: Double, in timeline: Timeline) -> Double {
        min(progress(t, over: timeline.pull * 0.45), 1 - diveProgress(at: t, in: timeline))
    }

    // MARK: - Curves

    /// Yanked out fast, braking into the catch. Its speed only ever drops.
    static let pullCurve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.33, y: 1),
                                            endControlPoint: UnitPoint(x: 0.68, y: 1))
    static let diveCurve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.32, y: 0.72),
                                            endControlPoint: UnitPoint(x: 0, y: 1))

    static func progress(_ elapsed: Double, over duration: Double) -> Double {
        min(max(elapsed / duration, 0), 1)
    }
}
