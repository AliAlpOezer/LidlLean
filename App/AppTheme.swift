import SwiftUI

enum AppTheme {
    static let canvas = Color(red: 0.965, green: 0.969, blue: 0.957)
    static let surface = Color.white
    static let elevated = Color(red: 0.902, green: 0.929, blue: 0.906)
    static let ink = Color(red: 0.035, green: 0.071, blue: 0.118)
    static let muted = Color(red: 0.36, green: 0.41, blue: 0.46)
    static let primary = Color(red: 0.075, green: 0.255, blue: 0.62)
    static let success = Color(red: 0.055, green: 0.49, blue: 0.34)
    static let warning = Color(red: 0.89, green: 0.37, blue: 0.12)
    static let lime = Color(red: 0.72, green: 0.91, blue: 0.31)
    static let orange = warning
    static let hero = Color(red: 0.035, green: 0.09, blue: 0.16)
    static let health = Color(red: 0.87, green: 0.20, blue: 0.25)
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

struct AppTabBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(AppTheme.surface, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(.light, for: .tabBar)
            .tint(AppTheme.primary)
    }
}
