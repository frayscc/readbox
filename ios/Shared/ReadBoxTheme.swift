import SwiftUI

enum ReadBoxTheme {
    static let bg = Color(red: 0.975, green: 0.982, blue: 0.966)
    static let surface = Color.white
    static let reader = Color(red: 1.0, green: 0.996, blue: 0.976)
    static let ink = Color(red: 0.09, green: 0.21, blue: 0.18)
    static let inkDeep = Color(red: 0.05, green: 0.13, blue: 0.12)
    static let muted = Color(red: 0.42, green: 0.50, blue: 0.47)
    static let border = Color(red: 0.86, green: 0.90, blue: 0.87)
    static let accent = Color(red: 0.40, green: 0.91, blue: 0.78)
    static let warn = Color(red: 0.84, green: 0.66, blue: 0.24)
    static let danger = Color(red: 0.75, green: 0.20, blue: 0.16)
}

struct ReadBoxMark: View {
    var size: CGFloat = 34

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(ReadBoxTheme.inkDeep)
            Rectangle()
                .fill(ReadBoxTheme.accent)
                .frame(height: max(3, size * 0.09))
                .clipShape(Capsule())
                .padding(.horizontal, size * 0.22)
                .padding(.bottom, size * 0.12)
            Image(systemName: "doc.text")
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.bottom, size * 0.08)
        }
        .frame(width: size, height: size)
    }
}

struct ReadBoxCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(ReadBoxTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(ReadBoxTheme.border, lineWidth: 1)
            }
    }
}

struct ReadBoxPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(ReadBoxTheme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.76 : 1)
    }
}
