import SwiftUI
import AppKit

struct HumanizeView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var voiceProfile: VoiceProfileStore

    var onSendToReview: (String) -> Void
    var onGoToSettings: () -> Void
    var onGoToLearn: () -> Void

    @State private var draft = ""
    @State private var output = ""
    @State private var status = ""
    @State private var isRunning = false
    @State private var firstPassDraft: String?
    @State private var showFirstPassDraft = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !settings.hasAnyKeySet {
                    banner(
                        title: "Add an API key to get started.",
                        text: "Humanizer calls Claude or GPT-4o to do the rewriting, so it needs a key from whichever provider you'd like to use before it can run.",
                        buttonTitle: "Go to Settings",
                        action: onGoToSettings
                    )
                } else if voiceProfile.isEmpty {
                    banner(
                        title: "New here?",
                        text: "Humanize works right away with a generic pass, but it gets much better once it knows your voice. If you have past examples — an AI draft and what you actually published — bootstrap it now.",
                        buttonTitle: "Start Learn Mode",
                        action: onGoToLearn
                    )
                }

                fieldLabel("AI-generated draft")
                TextEditor(text: $draft)
                    .font(.system(size: 15))
                    .frame(minHeight: 180)
                    .padding(6)
                    .background(AppTheme.panel)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border))

                Button(isRunning ? "Humanizing..." : "Humanize") {
                    run()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isRunning || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !status.isEmpty {
                    Text(status).foregroundStyle(AppTheme.muted).font(.system(size: 14))
                }

                fieldLabel("Humanized draft")
                TextEditor(text: .constant(output))
                    .font(.system(size: 15))
                    .frame(minHeight: 180)
                    .padding(6)
                    .background(AppTheme.panel)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border))

                if let firstPassDraft {
                    Button(showFirstPassDraft ? "Hide first-pass draft ▾" : "Show first-pass draft (before second pass) ▸") {
                        showFirstPassDraft.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.muted)

                    if showFirstPassDraft {
                        fieldLabel("Output before the second pass ran")
                        TextEditor(text: .constant(firstPassDraft))
                            .font(.system(size: 14))
                            .frame(minHeight: 160)
                            .padding(6)
                            .background(AppTheme.panel)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border))
                    }
                }

                HStack {
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(output, forType: .string)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(output.isEmpty)

                    Button("Save As...") { saveAs() }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(output.isEmpty)

                    Button("Send to Review Loop →") { onSendToReview(output) }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(output.isEmpty)
                }
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).foregroundStyle(AppTheme.muted)
    }

    private func banner(title: String, text: String, buttonTitle: String, action: (() -> Void)?) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 15, weight: .bold))
                Text(text).font(.system(size: 14)).foregroundStyle(AppTheme.muted)
            }
            Spacer(minLength: 0)
            if let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.buttonBackground)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func run() {
        isRunning = true
        status = "Working..."
        firstPassDraft = nil
        showFirstPassDraft = false
        let provider = settings.makeProvider()
        let maxTokens = settings.maxTokens
        let draftValue = draft

        Task {
            do {
                let result = try await Pipeline.humanize(
                    provider: provider, maxTokens: maxTokens, voiceProfile: voiceProfile,
                    draft: draftValue, platform: "Other"
                )
                output = result.draft
                firstPassDraft = result.firstPassDraft
                status = result.usedVoiceProfile
                    ? "Applied generic pass + your voice profile."
                    : "No voice profile yet — generic pass only."
            } catch {
                status = error.localizedDescription
            }
            isRunning = false
        }
    }

    private func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "humanized-draft.md"
        if panel.runModal() == .OK, let url = panel.url {
            try? output.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
