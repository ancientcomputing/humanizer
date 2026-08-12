import SwiftUI

struct LearnView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var voiceProfile: VoiceProfileStore

    @State private var original = ""
    @State private var published = ""
    @State private var status = ""
    @State private var isRunning = false
    @State private var result: ReviewResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Bootstrap the voice profile from historical articles. Paste an original AI draft and the version you actually published, run it, then repeat for the next pair.")
                    .font(.system(size: 14)).foregroundStyle(AppTheme.muted)

                fieldLabel("Original AI-generated draft")
                TextEditor(text: $original)
                    .font(.system(size: 15))
                    .frame(minHeight: 150)
                    .padding(6)
                    .background(AppTheme.panel)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border))

                fieldLabel("Actually published version")
                TextEditor(text: $published)
                    .font(.system(size: 15))
                    .frame(minHeight: 150)
                    .padding(6)
                    .background(AppTheme.panel)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border))

                HStack {
                    Button(isRunning ? "Running..." : "Run Learn Pair") { run() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isRunning || original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || published.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Clear for Next Pair") {
                        original = ""
                        published = ""
                        result = nil
                        status = ""
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(isRunning)
                }

                if !status.isEmpty {
                    Text(status).foregroundStyle(AppTheme.muted).font(.system(size: 14))
                }

                if let result {
                    if result.mismatch {
                        Text(result.message ?? "").foregroundStyle(.orange).font(.system(size: 14, weight: .semibold))
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(result.summary).font(.system(size: 14, weight: .semibold))
                            Text("Edits absorbed: \(result.editsAbsorbed)").font(.system(size: 14))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.buttonBackground)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).foregroundStyle(AppTheme.muted)
    }

    private func run() {
        isRunning = true
        status = "Working..."
        result = nil
        let provider = settings.makeProvider()
        let maxTokens = settings.maxTokens
        let threshold = settings.mismatchThreshold
        let originalValue = original
        let publishedValue = published

        Task {
            do {
                let reviewResult = try await Pipeline.review(
                    provider: provider, maxTokens: maxTokens, mismatchThreshold: threshold,
                    voiceProfile: voiceProfile, humanizedText: originalValue, editedText: publishedValue
                )
                result = reviewResult
                status = ""
            } catch {
                status = error.localizedDescription
            }
            isRunning = false
        }
    }
}
