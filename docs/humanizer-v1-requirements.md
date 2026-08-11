# Humanizer Tool — V1 Requirements

## 1. Overview & Goal

A local tool that takes AI-generated marketing content (for LocalLM Lab) and
transforms it toward the user's authentic writing voice, before the user does
a final manual edit and posts it themselves.

**Hard gate principle (non-negotiable):** No step in this pipeline auto-publishes
content. The flow always ends with the human copying/exporting the text and
posting it manually. Nothing in V1 should create a path to auto-post.

**Core insight driving the design:** "AI slop" and "sounds like AI" are two
separate problems. This tool only addresses the second one (style/voice), not
content quality or substance — those are assumed to be settled upstream before
content enters this tool. The tool must never silently absorb content changes
(new claims, removed points, factual edits) into the learned voice model —
only genuine style edits should train the voice profile.

The user's voice is **one and the same across platforms** (Reddit, LinkedIn,
etc.) — this is explicitly a matter of authenticity, not audience-adaptation.
Platform differences are handled as separate, mechanical **format rules**
(length, markdown conventions, hashtags), never as voice variation.

---

## 2. Out of Scope for V1

- Mobile support
- Live in-app editor with real-time diffing (V1 uses paste-out / paste-back)
- Per-platform voice profiles (one voice profile only)
- Auto-posting to any platform
- Multi-user support, accounts, auth
- Cloud sync / hosted storage
- Docker or any containerized deployment
- Native app shell (Win UI / Swift) — browser-based local UI only for V1

---

## 3. Architecture

- **Stack:** Python backend (FastAPI or Flask — follow conventions from
  AnswerSearch and other reference projects the user will point to), static
  HTML/JS/CSS frontend served locally.
- **Run model:** local venv + a simple run script (e.g. `python app.py` or
  `./run.sh`). No Docker, no container orchestration. Should be a "clone and
  run" experience documented in a README.
- **Storage:** local filesystem only.
  - Voice profile stored as a human-readable JSON (or JSON + markdown) file.
  - Optionally, a local history/log of processed articles and their diffs
    (for debugging and future analysis) — not required for core function.
- **AI provider:** abstracted provider interface.
  - Default: Claude (Anthropic API).
  - Fallback: OpenAI.
  - Provider selected via local config, not hardcoded in call sites.
  - API keys read from a local `.env` / config file — never hardcoded,
    never committed.
- **No telemetry.** Drafts and edits stay local except for the API calls
  required to run humanize/classify prompts through the chosen provider.
- Follow structural conventions (folder layout, config handling, naming) from
  the user's reference projects (e.g. AnswerSearch) rather than inventing new
  patterns.

---

## 4. Voice Profile Schema

A single, human-readable, editable artifact — not a black-box embedding.
Rough shape (adjust as needed during implementation):

```json
{
  "version": 1,
  "last_updated": "2026-08-11",
  "rules": [
    {
      "id": "rule_001",
      "description": "Prefers direct statements over hedged claims",
      "example_before": "It could be argued that this approach may offer some benefits",
      "example_after": "This approach works better",
      "category": "tone",
      "confidence": "high",
      "source_count": 4
    }
  ],
  "lexical_preferences": {
    "avoid": ["moreover", "furthermore", "it's worth noting"],
    "prefer": []
  },
  "structural_notes": [
    "Tends to front-load the main point rather than build up to it",
    "Uses sentence fragments for emphasis"
  ],
  "history": [
    { "date": "2026-08-11", "article_id": "abc123", "edits_absorbed": 4 }
  ]
}
```

Requirements:
- Must be human-readable and manually editable (user can add/remove/veto rules
  directly in the file).
- Must track some notion of confidence/source_count per rule, so noisy
  one-off edits don't get equal weight to repeated patterns.
- Must be versioned so changes over time can be inspected.

---

## 5. Core Flows

### 5.1 Humanize

**Input:** pasted text or uploaded doc (AI-generated draft), plus a platform
selector (Reddit / LinkedIn / Other) used only for downstream format rules.

