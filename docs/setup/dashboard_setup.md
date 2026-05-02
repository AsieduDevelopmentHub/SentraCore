# SentraCore Dashboard Setup

The dashboard is built with Flutter and compiles to a native Windows Desktop application.

## Prerequisites
- Flutter SDK (stable channel)
- Visual Studio 2022 Community (or higher)
  - **Important:** Must include the **"Desktop development with C++"** workload.

## Developer Mode (Windows)
Flutter requires Windows Developer Mode to be enabled to create necessary symlinks during the build process.
1. Open Windows Settings.
2. Search for "Developer Mode".
3. Toggle "Developer Mode" to **On**.

## Installation & Running

1. Navigate to the dashboard directory:
   ```powershell
   cd dashboard
   ```
2. Get Flutter dependencies:
   ```powershell
   flutter pub get
   ```
3. Run the application in debug mode:
   ```powershell
   flutter run -d windows
   ```

## Building for Production
To create a standalone executable:
```powershell
flutter build windows
```
The executable will be located in `dashboard\build\windows\x64\runner\Release\`.
