import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? AppTheme.accentHover : AppTheme.accent)
            .foregroundStyle(AppTheme.accentText)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(isEnabled ? 1.0 : 0.4)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(configuration.isPressed ? AppTheme.buttonBackgroundHover : AppTheme.buttonBackground)
            .foregroundStyle(AppTheme.text)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.buttonBorder))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(isEnabled ? 1.0 : 0.4)
    }
}
