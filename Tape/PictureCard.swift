//
//  PictureCard.swift
//  Tape
//
//  "Picture it": one plain line about the amount, and a drawing of something
//  you already know the size of. Which thing, and how many, comes from
//  `PictureLogic`; this file only draws it.
//

import SwiftUI

struct PictureCard: View {
    let picture: Picture

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title3) private var drawingHeight: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            Text("\(picture.lead)\(Text(picture.emphasis).foregroundStyle(Theme.accent))\(picture.trail)")
                .font(Theme.display(.title3).weight(.heavy))
                .fixedSize(horizontal: false, vertical: true)
            Text(picture.detail)
                .font(Tokens.Typography.text(.footnote))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            drawing
                .frame(maxWidth: .infinity)
                .frame(height: min(drawingHeight, 180))
                .padding(.top, Tokens.Spacing.md)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(picture.sentence). \(picture.detail)")
    }

    private var drawing: some View {
        ZStack {
            switch picture.drawing {
            case .tally(let tally):
                TallyDrawing(tally: tally)
                    .id(tally.object)
                    .transition(.opacity)
            case .door(let metres):
                DoorDrawing(personMetres: metres)
                    .id("door")
                    .transition(.opacity)
            case .thermometer(let fill):
                ThermometerDrawing(fill: fill)
                    .id("thermometer")
            }
        }
        // Only the drawing moves: blocks arrive and leave, fills rise and fall.
        .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0), value: picture.drawing)
    }
}

// MARK: - Counts of things

private struct TallyDrawing: View {
    let tally: Tally

    @State private var size: CGSize = .zero
    private let spacing: CGFloat = 6

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
    }

    @ViewBuilder private var content: some View {
        if let overflow = tally.overflow {
            let cell = PictureLogic.grid(count: 1, aspect: tally.aspect, width: size.width * 0.55,
                                         height: size.height, spacing: spacing, maxHeight: size.height * 0.8)
            HStack(spacing: Tokens.Spacing.md) {
                ObjectView(object: tally.object, fill: 1, label: nil)
                    .frame(width: cell.cellWidth, height: cell.cellHeight)
                Text(overflow)
                    .font(Theme.display(.title2).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let cells = PictureLogic.cells(for: tally, width: size.width, height: size.height,
                                           spacing: spacing, maxHeight: size.height * 0.8,
                                           maxWidth: size.width * 0.6)
            ZStack(alignment: .topLeading) {
                ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                    ObjectView(object: tally.object, fill: cell.fill, outlined: cell.outlined,
                               label: tally.labels.indices.contains(index) ? tally.labels[index] : nil)
                        .frame(width: cell.width, height: cell.height)
                        .offset(x: cell.x, y: cell.y)
                        .transition(.opacity)
                }
            }
        }
    }
}

/// One object, full or partly filled. A part shows the whole outline, dashed,
/// so you can see how much of one it is.
private struct ObjectView: View {
    let object: PictureObject
    let fill: Double
    var outlined = true
    let label: String?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                if fill < 1, outlined {
                    ObjectShape(object: object)
                        .stroke(Theme.chipFill, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }
                ZStack {
                    ObjectShape(object: object).fill(Theme.chipFill)
                    ObjectShape(object: object, layer: .detail).fill(Theme.cardBackground)
                }
                .mask(alignment: object.fillsFromBottom ? .bottom : .leading) {
                    Rectangle().frame(
                        width: object.fillsFromBottom ? nil : size.width * fill,
                        height: object.fillsFromBottom ? size.height * fill : nil
                    )
                }
            }
            .overlay(alignment: .bottom) {
                if let label {
                    Text(label)
                        .font(Theme.display(.subheadline).weight(.heavy))
                        .monospacedDigit()
                        .foregroundStyle(Theme.chipText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.bottom, size.height * 0.14)
                }
            }
        }
    }
}

// MARK: - Heights

/// A person `personMetres` tall beside a 2.1 m door, both to scale.
private struct DoorDrawing: View {
    let personMetres: Double

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let scale = height / max(PictureLogic.doorMetres, personMetres)
            let person = personMetres * scale
            let doorHeight = PictureLogic.doorMetres * scale
            HStack(alignment: .bottom, spacing: Tokens.Spacing.lg) {
                HeightBracket()
                    .stroke(.secondary.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 12, height: person)
                PersonShape()
                    .fill(Theme.chipFill)
                    .frame(width: person * 0.3, height: person)
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Theme.chipFill, lineWidth: 3)
                    .overlay(alignment: .trailing) {
                        Circle().fill(Theme.chipFill)
                            .frame(width: 6, height: 6)
                            .padding(.trailing, doorHeight * 0.06)
                    }
                    .frame(width: 0.9 * scale, height: doorHeight)
                    .padding(.leading, Tokens.Spacing.sm)
            }
            .frame(width: geometry.size.width, height: height, alignment: .bottom)
        }
    }
}

/// An I-beam: a vertical line with a tick at each end.
private struct HeightBracket: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        for y in [r.minY, r.maxY] {
            p.move(to: CGPoint(x: r.minX, y: y))
            p.addLine(to: CGPoint(x: r.maxX, y: y))
        }
        return p
    }
}

// MARK: - Temperature

private struct ThermometerDrawing: View {
    let fill: Double

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let bulb = min(36, height * 0.26)
            let rise = height - bulb
            let freezing = PictureLogic.thermometerFill(celsius: 0)
            HStack(alignment: .bottom, spacing: Tokens.Spacing.sm) {
                ZStack {
                    ThermometerShape()
                        .stroke(Theme.chipFill, lineWidth: 2)
                    ThermometerShape()
                        .fill(Theme.chipFill)
                        .mask(alignment: .bottom) {
                            Rectangle().frame(height: bulb + rise * fill)
                        }
                }
                .frame(width: bulb, height: height)
                ZStack(alignment: .topLeading) {
                    tick("100 °C", at: 0)
                    tick("0 °C", at: rise * (1 - freezing))
                }
                .frame(width: 64, height: height, alignment: .topLeading)
            }
            .frame(width: geometry.size.width, height: height)
            .offset(x: 32)
        }
    }

    private func tick(_ text: String, at y: CGFloat) -> some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Rectangle().fill(.secondary.opacity(0.6)).frame(width: 8, height: 1.5)
            Text(text)
                .font(Tokens.Typography.text(.caption2))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .frame(height: 12)
        .offset(y: y - 6)
    }
}
