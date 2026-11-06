//
//  SplashLogicTests.swift
//  TapeTests
//
//  The opening animation's timeline in all three variants: phases in order,
//  inside the time budget, the blade home before the dive, the ticker on
//  "plot", the app at full size at the end, and a mark the same size as the
//  launch screen image.
//

import Testing
import Foundation
import SwiftUI
@testable import Tape

private let screen = CGSize(width: 402, height: 874)   // iPhone 17 Pro

private func close(_ a: CGFloat, _ b: CGFloat, within tolerance: CGFloat = 1e-6) -> Bool {
    abs(a - b) <= tolerance
}

private func timeline(_ variant: SplashLogic.Variant) -> SplashLogic.Timeline {
    SplashLogic.Timeline(variant: variant)
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
    }

    @Test func restingBladeShowsTheIconsTwoTicks() {
        let ticks = TapeMark.ticks(reach: 0)
        #expect(ticks.map(\.minX) == [484, 514])
        #expect(ticks.map(\.height) == [52, 30])
        // Pulled out, more come out from under the case and none sit over it.
        let pulled = TapeMark.ticks(reach: 400)
        #expect(pulled.count > ticks.count)
        #expect(pulled.allSatisfy { $0.minX >= TapeMark.tickClipX && $0.width > 0 })
    }

    @Test func variantDefaultsToPull() {
        #expect(SplashLogic.Timeline().variant == .pull)
        #expect(SplashLogic.Variant(rawValue: "wipe") == .wipe)
        #expect(SplashLogic.Variant(rawValue: "nope") == nil)
    }

    // MARK: - Timing

    @Test(arguments: SplashLogic.Variant.allCases)
    func totalIsInsideTheBudget(_ variant: SplashLogic.Variant) {
        let t = timeline(variant)
        #expect(t.total >= 1.6 && t.total <= 2.2)
        #expect(t.exitStarts > 0 && t.exitStarts < t.total)
        #expect(t.hapticTimes.allSatisfy { $0 > 0 && $0 <= t.exitStarts })
    }

    @Test(arguments: SplashLogic.Variant.allCases)
    func slowMotionStretchesEveryPhase(_ variant: SplashLogic.Variant) {
        let normal = timeline(variant)
        let slow = normal.slowed(by: 4)
        #expect(abs(slow.total - normal.total * 4) < 1e-9)
        #expect(abs(slow.exitStarts - normal.exitStarts * 4) < 1e-9)
        #expect(slow.variant == variant)
    }

    @Test func pullPhasesRunInOrder() {
        let t = timeline(.pull)
        #expect(t.pull < t.snapStarts)
        #expect(t.snapStarts < t.snapEnds)
        #expect(t.snapEnds < t.exitStarts)
        #expect(t.hapticTimes == [t.snapEnds])
    }

    // MARK: - Pull

    @Test func pullCatchesAtTheScreenEdgeAndHolds() {
        let t = timeline(.pull)
        let full = SplashLogic.pullReach(screen: screen)
        #expect(close(SplashLogic.bladeReach(at: 0, in: t, screen: screen), 0))
        #expect(close(SplashLogic.bladeReach(at: t.pull, in: t, screen: screen), full))
        #expect(close(SplashLogic.bladeReach(at: t.snapStarts - 0.01, in: t, screen: screen), full))
        // The hook's outer edge is exactly at the right edge of the screen.
        #expect(close(screen.width / 2 + SplashLogic.markSize.width / 2 + full, screen.width))
        #expect(close(CGFloat(SplashLogic.counterValue(at: t.pull, in: t, screen: screen)), 1.2))
        #expect(SplashLogic.counterOpacity(at: t.pull, in: t) == 1)
        #expect(SplashLogic.counterOpacity(at: t.snapEnds, in: t) == 0)
    }

    @Test func bladeIsBackAtRestBeforeTheDive() {
        let t = timeline(.pull)
        #expect(close(SplashLogic.bladeReach(at: t.snapEnds, in: t, screen: screen), 0))
        // One small bounce into the case after it snaps home…
        #expect(SplashLogic.bladeReach(at: t.snapEnds + t.settle * 0.2, in: t, screen: screen) < 0)
        // …and the case kicks, then is still before the dive.
        #expect(abs(SplashLogic.recoil(at: t.snapEnds + t.settle * 0.15, in: t)) > 0.3)
        #expect(close(SplashLogic.bladeReach(at: t.exitStarts, in: t, screen: screen), 0))
        #expect(abs(SplashLogic.recoil(at: t.exitStarts, in: t)) < 1e-9)
        #expect(close(SplashLogic.markOffset(at: t.exitStarts, in: t, screen: screen).width, 0))
        #expect(SplashLogic.diveProgress(at: t.exitStarts, in: t) == 0)
    }

    @Test func snapIsFasterThanThePull() {
        let t = timeline(.pull)
        #expect(t.snap < t.pull / 2)
        // Ease-in: it has covered less than half the way back at half time.
        let full = SplashLogic.pullReach(screen: screen)
        let half = SplashLogic.bladeReach(at: t.snapStarts + t.snap / 2, in: t, screen: screen)
        #expect(half > full / 2)
    }

    // MARK: - Wipe

    @Test func wipeSpansTheScreenThenLeavesOffTheBottom() {
        let t = timeline(.wipe)
        let reach = SplashLogic.bladeReach(at: t.pull, in: t, screen: screen)
        let offset = SplashLogic.markOffset(at: t.pull, in: t, screen: screen)
        let markLeft = screen.width / 2 - SplashLogic.markSize.width / 2 + offset.width
        #expect(close(markLeft, SplashLogic.caseInset))
        #expect(close(markLeft + SplashLogic.markSize.width + reach, screen.width))

        // The reveal line starts at the blade's top edge and ends below the
        // screen, with the whole case off the bottom too.
        let startLine = SplashLogic.revealLine(at: 0, in: t, screen: screen)
        #expect(close(startLine, screen.height / 2 - SplashLogic.markSize.height / 2 + TapeMark.bladeTop * SplashLogic.pointsPerUnit))
        let end = SplashLogic.markOffset(at: t.total, in: t, screen: screen)
        #expect(screen.height / 2 - SplashLogic.markSize.height / 2 + end.height > screen.height)
        #expect(SplashLogic.revealLine(at: t.total, in: t, screen: screen) > screen.height)

        #expect(SplashLogic.upperGroundOpacity(at: t.exitStarts, in: t) == 1)
        #expect(SplashLogic.upperGroundOpacity(at: t.total, in: t) == 0)
        #expect(t.hapticTimes == [t.pull])
    }

    @Test func wipeTravelEasesInAndOut() {
        let t = timeline(.wipe)
        let distance = SplashLogic.travelDistance(screen: screen)
        let early = SplashLogic.markOffset(at: t.exitStarts + t.travel * 0.1, in: t, screen: screen).height
        let middle = SplashLogic.markOffset(at: t.exitStarts + t.travel * 0.5, in: t, screen: screen).height
        #expect(early < distance * 0.1)
        #expect(close(middle, distance / 2, within: distance * 0.02))
    }

    // MARK: - Reel

    @Test func tickerLandsOnPlot() {
        let t = timeline(.reel)
        #expect(SplashLogic.tickerUnits.last == "plot")
        #expect(Set(SplashLogic.tickerUnits).count == SplashLogic.tickerUnits.count)
        #expect(SplashLogic.tickerUnit(at: 0, in: t) == SplashLogic.tickerUnits.first)
        let last = CGFloat(SplashLogic.tickerUnits.count - 1)
        #expect(close(SplashLogic.tickerPosition(at: t.roll, in: t), last))
        #expect(close(SplashLogic.tickerPosition(at: t.exitStarts, in: t), last))
        #expect(SplashLogic.tickerUnit(at: t.exitStarts, in: t) == "plot")
        #expect(SplashLogic.tickerUnit(at: t.total, in: t) == "plot")
        #expect(t.hapticTimes == [t.roll])
    }

    @Test func tickerOnlyMovesForward() {
        let t = timeline(.reel)
        var previous = SplashLogic.tickerPosition(at: 0, in: t)
        for step in 1...100 {
            let now = SplashLogic.tickerPosition(at: t.roll * Double(step) / 100, in: t)
            #expect(now >= previous)
            previous = now
        }
    }

    @Test func hubSpinsWithTheTickerAndStops() {
        let t = timeline(.reel)
        let landed = SplashLogic.hubAngle(at: t.roll, in: t, screen: screen).degrees
        #expect(abs(landed - 360 * SplashLogic.reelTurns) < 1e-6)
        #expect(abs(SplashLogic.hubAngle(at: t.exitStarts, in: t, screen: screen).degrees - landed) < 1e-6)
        #expect(SplashLogic.slotOpacity(at: 0, in: t) == 0)
        #expect(SplashLogic.slotOpacity(at: t.roll, in: t) == 1)
    }

    // MARK: - Exit

    @Test(arguments: SplashLogic.Variant.allCases)
    func appEndsAtFullSize(_ variant: SplashLogic.Variant) {
        let t = timeline(variant)
        #expect(close(SplashLogic.appScale(at: t.total, in: t), 1))
        #expect(abs(SplashLogic.creditOpacity(at: t.total, in: t)) < 0.001)
        #expect(SplashLogic.creditOpacity(at: 0, in: t) == 0)
    }

    @Test(arguments: [SplashLogic.Variant.pull, .reel])
    func diveDipsThenPushesPast(_ variant: SplashLogic.Variant) {
        let t = timeline(variant)
        #expect(SplashLogic.diveScale(at: t.exitStarts + t.dive * 0.1, in: t) < 1)
        #expect(close(SplashLogic.diveScale(at: t.total, in: t), 6, within: 0.001))
        #expect(SplashLogic.appScale(at: t.exitStarts, in: t) < 1)
        #expect(SplashLogic.creditOpacity(at: t.exitStarts, in: t) == 1)
        // Nothing starts from nothing: the mark is at full size until the dive.
        #expect(SplashLogic.diveScale(at: 0, in: t) == 1)
    }

    @Test func wipeNeverScalesTheApp() {
        let t = timeline(.wipe)
        for step in 0...20 {
            let time = t.total * Double(step) / 20
            #expect(SplashLogic.appScale(at: time, in: t) == 1)
            #expect(SplashLogic.diveScale(at: time, in: t) == 1)
        }
    }
}
