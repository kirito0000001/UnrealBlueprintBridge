import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_document.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_node.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_viewport.dart';
import 'package:unreal_blueprint_bridge/core/services/graph_json_codec.dart';
import 'package:unreal_blueprint_bridge/core/workspace/blueprint_bridge_graph_package_service.dart';
import 'package:unreal_blueprint_bridge/core/workspace/canvas_workspace.dart';

void main() {
  test('loads GraphIndex package into canvas drafts', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'ubbridge_graph_package_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    await _writePackageIndex(tempDir, [
      <String, Object?>{
        'id': 'gm_mainmode_userlogin',
        'title': 'GM_MainMode / UserLogin',
        'assetName': 'GM_MainMode',
        'assetPath': '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
        'graphName': 'UserLogin',
        'source': 'ai-generated',
        'purpose': 'example',
        'file': 'Graphs/GM_MainMode_UserLogin.json',
      },
    ]);
    await _writeGraph(
      tempDir,
      'Graphs/GM_MainMode_UserLogin.json',
      _document('GM_MainMode / UserLogin', 180),
    );

    const service = BlueprintBridgeGraphPackageService();
    final result = await service.loadPackage(tempDir);

    expect(result.available, isTrue);
    expect(result.importedCount, 1);
    expect(result.warnings, isEmpty);
    expect(result.workspace.drafts, hasLength(1));
    expect(result.workspace.activeDraft?.assetName, 'GM_MainMode');
    expect(
      result.workspace.activeDraft?.assetPath,
      '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
    );
    expect(result.workspace.activeDraft?.graphName, 'UserLogin');
    expect(result.workspace.activeDraft?.document.nodes.single.position.x, 180);
  });

  test(
    'loads package from selected GraphIndex file parent directory',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'ubbridge_graph_package_selected_index_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await _writePackageIndex(tempDir, [
        <String, Object?>{
          'id': 'draft_toggle_door',
          'title': '幻杀图例草稿 / 开关门逻辑',
          'assetName': '幻杀图例草稿',
          'assetPath': 'draft://幻杀图例草稿',
          'graphName': '开关门逻辑',
          'source': 'ai-generated',
          'purpose': 'example',
          'file': 'Graphs/幻杀图例草稿_开关门逻辑.json',
        },
      ]);
      await _writeGraph(
        tempDir,
        'Graphs/幻杀图例草稿_开关门逻辑.json',
        _document('幻杀图例草稿 / 开关门逻辑', 240),
      );

      const service = BlueprintBridgeGraphPackageService();
      final result = await service.loadPackageFromIndexFile(
        File('${tempDir.path}${Platform.pathSeparator}GraphIndex.json'),
      );

      expect(result.available, isTrue);
      expect(result.importedCount, 1);
      expect(result.warnings, isEmpty);
      expect(result.workspace.activeDraft?.assetName, '幻杀图例草稿');
      expect(result.workspace.activeDraft?.graphName, '开关门逻辑');
    },
  );

  test(
    'loads the original graph document for a matching canvas draft',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'ubbridge_graph_package_reset_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await _writePackageIndex(tempDir, [
        <String, Object?>{
          'title': 'BP_Door / 门交互开关逻辑',
          'assetName': 'BP_Door',
          'assetPath': '/Game/Blueprints/BP_Door.BP_Door',
          'graphName': '门交互开关逻辑',
          'file': 'Graphs/BP_Door_门交互开关逻辑.json',
        },
      ]);
      await _writeGraph(
        tempDir,
        'Graphs/BP_Door_门交互开关逻辑.json',
        _document('BP_Door / 门交互开关逻辑', 320),
      );

      const service = BlueprintBridgeGraphPackageService();
      final document = await service.loadOriginalDocumentForDraft(
        root: tempDir,
        draft: CanvasDraft(
          key: canvasDraftKey(
            assetPath: '/Game/Blueprints/BP_Door.BP_Door',
            graphName: '门交互开关逻辑',
          ),
          assetName: 'BP_Door',
          assetPath: '/Game/Blueprints/BP_Door.BP_Door',
          graphName: '门交互开关逻辑',
          document: _document('已编辑版本', 900),
        ),
      );

      expect(document?.graph.title, 'BP_Door / 门交互开关逻辑');
      expect(document?.nodes.single.position.x, 320);
    },
  );

  test(
    'loads the original graph document when a manual draft key matches by asset and graph',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'ubbridge_graph_package_manual_key_reset_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await _writePackageIndex(tempDir, [
        <String, Object?>{
          'title': 'BP_Door / 门交互开关逻辑',
          'assetName': 'BP_Door',
          'assetPath': '/Game/Blueprints/BP_Door.BP_Door',
          'graphName': '门交互开关逻辑',
          'file': 'Graphs/BP_Door_门交互开关逻辑.json',
        },
      ]);
      await _writeGraph(
        tempDir,
        'Graphs/BP_Door_门交互开关逻辑.json',
        _document('BP_Door / 门交互开关逻辑', 360),
      );

      const service = BlueprintBridgeGraphPackageService();
      final document = await service.loadOriginalDocumentForDraft(
        root: tempDir,
        draft: CanvasDraft(
          key: 'manual:bp_door_actor::开关门逻辑',
          assetName: 'BP_Door',
          assetPath: '/Game/Blueprints/BP_Door.BP_Door',
          graphName: '门交互开关逻辑',
          document: _document('已编辑版本', 900),
        ),
      );

      expect(document?.graph.title, 'BP_Door / 门交互开关逻辑');
      expect(document?.nodes.single.position.x, 360);
    },
  );

  test('skips missing graph files and reports warnings', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'ubbridge_graph_package_missing_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    await _writePackageIndex(tempDir, [
      <String, Object?>{
        'assetName': 'GM_MainMode',
        'assetPath': '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
        'graphName': 'JudgeRoom',
        'file': 'Graphs/Missing.json',
      },
    ]);

    const service = BlueprintBridgeGraphPackageService();
    final result = await service.loadPackage(tempDir);

    expect(result.available, isFalse);
    expect(result.importedCount, 0);
    expect(result.workspace.drafts, isEmpty);
    expect(result.warnings.single, contains('Missing.json'));
  });

  test('returns unavailable result when GraphIndex is absent', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'ubbridge_graph_package_no_index_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    const service = BlueprintBridgeGraphPackageService();
    final result = await service.loadPackage(tempDir);

    expect(result.available, isFalse);
    expect(result.importedCount, 0);
    expect(result.message, contains('GraphIndex.json'));
  });

  test('writes a readable example package that can be imported back', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'ubbridge_graph_package_example_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    const service = BlueprintBridgeGraphPackageService();

    final result = await service.writeExamplePackage(tempDir);
    final loaded = await service.loadPackage(tempDir);

    expect(result.indexFile.path, endsWith('GraphIndex.json'));
    expect(await result.indexFile.exists(), isTrue);
    expect(result.graphFiles, hasLength(1));
    expect(await result.graphFiles.single.exists(), isTrue);
    expect(loaded.available, isTrue);
    expect(loaded.importedCount, 1);
    expect(loaded.workspace.activeDraft?.assetName, 'ExampleBlueprint');
    expect(loaded.workspace.activeDraft?.graphName, 'ExampleFlow');
    expect(loaded.workspace.activeDraft?.document.nodes, hasLength(4));
    expect(loaded.workspace.activeDraft?.document.links, hasLength(3));
  });
}

