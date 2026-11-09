//
//  ConverterUITests.swift
//  TapeUITests
//
//  The converter with real touches. `-TapeNoSplash` skips the opening
//  animation, and `-TapeCategory`/`-TapeUnit`/`-TapeAmount` pick what it opens
//  on, so nothing depends on what an earlier run left behind. XCTest because
//  Swift Testing can't drive the UI.
//

import XCTest

@MainActor
final class ConverterUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-TapeNoSplash",
            "-TapeCategory", "area", "-TapeUnit", "plot", "-TapeAmount", "5",
            // Number formatting follows the region, so pin it.
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()
    }

    private var amountField: XCUIElement { app.textFields["amount-field"] }

    private func row(_ unitID: String) -> XCUIElement {
        app.descendants(matching: .any)["result-\(unitID)"]
    }

    /// Waits until `element` matches `format`, without a fixed sleep.
    private func wait(for element: XCUIElement, _ format: String, _ args: any CVarArg..., timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: format, argumentArray: args)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// No splash: the converter is the first thing on screen, on Area with
    /// the amount from the launch arguments.
    func testOpensOnTheConverter() {
        XCTAssertTrue(app.staticTexts["Tape"].waitForExistence(timeout: 5))
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        XCTAssertEqual(amountField.value as? String, "5")
        XCTAssertTrue(app.buttons["Area"].isSelected)
        XCTAssertTrue(app.buttons["Settings"].exists)
        XCTAssertTrue(row("m2").waitForExistence(timeout: 5))
    }

    /// Typing 1 plot lists 668.9 m², the default 60 × 120 ft plot.
    func testTypingOnePlotShowsSquareMetres() {
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        // Works with or without the Simulator's hardware keyboard connected.
        XCTAssertTrue(wait(for: amountField, "hasKeyboardFocus == true"))
        let current = amountField.value as? String ?? ""
        amountField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 1))
        amountField.typeText("1")

        XCTAssertTrue(wait(for: amountField, "value == %@", "1"), "Amount was \(amountField.value ?? "nil")")
        let squareMetres = row("m2")
        XCTAssertTrue(wait(for: squareMetres, "label CONTAINS %@", "668.9 m²"), "Row was \(squareMetres.label)")
        XCTAssertTrue(wait(for: row("ft2"), "label CONTAINS %@", "7,200 ft²"))
    }
}
