import 'dart:async';
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
