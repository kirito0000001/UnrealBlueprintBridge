import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/update/app_update_models.dart';

void main() {
  test('AppUpdateManifest parses Windows update manifest', () {
    final manifest = AppUpdateManifest.fromJson({
      'schemaVersion': 1,
      'productKey': 'unreal-blueprint-bridge',
      'displayName': '虚幻：蓝图连结',
      'version': '1.0.1',
      'channel': 'stable',
      'releaseNotes': '更新说明',
      'releaseNotesUrl': 'https://example.com/release',
      'assets': [
        {
          'runtime': 'win-x64',
          'fileName': 'UnrealBlueprintBridge-v1.0.1-win-x64.zip',
          'sha256': 'abc',
          'sizeBytes': 42,
          'downloadUrl': 'https://example.com/app.zip',
        },
      ],
    });

    expect(manifest.productKey, 'unreal-blueprint-bridge');
    expect(manifest.version, '1.0.1');
    expect(manifest.assets.single.runtime, 'win-x64');
    expect(manifest.assets.single.sizeBytes, 42);
  });
}
