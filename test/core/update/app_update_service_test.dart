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
}
