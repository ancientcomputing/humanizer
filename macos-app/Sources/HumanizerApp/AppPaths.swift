import Foundation

enum AppPaths {
    static let supportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Humanizer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static var voiceProfilePath: URL {
        supportDir.appendingPathComponent("voice_profile.json")
    }

    /// Where voice_profile.json lived under early builds that had App Sandbox
    /// enabled — macOS silently redirected Application Support into this
    /// per-app container. Sandboxing was later removed (see Humanizer.entitlements),
    /// but anyone who ran one of those builds still has their real, learned
    /// voice profile sitting here instead of the documented location.
    private static var legacySandboxedVoiceProfilePath: URL? {
        guard let containerBase = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        return containerBase
            .appendingPathComponent("Containers", isDirectory: true)
            .appendingPathComponent("com.humanizer.app", isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Humanizer", isDirectory: true)
            .appendingPathComponent("voice_profile.json")
    }

    /// One-time migration: if the standard location has no profile yet but an
    /// old sandboxed container does, copy it over so upgrading users don't
    /// silently lose everything they've taught the app.
    static func migrateLegacySandboxedVoiceProfileIfNeeded() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: voiceProfilePath.path) else { return }
        guard let legacyPath = legacySandboxedVoiceProfilePath, fm.fileExists(atPath: legacyPath.path) else { return }
        try? fm.copyItem(at: legacyPath, to: voiceProfilePath)
    }
}
