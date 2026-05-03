@echo off
echo ==========================================
echo Running SentraCore Local CI/CD Checks
echo ==========================================

echo.
echo [1/4] Running Python Linter (Ruff)...
cd "%~dp0.."
if not exist ".venv" (
    echo Python virtual environment not found. Please set it up first.
    exit /b 1
)
call .venv\Scripts\activate.bat
ruff check .
if %errorlevel% neq 0 (
    echo Ruff check failed!
    exit /b %errorlevel%
)
echo Ruff check passed.

echo.
echo [2/4] Running Python Formatter Check (Ruff)...
ruff format --check .
if %errorlevel% neq 0 (
    echo Ruff format check failed!
    exit /b %errorlevel%
)
echo Ruff format passed.

echo.
echo [3/4] Running Flutter Analyzer...
cd dashboard
call flutter analyze
if %errorlevel% neq 0 (
    echo Flutter analyze failed!
    exit /b %errorlevel%
)
echo Flutter analyze passed.

echo.
echo [4/4] Running Dart Formatter...
call dart format --set-exit-if-changed .
if %errorlevel% neq 0 (
    echo Dart format check failed!
    exit /b %errorlevel%
)
echo Dart format passed.

echo.
echo ==========================================
echo All Local CI/CD Checks Passed Successfully!
echo ==========================================
pause
