import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var voiceProfile: VoiceProfileStore

    var onGoToLearn: () -> Void = {}

    @State private var anthropicKeyInput = ""
    @State private var openAIKeyInput = ""
    @State private var status = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if settings.hasAnyKeySet && voiceProfile.isEmpty {
                    banner(
                        title: "New here?",
                        text: "Humanize works right away with a generic pass, but it gets much better once it knows your voice. If you have past examples — an AI draft and what you actually published — bootstrap it now.",
                        buttonTitle: "Start Learn Mode",
                        action: onGoToLearn
                    )
                }

                Text("Keys are stored in the macOS Keychain only — never sent anywhere except to the provider you choose, and never displayed back here once saved.")
                    .font(.system(size: 14)).foregroundStyle(AppTheme.muted)

                fieldLabel("Default provider")
                Picker("", selection: $settings.provider) {
                    Text("Anthropic (Claude)").tag(LLMProvider.anthropic)
                    Text("OpenAI").tag(LLMProvider.openai)
                }
                .labelsHidden()
                .frame(width: 260)

                fieldLabel("Anthropic API key" + (settings.anthropicKeySet ? "  (set)" : ""))
                SecureField("sk-ant-...", text: $anthropicKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
                    .frame(width: 400)

                fieldLabel("Anthropic model")
                TextField("claude-sonnet-4-5", text: $settings.anthropicModel)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
                    .frame(width: 300)

                fieldLabel("OpenAI API key" + (settings.openAIKeySet ? "  (set)" : ""))
                SecureField("sk-...", text: $openAIKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
                    .frame(width: 400)

                fieldLabel("OpenAI model")
                TextField("gpt-4o", text: $settings.openAIModel)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
                    .frame(width: 300)

                Button("Save") {
                    var failures: [String] = []

                    if !anthropicKeyInput.isEmpty {
                        if settings.setAnthropicAPIKey(anthropicKeyInput) {
                            anthropicKeyInput = ""
                        } else {
                            failures.append("Anthropic")
                        }
                    }
                    if !openAIKeyInput.isEmpty {
                        if settings.setOpenAIAPIKey(openAIKeyInput) {
                            openAIKeyInput = ""
                        } else {
                            failures.append("OpenAI")
                        }
                    }

                    status = failures.isEmpty
                        ? "Saved."
                        : "Could not save the \(failures.joined(separator: " / ")) key to the Keychain. Check Keychain Access permissions for Humanizer and try again."
                }
                .buttonStyle(PrimaryButtonStyle())

                if !status.isEmpty {
                    Text(status).foregroundStyle(AppTheme.muted).font(.system(size: 14))
                }
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).foregroundStyle(AppTheme.muted)
    }

    private func banner(title: String, text: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 15, weight: .bold))
                Text(text).font(.system(size: 14)).foregroundStyle(AppTheme.muted)
            }
            Spacer(minLength: 0)
            Button(buttonTitle, action: action)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.buttonBackground)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
