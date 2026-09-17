# 124 Phone

Flutter SIP phone workspace with a local Dart API for login and recent call history.

## 1. Start the backend

Open PowerShell 1 in the project folder:

```powershell
cd C:\Rushank\Balatrix\SIP_Phone\Flutter\SIP_Phone\sip_phone
dart run backend/server.dart
```

Leave this terminal running. The API listens on port `8080`.

Open PowerShell 2 for Flutter commands:

```powershell
flutter pub get
flutter devices
```

The backend stores data in memory for development. Restarting it clears users, sessions, and calls.

## 2. Windows

Requirements: Windows, Flutter, and Visual Studio with the Desktop development with C++ workload.

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8080/api
```

## 3. Android emulator

Requirements: Android Studio, Android SDK, and an AVD.

1. Start an emulator in Android Studio, or run `flutter emulators`.
2. Confirm Flutter sees it with `flutter devices`.
3. Run with `10.0.2.2`, which maps from the emulator to the host computer:

```powershell
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

## 4. Physical Android phone

1. Enable Developer options and USB debugging on the phone.
2. Connect it by USB and accept the RSA prompt.
3. Check the connection:

```powershell
adb devices
flutter devices
```

4. Find the computer LAN address with `ipconfig`.
5. Put the phone and computer on the same Wi-Fi network.
6. Allow inbound TCP port `8080` in Windows Firewall if prompted.
7. Run with the computer LAN address:

```powershell
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://<computer-lan-ip>:8080/api
```

## 5. iOS and iPhone

iOS builds require macOS and Xcode. Windows cannot compile or run the iOS target.

On the Mac:

```bash
cd /path/to/sip_phone
flutter pub get
open -a Simulator
flutter devices
flutter run -d <ios-device-id> --dart-define=API_BASE_URL=http://127.0.0.1:8080/api
```

For a physical iPhone, open `ios/Runner.xcworkspace` in Xcode, select a development Team under **Signing & Capabilities**, trust the Mac on the iPhone, then run:

```bash
flutter run -d <iphone-device-id> --dart-define=API_BASE_URL=http://<mac-lan-ip>:8080/api
```

The iPhone and Mac must be on the same network. Use HTTPS for a production API.

## 6. macOS

macOS builds require macOS and Xcode:

```bash
flutter config --enable-macos-desktop
flutter run -d macos --dart-define=API_BASE_URL=http://127.0.0.1:8080/api
```

## 7. Linux

Linux builds require a Linux machine with Flutter and desktop build dependencies installed:

```bash
flutter config --enable-linux-desktop
flutter run -d linux --dart-define=API_BASE_URL=http://127.0.0.1:8080/api
```

Linux cannot be compiled natively from Windows. Use a Linux machine, VM, or CI runner.

## 8. Web

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080/api
```

## Troubleshooting

- `No supported devices connected`: start an emulator or connect a phone, then rerun `flutter devices`.
- `flutter run -d android`: `android` is not a device ID. Use the exact ID printed by `flutter devices`.
- API unavailable: start `dart run backend/server.dart` first and verify `http://127.0.0.1:8080/api/health`.
- Android API unavailable: use `10.0.2.2` for an emulator or the computer LAN IP for a physical phone.
- iOS/macOS/Linux unavailable on Windows: those targets require their native operating system toolchains.

## Validation

```powershell
flutter analyze
flutter test
dart analyze backend/server.dart
```
