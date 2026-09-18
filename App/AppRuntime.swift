import Foundation

enum AppRuntime {
    static var isUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
        #else
        false
        #endif
    }
    static var preferences: UserDefaults {
        isUITest ? UserDefaults(suiteName: "LidlLean.UITests")! : .standard
    }
    static var usesFixtures: Bool { isUITest && ProcessInfo.processInfo.arguments.contains("-seed-fixtures") }
}
