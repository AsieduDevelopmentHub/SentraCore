@echo off
echo ===========================================
echo Building SentraCore Engine (Python)
echo ===========================================

REM Ensure we are in the root directory
cd %~dp0\..

REM Activate the virtual environment
call .venv\Scripts\activate

REM Clean previous builds
if exist "build" rmdir /s /q build
if exist "dist\SentraCoreEngine.exe" del /q "dist\SentraCoreEngine.exe"

REM Run PyInstaller
REM --onefile: creates a single executable
REM --noconsole: hides the terminal window
REM --name: the name of the executable
REM --hidden-import: ensure fastapi/uvicorn dependencies are included
echo Running PyInstaller...
pyinstaller --name "SentraCoreEngine" ^
            --noconsole ^
            --onefile ^
            --hidden-import "uvicorn.logging" ^
            --hidden-import "uvicorn.loops" ^
            --hidden-import "uvicorn.loops.auto" ^
            --hidden-import "uvicorn.protocols" ^
            --hidden-import "uvicorn.protocols.http" ^
            --hidden-import "uvicorn.protocols.http.auto" ^
            --hidden-import "uvicorn.protocols.websockets" ^
            --hidden-import "uvicorn.protocols.websockets.auto" ^
            --hidden-import "engine.api.server" ^
            --clean ^
            engine/main.py

echo.
echo Engine build complete! Executable is located at dist\SentraCoreEngine.exe
