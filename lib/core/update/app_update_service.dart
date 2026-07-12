import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_update_models.dart';

class AppUpdateService {
  const AppUpdateService({this._httpClient});

  static const productKey = 'unreal-blueprint-bridge';
  static const displayName = '虚幻：蓝图连结';
  static const stableKey = 'UnrealBlueprintBridge';
  static const runtime = 'win-x64';
  static const entryExe = 'unreal_blueprint_bridge.exe';
  static const defaultManifestUrl =
      'https://github.com/kirito0000001/UnrealBlueprintBridge/releases/latest/download/blueprint-bridge-update.json';
  static const networkTimeout = Duration(seconds: 8);
  static const currentVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.2',
  );

  final HttpClient? _httpClient;

  static String resolveManifestUrl(String manifestUrl) {
    final trimmed = manifestUrl.trim();
    return trimmed.isEmpty ? defaultManifestUrl : trimmed;
  }

  Future<AppUpdateCheckResult> check({
    required String manifestUrl,
    required String currentVersion,
  }) async {
    if (!Platform.isWindows) {
      return AppUpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
        message: '当前平台暂不使用 Windows 热更新。Android 后续应走应用商店或 Play In-App Updates。',
      );
    }
    final effectiveManifestUrl = resolveManifestUrl(manifestUrl);
    if (effectiveManifestUrl.isEmpty) {
      return AppUpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
        message: '没有设置更新清单 URL。',
      );
    }

    final manifest = AppUpdateManifest.fromJson(
      jsonDecode(await _getString(effectiveManifestUrl))
          as Map<String, Object?>,
    );
    if (manifest.productKey != productKey) {
      return AppUpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
        message: '更新清单产品标识不匹配：${manifest.productKey}',
      );
    }

    final asset = manifest.assets
        .where((asset) => asset.runtime == runtime)
        .firstOrNull;
    if (asset == null) {
      return AppUpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
        manifest: manifest,
        message: '远端版本 ${manifest.version} 没有 $runtime 更新包。',
      );
    }

    if (_compareVersions(manifest.version, currentVersion) <= 0) {
      return AppUpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
        manifest: manifest,
        asset: asset,
        message: '当前已是最新版本：$currentVersion',
      );
    }

    return AppUpdateCheckResult(
      hasUpdate: true,
      currentVersion: currentVersion,
      manifest: manifest,
      asset: asset,
      message: '发现新版本：$currentVersion -> ${manifest.version}',
    );
  }

  Future<AppUpdateDownloadResult> downloadAndVerify({
    required AppUpdateManifest manifest,
    required AppUpdateAsset asset,
    required void Function(double progress, String message)? onProgress,
  }) async {
    final updatesDir = Directory(
      '${_localAppDataPath()}${Platform.pathSeparator}$stableKey${Platform.pathSeparator}Updates',
    );
    if (!await updatesDir.exists()) {
      await updatesDir.create(recursive: true);
    }

    final safeName = asset.fileName.split(RegExp(r'[\\/]')).last;
    final packagePath = '${updatesDir.path}${Platform.pathSeparator}$safeName';
    final tempPath = '$packagePath.download';
    final tempFile = File(tempPath);
    final packageFile = File(packagePath);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    onProgress?.call(0.05, '正在下载更新包...');
    await _downloadFile(
      asset.downloadUrl,
      tempFile,
      asset.sizeBytes,
      onProgress,
    );
    onProgress?.call(0.86, '正在校验 SHA-256...');
    final sha256 = await _sha256(tempFile);
    if (sha256.toLowerCase() != asset.sha256.toLowerCase()) {
      await tempFile.delete();
      throw StateError('更新包 SHA-256 不一致：$sha256');
    }

    if (asset.sizeBytes > 0) {
      final size = await tempFile.length();
      if (size != asset.sizeBytes) {
        await tempFile.delete();
        throw StateError('更新包大小不一致：$size / ${asset.sizeBytes}');
      }
    }

    if (await packageFile.exists()) {
      await packageFile.delete();
    }
    await tempFile.rename(packagePath);
    onProgress?.call(1, '更新包已准备就绪。');

    return AppUpdateDownloadResult(
      packagePath: packagePath,
      manifest: manifest,
      asset: asset,
    );
  }

  Future<void> launchWindowsUpdater({
    required AppUpdateDownloadResult download,
  }) async {
    if (!Platform.isWindows) {
      throw StateError('当前平台不支持 Windows 覆盖更新。');
    }

    final installDir = File(Platform.resolvedExecutable).parent.path;
    final scriptPath =
        '$installDir${Platform.pathSeparator}Scripts${Platform.pathSeparator}热更新覆盖.ps1';
    if (!await File(scriptPath).exists()) {
      throw FileSystemException('热更新脚本不存在', scriptPath);
    }

    final runnerDir = Directory(
      '${_localAppDataPath()}${Platform.pathSeparator}$stableKey${Platform.pathSeparator}UpdateRunners',
    );
    if (!await runnerDir.exists()) {
      await runnerDir.create(recursive: true);
    }
    final runnerPath =
        '${runnerDir.path}${Platform.pathSeparator}RunUpdate-${DateTime.now().millisecondsSinceEpoch}.cmd';
    final runner = File(runnerPath);
    await runner.writeAsString(
      [
        '@echo off',
        'chcp 65001 >nul',
        'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${_escape(scriptPath)}" -AppProcessId "$pid" -InstallDir "${_escape(installDir)}" -PackagePath "${_escape(download.packagePath)}" -ExpectedSha256 "${download.asset.sha256}" -ExeRelativePath "$entryExe" -ToolboxStableKey "$stableKey" -TargetVersion "${download.manifest.version}"',
      ].join('\r\n'),
    );

    await Process.start(
      'cmd.exe',
      ['/c', runnerPath],
      mode: ProcessStartMode.detached,
      workingDirectory: installDir,
    );
    exit(0);
  }

  Future<String> _getString(String url) async {
    final client = _httpClient ?? HttpClient();
    final request = await _waitForNetwork(
      client.getUrl(Uri.parse(url)),
      '连接更新服务器',
    );
    request.headers.set(HttpHeaders.userAgentHeader, 'UnrealBlueprintBridge');
    final response = await _waitForNetwork(request.close(), '等待更新服务器响应');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('更新清单请求失败：HTTP ${response.statusCode}');
    }
    return utf8.decode(
      await _waitForNetwork(
        consolidateHttpClientResponseBytes(response),
        '读取更新清单',
      ),
    );
  }

  Future<void> _downloadFile(
    String url,
    File file,
    int expectedSize,
    void Function(double progress, String message)? onProgress,
  ) async {
    final client = _httpClient ?? HttpClient();
    final request = await _waitForNetwork(
      client.getUrl(Uri.parse(url)),
      '连接更新服务器',
    );
    request.headers.set(HttpHeaders.userAgentHeader, 'UnrealBlueprintBridge');
    final response = await _waitForNetwork(request.close(), '等待更新服务器响应');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('更新包下载失败：HTTP ${response.statusCode}');
    }

    var downloaded = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response.timeout(networkTimeout)) {
        downloaded += chunk.length;
        sink.add(chunk);
        if (expectedSize > 0) {
          final ratio = downloaded / expectedSize;
          onProgress?.call(
            0.05 + ratio.clamp(0, 1) * 0.76,
            '正在下载更新包 ${(ratio * 100).clamp(0, 100).toStringAsFixed(0)}%',
          );
        }
      }
    } finally {
      await sink.close();
    }
  }

  Future<T> _waitForNetwork<T>(Future<T> operation, String action) {
    return operation.timeout(
      networkTimeout,
      onTimeout: () => throw TimeoutException('$action超时，请检查网络后重试。'),
    );
  }

  Future<String> _sha256(File file) async {
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-Command',
      "(Get-FileHash -LiteralPath '${file.path.replaceAll("'", "''")}' -Algorithm SHA256).Hash.ToLowerInvariant()",
    ]);
    if (result.exitCode != 0) {
      throw StateError('计算 SHA-256 失败：${result.stderr}');
    }
    return result.stdout.toString().trim();
  }

  String _localAppDataPath() {
    return Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
  }

  String _escape(String value) {
    return value.replaceAll('"', r'\"');
  }

  int _compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    for (var index = 0; index < 3; index++) {
      final diff = leftParts[index].compareTo(rightParts[index]);
      if (diff != 0) {
        return diff;
      }
    }
    return 0;
  }

  List<int> _versionParts(String value) {
    final core = _trimVersionPrefix(
      value.trim(),
    ).split('-').first.split('+').first;
    final parts = core.split('.');
    return [
      for (var index = 0; index < 3; index++)
        index < parts.length ? int.tryParse(parts[index]) ?? 0 : 0,
    ];
  }

  String _trimVersionPrefix(String value) {
    var result = value;
    while (result.isNotEmpty && (result[0] == 'v' || result[0] == 'V')) {
      result = result.substring(1);
    }
    return result;
  }
}
