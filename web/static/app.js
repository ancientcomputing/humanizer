const tabButtons = document.querySelectorAll(".tab-btn, .tab-btn-secondary");
const tabPanels = document.querySelectorAll(".tab-panel");

function showTab(tabName) {
  tabButtons.forEach((b) => b.classList.toggle("active", b.dataset.tab === tabName));
  tabPanels.forEach((p) => p.classList.toggle("active", p.id === `tab-${tabName}`));

  if (tabName === "profile") {
    loadProfile();
  } else if (tabName === "settings") {
    loadSettings();
  }
}

tabButtons.forEach((btn) => {
  btn.addEventListener("click", () => showTab(btn.dataset.tab));
});

// The OOBE banner's button jumps straight to the Learn Mode tab; Learn Mode
// itself is always reachable afterward via the secondary nav, so this is
// just a shortcut, not the only way in.
document.getElementById("oobe-start-learn").addEventListener("click", () => showTab("learn"));
document.getElementById("setup-start-settings").addEventListener("click", () => showTab("settings"));

async function checkSetupBanner() {
  try {
    const response = await fetch("/api/settings");
    const data = await response.json();
    const hasKey = data.anthropic_api_key_set || data.openai_api_key_set;
    document.getElementById("setup-banner").style.display = hasKey ? "none" : "";
  } catch (err) {
    // If this fails the Humanize button will surface the real error anyway.
  }
}
checkSetupBanner();

function setStatus(el, message, kind) {
  el.textContent = message;
  el.className = "status" + (kind ? ` ${kind}` : "");
}

async function postJSON(url, body) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await response.json();
  if (!response.ok || data.error) {
    throw new Error(data.error || `Request failed (${response.status})`);
  }
  return data;
}

// --- Humanize tab ---

const humanizeInput = document.getElementById("humanize-input");
const humanizeOutput = document.getElementById("humanize-output");
const humanizeStatus = document.getElementById("humanize-status");

document.getElementById("humanize-run").addEventListener("click", async () => {
  const draft = humanizeInput.value.trim();
  if (!draft) {
    setStatus(humanizeStatus, "Paste a draft first.", "error");
    return;
  }
  setStatus(humanizeStatus, "Humanizing...");
  try {
    // Platform picker is hidden for now; format rules only matter at Export,
    // and the backend already defaults to "Other" (no format changes) if
    // omitted, so there's no dedicated per-platform behavior lost here.
    const result = await postJSON("/api/humanize", { draft });
    humanizeOutput.value = result.draft;
    setStatus(
      humanizeStatus,
      result.used_voice_profile
        ? "Applied generic pass + your voice profile."
        : "No voice profile yet — generic pass only.",
      "ok"
    );
  } catch (err) {
    setStatus(humanizeStatus, err.message, "error");
  }
});

document.getElementById("humanize-copy").addEventListener("click", async () => {
  await navigator.clipboard.writeText(humanizeOutput.value);
  setStatus(humanizeStatus, "Copied to clipboard.", "ok");
});

document.getElementById("humanize-save").addEventListener("click", () => {
  downloadText(humanizeOutput.value, "humanized-draft.md");
});

document.getElementById("humanize-send-review").addEventListener("click", () => {
  document.getElementById("review-humanized").value = humanizeOutput.value;
  document.querySelector('.tab-btn[data-tab="review"]').click();
});

