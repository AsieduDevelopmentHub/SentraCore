# SentraCore Dashboard (Flutter / Windows)

The SentraCore dashboard is a Flutter Windows desktop UI that connects to the local Python engine and renders real-time system intelligence:

- Live system state stream (WebSocket)
- Status/health/process/event queries (REST)
- Stability Index, stress, predictions, and root cause panels

## Connectivity

By default the engine runs on:

- REST: `http://127.0.0.1:8740/api/v1/`
- WebSocket: `ws://127.0.0.1:8740/ws/live`

If you change the engine port, update `EngineService` in `lib/services/engine_service.dart` (or make it configurable via settings).

## Running locally

From the repository root, start the engine:

```powershell
.venv\Scripts\python -m engine.main
```

Then in a second terminal:

```powershell
cd dashboard
flutter pub get
flutter run -d windows
```

## Quality checks

```powershell
cd dashboard
flutter analyze
flutter test
```
