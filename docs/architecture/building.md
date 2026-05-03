# Building SentraCore

This guide covers how to produce standalone, production-ready executables and compile the final Windows installer.

---

## Prerequisites

| Requirement | Verification Command |
|---|---|
| Python 3.11+ with virtual environment | `.venv\Scripts\python --version` |
| PyInstaller (installed in venv) | `.venv\Scripts\pyinstaller --version` |
| Flutter SDK (stable) | `flutter --version` |
| Visual Studio with "Desktop development with C++" | `flutter doctor` |
| Inno Setup 6 | Installed from [jrsoftware.org](https://jrsoftware.org/isinfo.php) |

---

## Step 1: Build the Python Engine

```powershell
scripts\build_engine.bat
```

This script activates the virtual environment, cleans previous artifacts, runs PyInstaller with the correct hidden imports for `uvicorn` and `fastapi`, and outputs `SentraCoreEngine.exe` to the `dist/` directory.

The engine is compiled with `--noconsole` so it runs as a fully invisible background process.

**Output:** `dist\SentraCoreEngine.exe`

---

## Step 2: Build the Flutter Dashboard

```powershell
scripts\build_dashboard.bat
```

This script navigates to the `dashboard/` directory and runs `flutter build windows --release`.

> Note: Flutter bundles the executable alongside several required DLL files and data directories. The entire `Release\` folder contents must be included in the installer.

**Output:** `dashboard\build\windows\x64\runner\Release\`

---

## Step 3: Compile the Installer

1. Open **Inno Setup Compiler**.
2. Go to **File → Open** and select `installer\sentracore.iss`.
3. Press **Ctrl+F9** to compile.

**Output:** `dist\SentraCore_Setup_v1.0.exe`

---

## What the Installer Does

| Action | Detail |
|---|---|
| Install location | `C:\Program Files\SentraCore\` |
| Desktop shortcut | Optional, user-selectable during install |
| Start Menu group | `SentraCore\` with shortcuts to Dashboard and Uninstaller |
| Auto-start on login | Adds `SentraCoreEngine.exe` to `HKCU\...\Run` (optional) |
| Post-install launch | Starts the engine in background, optionally opens the dashboard |
| Uninstall | Kills the engine process and removes all files and registry keys |

---

## Releasing a New Version

1. Update `__version__` in `engine/__init__.py`.
2. Update `AppVersion` and `OutputBaseFilename` in `installer/sentracore.iss`.
3. Commit all changes.
4. Create and push an annotated Git tag:
   ```powershell
   git tag -a v1.1.0 -m "Release v1.1.0"
   git push origin main --tags
   ```
5. Run the three build steps above to produce the new installer.
6. Create a GitHub Release from the tag and attach the new `SentraCore_Setup_v*.exe` as a release asset.
