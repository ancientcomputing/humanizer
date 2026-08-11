#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi

source .venv/bin/activate
pip install -q -r requirements.txt

if [ ! -f ".env" ]; then
    cp .env.example .env
    echo "Created .env from .env.example — add your API key(s) before running again."
    exit 1
fi

python app.py
