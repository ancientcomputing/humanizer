@echo off
cd /d "%~dp0"

if not exist ".venv" (
    python -m venv .venv
)

call .venv\Scripts\activate.bat
pip install -q -r requirements.txt

if not exist ".env" (
    copy .env.example .env
    echo Created .env from .env.example -- add your API key before running again.
    exit /b 1
)

python app.py
