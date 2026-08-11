# Humanizer

A local tool that takes AI-generated marketing drafts and rewrites them
toward your own authentic writing voice, before you do a final manual edit
and post it yourself.

**Nothing in this tool auto-posts anywhere.** Every flow ends with you
copying or saving the text and publishing it manually.

See [docs/humanizer-v1-requirements.md](docs/humanizer-v1-requirements.md)
for the full design spec.

## Quick start

```bash
./run.sh
```

(Windows: `run.bat`)

First run creates a `.env` from `.env.example` and exits so you can add your
API key. Add `ANTHROPIC_API_KEY` (default provider) or `OPENAI_API_KEY`
(fallback — set `HUMANIZER_PROVIDER=openai` to use it), then run again. The
app opens at `http://127.0.0.1:8420` by default.

## How it works

- **Humanize** — paste an AI-generated draft, pick a platform (format only,
  never voice), get a rewritten draft that strips common AI tells and
  applies your learned voice profile (if any).
- **Review Loop** — paste the humanized draft and the version you actually
  ended up publishing after your own edit pass. The app diffs them,
  classifies each change as style or content via an LLM call, and folds
  style edits into your voice profile. Content edits are ignored for
  learning.
- **Learn Mode** — same engine, used to bootstrap the voice profile from a
  batch of historical (original draft, published version) pairs.
- **Voice Profile** — a human-readable, hand-editable JSON file at
  `data/voice_profile.json`. Add, remove, or veto rules directly.

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
web/static/                browser UI (plain HTML/CSS/JS, no build step)
data/voice_profile.json    your voice profile (not committed once populated)
```

## Notes

- Runs entirely locally, no Docker, no accounts, no telemetry. The only
  network calls are to your chosen LLM provider for humanize/classify.
- `.env` is gitignored — never commit API keys.
- Prompts are plain markdown files in `prompts/` — edit them directly to
  tune behavior.
