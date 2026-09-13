import SwiftUI

enum AppTheme {
    static let canvas = Color(red: 0.956, green: 0.965, blue: 0.976)
    static let surface = Color.white
    static let elevated = Color(red: 0.922, green: 0.941, blue: 0.969)
    static let ink = Color(red: 0.055, green: 0.102, blue: 0.184)
    static let muted = Color(red: 0.36, green: 0.42, blue: 0.51)
    static let primary = Color(red: 0.08, green: 0.31, blue: 0.84)
    static let success = Color(red: 0.02, green: 0.57, blue: 0.45)
    static let warning = Color(red: 0.93, green: 0.39, blue: 0.16)
    static let lime = primary
    static let orange = warning
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.045)) }
            .shadow(color: AppTheme.ink.opacity(0.055), radius: 16, y: 7)
    }
}

struct SectionEyebrow: View {
    let title: String
    var body: some View {
        Text(title.uppercased()).font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(AppTheme.primary)
    }
}

struct PrimaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(.white)
            .background(configuration.isPressed ? AppTheme.primary.opacity(0.78) : AppTheme.primary,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
