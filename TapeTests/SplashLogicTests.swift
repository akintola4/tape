//
//  SplashLogicTests.swift
//  TapeTests
//
//  The opening animation's timeline: phases in order and inside the time
//  budget, the curves easing the right way, the counter's readings, the blade
//  at rest before the dive, the app at full size at the end, and a mark the
//  same size and shape as the launch screen image.
//

import Testing
import Foundation
import SwiftUI
@testable import Tape

private let screen = CGSize(width: 402, height: 874)   // iPhone 17 Pro
private let timeline = SplashLogic.Timeline()

private func close(_ a: CGFloat, _ b: CGFloat, within tolerance: CGFloat = 1e-6) -> Bool {
    abs(a - b) <= tolerance
}

private func reach(at t: Double) -> CGFloat {
    SplashLogic.bladeReach(at: t, in: timeline, screen: screen)
}

/// Samples `f` at `count` + 1 evenly spaced times from `start` to `end`.
private func samples(from start: Double, to end: Double, count: Int = 200, _ f: (Double) -> CGFloat) -> [CGFloat] {
    (0...count).map { f(start + (end - start) * Double($0) / Double(count)) }
}

struct SplashLogicTests {
    // MARK: - Launch screen hand-off

    @Test func markMatchesTheLaunchScreenImage() throws {
        let svgURL = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Tape/Assets.xcassets/LaunchTape.imageset/LaunchTape.svg")
        let svg = try String(contentsOf: svgURL, encoding: .utf8)
        func attribute(_ name: String) throws -> String {
            let match = try #require(svg.firstMatch(of: try Regex("<svg[^>]* \(name)=\"([^\"]+)\"")))
            return try #require(match.output[1].substring.map(String.init))
        }
        let width = try #require(Double(try attribute("width")))
        let height = try #require(Double(try attribute("height")))
        #expect(close(SplashLogic.markSize.width, width, within: 0.001))
        #expect(close(SplashLogic.markSize.height, height, within: 0.001))

        // The viewBox is the mark's own grid, with no empty margin.
        let viewBox = try attribute("viewBox").split(separator: " ").compactMap { Double($0) }
        #expect(viewBox == [0, 0, Double(TapeMark.gridSize.width), Double(TapeMark.gridSize.height)])
        #expect(close(SplashLogic.markSize.height / SplashLogic.markSize.width,
                      TapeMark.gridSize.height / TapeMark.gridSize.width))

        // The same rectangles as the shapes the splash draws at rest.
        let rects = try svg.matches(of: Regex(#"<rect x="([\d.]+)" y="([\d.]+)" width="([\d.]+)" height="([\d.]+)""#))
            .map { match in (1...4).compactMap { match.output[$0].substring.flatMap { Double($0) } } }
        let blade = [TapeMark.bladeLeft, TapeMark.bladeTop, TapeMark.bladeRestRight - TapeMark.bladeLeft, TapeMark.caseSide - TapeMark.bladeTop]
        let hook = [TapeMark.hookLeft, TapeMark.hookTop, TapeMark.gridSize.width - TapeMark.hookLeft, TapeMark.caseSide - TapeMark.hookTop]
        let ticks = TapeMark.visibleTicks(reach: 0).map { [$0.minX, $0.minY, $0.width, $0.height] }
        for shape in [blade, hook] + ticks {
            #expect(rects.contains(shape.map { Double($0) }))
        }
    }

    @Test func restingBladeShowsTheIconsTwoTicks() {
        let ticks = TapeMark.visibleTicks(reach: 0)
        #expect(ticks.map(\.minX) == TapeMark.restTicks)
        #expect(ticks.map(\.height) == [TapeMark.longTick, TapeMark.shortTick])
        // Pulled out, more come out from under the case and none sit over it.
        let pulled = TapeMark.visibleTicks(reach: 400)
        #expect(pulled.count > ticks.count)
        #expect(pulled.allSatisfy { $0.minX >= TapeMark.tickClipX && $0.width > 0 })
        // The same spacing as at rest, and always a long one every fourth.
        let whole = pulled.filter { $0.width == TapeMark.tickWidth }
        #expect(zip(whole, whole.dropFirst()).allSatisfy { $1.minX - $0.minX == TapeMark.tickStep })
        let longs = whole.filter { $0.height == TapeMark.longTick }.map(\.minX)
        #expect(zip(longs, longs.dropFirst()).allSatisfy { $1 - $0 == 4 * TapeMark.tickStep })
    }

    /// One grid unit is 0.7 px at 3×, so straight edges on multiples of 10
    /// units land on whole pixels and render sharp.
    @Test func straightEdgesLandOnWholePixels() {
        let pixelsPerUnit = SplashLogic.pointsPerUnit * 3
        let edges = [TapeMark.bladeLeft, TapeMark.bladeTop, TapeMark.hookLeft, TapeMark.hookTop,
                     TapeMark.caseSide, TapeMark.tickClipX, TapeMark.tickWidth, TapeMark.tickStep,
                     TapeMark.longTick, TapeMark.shortTick] + TapeMark.restTicks
        for edge in edges {
            #expect(close(edge * pixelsPerUnit, (edge * pixelsPerUnit).rounded(), within: 1e-9), "\(edge)")
        }
        // The mark itself sits on whole pixels when centred on a 3× iPhone.
        for height in [874.0, 844.0, 932.0, 956.0] {
            let top = (height - SplashLogic.markSize.height) / 2 * 3
            #expect(close(top, top.rounded(), within: 1e-6))
        }
    }

    @Test func movingTapeSnapsToWholePixels() {
        #expect(SplashLogic.snapped(10.2, scale: 3) == 31.0 / 3)
        #expect(SplashLogic.snapped(-1.4, scale: 3) == -4.0 / 3)
        #expect(SplashLogic.snapped(5.25, scale: 2) == 5.5)
        #expect(SplashLogic.snapped(5.25, scale: 0) == 5.25)
    }

    // MARK: - Timing

    @Test func totalIsInsideTheBudget() {
        #expect(timeline.total >= 1.6 && timeline.total <= 2)
        #expect(close(timeline.total, 1.68))
    }

    @Test func phasesRunInOrder() {
        #expect(timeline.pull < timeline.snapStarts)
        #expect(timeline.snapStarts < timeline.snapEnds)
        #expect(timeline.snapEnds < timeline.diveStarts)
        #expect(timeline.diveStarts < timeline.total)
    }

    @Test func slowMotionStretchesEveryPhase() {
        let slow = timeline.slowed(by: 4)
        #expect(abs(slow.total - timeline.total * 4) < 1e-9)
        #expect(abs(slow.snapEnds - timeline.snapEnds * 4) < 1e-9)
        #expect(abs(slow.diveStarts - timeline.diveStarts * 4) < 1e-9)
    }

    // MARK: - The pull

    @Test func pullCatchesAtTheScreenEdgeAndHolds() {
        let full = SplashLogic.pullReach(screen: screen)
        #expect(close(reach(at: 0), 0))
        #expect(close(reach(at: timeline.pull), full))
        #expect(close(reach(at: timeline.snapStarts - 0.01), full))
        // The hook's outer edge is exactly at the right edge of the screen.
        #expect(close(screen.width / 2 + SplashLogic.markSize.width / 2 + full, screen.width))
    }

    @Test func pullDeceleratesAllTheWay() {
        let path = samples(from: 0, to: timeline.pull, reach)
        let speeds = zip(path, path.dropFirst()).map { $1 - $0 }
        #expect(speeds.allSatisfy { $0 >= 0 })
        #expect(zip(speeds, speeds.dropFirst()).allSatisfy { $1 <= $0 + 1e-9 })
        // Fast off the mark: most of the way out by the halfway point.
        #expect(reach(at: timeline.pull / 2) > SplashLogic.pullReach(screen: screen) * 0.8)
    }

    @Test func snapAcceleratesIntoTheCase() {
        #expect(timeline.snap < timeline.pull / 2)
        let path = samples(from: timeline.snapStarts, to: timeline.snapEnds, reach)
        let speeds = zip(path, path.dropFirst()).map { $0 - $1 }
        #expect(speeds.allSatisfy { $0 >= 0 })
        #expect(zip(speeds, speeds.dropFirst()).allSatisfy { $1 >= $0 - 1e-9 })
    }

    @Test func snapBouncesOnceIntoTheCaseAndLandsAtRest() {
        #expect(close(reach(at: timeline.snapEnds), 0))
        let settle = samples(from: timeline.snapEnds, to: timeline.diveStarts, reach)
        // Into the case by the overshoot and no further, and never back out past rest.
        #expect(close(settle.min() ?? 0, -SplashLogic.snapOvershoot, within: 0.01))
        #expect(settle.allSatisfy { $0 <= 1e-9 })
        // One dip: down, then up, never down again.
        let steps = zip(settle, settle.dropFirst()).map { $1 - $0 }.filter { abs($0) > 1e-9 }
        let turns = zip(steps, steps.dropFirst()).filter { ($0 < 0) != ($1 < 0) }.count
        #expect(turns == 1)
        // Back at rest, and still, well before the dive.
        let landed = timeline.snapEnds + timeline.settle * SplashLogic.bounceShare
        #expect(close(reach(at: landed), 0))
        #expect(close(reach(at: landed - 0.001), 0, within: 0.01))
        #expect(close(reach(at: timeline.diveStarts), 0))
    }

    @Test func caseKicksThenIsStillForTheDive() {
        // About 5° at the peak of the kick.
        let peak = samples(from: timeline.snapEnds, to: timeline.diveStarts) {
            CGFloat(SplashLogic.kickDegrees * SplashLogic.kick(at: $0, in: timeline))
        }.max() ?? 0
        #expect(peak > 4.5 && peak < 5.5)
        #expect(SplashLogic.kick(at: timeline.snapEnds - 0.001, in: timeline) == 0)
        // Damped: each swing smaller than the last, and still when the dive starts.
        let swing = samples(from: timeline.snapEnds, to: timeline.diveStarts) {
            CGFloat(SplashLogic.kick(at: $0, in: timeline))
        }
        let extremes = zip(zip(swing, swing.dropFirst()), swing.dropFirst(2))
            .filter { pair, next in (pair.1 - pair.0) * (next - pair.1) < 0 }
            .map { abs($0.0.1) }
        #expect(extremes.count >= 2)
        #expect(zip(extremes, extremes.dropFirst()).allSatisfy { $1 < $0 })
        #expect(abs(SplashLogic.kick(at: timeline.diveStarts, in: timeline)) < 1e-9)
        #expect(abs(SplashLogic.kick(at: timeline.diveStarts - 0.001, in: timeline)) < 1e-4)
        #expect(close(SplashLogic.markOffset(at: timeline.diveStarts, in: timeline), 0))
        #expect(SplashLogic.diveProgress(at: timeline.diveStarts, in: timeline) == 0)
    }

    @Test func hubTurnsWithTheBladeAndComesBack() {
        #expect(SplashLogic.hubAngle(at: 0, in: timeline, screen: screen).radians == 0)
        #expect(SplashLogic.hubAngle(at: timeline.pull, in: timeline, screen: screen).radians < -1)
        #expect(abs(SplashLogic.hubAngle(at: timeline.diveStarts, in: timeline, screen: screen).radians) < 1e-9)
    }

    // MARK: - Counter

    @Test func counterReadsTheBlade() {
        func value(_ t: Double) -> Double { SplashLogic.counterValue(at: t, in: timeline, screen: screen) }
        #expect(value(0) == 0)
        #expect(abs(value(timeline.pull) - 1.2) < 1e-9)
        #expect(abs(value(timeline.snapStarts) - 1.2) < 1e-9)
        // Most of the reading comes early, with the blade.
        #expect(value(timeline.pull / 2) > 1)
        // It keeps the reading as it fades out during the whip, rather than counting down.
        #expect(abs(value(timeline.snapStarts + timeline.snap / 2) - 1.2) < 1e-9)
        #expect(abs(value(timeline.snapEnds) - 1.2) < 1e-9)
        // Only ever counts up.
        let readings = samples(from: 0, to: timeline.snapEnds) { CGFloat(value($0)) }
        #expect(zip(readings, readings.dropFirst()).allSatisfy { $1 >= $0 })
    }

    @Test func counterFadesInWithThePullAndOutWithTheSnap() {
        #expect(SplashLogic.counterOpacity(at: 0, in: timeline) == 0)
        #expect(SplashLogic.counterOpacity(at: timeline.pull, in: timeline) == 1)
        #expect(SplashLogic.counterOpacity(at: timeline.snapStarts, in: timeline) == 1)
        #expect(SplashLogic.counterOpacity(at: timeline.snapEnds, in: timeline) == 0)
    }

    @Test func counterSitsOverTheMiddleOfTheBladeAndStaysPutForTheSnap() {
        let caseEdge = TapeMark.caseSide * SplashLogic.pointsPerUnit
        let hookEnd = SplashLogic.markSize.width + SplashLogic.pullReach(screen: screen)
        let held = SplashLogic.counterX(at: timeline.pull, in: timeline, screen: screen)
        #expect(close(held, (caseEdge + hookEnd) / 2))
        #expect(close(SplashLogic.counterX(at: timeline.snapEnds, in: timeline, screen: screen), held))
    }

    // MARK: - Dive

    @Test func diveDipsThenPushesPast() {
        #expect(SplashLogic.diveScale(at: timeline.diveStarts + timeline.dive * 0.1, in: timeline) < 1)
        #expect(SplashLogic.diveScale(at: timeline.diveStarts + timeline.dive * 0.1, in: timeline) >= 0.94)
        #expect(close(SplashLogic.diveScale(at: timeline.total, in: timeline), 6, within: 0.001))
        #expect(SplashLogic.appScale(at: timeline.diveStarts, in: timeline) < 1)
        // Nothing starts from nothing: the mark is at full size until the dive,
        // and the app never smaller than 94 %.
        #expect(samples(from: 0, to: timeline.diveStarts) { SplashLogic.diveScale(at: $0, in: timeline) }.allSatisfy { $0 == 1 })
        #expect(samples(from: 0, to: timeline.total) { SplashLogic.appScale(at: $0, in: timeline) }.allSatisfy { $0 >= 0.94 })
    }

    @Test func appEndsAtFullSize() {
        #expect(close(SplashLogic.appScale(at: timeline.total, in: timeline), 1))
        #expect(SplashLogic.diveProgress(at: timeline.total, in: timeline) == 1)
    }

    @Test func creditFadesInWithThePullAndOutWithTheDive() {
        #expect(SplashLogic.creditOpacity(at: 0, in: timeline) == 0)
        #expect(SplashLogic.creditOpacity(at: timeline.pull, in: timeline) == 1)
        #expect(SplashLogic.creditOpacity(at: timeline.diveStarts, in: timeline) == 1)
        #expect(abs(SplashLogic.creditOpacity(at: timeline.total, in: timeline)) < 0.001)
        // Never pops: each fade spreads over at least six 60 Hz frames. The
        // fade-out runs with the blue it sits on, fast at first like the dive.
        let fade = samples(from: 0, to: timeline.total, count: Int(timeline.total * 60)) {
            CGFloat(SplashLogic.creditOpacity(at: $0, in: timeline))
        }
        #expect(zip(fade, fade.dropFirst()).allSatisfy { abs($1 - $0) < 0.2 })
    }
}
