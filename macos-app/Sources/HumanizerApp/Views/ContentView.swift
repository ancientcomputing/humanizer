import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case humanize = "Humanize"
    case review = "Review Loop"
    case learn = "Learn Mode"
    case profile = "Voice Profile"
    case settings = "Settings"
    case howTo = "How-To"

    var id: String { rawValue }

    /// Daily-usage tabs vs. the rest — mirrors the web UI's primary/secondary tab split.
    static let primary: [AppTab] = [.humanize, .review]
    static let secondary: [AppTab] = [.learn, .profile, .settings, .howTo]
}

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var selectedTab: AppTab = .humanize
    @State private var handoffText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            navBar
            Divider().background(AppTheme.border)

            Group {
                switch selectedTab {
                case .humanize:
                    HumanizeView(
                        onSendToReview: { text in
                            handoffText = text
                            selectedTab = .review
                        },
                        onGoToSettings: { selectedTab = .settings },
                        onGoToLearn: { selectedTab = .learn }
                    )
                case .review:
                    ReviewView(prefillHumanized: handoffText)
                case .learn:
                    LearnView()
                case .profile:
                    ProfileView()
                case .settings:
                    SettingsView(onGoToLearn: { selectedTab = .learn })
                case .howTo:
                    HowToView()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(AppTheme.background)
        .foregroundStyle(AppTheme.text)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.accent)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle().fill(AppTheme.accentText).frame(width: 11, height: 11).offset(y: -3)
                    )
                Text("Humanizer").font(.system(size: 19, weight: .bold))
            }
            Text("Style, not substance. You still post it yourself.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.muted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var navBar: some View {
        HStack(alignment: .lastTextBaseline) {
            HStack(spacing: 4) {
                ForEach(AppTab.primary) { tab in
                    tabButton(tab, secondary: false)
                }
            }
            Spacer()
            HStack(spacing: 2) {
                ForEach(AppTab.secondary) { tab in
                    tabButton(tab, secondary: true)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func tabButton(_ tab: AppTab, secondary: Bool) -> some View {
        let isActive = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            Text(tab.rawValue)
                .font(.system(size: secondary ? 12 : 15, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? AppTheme.text : AppTheme.muted)
                .padding(.horizontal, secondary ? 6 : 10)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isActive ? (secondary ? AppTheme.muted : AppTheme.accent) : Color.clear)
                        .frame(height: 2)
                }
        }
        .buttonStyle(.plain)
    }
}
