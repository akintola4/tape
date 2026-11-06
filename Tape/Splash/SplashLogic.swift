//
//  SplashLogic.swift
//  Tape
//
//  Sizes, timings and motion curves for the opening animation, as plain
//  functions of time so they can be tuned in one place and tested.
//
//  Three variants, picked with `-TapeSplash pull|wipe|reel` while Tope chooses:
//
//    pull  The blade pulls out to the screen edge with a counter ticking up,
//          holds, then snaps back and the case recoils. Then a dive into the app.
//    wipe  The blade pulls out across the screen, then case and blade travel
//          down together and the blade's top edge wipes the blue away.
//    reel  The hub spins while unit symbols roll through a slot beside the
//          case and land on "plot". Then a dive into the app.
//

import SwiftUI

nonisolated enum SplashLogic {
    /// The tape measure's size on screen. Must match LaunchTape.svg
    /// (140 × 107.333) or the hand-off from the launch screen jumps.
    static let markSize = CGSize(width: 140, height: 140 * 460.0 / 600)
    static let pointsPerUnit = markSize.width / TapeMark.gridSize.width

    enum Variant: String, CaseIterable {
        case pull, wipe, reel
    }

    // MARK: - Pull

    /// The counter above the blade reads 0 → this many metres.
    static let counterMax = 1.2
    /// How far the hook bounces back into the case when the blade snaps home.
    static let snapOvershoot: CGFloat = 3
    /// The case's recoil when the blade hits it: degrees and points.
    static let recoilDegrees = 7.0
    static let recoilShift: CGFloat = 3

    // MARK: - Wipe

    /// How close the case stops to the left edge when the blade spans the screen.
    static let caseInset: CGFloat = 12

    // MARK: - Reel

    /// Unit symbols rolling through the slot, landing on Tape's own unit.
    static let tickerUnits = ["cm", "in", "ft", "m²", "kg", "°C", "ac", "plot"]
    static let slotSize = CGSize(width: 58, height: 30)
    /// How many turns the hub makes while the ticker rolls.
    static let reelTurns = 2.0

    /// Phase lengths in seconds, at normal speed.
    struct Timeline: Equatable {
        var variant: Variant = .pull
        /// The blade pulling out (pull, wipe).
        var pull = 0.55
        /// The beat the hook holds at the screen edge (pull, wipe).
        var hold = 0.22
        /// The blade whipping back in (pull).
        var snap = 0.16
        /// The hook's bounce and the case's recoil (pull).
        var settle = 0.3
        /// The wipe down the screen (wipe).
        var travel = 0.85
        /// The ticker rolling (reel).
        var roll = 1.0
        /// The ticker settling on "plot" (reel).
        var land = 0.3
        /// The dive into the app (pull, reel).
        var dive = 0.45

        /// The same timeline stretched by `factor`, for watching it in slow motion.
        func slowed(by factor: Double) -> Timeline {
            Timeline(variant: variant, pull: pull * factor, hold: hold * factor, snap: snap * factor,
                     settle: settle * factor, travel: travel * factor, roll: roll * factor,
                     land: land * factor, dive: dive * factor)
        }

        var snapStarts: Double { pull + hold }
        /// When the blade is home and the case takes the hit (pull).
        var snapEnds: Double { snapStarts + snap }

        /// When the hand-off to the app begins.
        var exitStarts: Double {
            switch variant {
            case .pull: snapEnds + settle
            case .wipe: pull + hold
            case .reel: roll + land
            }
        }

        var exitDuration: Double { variant == .wipe ? travel : dive }
        var total: Double { exitStarts + exitDuration }

        /// When each haptic fires: the snap, the catch, or the landing.
        var hapticTimes: [Double] {
            switch variant {
            case .pull: [snapEnds]
            case .wipe: [pull]
            case .reel: [roll]
            }
        }
    }

    // MARK: - The blade

    /// How far the blade has pulled out past rest, in points. In pull the hook
    /// runs to the screen edge, whips back in with one small bounce and stops.
    /// In wipe it runs to the right edge while the case slides to the left one.
    static func bladeReach(at t: Double, in timeline: Timeline, screen: CGSize) -> CGFloat {
        switch timeline.variant {
        case .pull:
            let full = pullReach(screen: screen)
            if t < timeline.snapStarts {
                return full * CGFloat(pullCurve.value(at: progress(t, over: timeline.pull)))
            }
            if t < timeline.snapEnds {
                let p = progress(t - timeline.snapStarts, over: timeline.snap)
                return full * CGFloat(1 - p * p * p)              // ease-in: it whips in
            }
            let u = progress(t - timeline.snapEnds, over: timeline.settle)
            return u < 0.4 ? -snapOvershoot * CGFloat(sin(.pi * u / 0.4)) : 0
        case .wipe:
            return wipeReach(screen: screen) * CGFloat(pullCurve.value(at: progress(t, over: timeline.pull)))
        case .reel:
            return 0
        }
    }

    /// Hook from rest to the right edge of the screen, the mark centred.
    static func pullReach(screen: CGSize) -> CGFloat {
        screen.width / 2 - markSize.width / 2
    }

    /// Hook to the right edge while the case slides to `caseInset` from the left.
    static func wipeReach(screen: CGSize) -> CGFloat {
        screen.width - markSize.width - caseInset
    }

    /// The hub turns as the blade unwinds (pull, wipe) or as the ticker rolls
    /// (reel). Counter-clockwise when the blade comes out along the bottom.
    static func hubAngle(at t: Double, in timeline: Timeline, screen: CGSize) -> Angle {
        switch timeline.variant {
        case .pull, .wipe:
            let units = bladeReach(at: t, in: timeline, screen: screen) / pointsPerUnit
            return .radians(-Double(units / TapeMark.ringRadius))
        case .reel:
            return .degrees(360 * reelTurns * Double(tickerPosition(at: t, in: timeline)) / Double(tickerUnits.count - 1))
        }
    }

    // MARK: - Pull

    /// The counter above the blade, 0 → 1.2 m with the blade.
    static func counterValue(at t: Double, in timeline: Timeline, screen: CGSize) -> Double {
        let full = pullReach(screen: screen)
        guard full > 0 else { return 0 }
        let reach = bladeReach(at: t, in: timeline, screen: screen)
        return counterMax * min(max(Double(reach / full), 0), 1)
    }

    /// In as the blade starts to move, out quickly once it snaps.
    static func counterOpacity(at t: Double, in timeline: Timeline) -> Double {
        guard timeline.variant == .pull else { return 0 }
        return min(progress(t, over: timeline.pull * 0.2), 1 - progress(t - timeline.snapStarts, over: timeline.snap * 0.6))
    }

    /// The case's recoil from the blade hitting home: a kick clockwise, a
    /// smaller swing back, then rest. Exactly zero by the time the dive starts.
    static func recoil(at t: Double, in timeline: Timeline) -> Double {
        guard timeline.variant == .pull, t >= timeline.snapEnds else { return 0 }
        let u = progress(t - timeline.snapEnds, over: timeline.settle)
        return sin(3 * .pi * u) * (1 - u) * (1 - u)
    }

    // MARK: - Wipe

    /// How far the case and blade have moved from the centre, in points.
    static func markOffset(at t: Double, in timeline: Timeline, screen: CGSize) -> CGSize {
        switch timeline.variant {
        case .pull:
            return CGSize(width: -recoilShift * CGFloat(recoil(at: t, in: timeline)), height: 0)
        case .wipe:
            let out = CGFloat(pullCurve.value(at: progress(t, over: timeline.pull)))
            let down = CGFloat(travelCurve.value(at: progress(t - timeline.exitStarts, over: timeline.travel)))
            return CGSize(width: -(screen.width / 2 - markSize.width / 2 - caseInset) * out,
                          height: travelDistance(screen: screen) * down)
        case .reel:
            return .zero
        }
    }

    /// Far enough that the case, which sits above the blade, is off the bottom.
    static func travelDistance(screen: CGSize) -> CGFloat {
        screen.height / 2 + markSize.height / 2 + 8
    }

    /// The blade's top edge on screen, in points from the top. Above it the
    /// app shows, below it the blue.
    static func revealLine(at t: Double, in timeline: Timeline, screen: CGSize) -> CGFloat {
        screen.height / 2 - markSize.height / 2 + TapeMark.bladeTop * pointsPerUnit
            + markOffset(at: t, in: timeline, screen: screen).height
    }

    /// The blue above the blade. It holds until the wipe begins, then fades as
    /// the blade starts down, so the app doesn't appear above it in one frame.
    static func upperGroundOpacity(at t: Double, in timeline: Timeline) -> Double {
        1 - progress(t - timeline.exitStarts, over: timeline.travel * 0.35)
    }

    // MARK: - Reel

    /// Which row of `tickerUnits` is in the slot, as a fraction: 0 is "cm" and
    /// the last is "plot". It decelerates but arrives with a little speed, so
    /// it nudges past and settles back, like a mechanical counter.
    static func tickerPosition(at t: Double, in timeline: Timeline) -> CGFloat {
        guard timeline.variant == .reel else { return 0 }
        let last = CGFloat(tickerUnits.count - 1)
        if t < timeline.roll {
            let p = progress(t, over: timeline.roll)
            return last * CGFloat(0.85 * p * (2 - p) + 0.15 * p)
        }
        let u = progress(t - timeline.roll, over: timeline.land)
        return last + 0.12 * CGFloat(sin(.pi * u) * (1 - u))
    }

    /// The unit showing in the slot at `t`.
    static func tickerUnit(at t: Double, in timeline: Timeline) -> String {
        let index = Int(tickerPosition(at: t, in: timeline).rounded())
        return tickerUnits[min(max(index, 0), tickerUnits.count - 1)]
    }

    /// The slot fades in as the roll starts; the launch screen can't hold it.
    static func slotOpacity(at t: Double, in timeline: Timeline) -> Double {
        timeline.variant == .reel ? progress(t, over: 0.15 * timeline.roll) : 0
    }

    // MARK: - Exit

    /// 0 → 1 across the dive, on a fast-start curve. Drives the blue clearing,
    /// the blur and the app. Zero throughout for wipe, which exits by travel.
    static func diveProgress(at t: Double, in timeline: Timeline) -> Double {
        guard timeline.variant != .wipe else { return 0 }
        return diveCurve.value(at: progress(t - timeline.exitStarts, over: timeline.dive))
    }

    /// The mark during the dive: a small dip so the push reads as a push, then
    /// it grows past you.
    static func diveScale(at t: Double, in timeline: Timeline) -> CGFloat {
        guard timeline.variant != .wipe else { return 1 }
        let local = progress(t - timeline.exitStarts, over: timeline.dive)
        let dip = 0.15
        if local < dip {
            return 1 - 0.06 * CGFloat(sin(local / dip * .pi / 2))
        }
        let p = diveCurve.value(at: (local - dip) / (1 - dip))
        return 0.94 + (6 - 0.94) * CGFloat(p)
    }

    /// The app behind the splash settles from 0.94 to full size as the blue
    /// clears, on the same clock. The wipe uncovers it at full size.
    static func appScale(at t: Double, in timeline: Timeline) -> CGFloat {
        guard timeline.variant != .wipe else { return 1 }
        return 0.94 + 0.06 * CGFloat(diveProgress(at: t, in: timeline))
    }

    /// The "Made by" credit: fades in with the first motion, out with the exit.
    static func creditOpacity(at t: Double, in timeline: Timeline) -> Double {
        let out = timeline.variant == .wipe
            ? progress(t - timeline.exitStarts, over: timeline.travel * 0.4)
            : diveProgress(at: t, in: timeline)
        let fadeIn = timeline.variant == .reel ? timeline.roll * 0.25 : timeline.pull * 0.45
        return min(progress(t, over: fadeIn), 1 - out)
    }

    // MARK: - Curves

    /// Out fast, braking into the catch.
    static let pullCurve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.3, y: 0.4),
                                            endControlPoint: UnitPoint(x: 0.2, y: 1))
    /// Already on screen, so ease-in-out.
    static let travelCurve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.65, y: 0),
                                              endControlPoint: UnitPoint(x: 0.35, y: 1))
    static let diveCurve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.32, y: 0.72),
                                            endControlPoint: UnitPoint(x: 0, y: 1))

    private static func progress(_ elapsed: Double, over duration: Double) -> Double {
        min(max(elapsed / duration, 0), 1)
    }
}
