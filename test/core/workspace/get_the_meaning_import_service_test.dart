import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/workspace/get_the_meaning_import_service.dart';

void main() {
  test(
    'GetTheMeaningImportService reads index files and returns summary',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('gtm_import_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await File('${tempDir.path}/ExportIndex.json').writeAsString('''
{
  "schemaVersion": 1,
  "generatedBy": "GetTheMeaning",
  "assetCount": 2,
  "assets": [
    {"name": "GM_MainMode", "type": "Blueprint"},
    {"name": "WBP_Login", "type": "WidgetBlueprint"}
  ]
}
''');
      await File('${tempDir.path}/ExportGraph.json').writeAsString('''
{
  "schemaVersion": 2,
  "nodeCount": 40,
  "edgeCount": 55
}
''');
      await File('${tempDir.path}/CppSourceIndex.json').writeAsString('''
{
  "schemaVersion": 1,
  "projectName": "FantasyProject",
  "classCount": 25,
  "structCount": 16,
  "enumCount": 11,
  "functionCount": 194
}
''');

      const service = GetTheMeaningImportService();
      final summary = await service.inspectDirectory(tempDir.path);

      expect(summary.available, isTrue);
      expect(summary.assetCount, 2);
      expect(summary.blueprintCount, 1);
      expect(summary.widgetBlueprintCount, 1);
      expect(summary.graphNodeCount, 40);
      expect(summary.graphEdgeCount, 55);
      expect(summary.cppClassCount, 25);
      expect(summary.cppStructCount, 16);
      expect(summary.cppEnumCount, 11);
      expect(summary.cppFunctionCount, 194);
      expect(summary.assets, hasLength(2));
      expect(summary.assets.first.name, 'GM_MainMode');
      expect(summary.assets.first.type, 'Blueprint');
      expect(summary.assets.last.type, 'WidgetBlueprint');
    },
  );

  test('GetTheMeaningImportService preserves asset detail fields', () async {
    final tempDir = await Directory.systemTemp.createTemp('gtm_asset_detail_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    await File('${tempDir.path}/ExportIndex.json').writeAsString('''
{
  "assetCount": 1,
  "assets": [
    {
      "name": "GM_MainMode",
      "displayName": "GM_MainMode (/Game/BaseC/Mode)",
      "type": "Blueprint",
      "assetPath": "/Game/BaseC/Mode/GM_MainMode.GM_MainMode",
      "packagePath": "/Game/BaseC/Mode",
      "parentClass": "GameModeBase",
      "readablePath": "GetTheMeaningExports/Game/BaseC/Mode/GM_MainMode_ReadableCode.txt",
      "logicJsonPath": "GetTheMeaningExports/Game/BaseC/Mode/GM_MainMode_Logic.json",
      "variables": ["GUIDMaps", "PLayerMaps"],
      "events": ["ReceiveBeginPlay"],
      "rpcs": ["ROS_Login"],
      "functions": ["UserLogin", "JudgeRoom"],
      "calls": ["GameplayStatics::SaveGameToSlot"]
    }
  ]
}
''');

    const service = GetTheMeaningImportService();
    final summary = await service.inspectDirectory(tempDir.path);
    final asset = summary.assets.single;

    expect(asset.displayName, 'GM_MainMode (/Game/BaseC/Mode)');
    expect(asset.assetPath, '/Game/BaseC/Mode/GM_MainMode.GM_MainMode');
    expect(asset.parentClass, 'GameModeBase');
    expect(asset.variables, ['GUIDMaps', 'PLayerMaps']);
    expect(asset.events, ['ReceiveBeginPlay']);
    expect(asset.rpcs, ['ROS_Login']);
    expect(asset.functions, ['UserLogin', 'JudgeRoom']);
    expect(asset.calls, ['GameplayStatics::SaveGameToSlot']);
  });

  test(
    'GetTheMeaningImportService reports missing ExportIndex clearly',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'gtm_import_missing_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      const service = GetTheMeaningImportService();
      final summary = await service.inspectDirectory(tempDir.path);

      expect(summary.available, isFalse);
      expect(summary.message, contains('ExportIndex.json'));
    },
  );

  test(
    'GetTheMeaningImportService asks user to export when directory missing',
    () async {
      final missingPath =
          '${Directory.systemTemp.path}/gtm_missing_${DateTime.now().microsecondsSinceEpoch}';

      const service = GetTheMeaningImportService();
      final summary = await service.inspectDirectory(missingPath);

      expect(summary.available, isFalse);
      expect(summary.message, contains('请使用 GetTheMeaning 插件'));
    },
  );
}
