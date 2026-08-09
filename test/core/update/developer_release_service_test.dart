import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/update/developer_release_service.dart';

void main() {
  test('DeveloperReleaseService accepts semantic release versions', () {
    expect(DeveloperReleaseService.isValidVersion('1.2.3'), isTrue);
    expect(DeveloperReleaseService.isValidVersion('v1.2.3-beta.1'), isTrue);
    expect(DeveloperReleaseService.isValidVersion('1.2'), isFalse);
    expect(DeveloperReleaseService.isValidVersion('release-1.2.3'), isFalse);
  });

  test('DeveloperReleaseService builds the fixed publish script command', () {
    final arguments = DeveloperReleaseService.buildPowerShellArguments(
      projectRoot: r'D:\UnrealMap\UnrealBlueprintBridge',
      version: '1.2.3',
      releaseNotes: '修复更新检查。',
    );

    expect(arguments, contains('-File'));
    expect(
      arguments,
      contains(r'D:\UnrealMap\UnrealBlueprintBridge\Scripts\发布Windows热更新.ps1'),
    );
    expect(arguments, containsAllInOrder(['-Version', '1.2.3']));
    expect(arguments, containsAllInOrder(['-ReleaseNotes', '修复更新检查。']));
  });

  test('DeveloperReleaseService tolerates non-UTF8 Windows process output', () {
    expect(
      () => DeveloperReleaseService.decodeWindowsProcessOutput([0x81, 0x30]),
      returnsNormally,
    );
  });

  test(
    'DeveloperReleaseService reports a duplicate release without output decoding errors',
    () async {
      await expectLater(
        const DeveloperReleaseService().publish(
          version: '1.0.3',
          releaseNotes: '不应上传。',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('发布脚本失败，退出码：1。请查看下方发布日志。'),
          ),
        ),
      );
    },
    skip: Platform.environment['RUN_RELEASE_TESTS'] == 'true'
        ? false
        : '仅在已登录 GitHub 的 Windows 开发机上执行。',
  );

  test(
    'Publish script allows a missing release during its preflight check',
    () {
      final source = File('Scripts/发布Windows热更新.ps1').readAsStringSync();

      expect(source, contains(r'$releaseExists'));
      expect(source, contains(r'$ErrorActionPreference = "Continue"'));
    },
  );

  test('Package script uses .NET SHA-256 instead of Get-FileHash', () {
    final source = File('Scripts/打包Windows热更新.ps1').readAsStringSync();

    expect(source, contains('function Get-FileSha256'));
    expect(source, contains('[System.Security.Cryptography.SHA256]::Create()'));
    expect(source, isNot(contains('Get-FileHash')));
  });
}