function downloadText(text, filename) {
  const blob = new Blob([text], { type: "text/plain" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

// --- Review tab ---

const reviewStatus = document.getElementById("review-status");
const reviewResult = document.getElementById("review-result");

document.getElementById("review-run").addEventListener("click", async () => {
  const humanized = document.getElementById("review-humanized").value.trim();
  const edited = document.getElementById("review-edited").value.trim();
  if (!humanized || !edited) {
    setStatus(reviewStatus, "Paste both versions first.", "error");
    return;
  }
  setStatus(reviewStatus, "Diffing and classifying...");
  reviewResult.innerHTML = "";
  try {
    const result = await postJSON("/api/review", { humanized, edited });
    renderReviewResult(result, reviewStatus, reviewResult);
  } catch (err) {
    setStatus(reviewStatus, err.message, "error");
  }
});

function renderReviewResult(result, statusEl, boxEl) {
  if (result.mismatch) {
    setStatus(statusEl, result.message, "error");
    return;
  }
  setStatus(statusEl, result.summary, "ok");
  boxEl.innerHTML = "";

  // A successful run may have taken the voice profile from empty to
  // non-empty (or changed rule counts) — refresh in the background so the
  // OOBE banner and Voice Profile tab reflect it without waiting for the
  // user to happen to revisit that tab.
  loadProfile();

  const profileSummary = renderProfileChangesSummary(result.profile_changes);
  if (profileSummary) {
    boxEl.appendChild(profileSummary);
  }

  (result.changes || []).forEach((change) => {
    const item = document.createElement("div");
    item.className = "change-item";
    item.innerHTML = `
      <span class="change-tag ${change.classification}">${change.classification}</span>
      <span>${escapeHtml(change.reasoning || "")}</span>
      <span class="snippet">- ${escapeHtml(change.original_snippet || "")}</span>
      <span class="snippet">+ ${escapeHtml(change.edited_snippet || "")}</span>
    `;
    boxEl.appendChild(item);
  });
}

function renderProfileChangesSummary(profileChanges) {
  if (!profileChanges) return null;
  const { new_rules = [], reinforced_rules = [], merges = [] } = profileChanges;
  if (!new_rules.length && !reinforced_rules.length && !merges.length) return null;

  const box = document.createElement("div");
  box.className = "profile-summary";

  const title = document.createElement("div");
  title.className = "profile-summary-title";
  title.textContent = "Voice profile updated";
  box.appendChild(title);

  new_rules.forEach((rule) => {
    box.appendChild(
      profileSummaryLine("new", `Learned: "${rule.description}"`)
    );
  });
  reinforced_rules.forEach((rule) => {
    box.appendChild(
      profileSummaryLine(
        "reinforced",
        `Reinforced: "${rule.description}" — seen ${rule.source_count}x now (${rule.confidence} confidence)`
      )
    );
  });
  merges.forEach((merge) => {
    box.appendChild(
      profileSummaryLine(
        "merged",
        `Merged ${merge.merged_from_count} similar rules into: "${merge.description}" (${merge.confidence} confidence)`
      )
    );
  });

  return box;
}

function profileSummaryLine(kind, text) {
  const line = document.createElement("div");
  line.className = `profile-summary-line profile-summary-${kind}`;
  line.textContent = text;
  return line;
}

function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

// --- Learn Mode tab ---

const learnStatus = document.getElementById("learn-status");
const learnResult = document.getElementById("learn-result");

document.getElementById("learn-run").addEventListener("click", async () => {
  const original = document.getElementById("learn-original").value.trim();
  const published = document.getElementById("learn-published").value.trim();
  if (!original || !published) {
    setStatus(learnStatus, "Paste both versions first.", "error");
    return;
  }
  setStatus(learnStatus, "Diffing and classifying...");
  learnResult.innerHTML = "";
  try {
    const result = await postJSON("/api/learn", { humanized: original, edited: published });
    renderReviewResult(result, learnStatus, learnResult);
  } catch (err) {
    setStatus(learnStatus, err.message, "error");
  }
});

document.getElementById("learn-clear").addEventListener("click", () => {
  document.getElementById("learn-original").value = "";
  document.getElementById("learn-published").value = "";
  learnResult.innerHTML = "";
  setStatus(learnStatus, "Cleared. Ready for the next pair.", "");
});

// --- Voice Profile tab ---

const profileJson = document.getElementById("profile-json");
const profileStatus = document.getElementById("profile-status");
const profileCards = document.getElementById("profile-cards");
const profileGeekyActions = document.getElementById("profile-geeky-actions");
const profileModeFriendlyBtn = document.getElementById("profile-mode-friendly");
const profileModeGeekyBtn = document.getElementById("profile-mode-geeky");

let currentProfile = null;
let profileMode = "friendly";

async function loadProfile() {
  const response = await fetch("/api/voice-profile");
  currentProfile = await response.json();
  renderProfile();
}

function renderProfile() {
  profileJson.value = JSON.stringify(currentProfile, null, 2);
  renderProfileCards();
  updateOobeBanner();
}

function updateOobeBanner() {
  const isEmpty = !currentProfile || !(currentProfile.rules || []).length;
  document.getElementById("oobe-banner").style.display = isEmpty ? "" : "none";
}

function setProfileMode(mode) {
  profileMode = mode;
  const friendly = mode === "friendly";
  profileModeFriendlyBtn.classList.toggle("active", friendly);
  profileModeGeekyBtn.classList.toggle("active", !friendly);
  profileCards.style.display = friendly ? "" : "none";
  profileJson.style.display = friendly ? "none" : "";
  profileGeekyActions.style.display = friendly ? "none" : "";
  if (!friendly) {
    // Geeky Mode edits the same in-memory object via its own Save button, so
    // make sure we're showing current state rather than a stale render.
    profileJson.value = JSON.stringify(currentProfile, null, 2);
  }
}

profileModeFriendlyBtn.addEventListener("click", () => setProfileMode("friendly"));
profileModeGeekyBtn.addEventListener("click", () => setProfileMode("geeky"));

const CATEGORY_LABELS = { tone: "Tone", structure: "Structure", lexical: "Word choice" };

function renderProfileCards() {
  profileCards.innerHTML = "";
  const rules = (currentProfile && currentProfile.rules) || [];

  if (!rules.length) {
    const hint = document.createElement("div");
    hint.className = "profile-empty-hint";
    hint.textContent =
      "No learned rules yet. Run Review Loop or Learn Mode after editing a humanized draft to start building this.";
    profileCards.appendChild(hint);
    return;
  }

  const byCategory = {};
  rules.forEach((rule) => {
    const category = rule.category || "tone";
    (byCategory[category] = byCategory[category] || []).push(rule);
  });

  const order = ["tone", "structure", "lexical"];
  const categories = [
    ...order.filter((c) => byCategory[c]),
    ...Object.keys(byCategory).filter((c) => !order.includes(c)),
  ];

  categories.forEach((category) => {
    const heading = document.createElement("div");
    heading.className = "profile-category";
    heading.textContent = CATEGORY_LABELS[category] || category;
    profileCards.appendChild(heading);

    byCategory[category]
      .slice()
      .sort((a, b) => (b.source_count || 0) - (a.source_count || 0))
      .forEach((rule) => profileCards.appendChild(renderRuleCard(rule)));
  });
}

function renderRuleCard(rule) {
  const card = document.createElement("div");
  card.className = "rule-card";

  const top = document.createElement("div");
  top.className = "rule-card-top";

  const badge = document.createElement("span");
  badge.className = `confidence-badge ${rule.confidence || "low"}`;
  badge.textContent = rule.confidence || "low";
  top.appendChild(badge);

  const count = document.createElement("span");
  count.className = "rule-source-count";
  count.textContent = `seen ${rule.source_count || 1}x`;
  top.appendChild(count);

  card.appendChild(top);

  const description = document.createElement("div");
  description.className = "rule-description";
  description.textContent = rule.description || "";
  card.appendChild(description);

  if (rule.example_before && rule.example_after) {
    const example = document.createElement("div");
    example.className = "rule-example";
    example.textContent = `"${rule.example_before}" → "${rule.example_after}"`;
    card.appendChild(example);
  }

  return card;
}

document.getElementById("profile-reload").addEventListener("click", async () => {
  await loadProfile();
  setStatus(profileStatus, "Reloaded from disk.", "ok");
});

document.getElementById("profile-consolidate").addEventListener("click", async () => {
  setStatus(profileStatus, "Consolidating similar rules...");
  try {
    const result = await postJSON("/api/voice-profile/consolidate", {});
    currentProfile = result.profile;
    renderProfile();
    setStatus(
      profileStatus,
      result.changed
        ? `Merged ${result.before_count} rules down to ${result.after_count}.`
        : "No merges found — rules already look distinct.",
      "ok"
    );
  } catch (err) {
    setStatus(profileStatus, err.message, "error");
  }
});

document.getElementById("profile-save").addEventListener("click", async () => {
  let parsed;
  try {
    parsed = JSON.parse(profileJson.value);
  } catch (err) {
    setStatus(profileStatus, "Invalid JSON — fix before saving.", "error");
    return;
  }
  try {
    await fetch("/api/voice-profile", {
      method: "PUT",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ profile: parsed }),
    });
    currentProfile = parsed;
    renderProfileCards();
    setStatus(profileStatus, "Saved.", "ok");
  } catch (err) {
    setStatus(profileStatus, err.message, "error");
  }
});

loadProfile();

// --- Settings tab ---

const settingsProvider = document.getElementById("settings-provider");
const settingsAnthropicKey = document.getElementById("settings-anthropic-key");
const settingsAnthropicModel = document.getElementById("settings-anthropic-model");
const settingsOpenaiKey = document.getElementById("settings-openai-key");
const settingsOpenaiModel = document.getElementById("settings-openai-model");
const settingsAnthropicStatus = document.getElementById("settings-anthropic-status");
const settingsOpenaiStatus = document.getElementById("settings-openai-status");
const settingsStatus = document.getElementById("settings-status");

async function loadSettings() {
  const response = await fetch("/api/settings");
  const data = await response.json();
  settingsProvider.value = data.provider;
  settingsAnthropicModel.value = data.anthropic_model;
  settingsOpenaiModel.value = data.openai_model;
  settingsAnthropicStatus.textContent = data.anthropic_api_key_set ? "(key set)" : "(not set)";
  settingsAnthropicStatus.className = "key-status" + (data.anthropic_api_key_set ? " set" : "");
  settingsOpenaiStatus.textContent = data.openai_api_key_set ? "(key set)" : "(not set)";
  settingsOpenaiStatus.className = "key-status" + (data.openai_api_key_set ? " set" : "");
}

document.getElementById("settings-save").addEventListener("click", async () => {
  setStatus(settingsStatus, "Saving...");
  try {
    await postJSON("/api/settings", {
      provider: settingsProvider.value,
      anthropic_api_key: settingsAnthropicKey.value || null,
      anthropic_model: settingsAnthropicModel.value || null,
      openai_api_key: settingsOpenaiKey.value || null,
      openai_model: settingsOpenaiModel.value || null,
    });
    settingsAnthropicKey.value = "";
    settingsOpenaiKey.value = "";
    await loadSettings();
    await checkSetupBanner();
    setStatus(settingsStatus, "Saved. New requests will use these settings.", "ok");
  } catch (err) {
    setStatus(settingsStatus, err.message, "error");
  }
});

loadSettings();
