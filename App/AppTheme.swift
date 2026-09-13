import SwiftUI

enum AppTheme {
    static let canvas = Color(red: 0.035, green: 0.047, blue: 0.055)
    static let surface = Color(red: 0.075, green: 0.094, blue: 0.106)
    static let elevated = Color(red: 0.11, green: 0.135, blue: 0.15)
    static let ink = Color(red: 0.94, green: 0.96, blue: 0.93)
    static let muted = Color(red: 0.57, green: 0.63, blue: 0.62)
    static let lime = Color(red: 0.70, green: 1.0, blue: 0.31)
    static let orange = Color(red: 1.0, green: 0.55, blue: 0.25)
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
}
