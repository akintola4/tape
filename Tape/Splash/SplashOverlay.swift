//
//  SplashOverlay.swift
//  Tape
//
//  The opening animation, played once per cold launch on top of the app. It
//  starts on the launch screen's exact picture (baby blue, tape measure
//  centred), so iOS hands over without a flash. The app underneath is already
//  live, so the dive lands on the real converter. A tap skips straight to it.
//
//  Every position comes from SplashLogic as a function of elapsed time; this
//  view only reads the clock and draws.
//

import SwiftUI

struct SplashOverlay: View {
    let haptics: Bool
    var timeline = SplashLogic.Timeline()
    /// Debug: draw this moment and stay on it, for stills.
    var frozenAt: Double?
    /// When the clock starts, so the app underneath can move in step.
    var onStart: (Date) -> Void = { _ in }
    /// Called inside the tap's animation, so the app can settle with the fade.
    var onSkip: () -> Void = {}
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @State private var start: Date?
    @State private var snapped = false
    @State private var skipped = false
    @State private var creditShown = false

    var body: some View {
        ZStack {
            if reduceMotion {
                still.ignoresSafeArea()
                credit.opacity(creditShown ? 1 : 0)
            } else {
                TimelineView(.animation(paused: start == nil)) { context in
                    let t = frozenAt ?? start.map { context.date.timeIntervalSince($0) } ?? 0
                    ZStack {
                        // Full screen, so the mark sits where the launch image did.
                        GeometryReader { proxy in
                            frame(at: t, screen: proxy.size)
                        }
                        .ignoresSafeArea()
                        credit.opacity(SplashLogic.creditOpacity(at: t, in: timeline))
                    }
                }
            }
        }
        .opacity(skipped ? 0 : 1)
        .contentShape(.rect)
        .onTapGesture(perform: skip)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.9), trigger: snapped) { _, hit in
            haptics && hit
        }
        .task { await run() }
        .accessibilityHidden(true)
    }

    // MARK: - Drawing

    private func frame(at t: Double, screen: CGSize) -> some View {
        let p = SplashLogic.diveProgress(at: t, in: timeline)

        return ZStack {
            TapeMark.blue.opacity(1 - p)
            mark(at: t, screen: screen)
                .offset(x: SplashLogic.markOffset(at: t, in: timeline))
                // Only the mark blurs; blurring flat blue costs a full-screen
                // pass for nothing.
                .scaleEffect(SplashLogic.diveScale(at: t, in: timeline))
                .blur(radius: 8 * p)
                .opacity(1 - p)
        }
        .frame(width: screen.width, height: screen.height)
    }

    private func mark(at t: Double, screen: CGSize) -> some View {
        let reach = SplashLogic.snapped(SplashLogic.bladeReach(at: t, in: timeline, screen: screen), scale: displayScale)

        return ZStack {
            TapeMarkView(reach: reach,
                         hubAngle: SplashLogic.hubAngle(at: t, in: timeline, screen: screen))
            // Over the middle of the blade that's showing, sitting on a line
            // `counterGap` above it: a zero-size anchor whose bottom is that
            // line, with the text hung off it by its baseline.
            Color.clear
                .frame(width: 0, height: 0)
                .overlay(alignment: Alignment(horizontal: .center, vertical: .lastTextBaseline)) {
                    counter(SplashLogic.counterValue(at: t, in: timeline, screen: screen))
                }
                .position(x: SplashLogic.snapped(SplashLogic.counterX(at: t, in: timeline, screen: screen), scale: displayScale),
                          y: TapeMark.bladeTop * SplashLogic.pointsPerUnit - SplashLogic.counterGap)
                .opacity(SplashLogic.counterOpacity(at: t, in: timeline))
        }
        .frame(width: SplashLogic.markSize.width, height: SplashLogic.markSize.height)
        .rotationEffect(.degrees(SplashLogic.kickDegrees * SplashLogic.kick(at: t, in: timeline)))
    }

    /// "1.20 m": tabular digits so the reading doesn't jiggle or change width
    /// as it counts, and a narrow no-break space before the unit, as SI writes it.
    private func counter(_ metres: Double) -> some View {
        Text("\(metres.formatted(.number.precision(.fractionLength(2))))\u{202F}m")
            .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(TapeMark.navy)
            .fixedSize()
    }

    /// Reduce Motion: no pull, no spin, no dive. The mark holds while the
    /// credit fades in, then everything fades away.
    private var still: some View {
        ZStack {
            TapeMark.blue
            TapeMarkView()
        }
    }

    /// "Made by" and the DEVAKINTOLA wordmark, above the home indicator. The
    /// launch screen can only hold one centred image, so this fades in with
    /// the first motion rather than popping on.
    private var credit: some View {
        VStack {
            Spacer()
            // 8 pt between the inks: the y's side bearing adds the other 1⅓.
            // Centred, the wordmark's middle lands on the middle of the capitals.
            HStack(alignment: .center, spacing: 20.0 / 3) {
                Text("Made by")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Image("DevAkintola")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                    .accessibilityLabel("DevAkintola")
            }
            .foregroundStyle(TapeMark.navy)
            // The M's side bearing sits the inks a pixel right of centre.
            .offset(x: -1.0 / 3)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Timing

    private func run() async {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { creditShown = true }
            try? await Task.sleep(for: .seconds(0.45))
            withAnimation(.easeOut(duration: 0.2)) { skipped = true }
            try? await Task.sleep(for: .seconds(0.2))
            onFinish()
            return
        }
        // A frozen still never starts the clock, buzzes or leaves.
        guard frozenAt == nil else { return }
        let began = Date.now
        start = began
        onStart(began)
        // A tap takes over: no buzz for a snap you didn't watch.
        guard await sleep(until: timeline.snapEnds, from: began), !skipped else { return }
        snapped = true
        guard await sleep(until: timeline.total, from: began), !skipped else { return }
        onFinish()
    }

    /// False if the overlay went away while waiting.
    private func sleep(until time: Double, from began: Date) async -> Bool {
        do {
            try await Task.sleep(for: .seconds(max(time - Date.now.timeIntervalSince(began), 0)))
            return true
        } catch {
            return false
        }
    }

    private func skip() {
        guard !skipped else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            skipped = true
            onSkip()
        }
        Task {
            try? await Task.sleep(for: .seconds(0.15))
            onFinish()
        }
    }
}
