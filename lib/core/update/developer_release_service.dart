import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class DeveloperReleaseResult {
  const DeveloperReleaseResult({
    required this.version,
    required this.releaseDirectory,
    required this.log,
  });

  final String version;
  final String releaseDirectory;
  final String log;
}

class DeveloperReleaseService {
  const DeveloperReleaseService();

  static bool get isReleaseToolsEnabled {
    return kDebugMode || bool.fromEnvironment('ENABLE_RELEASE_TOOLS');
  }

  static bool isValidVersion(String value) {
    return RegExp(
      r'^v?\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$',
    ).hasMatch(value.trim());
  }

  static String nextPatchVersion(String version) {
    final normalized = version.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final parts = normalized.split('-').first.split('.');
    if (parts.length != 3) {
      return '1.0.0';
    }
    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patch = int.tryParse(parts[2]);
    if (major == null || minor == null || patch == null) {
      return '1.0.0';
    }
    return '$major.$minor.${patch + 1}';
  }

  static List<String> buildPowerShellArguments({
    required String projectRoot,
    required String version,
    required String releaseNotes,
  }) {
    final scriptPath =
        '$projectRoot${Platform.pathSeparator}Scripts${Platform.pathSeparator}发布Windows热更新.ps1';
    return [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      scriptPath,
      '-Version',
      version.trim().replaceFirst(RegExp(r'^[vV]'), ''),
      '-ReleaseNotes',
      releaseNotes.trim(),
    ];
  }

  static String decodeWindowsProcessOutput(List<int> bytes) {
    try {
      return systemEncoding.decode(bytes);
    } on FormatException {
      return const Latin1Codec(allowInvalid: true).decode(bytes);
    }
  }

  Future<DeveloperReleaseResult> publish({
    required String version,
    required String releaseNotes,
    void Function(String line)? onLog,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('开发发布工具目前仅支持 Windows。');
    }
    if (!isValidVersion(version)) {
      throw ArgumentError.value(
        version,
        'version',
        '版本号应为 1.2.3 或 1.2.3-beta.1。',
      );
    }

    final root = _findProjectRoot();
    final script = File(
      '${root.path}${Platform.pathSeparator}Scripts${Platform.pathSeparator}发布Windows热更新.ps1',
    );
    if (!await script.exists()) {
      throw FileSystemException('发布脚本不存在', script.path);
    }

    final process = await Process.start(
      'powershell.exe',
      buildPowerShellArguments(
        projectRoot: root.path,
        version: version,
        releaseNotes: releaseNotes,
      ),
      workingDirectory: root.path,
    );
    final output = StringBuffer();
    final stdoutDone = _collectOutput(process.stdout, output, onLog);
    final stderrDone = _collectOutput(process.stderr, output, onLog);
    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);

    if (exitCode != 0) {
      throw StateError('发布脚本失败，退出码：$exitCode。请查看下方发布日志。');
    }
    final normalizedVersion = version.trim().replaceFirst(RegExp(r'^[vV]'), '');
    return DeveloperReleaseResult(
      version: normalizedVersion,
      releaseDirectory: 'D:\\DabaoV\\虚幻蓝图连结V$normalizedVersion',
      log: output.toString(),
    );
  }

  Future<void> _collectOutput(
    Stream<List<int>> source,
    StringBuffer output,
    void Function(String line)? onLog,
  ) async {
    final pending = StringBuffer();
    await for (final bytes in source) {
      pending.write(decodeWindowsProcessOutput(bytes));
      final lines = pending.toString().split(RegExp(r'\r?\n'));
      pending
        ..clear()
        ..write(lines.removeLast());
      for (final line in lines) {
        output.writeln(line);
        onLog?.call(line);
      }
    }
    if (pending.isNotEmpty) {
      final line = pending.toString();
      output.writeln(line);
      onLog?.call(line);
    }
  }

  Directory _findProjectRoot() {
    final candidates = <Directory>[
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ];
    for (final candidate in candidates) {
      var current = candidate;
      while (true) {
        final pubspec = File(
          '${current.path}${Platform.pathSeparator}pubspec.yaml',
        );
        final script = File(
          '${current.path}${Platform.pathSeparator}Scripts${Platform.pathSeparator}发布Windows热更新.ps1',
        );
        if (pubspec.existsSync() && script.existsSync()) {
          return current;
        }
        final parent = current.parent;
        if (parent.path == current.path) {
          break;
        }
        current = parent;
      }
    }
    throw StateError('未找到包含 pubspec.yaml 与发布脚本的项目根目录。请从项目目录运行开发版本。');
  }
}
