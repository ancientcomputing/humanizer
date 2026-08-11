from __future__ import annotations

import threading
import webbrowser

import uvicorn
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from core.config import DATA_DIR, PROJECT_ROOT, Config, load_dotenv, update_dotenv
from core.format_rules import PLATFORMS, apply_format_rules
from core.pipeline import (
    PipelineError,
    consolidate_voice_profile,
    humanize as run_humanize,
    review as run_review,
)
from core.providers import get_provider
from core.voice_profile import VoiceProfile

load_dotenv()
config = Config.from_env()
provider = get_provider(config)
voice_profile_path = DATA_DIR / "voice_profile.json"
voice_profile = VoiceProfile(voice_profile_path)

app = FastAPI(title="Humanizer")


class HumanizeRequest(BaseModel):
    draft: str
    platform: str = "Other"


class ReviewRequest(BaseModel):
    humanized: str
    edited: str


class ExportRequest(BaseModel):
    text: str
    platform: str = "Other"


class VoiceProfileUpdateRequest(BaseModel):
    profile: dict


class SettingsUpdateRequest(BaseModel):
    provider: str
    anthropic_api_key: str | None = None
    anthropic_model: str | None = None
    openai_api_key: str | None = None
    openai_model: str | None = None


@app.post("/api/humanize")
def api_humanize(payload: HumanizeRequest) -> dict:
    voice_profile.reload()
    try:
        result = run_humanize(provider, config, voice_profile, payload.draft, payload.platform)
    except PipelineError as exc:
        return JSONResponse(status_code=400, content={"error": str(exc)})
    return result


@app.post("/api/review")
def api_review(payload: ReviewRequest) -> dict:
    voice_profile.reload()
    try:
        result = run_review(provider, config, voice_profile, payload.humanized, payload.edited)
    except PipelineError as exc:
        return JSONResponse(status_code=400, content={"error": str(exc)})
    return result


@app.post("/api/learn")
def api_learn(payload: ReviewRequest) -> dict:
    # Learn Mode reuses the review pipeline: original draft == "humanized" slot,
    # published version == "edited" slot.
    return api_review(payload)


@app.post("/api/export")
def api_export(payload: ExportRequest) -> dict:
    if payload.platform not in PLATFORMS:
        return JSONResponse(status_code=400, content={"error": f"Unknown platform '{payload.platform}'."})
    return {"text": apply_format_rules(payload.text, payload.platform)}


@app.get("/api/voice-profile")
def api_get_voice_profile() -> dict:
    voice_profile.reload()
    return voice_profile.data


@app.put("/api/voice-profile")
def api_put_voice_profile(payload: VoiceProfileUpdateRequest) -> dict:
    voice_profile.data = payload.profile
    voice_profile.save()
    return voice_profile.data


@app.post("/api/voice-profile/consolidate")
def api_consolidate_voice_profile() -> dict:
    voice_profile.reload()
    try:
        result = consolidate_voice_profile(provider, config, voice_profile)
    except PipelineError as exc:
        return JSONResponse(status_code=400, content={"error": str(exc)})
    result["profile"] = voice_profile.data
    return result


@app.get("/api/settings")
def api_get_settings() -> dict:
    return {
        "provider": config.provider,
        "anthropic_model": config.anthropic_model,
        "openai_model": config.openai_model,
        "anthropic_api_key_set": bool(config.anthropic_api_key),
        "openai_api_key_set": bool(config.openai_api_key),
        "host": config.host,
        "port": config.port,
    }


@app.post("/api/settings")
def api_post_settings(payload: SettingsUpdateRequest) -> dict:
    global config, provider

    updates: dict[str, str] = {"HUMANIZER_PROVIDER": payload.provider.strip().lower()}
    if payload.anthropic_api_key:
        updates["ANTHROPIC_API_KEY"] = payload.anthropic_api_key.strip()
    if payload.anthropic_model:
        updates["ANTHROPIC_MODEL"] = payload.anthropic_model.strip()
    if payload.openai_api_key:
        updates["OPENAI_API_KEY"] = payload.openai_api_key.strip()
    if payload.openai_model:
        updates["OPENAI_MODEL"] = payload.openai_model.strip()

    try:
        update_dotenv(updates)
    except OSError as exc:
        return JSONResponse(status_code=500, content={"error": f"Could not write .env: {exc}"})

    load_dotenv(override=True)
    config = Config.from_env()
    try:
        provider = get_provider(config)
    except Exception as exc:  # noqa: BLE001 - surface any provider construction error
        return JSONResponse(status_code=400, content={"error": str(exc)})

    return api_get_settings()


app.mount("/", StaticFiles(directory=str(PROJECT_ROOT / "web" / "static"), html=True), name="static")


def main() -> None:
    url = f"http://{config.host}:{config.port}"
    if config.open_browser:
        threading.Timer(1.0, lambda: webbrowser.open(url)).start()
    uvicorn.run(app, host=config.host, port=config.port, log_level="info")


if __name__ == "__main__":
    main()
