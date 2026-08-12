@echo off
cd /d "%~dp0"

if not exist ".venv" (
    python -m venv .venv
)
call .venv\Scripts\activate.bat
pip install -q -r requirements-build.txt

if exist "build" rmdir /s /q "build"
if exist "dist\Humanizer.exe" del /q "dist\Humanizer.exe"

pyinstaller --noconfirm --onefile --name Humanizer ^
  --icon "web\static\favicon.ico" ^
  --add-data "web;web" ^
  --add-data "prompts;prompts" ^
  --hidden-import "uvicorn.logging" ^
  --hidden-import "uvicorn.loops.auto" ^
  --hidden-import "uvicorn.protocols.http.auto" ^
  --hidden-import "uvicorn.protocols.websockets.auto" ^
  --hidden-import "uvicorn.lifespan.on" ^
  app.py

echo.
echo Build complete: dist\Humanizer.exe
echo Double-click it to run Humanizer -- no Python install needed.
