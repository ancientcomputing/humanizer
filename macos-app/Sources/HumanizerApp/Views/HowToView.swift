import SwiftUI

struct HowToView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                heading("What this tool actually does")
                bodyText("Humanizer only touches style — word choice, sentence rhythm, structure. It never adds, removes, or changes a claim, fact, or number on its own. And nothing here ever posts anywhere for you: every flow ends with you copying or saving text and publishing it yourself.")

                heading("Humanize")
                bodyText("Paste an AI-generated draft here and run it. You'll get back a rewrite that strips common \"AI tells\" — em-dash overuse, \"moreover/furthermore,\" hedge phrases, overly symmetric paragraph structure. If you don't have a voice profile yet, that's all it does. Once you do, it also applies whatever the tool has learned about how you actually write.\n\nUse the Send to Review Loop button once you've edited the result somewhere else, to teach the tool from that edit.")

                heading("Review Loop")
                bodyText("This is how the tool learns your voice. After you've taken a humanized draft and done your own edit pass on it (anywhere — this app doesn't need to be where you write), paste the before and after here. It diffs the two versions and classifies every change as style or content:\n\n• Style edits (word swaps, rephrasing, tone shifts that don't change what's being said) get folded into your voice profile.\n• Content edits (new facts, removed points, changed numbers or claims) are deliberately ignored — the tool should never quietly absorb a factual change into how it thinks you write.\n\nIf the two texts you paste look unrelated rather than like an edit of each other, you'll get a warning instead of a silent, meaningless result — that usually means a paste mistake.")

                heading("Learn Mode")
                bodyText("Same engine as Review Loop, different purpose: bootstrapping. If you've got a backlog of articles where you have both the original AI draft and what you actually ended up publishing, feed those pairs in here one at a time to seed your voice profile faster than waiting for it to build up naturally through everyday use.")

                heading("Voice Profile")
                bodyText("This is what Humanize actually reads from — not a black box. Each entry is a plain-language description of a tendency (not a rigid find-and-replace pair, since the same habit shows up differently depending on context), with a confidence level that grows the more times that pattern shows up in your edits.\n\nFriendly mode is a read-only view, grouped by category. Geeky Mode is the raw underlying JSON, if you want to hand-edit, delete, or add rules directly.\n\nNear-duplicate rules get automatically merged after each Review Loop or Learn Mode run, so this stays readable instead of turning into dozens of one-off entries over time.")

                heading("Settings")
                bodyText("Pick Anthropic or OpenAI as your provider and paste an API key — it's stored in the macOS Keychain and never sent anywhere except to that provider when you actually run Humanize or Review Loop. Keys are never shown back to you once saved, only whether one is currently set.")

                heading("Where your data lives")
                bodyText("Everything stays on your machine. Your voice profile lives in ~/Library/Application Support/Humanizer, API keys live in the Keychain, and neither ever leaves your computer except for the specific API call each action makes to your chosen provider. There's no account, no cloud sync, and no telemetry.")

                heading("Bringing an existing voice profile")
                bodyText("Already have a voice_profile.json from a previous install (this app or the original web version)? Drop it in as ~/Library/Application Support/Humanizer/voice_profile.json, replacing whatever's there, then open Voice Profile → Reload from disk (switch to Geeky Mode first if the button isn't visible) to pick it up without restarting the app.")
            }
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(.system(size: 17, weight: .bold)).foregroundStyle(AppTheme.text)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).foregroundStyle(AppTheme.text)
    }
}
