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

**Windows, no Python required:** download [`Humanizer.exe`](https://github.com/ancientcomputing/humanizer/releases/latest) from the latest release and double-click it. Windows SmartScreen may warn since it isn't code-signed — click "More info" → "Run anyway". Your browser opens the app; go to **Settings** and paste an API key to get started.

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
