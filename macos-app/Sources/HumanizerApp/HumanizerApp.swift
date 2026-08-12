import SwiftUI

@main
struct HumanizerApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var voiceProfile = VoiceProfileStore()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(voiceProfile)
                .frame(minWidth: 760, minHeight: 620)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {
                Button("Humanizer Help") {
                    openWindow(id: "help")
                }
            }
        }

        WindowGroup("Humanizer Help", id: "help") {
            HowToView()
                .padding(24)
                .frame(minWidth: 560, idealWidth: 640, minHeight: 480, idealHeight: 640)
                .background(AppTheme.background)
                .foregroundStyle(AppTheme.text)
        }
        .windowResizability(.contentSize)
    }
}
