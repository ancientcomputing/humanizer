import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var voiceProfile: VoiceProfileStore

    @State private var geekyMode = false
    @State private var jsonText = ""
    @State private var status = ""
    @State private var isConsolidating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("What Humanizer has learned about how you write. This reloads automatically whenever you open this tab.")
                    .font(.system(size: 14)).foregroundStyle(AppTheme.muted)

                Picker("", selection: $geekyMode) {
                    Text("Friendly").tag(false)
                    Text("Geeky Mode").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                if geekyMode {
                    HStack {
                        Button("Reload from disk") {
                            voiceProfile.reload()
                            jsonText = voiceProfile.rulesAsJSON()
                            status = "Reloaded."
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Button(isConsolidating ? "Consolidating..." : "Consolidate Similar Rules") { consolidate() }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(isConsolidating || voiceProfile.data.rules.count < 2)

                        Button("Save to disk") {
                            if let data = jsonText.data(using: .utf8),
                               let decoded = try? JSONDecoder().decode([VoiceRule].self, from: data) {
                                voiceProfile.data.rules = decoded
                                voiceProfile.save()
                                status = "Saved."
                            } else {
                                status = "Could not parse JSON — fix and try again."
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }

                if !status.isEmpty {
                    Text(status).foregroundStyle(AppTheme.muted).font(.system(size: 14))
                }

                if geekyMode {
                    TextEditor(text: $jsonText)
                        .font(.system(size: 14, design: .monospaced))
                        .frame(minHeight: 400)
                        .padding(6)
                        .background(AppTheme.panel)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border))
                        .onAppear { jsonText = voiceProfile.rulesAsJSON() }
                } else {
                    friendlyCards
                }
            }
        }
        .onAppear {
            voiceProfile.reload()
            jsonText = voiceProfile.rulesAsJSON()
        }
    }

    private var friendlyCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            if voiceProfile.data.rules.isEmpty {
                Text("No rules learned yet. Use Learn Mode or Review Loop to teach Humanizer your voice.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.muted)
            }
            ForEach(Dictionary(grouping: voiceProfile.data.rules, by: { $0.category }).sorted(by: { $0.key < $1.key }), id: \.key) { category, rules in
                VStack(alignment: .leading, spacing: 6) {
                    Text(category.capitalized).font(.system(size: 15, weight: .bold))
                    ForEach(rules) { rule in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.description).font(.system(size: 14))
                            if !rule.exampleBefore.isEmpty && !rule.exampleAfter.isEmpty {
                                Text("\"\(rule.exampleBefore)\" → \"\(rule.exampleAfter)\"")
                                    .font(.system(size: 13)).foregroundStyle(AppTheme.muted)
                            }
                            Text("\(rule.confidence) confidence · seen \(rule.sourceCount)×")
                                .font(.system(size: 12)).foregroundStyle(AppTheme.muted)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.buttonBackground)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            if !voiceProfile.data.lexicalPreferences.avoid.isEmpty {
                Text("Avoid: " + voiceProfile.data.lexicalPreferences.avoid.joined(separator: ", "))
                    .font(.system(size: 14))
            }
        }
    }

    private func consolidate() {
        isConsolidating = true
        status = "Consolidating..."
        let provider = settings.makeProvider()
        let maxTokens = settings.maxTokens
        Task {
            do {
                let result = try await Pipeline.consolidateVoiceProfile(provider: provider, maxTokens: maxTokens, voiceProfile: voiceProfile)
                jsonText = voiceProfile.rulesAsJSON()
                status = result.changed ? "Merged \(result.beforeCount) rules into \(result.afterCount)." : "No near-duplicates found."
            } catch {
                status = error.localizedDescription
            }
            isConsolidating = false
        }
    }
}
