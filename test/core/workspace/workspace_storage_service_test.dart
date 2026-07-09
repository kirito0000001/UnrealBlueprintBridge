import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_document.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_link.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_node.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_pin.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_viewport.dart';
import 'package:unreal_blueprint_bridge/core/workspace/canvas_workspace.dart';
import 'package:unreal_blueprint_bridge/core/workspace/get_the_meaning_import_service.dart';
import 'package:unreal_blueprint_bridge/core/workspace/workspace_models.dart';
import 'package:unreal_blueprint_bridge/core/workspace/workspace_storage_service.dart';

void main() {
  test('WorkspaceStorageService saves and loads app state JSON', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'ubbridge_workspace_storage_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final service = WorkspaceStorageService(appDataDirectory: tempDir);
    const state = BridgeAppState(
      lastWorkspaceId: 'fantasy_project',
      recentWorkspaces: [
        WorkspaceSummary(
          id: 'fantasy_project',
          name: 'FantasyProject',
          workspacePath:
              r'D:\UnrealMap\FantasyProject\Saved\BlueprintBridge\FantasyProject.ubbridge',
          unrealProjectPath:
              r'D:\UnrealMap\FantasyProject\FantasyProject.uproject',
          getTheMeaningExportPath:
              r'D:\UnrealMap\FantasyProject\Saved\GetTheMeaningExports',
          lastOpenedAt: '2026-07-07T14:00:00+08:00',
        ),
      ],
    );

    await service.saveAppState(state);
    final loaded = await service.loadAppState();

    expect(loaded.lastWorkspaceId, 'fantasy_project');
    expect(loaded.recentWorkspaces.single.name, 'FantasyProject');
    expect(await service.appStateFile.exists(), isTrue);
  });

  test(
    'WorkspaceStorageService creates sample state when app state is missing',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'ubbridge_workspace_storage_missing_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final service = WorkspaceStorageService(appDataDirectory: tempDir);

      final loaded = await service.loadOrCreateInitialState();

      expect(loaded.currentWorkspace?.name, 'FantasyProject');
      expect(await service.appStateFile.exists(), isTrue);
    },
  );

  test(
    'WorkspaceStorageService saves and loads import summary cache',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'ubbridge_import_summary_cache_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final service = WorkspaceStorageService(appDataDirectory: tempDir);
      const summary = GetTheMeaningImportSummary(
        available: true,
        message: '已识别 GetTheMeaning 导出',
        exportPath: r'D:\UnrealMap\FantasyProject\Saved\GetTheMeaningExports',
        assetCount: 1,
        blueprintCount: 1,
        widgetBlueprintCount: 0,
        graphNodeCount: 12,
        graphEdgeCount: 18,
        cppClassCount: 3,
        cppStructCount: 2,
        cppEnumCount: 1,
        cppFunctionCount: 8,
        assets: [
          GetTheMeaningAssetSummary(
            name: 'Card',
            displayName: 'Card (/Game/UIWidget/ImportantUI)',
            type: 'Blueprint',
            assetPath: '/Game/UIWidget/ImportantUI/Card.Card',
            packagePath: '/Game/UIWidget/ImportantUI',
            parentClass: 'UserWidget',
            readablePath: 'Card_ReadableCode.txt',
            logicJsonPath: 'Card_Logic.json',
            variables: ['Button_Card'],
            events: ['Construct'],
            rpcs: [],
            functions: ['Refresh'],
            calls: ['SetText'],
          ),
        ],
      );

      await service.saveImportSummary('Fantasy Project', summary);
      final loaded = await service.loadImportSummary('Fantasy Project');

      expect(loaded, isNotNull);
      expect(loaded?.assetCount, 1);
      expect(loaded?.assets.single.name, 'Card');
      expect(loaded?.assets.single.parentClass, 'UserWidget');
      expect(
        await service.importSummaryFile('Fantasy Project').exists(),
        isTrue,
      );
    },
  );

  test(
    'WorkspaceStorageService saves and loads canvas document cache',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'ubbridge_canvas_cache_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final service = WorkspaceStorageService(appDataDirectory: tempDir);
      final document = GraphDocument(
        schemaVersion: GraphDocument.currentSchemaVersion,
        graph: GraphMetadata(
          id: 'graph_user_login',
          title: 'GM_MainMode / UserLogin',
          description: '由蓝图执行线预览生成的草稿图。',
          createdAt: DateTime.parse('2026-07-07T12:00:00+08:00'),
          updatedAt: DateTime.parse('2026-07-07T12:10:00+08:00'),
          viewport: const GraphViewport(offsetX: 80, offsetY: 64, zoom: 0.86),
        ),
        nodes: const [
          GraphNode(
            id: 'node_userlogin',
            nodeType: 'Event',
            title: 'UserLogin',
            description: '入口',
            position: GraphNodePosition(x: 80, y: 90),
            size: GraphNodeSize(width: 240, height: 140),
            pins: [
              GraphPin(
                id: 'then',
                direction: GraphPinDirection.output,
                title: 'Then',
                dataType: 'exec',
              ),
            ],
          ),
          GraphNode(
            id: 'node_branch',
            nodeType: 'Branch',
            title: '分支',
            description: '判断',
            position: GraphNodePosition(x: 400, y: 90),
            size: GraphNodeSize(width: 240, height: 140),
            pins: [
              GraphPin(
                id: 'exec_in',
                direction: GraphPinDirection.input,
                title: 'Exec',
                dataType: 'exec',
              ),
            ],
          ),
        ],
        links: const [
          GraphLink(
            id: 'link_userlogin_branch',
            fromNodeId: 'node_userlogin',
            fromPinId: 'then',
            toNodeId: 'node_branch',
            toPinId: 'exec_in',
            title: '',
            description: '',
            linkType: 'exec',
          ),
        ],
      );

      await service.saveCanvasDocument('fantasy_project', document);
      final loaded = await service.loadCanvasDocument('fantasy_project');

      expect(loaded, isNotNull);
      expect(loaded?.graph.title, 'GM_MainMode / UserLogin');
      expect(loaded?.nodes, hasLength(2));
      expect(loaded?.links.single.fromNodeId, 'node_userlogin');
      expect(
        await service.canvasDocumentFile('fantasy_project').exists(),
        isTrue,
      );
    },
  );

  test(
    'WorkspaceStorageService saves and loads multiple canvas drafts',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'ubbridge_canvas_workspace_cache_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final service = WorkspaceStorageService(appDataDirectory: tempDir);
      final loginKey = canvasDraftKey(
        assetPath: '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
        graphName: 'UserLogin',
      );
      final judgeRoomKey = canvasDraftKey(
        assetPath: '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
        graphName: 'JudgeRoom',
      );
      final workspace = CanvasWorkspace.empty()
          .upsert(
            CanvasDraft(
              key: loginKey,
              assetName: 'GM_MainMode',
              assetPath: '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
              graphName: 'UserLogin',
              document: _document('GM_MainMode / UserLogin', 140),
            ),
          )
          .upsert(
            CanvasDraft(
              key: judgeRoomKey,
              assetName: 'GM_MainMode',
              assetPath: '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
              graphName: 'JudgeRoom',
              document: _document('GM_MainMode / JudgeRoom', 360),
            ),
          );

      await service.saveCanvasWorkspace('fantasy_project', workspace);
      final loaded = await service.loadCanvasWorkspace('fantasy_project');

      expect(loaded.activeKey, judgeRoomKey);
      expect(loaded.drafts, hasLength(2));
      expect(loaded.drafts[loginKey]?.document.nodes.single.position.x, 140);
      expect(
        loaded.activeDraft?.document.graph.title,
        'GM_MainMode / JudgeRoom',
      );
      expect(
        await service.canvasWorkspaceFile('fantasy_project').exists(),
        isTrue,
      );
    },
  );

  test(
    'WorkspaceStorageService exports and imports standalone graph drafts',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'ubbridge_standalone_graph_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final service = WorkspaceStorageService(appDataDirectory: tempDir);
      final document = _document('独立草稿 / 测试图', 220);

      final exported = await service.exportGraphDocument(
        workspaceId: 'Fantasy Project',
        fileName: '测试 草稿.json',
        document: document,
      );
      final loaded = await service.importGraphDocument(exported);

      expect(await exported.exists(), isTrue);
      expect(exported.path, contains('graph_exports_Fantasy_Project'));
      expect(exported.path, contains('测试_草稿.json'));
      expect(loaded.graph.title, '独立草稿 / 测试图');
      expect(loaded.nodes.single.position.x, 220);
    },
  );
}

GraphDocument _document(String title, double x) {
  final now = DateTime.parse('2026-07-07T12:00:00+08:00');

  return GraphDocument(
    schemaVersion: GraphDocument.currentSchemaVersion,
    graph: GraphMetadata(
      id: title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
      title: title,
      description: '',
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