Future<void> _writePackageIndex(
  Directory root,
  List<Map<String, Object?>> graphs,
) async {
  const encoder = JsonEncoder.withIndent('  ');
  final file = File('${root.path}${Platform.pathSeparator}GraphIndex.json');
  await file.writeAsString(
    encoder.convert(<String, Object?>{'schemaVersion': 1, 'graphs': graphs}),
  );
}

Future<void> _writeGraph(
  Directory root,
  String relativePath,
  GraphDocument document,
) async {
  final file = File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  );
  await file.parent.create(recursive: true);
  await file.writeAsString(const GraphJsonCodec().encode(document));
}

GraphDocument _document(String title, double x) {
  final now = DateTime.parse('2026-07-07T12:00:00+08:00');

  return GraphDocument(
    schemaVersion: GraphDocument.currentSchemaVersion,
    graph: GraphMetadata(
      id: title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
      title: title,
      description: '图包测试草稿',
      createdAt: now,
      updatedAt: now,
      viewport: const GraphViewport(offsetX: 80, offsetY: 64, zoom: 0.9),
    ),
    nodes: [
      GraphNode(
        id: 'node_${x.round()}',
        nodeType: 'Function',
        title: title,
        description: '',
        position: GraphNodePosition(x: x, y: 90),
        size: GraphNodeSize.standard(),
        pins: const [],
      ),
    ],
    links: const [],
  );
}
