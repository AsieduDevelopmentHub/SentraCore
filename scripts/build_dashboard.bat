@echo off
echo ===========================================
echo Building SentraCore Dashboard (Flutter)
echo ===========================================

REM Ensure we are in the root directory
cd %~dp0\..\dashboard

echo Running flutter build windows...
call flutter build windows --release

echo.
echo Dashboard build complete! Executables are located in dashboard\build\windows\x64\runner\Release
