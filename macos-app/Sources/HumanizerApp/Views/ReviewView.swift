import SwiftUI

struct ReviewView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var voiceProfile: VoiceProfileStore

    @State private var humanizedText: String
    @State private var editedText = ""
    @State private var status = ""
    @State private var isRunning = false
    @State private var result: ReviewResult?

    init(prefillHumanized: String = "") {
        _humanizedText = State(initialValue: prefillHumanized)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Teach Humanizer to write like you. Paste the humanized draft, and the version you ended up with after your own edit pass. Style edits train the voice profile; content edits are ignored.")
                    .font(.system(size: 14)).foregroundStyle(AppTheme.muted)

                fieldLabel("Humanized draft (before your edits)")
                TextEditor(text: $humanizedText)
                    .font(.system(size: 15))
                    .frame(minHeight: 150)
                    .padding(6)
                    .background(AppTheme.panel)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border))

                fieldLabel("Your edited version (after your edits)")
                TextEditor(text: $editedText)
                    .font(.system(size: 15))
                    .frame(minHeight: 150)
                    .padding(6)
                    .background(AppTheme.panel)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border))

                Button(isRunning ? "Running..." : "Run Review") { run() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isRunning || humanizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !status.isEmpty {
                    Text(status).foregroundStyle(AppTheme.muted).font(.system(size: 14))
                }

                if let result {
                    resultView(result)
                }
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).foregroundStyle(AppTheme.muted)
    }

    @ViewBuilder
    private func resultView(_ result: ReviewResult) -> some View {
        if result.mismatch {
            Text(result.message ?? "").foregroundStyle(.orange).font(.system(size: 14, weight: .semibold))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(result.summary).font(.system(size: 14, weight: .semibold))
                if !result.newRules.isEmpty {
                    Text("New rules").font(.system(size: 14, weight: .bold))
                    ForEach(result.newRules, id: \.id) { rule in
                        Text("• \(rule.description)").font(.system(size: 14))
                    }
                }
                if !result.reinforcedRules.isEmpty {
                    Text("Reinforced rules").font(.system(size: 14, weight: .bold))
                    ForEach(result.reinforcedRules, id: \.id) { rule in
                        Text("• \(rule.description) (×\(rule.sourceCount), \(rule.confidence))").font(.system(size: 14))
                    }
                }
                if !result.merges.isEmpty {
                    Text("Merged rules").font(.system(size: 14, weight: .bold))
                    ForEach(result.merges, id: \.id) { merge in
                        Text("• \(merge.description) (merged \(merge.mergedFromCount))").font(.system(size: 14))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.buttonBackground)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func run() {
        isRunning = true
        status = "Working..."
        result = nil
        let provider = settings.makeProvider()
        let maxTokens = settings.maxTokens
        let threshold = settings.mismatchThreshold
        let humanizedValue = humanizedText
        let editedValue = editedText

        Task {
            do {
                let reviewResult = try await Pipeline.review(
                    provider: provider, maxTokens: maxTokens, mismatchThreshold: threshold,
                    voiceProfile: voiceProfile, humanizedText: humanizedValue, editedText: editedValue
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
