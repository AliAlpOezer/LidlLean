import SwiftUI

enum AppTheme {
    static let canvas = Color(red: 0.969, green: 0.973, blue: 0.953)
    static let surface = Color.white
    static let elevated = Color(red: 0.925, green: 0.941, blue: 0.906)
    static let ink = Color(red: 0.055, green: 0.075, blue: 0.063)
    static let muted = Color(red: 0.38, green: 0.43, blue: 0.39)
    static let primary = Color(red: 0.10, green: 0.18, blue: 0.13)
    static let success = Color(red: 0.03, green: 0.48, blue: 0.25)
    static let warning = Color(red: 0.83, green: 0.31, blue: 0.08)
    static let lime = Color(red: 0.76, green: 1.0, blue: 0.22)
    static let orange = warning
    static let hero = Color(red: 0.055, green: 0.082, blue: 0.065)
    static let health = Color(red: 0.90, green: 0.18, blue: 0.30)
    static let stroke = Color(red: 0.055, green: 0.075, blue: 0.063).opacity(0.08)
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 24).stroke(AppTheme.stroke) }
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
            .foregroundStyle(AppTheme.ink)
            .background(configuration.isPressed ? AppTheme.lime.opacity(0.7) : AppTheme.lime,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct QuietActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AppTheme.ink)
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .background(configuration.isPressed ? AppTheme.elevated.opacity(0.7) : AppTheme.elevated,
                        in: Capsule())
    }
}

struct MetricPill: View {
    let icon: String
    let value: String
    let label: String
    var tint = AppTheme.primary

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.11), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink)
                Text(label).font(.caption2.weight(.medium)).foregroundStyle(AppTheme.muted)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(AppTheme.surface.opacity(0.12), in: Capsule())
    }
}

struct AppTabBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(AppTheme.surface, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(.light, for: .tabBar)
            .tint(AppTheme.success)
    }
}