**Behavior:**
- If no voice profile exists yet (or it's empty): run a **generic pass only**
  — strip common AI tells (em-dash overuse, "moreover/furthermore," hedge
  phrases, triplet lists, overly symmetric structure), vary sentence rhythm.
  UI must clearly indicate: *"No voice profile yet — generic pass only."*
- If a voice profile exists: apply the generic tell-stripping pass **plus**
  the learned voice profile rules.
- Output is shown as a fresh draft, not silently substituted for the input.

### 5.2 Review Loop (paste-out / paste-back, V1 design)

1. Humanized draft shown in a text box with a **Copy** button.
2. User pastes into wherever they normally write/edit (external tool, not
   this app), edits freely — style tweaks and content changes both allowed,
   no restriction.
3. User pastes the final edited version into a second box in the app.
4. App runs a diff between the humanized draft and the pasted-back final
   version.
   - **Mismatch check:** if the two texts are dissimilar beyond a rough
     threshold (e.g. near-total rewrite, very low overlap), the app should
     surface a warning — *"This looks like a different article, not an
     edit — check your paste"* — rather than silently running the classifier
     on an unrelated pair. This applies to both the Review Loop and Learn
     Mode (Section 5.3), since Learn Mode is especially prone to
     accidentally pasting a mismatched historical pair. Exact
     threshold/method left as an implementation detail — a simple
     similarity heuristic is sufficient for V1, doesn't need to be
     sophisticated.
5. Each diffed change is classified as **style** or **content** (see Section
   6 for heuristics).
6. App shows a short summary, e.g.: *"4 style edits (added to voice profile),
   1 content edit (ignored for learning)."* No need to confirm every
   individual edit in V1 — just show the summary. (A future version may add
   per-edit confirmation for ambiguous cases.)
7. Confirmed style edits update the voice profile (increment matching rules
   or propose new ones). Content edits are discarded from training.

### 5.3 Learn Mode (bootstrap from historical content)

Same underlying engine as 5.2, different entry point:

- User pastes an original AI-generated draft (e.g. original Claude Cowork
  output) and the corresponding actually-published version, for each of a
  batch of historical articles.
- Each pair runs through the same diff → classify → extract pipeline as the
  Review Loop.
- Intended to seed the voice profile with a larger, more reliable sample
  before relying on the tool for new articles going forward.
- No special UI beyond looping the same two-box interface across multiple
  pairs (does not need to be a polished batch importer for V1 — sequential
  entry is fine).

---

## 6. Classifier Spec (style vs. content)

Given a diffed change, classify as **content** if any of the following hold:

- **Net-new information** — introduces a fact, number, feature, or point not
  present (even paraphrased) in the original.
- **Wholesale deletion** — removes an entire paragraph or claim.
- **Entity/number changes** — product names, stats, dates, prices, competitor
  mentions changed. Always flag as content, no ambiguity.
- **Semantic non-equivalence** — the edited sentence asserts something
  different in substance (a hedge added/removed changing the claim, scope
  changed e.g. "some users" → "most users", a new comparison introduced).
  This is the core test: if truth-conditions changed, it's content.
- **Structural/argument changes** — reordering sections or paragraphs because
  the logic/flow was wrong (as opposed to reordering purely for rhythm).

Otherwise classify as **style**:
- Word/phrase-level rewording that preserves the same claim (lexical swap).
- Local sentence-level restructuring that doesn't change what's asserted.
- Tone/register shifts (formality, hedging removed for confidence, added
  informality) that don't change the underlying claim.
- Rhythm-only reordering (e.g., moving a sentence for pacing, not logic).

Implementation approach: use an LLM call (via the same provider abstraction)
with these heuristics as explicit instructions in the prompt, rather than
hand-rolled NLP/rule-based classification — the semantic-equivalence test in
particular is not reliably solvable with deterministic rules. Classifier
prompt should be an externalized, editable template (see Section 7), not
hardcoded logic.

**Note from manual test runs against real content:** style edits are not
reliable find-and-replace patterns even for a single, consistent stylistic
habit. E.g. the user's tendency to avoid em-dashes showed up across two
sample edits as three different replacements (period + new sentence,
ellipsis, plain comma) depending on context — never a fixed substitution.
Voice profile rules should be captured as *descriptions of a tendency*
("avoids em-dashes; replacement varies by context — period+sentence,
ellipsis, or comma"), not as literal before/after string pairs to match
against. This reinforces why an LLM-based classifier/humanizer is required
over deterministic rules.

---

## 7. Prompts

Both prompts must be externalized as editable template files (not hardcoded
in application logic), versioned similarly to the voice profile.

- **Humanize prompt template** — takes: draft text, voice profile (rules +
  lexical preferences + structural notes), platform (for context only, not
  voice). Produces: humanized draft.
- **Classify prompt template** — takes: original (humanized) text, edited
  (pasted-back) text, diff. Produces: per-change classification (style /
  content) with brief reasoning, plus a proposed voice-profile rule update
  for style changes where applicable.

Exact prompt wording can be drafted by Claude Code and iterated on by the
user; this doc specifies required inputs/outputs, not final wording.

---

## 8. Export

- Plain **Copy to clipboard** and **Save As** (markdown or plain text) from
  the final reviewed text.
- Platform-specific **format rules** applied at this step (mechanical only):
  - Reddit: markdown conventions, no hashtags, casual first-person framing
    conventions as needed.
  - LinkedIn: hook-line convention, line break/paragraph spacing conventions,
    hashtags if applicable.
  - Other: no special formatting.
- Format rules are a separate, simple config (platform → formatting
  transform), explicitly decoupled from the voice profile so platform
  formatting never leaks into or influences voice.

---

## 9. Non-Functional Requirements

- Runs entirely locally; no Docker.
- Single-user, no auth, no accounts.
- No telemetry or analytics.
- Drafts/history stored locally only; nothing sent anywhere except the
  minimum needed for provider API calls (humanize, classify).
- API keys via local config/`.env`, never hardcoded or committed.
- Provider abstraction: one interface, Claude (default) and OpenAI (fallback)
  implementations, selectable via config.
- Code structure, framework choice (FastAPI vs Flask), and file/folder
  conventions should follow the pattern of the user's reference projects
  (e.g. AnswerSearch) rather than being dictated here.

---

## 10. Open Items for Claude Code / Implementation

- Exact prompt wording for humanize and classify (draft + iterate).
- Whether voice-profile rule updates from Section 5.2/5.3 are auto-appended
  or require a lightweight confirm step (V1 leans toward auto-append with a
  visible summary, per Section 5.2 step 6).
- Minimal local history/logging format, if implemented.
- Whether Learn Mode needs any batch UI polish beyond sequential pair entry.
