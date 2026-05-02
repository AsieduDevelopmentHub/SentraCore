# SentraCore Engine Setup

The SentraCore engine is a Python-based system telemetry collector and intelligence layer.

## Prerequisites
- Python 3.11+
- Windows OS (psutil relies on Windows counters for some accurate metrics)

## Installation

1. Navigate to the root of the mono-repo.
2. Create a virtual environment:
   ```powershell
   python -m venv .venv
   ```
3. Activate the environment:
   ```powershell
   .venv\Scripts\Activate
   ```
4. Install dependencies:
   ```powershell
   pip install -r requirements.txt
   ```

## Running the Engine

The engine must be run as a module from the root directory so imports resolve correctly:

```powershell
.venv\Scripts\python -m engine.main
```

## Running Tests

To run the unit test suite:
```powershell
.venv\Scripts\python -m pytest tests/
```
