import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/update/app_update_service.dart';

void main() {
  test(
    'AppUpdateService uses built-in manifest URL when override is empty',
    () {
      expect(
        AppUpdateService.resolveManifestUrl(''),
        AppUpdateService.defaultManifestUrl,
      );
      expect(
        AppUpdateService.resolveManifestUrl('   '),
        AppUpdateService.defaultManifestUrl,
      );
    },
  );

  test('AppUpdateService keeps custom manifest URL for temporary sources', () {
    expect(
      AppUpdateService.resolveManifestUrl(' https://example.com/update.json '),
      'https://example.com/update.json',
    );
  });

  test('AppUpdateService converts Windows system proxy settings', () {
    expect(
      AppUpdateService.proxyDirectiveForWindowsSetting('127.0.0.1:7897'),
      'PROXY 127.0.0.1:7897; DIRECT',
    );
    expect(
      AppUpdateService.proxyDirectiveForWindowsSetting(
        'http=127.0.0.1:7897;https=127.0.0.1:7897',
      ),
      'PROXY 127.0.0.1:7897; DIRECT',
    );
  });

  test(
    'AppUpdateService sends manifest requests through the system proxy',
    () async {
      final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <Uri>[];
      proxy.listen((request) async {
        requests.add(request.uri);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'schemaVersion': 1,
            'productKey': AppUpdateService.productKey,
            'displayName': AppUpdateService.displayName,
            'version': '1.0.1',
            'channel': 'stable',
            'assets': [],
          }),
        );
        await request.response.close();
      });

      try {
        final result =
            await AppUpdateService(
              windowsProxyResolver: () async =>
                  '${proxy.address.address}:${proxy.port}',
            ).check(
              manifestUrl: 'http://updates.example.invalid/manifest.json',
              currentVersion: '1.0.1',
            );

        expect(result.hasUpdate, isFalse);
        expect(requests, hasLength(1));
      } finally {
        await proxy.close(force: true);
      }
    },
  );

  test(
    'AppUpdateService reaches the built-in manifest through Windows proxy',
    () async {
      final result = await AppUpdateService().check(
        manifestUrl: AppUpdateService.defaultManifestUrl,
        currentVersion: '0.0.0',
      );

      expect(result.hasUpdate, isTrue);
    },
    skip: Platform.environment['RUN_NETWORK_TESTS'] == 'true'
        ? false
        : '仅在配置了 Windows 网络环境的机器上执行。',
  );

  test(
    'AppUpdateService stops waiting when the manifest server does not respond',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((_) {});
      final service = AppUpdateService();

      try {
        await expectLater(
          service.check(
            manifestUrl:
                'http://${server.address.address}:${server.port}/update.json',
            currentVersion: '1.0.1',
          ),
          throwsA(isA<TimeoutException>()),
        );
      } finally {
        await server.close(force: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );
}
