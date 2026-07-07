# 虚幻：蓝图连结

`unreal_blueprint_bridge` is a Flutter node graph draft editor for Windows and Android.

Display name: `虚幻：蓝图连结`

Android application id: `com.TFAC.unreal_blueprint_bridge`

The first version focuses on drawing blueprint-style planning graphs, connecting pins, and saving/loading structured JSON. It does not execute graph logic, generate Unreal assets, or modify `.uasset` files.

## Current Scope

- Windows and Android Flutter app.
- Shared Dart graph models.
- JSON graph codec.
- Desktop/mobile editor shell.
- Foundation for node canvas, pins, links, and graph file workflows.

## Environment

Flutter SDK:

```text
C:\Users\liuyu\develop\flutter
```

Use the explicit Flutter path when the current terminal has not refreshed `PATH`:

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' --version
```

Android builds should use the dedicated Gradle cache to avoid conflicts with the global Unreal-related Gradle config:

```powershell
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:GRADLE_USER_HOME='C:\Users\liuyu\.gradle_flutter'
```

## Common Commands

Install dependencies:

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' pub get
```

Format:

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\dart.bat' format .
```

Analyze:

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' analyze
```

Test:

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' test
```

Build Windows:

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' build windows
```

Build Android debug APK:

```powershell
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:GRADLE_USER_HOME='C:\Users\liuyu\.gradle_flutter'
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' build apk --debug
```

## Graph JSON Shape

The first schema uses `.ubbridge.json` documents with this top-level shape:

```json
{
  "schemaVersion": 1,
  "graph": {
    "id": "graph_001",
    "title": "Login Flow",
    "description": "登录流程草稿",
    "createdAt": "2026-07-07T12:00:00+08:00",
    "updatedAt": "2026-07-07T12:20:00+08:00",
    "viewport": {
      "offsetX": 0,
      "offsetY": 0,
      "zoom": 1.0
    }
  },
  "nodes": [],
  "links": []
}
```
