# Humanizer

A local tool that takes AI-generated drafts and rewrites them toward your
own authentic writing voice — then hands the result back to you to do a
final manual edit and post yourself.

**Nothing in this tool auto-posts anywhere.** Every flow ends with you
copying or saving the text and publishing it manually. There is no
integration that posts on your behalf, and there never will be in this
tool's design.

---

## Quick start

**Windows, no Python required:** download [`Humanizer.exe`](https://github.com/ancientcomputing/humanizer/releases/latest) from the latest release. It isn't code-signed, so Windows will show a couple of warnings before it'll let you run it — this is normal, and only needs doing once:

1. **Browser download warning** (Edge/Chrome): after the download finishes, click the **`⋮`** menu next to the file and choose **Keep**. In the "Make sure you trust `Humanizer.exe`" dialog, click the small **∨** dropdown on the **Delete** button and choose **Keep anyway**.
2. **Windows SmartScreen**, when you double-click the exe: click **"More info"**, then **"Run anyway"**.

Both warnings show up because the exe isn't signed with a paid code-signing certificate — not because anything's actually wrong with it. Your browser opens the app; go to **Settings** and paste an API key to get started.

**macOS, native app:** download [`Humanizer-0.1.0-arm64.dmg`](https://github.com/ancientcomputing/humanizer/releases/tag/0.1.0-macos), open it, and drag Humanizer into Applications. This is a
signed and notarized native SwiftUI app — no Python, no local server, no
Gatekeeper warnings. See [macOS native app](#macos-native-app) below for
details, and how to build it yourself.

**From source (macOS/Linux/Windows):**

**Prerequisites:** Python 3.10+, and an API key for [Anthropic](https://console.anthropic.com/settings/keys) (default) or [OpenAI](https://platform.openai.com/api-keys) (fallback).

1. Clone the repo:
   ```bash
   git clone https://github.com/ancientcomputing/humanizer.git
   cd humanizer
   ```
2. Run it:
   - macOS/Linux: `./run.sh`
   - Windows: `run.bat`

   First run creates a `.env` file and a local Python virtual environment,
   then exits so you can add your API key.
3. Run it again. The app opens automatically at `http://127.0.0.1:8420`.
4. Go to the **Settings** tab in the app and paste your API key there — it
   writes straight to your local `.env` file. (You can also edit `.env`
   directly with a text editor instead, if you'd rather not use the UI.)

That's it — no Docker, no account, no cloud dependency beyond the LLM API
calls the tool itself makes on your behalf.

---

## What it does

- **Humanize** — paste an AI-generated draft, get back a rewrite that
  strips common AI tells (em-dash overuse, "moreover/furthermore," hedge
  phrases, overly symmetric structure) and applies your learned voice
  profile, if you have one yet.
- **Review Loop** — paste the humanized draft and the version you ended up
  with after your own edit pass. The app diffs them, classifies each
  change as *style* or *content*, and folds only the style edits into your
  voice profile — content edits (new facts, removed points) are ignored
  for learning, on purpose.
- **Learn Mode** — the same engine, but for bootstrapping: feed it a batch
  of historical (original AI draft, what you actually published) pairs to
  seed your voice profile before you rely on Humanize day to day. Always
  available from the nav, not just a first-run thing.
- **Voice Profile** — a human-readable, editable view of what the tool has
  learned about your writing (word choices, sentence rhythm, structural
  habits), with a raw-JSON "Geeky Mode" if you want to hand-edit the file
  directly. Confidence grows the more times a pattern shows up, and
  near-duplicate rules get auto-merged so it doesn't get noisy over time.
- **Settings** — pick your provider (Anthropic or OpenAI) and manage API
  keys from the UI instead of hand-editing `.env`.
- **How-To** — an in-app guide covering all of the above, one click away
  from Settings.

See [docs/humanizer-v1-requirements.md](docs/humanizer-v1-requirements.md)
for the full original design spec.

---

## macOS native app

`macos-app/` is a from-scratch **SwiftUI** rewrite of the same product —
not a wrapper around the Python app. There is no embedded Python, no
bundled interpreter, and no local HTTP server: the app calls the
Anthropic/OpenAI HTTP APIs directly over `URLSession`, the same way
`core/providers/*.py` does, just ported to Swift line-for-line (pipeline,
diffing, format rules, prompts, voice-profile logic all live under
`macos-app/Sources/HumanizerApp/`), and means it starts instantly with no
subprocess to manage.

**Not sandboxed, on purpose.** `Humanizer.entitlements` only declares
`com.apple.security.network.client` — no `com.apple.security.app-sandbox`.
The voice profile is explicitly meant to be a plain file you can find and
hand-edit (see below), and macOS App Sandbox silently redirects
`Application Support` into a private per-app container the moment
`app-sandbox` is enabled, which defeats that. Mac App Store distribution
*requires* sandboxing, so if this ever ships there, it'll need its own
`-AppStore` entitlements file and release script (mirroring
`release-macos-appstore.sh` in the AnswerSearch project this was ported
from) rather than sandboxing the direct-download build.

**Where its data lives** (deliberately different from the web app, more
native to macOS):

- API keys → **macOS Keychain** (`com.humanizer.app.apikeys` service),
  never written to disk in plaintext, never a `.env` file. Managed from
  the in-app **Settings** tab.
- Voice profile → `~/Library/Application Support/Humanizer/voice_profile.json`
  — same JSON schema as the Python app's `data/voice_profile.json`, so a
  file from one can be dropped into the other's location to carry your
  learned voice over. It's a plain file you can hand-edit; the app's
  Voice Profile → Geeky Mode → **Reload from disk** button re-reads it
  without restarting.
- Everything else (provider choice, model names, max tokens) →
  `UserDefaults`.

### Building from source

Requires Xcode (or the Xcode command line tools) with Swift 6 support,
macOS 13+ as the deployment target.

```bash
cd macos-app
swift build -c release
open .build/release/HumanizerApp
```

That's an unsigned dev build — fine for local testing, but macOS Keychain
access for an unsigned/ad-hoc binary can prompt for permission the first
time a key is saved. For a real distributable build, use the release
script below instead.

### Building a signed, notarized release DMG

`scripts/release-macos.sh` builds the arm64 release binary, generates the
app icon, assembles and code-signs the `.app` bundle, notarizes and
staples it, then packages a drag-to-Applications DMG (also
signed/notarized/stapled) with a `.sha256` checksum. It's a straight port
of the same release flow used for the AnswerSearch macOS app.

Requirements:

- An Apple Developer ID Application signing certificate installed in your
  keychain (`APP_IDENTITY`).
- A notarization keychain profile created once via
  `xcrun notarytool store-credentials <profile-name>` (`KEYCHAIN_PROFILE`).
- Pillow for the Python interpreter used to generate the app icon
  (`pip install pillow`, or point `ICON_PYTHON` at one that has it).

```bash
VERSION=0.1.0 \
APP_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
KEYCHAIN_PROFILE="your-notary-profile" \
./scripts/release-macos.sh
```

Useful overrides:

| Variable | Default | Purpose |
| --- | --- | --- |
| `NOTARIZE_APP` | `1` | Set to `0` to skip app notarization (e.g. local testing of the signing flow). |
| `NOTARIZE_DMG` | `1` | Set to `0` to skip DMG notarization. |
| `TEAM_ID` | unset | Pass explicitly if `notarytool` can't infer it from the keychain profile. |
| `ICON_PYTHON` / `PYTHON` | `python3` | Python interpreter used to render the app icon (`macos-app/Resources/generate_app_icon.py`). |

Output lands in `dist/`: `Humanizer.app`, `Humanizer-<version>-arm64.dmg`,
and its `.sha256`. Both `build/` and `dist/` are gitignored.

### Project layout (macOS app)

```
macos-app/
  Package.swift                    SwiftPM manifest (macOS 13+)
  Resources/
    Info.plist                      bundle metadata, version, copyright
    Humanizer.entitlements           unsandboxed, network-client only (see note above)
    generate_app_icon.py            renders the AppIcon.appiconset PNGs
    Assets.xcassets/                app icon asset catalog
  Sources/HumanizerApp/
    HumanizerApp.swift               app entry point, menu commands
    AppSettings.swift                provider/model settings + Keychain-backed API keys
    KeychainStore.swift              thin Keychain wrapper
    VoiceProfileStore.swift          voice profile load/save/rule-update logic
    Pipeline.swift                   humanize / review / consolidate orchestration
    PromptTemplates.swift            prompt text ported from prompts/*.md
    Diffing.swift / FormatRules.swift
    AppTheme.swift                   color palette ported from web/static/styles.css
    Providers/                       Anthropic + OpenAI URLSession clients
    Views/                           SwiftUI views for each tab
```

---

## Project layout

```
app.py                  FastAPI app + local server entrypoint
core/
  config.py              env/config loading
  providers/              Anthropic (default) + OpenAI (fallback) abstraction
  voice_profile.py        load/save/update the voice profile JSON
  pipeline.py             humanize / review orchestration
  diffing.py               mismatch heuristic + unified diff
  format_rules.py          mechanical per-platform export formatting
  prompts.py               prompt template loader
prompts/
  humanize.md              editable humanize prompt
  classify.md               editable style-vs-content classifier prompt
  consolidate.md            editable duplicate-rule-merging prompt
web/static/                browser UI (plain HTML/CSS/JS, no build step)
data/voice_profile.json    your voice profile (gitignored — stays local)
macos-app/                 native SwiftUI macOS app — see "macOS native app" above
scripts/release-macos.sh   builds + signs + notarizes the macOS release DMG
```

## Notes

- Runs entirely locally, no Docker, no accounts, no telemetry. The only
  network calls are to your chosen LLM provider, for the humanize/classify
  requests you trigger.
- `.env` and `data/` are gitignored — your API keys and your actual
  learned voice profile (which contains excerpts of your real writing)
  never leave your machine or get committed.
- Prompts are plain markdown files in `prompts/` — edit them directly to
  tune behavior, no code changes required.

## License

[MIT](LICENSE.md)
