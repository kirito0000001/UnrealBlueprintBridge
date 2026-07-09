# Windows 热更新方案

## 官方边界

Flutter 官方提供 Windows 和 Android 的构建发布流程，但没有一个跨平台的官方“热更新代码”机制。

- Windows：Flutter 可构建桌面 Release，正式分发可以走压缩包、安装器、MSIX 或商店渠道。
- Android：正式应用更新应走应用商店。Google Play 场景下可接 Android In-App Updates。
- 本项目的 Windows 热更新只替换 Windows Release 程序目录，不适用于 Android。

## 当前采用方案

第一版采用和本机 `FantasyTools` 类似的普通 exe 更新方式：

1. 打包 Windows Release 目录。
2. 在 Release 目录内写入 `update-package.json`。
3. 把整个 Release 目录压缩为 zip。
4. 生成 `blueprint-bridge-update.json` 更新清单。
5. 程序内读取清单，比较版本。
6. 下载 zip，校验大小和 SHA-256。
7. 启动外部 PowerShell 覆盖脚本。
8. 主程序退出，脚本解压、覆盖程序目录并重启新版本。

## 更新清单

程序内读取的清单文件名建议为：

```text
blueprint-bridge-update.json
```

结构示例：

```json
{
  "schemaVersion": 1,
  "productKey": "unreal-blueprint-bridge",
  "displayName": "虚幻：蓝图连结",
  "version": "1.0.1",
  "channel": "stable",
  "releaseNotes": "更新说明",
  "releaseNotesUrl": "",
  "assets": [
    {
      "runtime": "win-x64",
      "fileName": "UnrealBlueprintBridge-v1.0.1-win-x64.zip",
      "sha256": "...",
      "sizeBytes": 123456,
      "downloadUrl": "https://example.com/UnrealBlueprintBridge-v1.0.1-win-x64.zip"
    }
  ]
}
```

## 打包命令

```powershell
.\Scripts\打包Windows热更新.ps1 -Version 1.0.1 -DownloadBaseUrl "https://example.com/releases"
```

输出目录默认是：

```text
ReleaseAssets
```

输出内容：

- `UnrealBlueprintBridge-v版本-win-x64.zip`
- `UnrealBlueprintBridge-v版本-win-x64.sha256.txt`
- `blueprint-bridge-update.json`

## 程序内使用

在“整体设置”里填写更新清单 URL，然后点击“检查更新”。发现新版本后可以点击“下载并更新”。

注意：

- 只有 Windows 使用该覆盖更新。
- 更新脚本必须存在于程序目录的 `Scripts/热更新覆盖.ps1`。
- zip 内必须包含 `update-package.json`。
- `update-package.json` 的 `toolboxStableKey` 必须是 `UnrealBlueprintBridge`。

## Android 后续路线

Android 不使用 PowerShell 覆盖更新。后续建议：

- 内部测试：显示版本提示，让用户下载新的 APK。
- 正式发布：走应用商店更新。
- Google Play：接入 In-App Updates。
