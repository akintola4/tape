//
//  TapeApp.swift
//  Tape
//
//  Tape converts one number into every other unit of its category at once.
//  One screen, no network, no account.
//

import SwiftUI

@main
struct TapeApp: App {
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ConverterView(settings: settings)
        }
    }
}

// MARK: - Launch arguments

/// Debug-only switches for screenshots, set in the scheme or passed to
/// `simctl launch`. Each one only changes what the app opens on; nothing is
/// saved until you change it by hand.
enum LaunchOptions {
    /// `-TapeCategory area`: open on this category.
    static var category: UnitCategory? { value(after: "-TapeCategory").flatMap(UnitCategory.init(rawValue:)) }

    /// `-TapeUnit plot`: the input unit, by id (see `UnitCatalog`).
    static var unitID: String? { value(after: "-TapeUnit") }

    /// `-TapeAmount 2.5`: the amount, as you'd type it.
    static var amount: String? { value(after: "-TapeAmount") }

    /// `-TapeOpenSettings`: open the settings sheet on launch.
    static var openSettings: Bool { flag("-TapeOpenSettings") }

    /// `-TapeDemoToast`: show the "Copied" toast for the first row, and leave it up.
    static var demoToast: Bool { flag("-TapeDemoToast") }

    /// `-TapeDemoTyping "2.5<<<8"`: after a moment, types this into the amount
    /// field one key at a time; `<` is delete. For recording the drawing change.
    static var demoTyping: String? { value(after: "-TapeDemoTyping") }

    private static func flag(_ name: String) -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(name)
        #else
        false
        #endif
    }

    private static func value(after name: String) -> String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
        #else
        nil
        #endif
    }
}
