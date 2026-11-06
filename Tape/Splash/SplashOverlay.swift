//
//  SplashOverlay.swift
//  Tape
//
//  The opening animation, played once per cold launch on top of the app. It
//  starts on the launch screen's exact picture (baby blue, tape measure
//  centred), so iOS hands over without a flash. The app underneath is already
//  live, so the exit lands on the real converter. A tap skips straight to it.
//
//  Every position comes from SplashLogic as a function of elapsed time; this
//  view only reads the clock and draws.
//

import SwiftUI

struct SplashOverlay: View {
    let haptics: Bool
    var timeline = SplashLogic.Timeline()
    /// When the clock starts, so the app underneath can move in step.
    var onStart: (Date) -> Void = { _ in }
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?
    @State private var bumps = 0
    @State private var skipped = false

    var body: some View {
        ZStack {
            if reduceMotion {
                still.ignoresSafeArea()
                credit
            } else {
                TimelineView(.animation(paused: start == nil)) { context in
                    let t = start.map { context.date.timeIntervalSince($0) } ?? 0
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
        .sensoryFeedback(trigger: bumps) { _, count in
            guard haptics, count > 0 else { return nil }
            return switch timeline.variant {
            case .pull: .impact(flexibility: .rigid, intensity: 0.9)
            case .wipe: .impact(weight: .light, intensity: 0.6)
            case .reel: .impact(flexibility: .soft, intensity: 0.8)
            }
        }
        .task { await run() }
        .accessibilityHidden(true)
    }

    // MARK: - Drawing

    private func frame(at t: Double, screen: CGSize) -> some View {
        let p = SplashLogic.diveProgress(at: t, in: timeline)

        return ZStack {
            ground(at: t, screen: screen, dive: p)
            mark(at: t, screen: screen)
                .offset(SplashLogic.markOffset(at: t, in: timeline, screen: screen))
                // Only the mark blurs; blurring flat blue costs a full-screen
                // pass for nothing.
                .scaleEffect(SplashLogic.diveScale(at: t, in: timeline))
                .blur(radius: 8 * p)
                .opacity(1 - p)
        }
        .frame(width: screen.width, height: screen.height)
    }

    /// The blue. For the dive it fades as a whole. For the wipe it splits at
    /// the blade's top edge: the part below travels down with the blade, the
    /// part above fades as the blade sets off.
    @ViewBuilder
    private func ground(at t: Double, screen: CGSize, dive p: Double) -> some View {
        if timeline.variant == .wipe {
            let line = SplashLogic.revealLine(at: t, in: timeline, screen: screen)
            ZStack {
                // 1 pt of overlap so no hairline of app shows between the two.
                TapeMark.blue
                    .offset(y: line - screen.height + 1)
                    .opacity(SplashLogic.upperGroundOpacity(at: t, in: timeline))
                TapeMark.blue
                    .offset(y: line)
            }
        } else {
            TapeMark.blue.opacity(1 - p)
        }
    }

    private func mark(at t: Double, screen: CGSize) -> some View {
        let size = SplashLogic.markSize
        let unit = SplashLogic.pointsPerUnit
        let reach = SplashLogic.bladeReach(at: t, in: timeline, screen: screen)

        return ZStack {
            TapeMarkView(reach: reach / unit,
                         hubAngle: SplashLogic.hubAngle(at: t, in: timeline, screen: screen))
            if timeline.variant == .pull {
                // Centred over the blade that's showing, just above the hook.
                counter(SplashLogic.counterValue(at: t, in: timeline, screen: screen))
                    .position(x: (TapeMark.caseSide * unit + size.width + reach) / 2,
                              y: TapeMark.hookTop * unit - 14)
                    .opacity(SplashLogic.counterOpacity(at: t, in: timeline))
            }
            if timeline.variant == .reel {
                // Beside the case, level with the hub.
                slot(at: t)
                    .position(x: TapeMark.caseSide * unit + 8 + SplashLogic.slotSize.width / 2,
                              y: TapeMark.hub.y * unit)
                    .opacity(SplashLogic.slotOpacity(at: t, in: timeline))
            }
        }
        .frame(width: size.width, height: size.height)
        .rotationEffect(.degrees(SplashLogic.recoilDegrees * SplashLogic.recoil(at: t, in: timeline)))
    }

    private func counter(_ metres: Double) -> some View {
        Text("\(metres.formatted(.number.precision(.fractionLength(2)))) m")
            .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(TapeMark.navy)
            .fixedSize()
    }

    /// A white window the unit symbols roll up through.
    private func slot(at t: Double) -> some View {
        let height = SplashLogic.slotSize.height
        return VStack(spacing: 0) {
            ForEach(SplashLogic.tickerUnits, id: \.self) { unit in
                Text(unit)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .frame(width: SplashLogic.slotSize.width, height: height)
            }
        }
        .offset(y: -SplashLogic.tickerPosition(at: t, in: timeline) * height)
        .frame(width: SplashLogic.slotSize.width, height: height, alignment: .top)
        .clipped()
        .background(.white, in: .rect(cornerRadius: 8))
        .foregroundStyle(TapeMark.navy)
    }

    /// Reduce Motion: no pull, no spin, no exit move. The mark holds, then the
    /// blue fades away.
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
            HStack(alignment: .center, spacing: 8) {
                Text("Made by")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Image("DevAkintola")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                    .accessibilityLabel("DevAkintola")
            }
            .foregroundStyle(TapeMark.navy)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Timing

    private func run() async {
        if reduceMotion {
            try? await Task.sleep(for: .seconds(0.15))
            withAnimation(.easeOut(duration: 0.2)) { skipped = true }
            try? await Task.sleep(for: .seconds(0.2))
            onFinish()
            return
        }
        let began = Date.now
        start = began
        onStart(began)
        for (index, time) in timeline.hapticTimes.enumerated() {
            try? await Task.sleep(for: .seconds(max(time - Date.now.timeIntervalSince(began), 0)))
            bumps = index + 1
        }
        try? await Task.sleep(for: .seconds(max(timeline.total - Date.now.timeIntervalSince(began), 0)))
        onFinish()
    }

    private func skip() {
        withAnimation(.easeOut(duration: 0.15)) { skipped = true }
        Task {
            try? await Task.sleep(for: .seconds(0.15))
            onFinish()
        }
    }
}
