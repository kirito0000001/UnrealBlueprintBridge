import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/workspace/blueprint_logic_detail_service.dart';
import 'package:unreal_blueprint_bridge/core/workspace/canvas_workspace.dart';
import 'package:unreal_blueprint_bridge/core/workspace/get_the_meaning_import_service.dart';
import 'package:unreal_blueprint_bridge/features/workspace/blueprint_assets_view.dart';
import 'package:unreal_blueprint_bridge/features/editor/sample_graph_document.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first
        .physicalSize = const Size(
      1280,
      800,
    );
    TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .views
            .first
            .devicePixelRatio =
        1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .resetPhysicalSize();
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .resetDevicePixelRatio();
  });

  testWidgets('BlueprintAssetsView asks for import before data exists', (
    tester,
  ) async {
    var importRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlueprintAssetsView(
            summary: null,
            selectedAsset: null,
            onSelectedAssetChanged: (_) {},
            onImportRequested: () => importRequested = true,
            onCreateCanvasFromFlows: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('先导入 GetTheMeaning'), findsOneWidget);

    await tester.tap(find.text('导入 GetTheMeaning'));

    expect(importRequested, isTrue);
  });

  testWidgets('BlueprintAssetsView shows loading state during import', (
    tester,
  ) async {
    var importRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlueprintAssetsView(
            summary: null,
            selectedAsset: null,
            isImporting: true,
            onSelectedAssetChanged: (_) {},
            onImportRequested: () => importRequested = true,
            onCreateCanvasFromFlows: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('正在导入'), findsOneWidget);

    await tester.tap(find.text('正在导入'));

    expect(importRequested, isFalse);
  });

  testWidgets(
    'BlueprintAssetsView lists assets and switches detail selection',
    (tester) async {
      final mainMode = _asset(
        name: 'GM_MainMode',
        displayName: 'GM_MainMode (/Game/BaseC/Mode)',
        assetPath: '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
        parentClass: 'GameModeBase',
        variables: ['GUIDMaps', 'PLayerMaps'],
        events: ['ReceiveBeginPlay'],
        rpcs: ['ROS_Login'],
        functions: ['UserLogin', 'JudgeRoom'],
        calls: ['GameplayStatics::SaveGameToSlot'],
      );
      final loginWidget = _asset(
        name: 'WBP_Login',
        displayName: 'WBP_Login (/Game/UI)',
        type: 'WidgetBlueprint',
        assetPath: '/Game/UI/WBP_Login.WBP_Login',
        packagePath: '/Game/UI',
        parentClass: 'UserWidget',
        variables: ['Button_Login'],
        events: ['Construct'],
        functions: ['OnLoginClicked'],
      );
      final summary = _summary([mainMode, loginWidget]);
      var selectedAsset = mainMode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return BlueprintAssetsView(
                  summary: summary,
                  selectedAsset: selectedAsset,
                  onSelectedAssetChanged: (asset) {
                    setState(() => selectedAsset = asset);
                  },
                  onImportRequested: () {},
                  onCreateCanvasFromFlows: (_, _) {},
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('GM_MainMode'), findsWidgets);
      expect(find.text('WBP_Login'), findsWidgets);
      expect(
        find.text('/Game/BaseC/Mode/GM_MainMode.GM_MainMode'),
        findsOneWidget,
      );
      expect(find.text('GameModeBase'), findsWidgets);
      expect(find.text('GUIDMaps'), findsOneWidget);
      expect(find.text('ROS_Login'), findsOneWidget);

      await tester.tap(find.text('WBP_Login').first);
      await tester.pumpAndSettle();

      expect(find.text('/Game/UI/WBP_Login.WBP_Login'), findsOneWidget);
      expect(find.text('UserWidget'), findsWidgets);
      expect(find.text('Button_Login'), findsOneWidget);
    },
  );

  testWidgets('BlueprintAssetsView groups assets by package folder', (
    tester,
  ) async {
    final summary = _summary([
      _asset(
        name: 'GM_MainMode',
        displayName: 'GM_MainMode (/Game/BaseC/Mode)',
        assetPath: '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
        packagePath: '/Game/BaseC/Mode',
        parentClass: 'GameModeBase',
      ),
      _asset(
        name: 'WBP_Login',
        displayName: 'WBP_Login (/Game/UI/Login)',
        type: 'WidgetBlueprint',
        assetPath: '/Game/UI/Login/WBP_Login.WBP_Login',
        packagePath: '/Game/UI/Login',
        parentClass: 'UserWidget',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlueprintAssetsView(
            summary: summary,
            selectedAsset: summary.assets.first,
            onSelectedAssetChanged: (_) {},
            onImportRequested: () {},
            onCreateCanvasFromFlows: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('/Game'), findsOneWidget);
    expect(find.text('BaseC'), findsOneWidget);
    expect(find.text('Mode'), findsOneWidget);
    expect(find.text('UI'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('GM_MainMode'), findsWidgets);
    expect(find.text('WBP_Login'), findsWidgets);
  });

  testWidgets('BlueprintAssetsView searches by name and path', (tester) async {
    final summary = _summary([
      _asset(
        name: 'GM_MainMode',
        displayName: 'GM_MainMode (/Game/BaseC/Mode)',
        assetPath: '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
        packagePath: '/Game/BaseC/Mode',
        parentClass: 'GameModeBase',
      ),
      _asset(
        name: 'WBP_Login',
        displayName: 'WBP_Login (/Game/UI/Login)',
        type: 'WidgetBlueprint',
        assetPath: '/Game/UI/Login/WBP_Login.WBP_Login',
        packagePath: '/Game/UI/Login',
        parentClass: 'UserWidget',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlueprintAssetsView(
            summary: summary,
            selectedAsset: summary.assets.first,
            onSelectedAssetChanged: (_) {},
            onImportRequested: () {},
            onCreateCanvasFromFlows: (_, _) {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Login');
    await tester.pumpAndSettle();

    expect(find.text('WBP_Login'), findsWidgets);
    expect(find.text('GM_MainMode'), findsNothing);
    expect(find.text('没有匹配资产'), findsNothing);
  });

  testWidgets('BlueprintAssetsView filters assets by type and parent class', (
    tester,
  ) async {
    final summary = _summary([
      _asset(
        name: 'GM_MainMode',
        displayName: 'GM_MainMode (/Game/BaseC/Mode)',
        assetPath: '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
        packagePath: '/Game/BaseC/Mode',
        parentClass: 'GameModeBase',
      ),
      _asset(
        name: 'BP_Player',
        displayName: 'BP_Player (/Game/BaseC/Player)',
        assetPath: '/Game/BaseC/Player/BP_Player.BP_Player',
        packagePath: '/Game/BaseC/Player',
        parentClass: 'Actor',
      ),
      _asset(
        name: 'WBP_Login',
        displayName: 'WBP_Login (/Game/UI/Login)',
        type: 'WidgetBlueprint',
        assetPath: '/Game/UI/Login/WBP_Login.WBP_Login',
        packagePath: '/Game/UI/Login',
        parentClass: 'UserWidget',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlueprintAssetsView(
            summary: summary,
            selectedAsset: summary.assets.first,
            onSelectedAssetChanged: (_) {},
            onImportRequested: () {},
            onCreateCanvasFromFlows: (_, _) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Widget'));
    await tester.pumpAndSettle();

    expect(find.text('WBP_Login'), findsWidgets);
    expect(find.text('GM_MainMode'), findsNothing);
    expect(find.text('BP_Player'), findsNothing);

    await tester.tap(find.text('GameMode'));
    await tester.pumpAndSettle();

    expect(find.text('GM_MainMode'), findsWidgets);
    expect(find.text('WBP_Login'), findsNothing);
    expect(find.text('BP_Player'), findsNothing);
  });

  testWidgets('BlueprintAssetsView treats Blueprint UserWidget as Widget', (
    tester,
  ) async {
    final summary = _summary([
      _asset(
        name: 'Card',
        displayName: 'Card (/Game/UIWidget/ImportantUI)',
        type: 'Blueprint',
        assetPath: '/Game/UIWidget/ImportantUI/Card.Card',
        packagePath: '/Game/UIWidget/ImportantUI',
        parentClass: 'UserWidget',
      ),
      _asset(
        name: 'BP_Player',
        displayName: 'BP_Player (/Game/BaseC/Player)',
        assetPath: '/Game/BaseC/Player/BP_Player.BP_Player',
        packagePath: '/Game/BaseC/Player',
        parentClass: 'Actor',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlueprintAssetsView(
            summary: summary,
            selectedAsset: summary.assets.first,
            onSelectedAssetChanged: (_) {},
            onImportRequested: () {},
            onCreateCanvasFromFlows: (_, _) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Widget'));
    await tester.pumpAndSettle();

    expect(find.text('Card'), findsWidgets);
    expect(find.text('/Game/UIWidget/ImportantUI'), findsWidgets);
    expect(find.text('BP_Player'), findsNothing);
    expect(find.text('没有匹配资产'), findsNothing);
  });

  testWidgets('BlueprintAssetsView displays loaded logic detail summary', (
    tester,
  ) async {
    final summary = _summary([
      _asset(
        name: 'GM_MainMode',
        displayName: 'GM_MainMode (/Game/BaseC/Mode)',
        assetPath: '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
        packagePath: '/Game/BaseC/Mode',
        parentClass: 'GameModeBase',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlueprintAssetsView(
            summary: summary,
            selectedAsset: summary.assets.first,
            logicDetail: const BlueprintLogicDetail(
              available: true,
              message: '已读取 Logic JSON',
              logicPath: 'GM_MainMode_Logic.json',
              entryPoints: [
                BlueprintEntryPoint(
                  graphName: 'EventGraph',
                  name: 'ReceiveBeginPlay',
                  type: 'Event',
                  replication: 'Local',
                  reliable: false,
                ),
              ],
              controlFlows: [
                BlueprintControlFlow(
                  graphName: 'EventGraph',
                  fromNodeTitle: 'ReceiveBeginPlay',
                  toNodeTitle: 'Initialize',
                  kind: 'then',
                  depth: 0,
                ),
              ],
              branchRoutes: [
                BlueprintBranchRoute(
                  graphName: 'EventGraph',
                  nodeTitle: '分支',
                  condition: 'Call DoesSaveGameExist.ReturnValue',
                  trueTarget: 'LoadGame',
                  falseTarget: 'CreateSave',
                ),
              ],
              callParameters: [
                BlueprintCallParameterTable(
                  graphName: 'EventGraph',
                  nodeTitle: '游戏存档存在',
                  functionName: 'DoesSaveGameExist',
                  ownerClass: 'GameplayStatics',
                  replication: 'Local',
                  parameters: [
                    BlueprintCallParameter(
                      name: 'SlotName',
                      value: 'ServerData',
                      defaultValue: 'ServerData',
                      linked: false,
                    ),
                  ],
                ),
              ],
              warnings: [
                BlueprintLogicWarning(
                  severity: 'Warning',
                  category: 'UnusedReturnValue',
                  graphName: 'ServerSave',
                  nodeTitle: '将游戏保存到插槽',
                  message: 'Bool output pin is not connected.',
                  details: 'Pin: ReturnValue',
                ),
              ],
              commentBoxes: [
                BlueprintCommentBox(
                  graphName: 'EventGraph',
                  text: '检查玩家账号数据是否存在',
                ),
              ],
              gameModeDefaults: {
                'PlayerControllerClass': '/Game/BaseC/PC/PC_Main.PC_Main',
              },
              callCount: 8,
            ),
            onSelectedAssetChanged: (_) {},
            onImportRequested: () {},
            onCreateCanvasFromFlows: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('逻辑深读'), findsOneWidget);
    expect(find.text('ReceiveBeginPlay'), findsOneWidget);
    expect(find.text('执行线预览'), findsOneWidget);
    expect(
      find.textContaining('ReceiveBeginPlay -> Initialize'),
      findsOneWidget,
    );
    expect(find.text('UnusedReturnValue'), findsOneWidget);
    expect(find.text('Call DoesSaveGameExist.ReturnValue'), findsOneWidget);
    expect(find.textContaining('SlotName = ServerData'), findsOneWidget);
    expect(find.text('检查玩家账号数据是否存在'), findsOneWidget);
    expect(find.text('/Game/BaseC/PC/PC_Main.PC_Main'), findsOneWidget);
  });

  testWidgets('BlueprintAssetsView slices logic detail by entry graph', (
    tester,
  ) async {
    final summary = _summary([
      _asset(
        name: 'GM_MainMode',
        displayName: 'GM_MainMode (/Game/BaseC/Mode)',
        assetPath: '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
        packagePath: '/Game/BaseC/Mode',
        parentClass: 'GameModeBase',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlueprintAssetsView(
            summary: summary,
            selectedAsset: summary.assets.first,
            logicDetail: const BlueprintLogicDetail(
              available: true,
              message: '已读取 Logic JSON',
              logicPath: 'GM_MainMode_Logic.json',
              entryPoints: [
                BlueprintEntryPoint(
                  graphName: 'EventGraph',
                  name: 'ReceiveBeginPlay',
                  type: 'Event',
                  replication: 'Local',
                  reliable: false,
                ),
                BlueprintEntryPoint(
                  graphName: 'UserLogin',
                  name: 'UserLogin',
                  type: 'Function',
                  replication: 'Local',
                  reliable: false,
                ),
              ],
              controlFlows: [
                BlueprintControlFlow(
                  graphName: 'EventGraph',
                  fromNodeTitle: 'ReceiveBeginPlay',
                  toNodeTitle: 'Initialize',
                  kind: 'then',
                  depth: 0,
                ),
                BlueprintControlFlow(
                  graphName: 'UserLogin',
                  fromNodeTitle: 'UserLogin',
                  toNodeTitle: '分支',
                  kind: 'then',
                  depth: 0,
                ),
                BlueprintControlFlow(
                  graphName: 'UserLogin',
                  fromNodeTitle: '分支',
                  toNodeTitle: 'LoginSuccess',
                  kind: 'Branch',
                  depth: 1,
                ),
              ],
              branchRoutes: [
                BlueprintBranchRoute(
                  graphName: 'EventGraph',
                  nodeTitle: '分支',
                  condition: 'EventGraphCondition',
                  trueTarget: 'LoadGame',
                  falseTarget: 'CreateSave',
                ),
                BlueprintBranchRoute(
                  graphName: 'UserLogin',
                  nodeTitle: '分支',
                  condition: 'UserLoginCondition',
                  trueTarget: 'LoginSuccess',
                  falseTarget: 'LoginFail',
                ),
              ],
              callParameters: [
                BlueprintCallParameterTable(
                  graphName: 'EventGraph',
                  nodeTitle: '游戏存档存在',
                  functionName: 'DoesSaveGameExist',
                  ownerClass: 'GameplayStatics',
                  replication: 'Local',
                  parameters: [],
                ),
                BlueprintCallParameterTable(
                  graphName: 'UserLogin',
                  nodeTitle: '查找',
                  functionName: 'Map_Find',
                  ownerClass: 'BlueprintMapLibrary',
                  replication: 'Local',
                  parameters: [],
                ),
              ],
              warnings: [
                BlueprintLogicWarning(
                  severity: 'Warning',
                  category: 'EventGraphWarning',
                  graphName: 'EventGraph',
                  nodeTitle: '保存',
                  message: 'EventGraph risk',
                  details: '',
                ),
                BlueprintLogicWarning(
                  severity: 'Warning',
                  category: 'UserLoginWarning',
                  graphName: 'UserLogin',
                  nodeTitle: '查找',
                  message: 'UserLogin risk',
                  details: '',
                ),
              ],
              commentBoxes: [
                BlueprintCommentBox(
                  graphName: 'EventGraph',
                  text: 'EventGraph 注释',
                ),
                BlueprintCommentBox(
                  graphName: 'UserLogin',
                  text: 'UserLogin 注释',
                ),
              ],
              gameModeDefaults: {},
              callCount: 8,
            ),
            onSelectedAssetChanged: (_) {},
            onImportRequested: () {},
            onCreateCanvasFromFlows: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('EventGraphWarning'), findsOneWidget);
    expect(find.text('UserLoginWarning'), findsOneWidget);

    final userLoginSlice = find.widgetWithText(ChoiceChip, 'UserLogin');
    await tester.ensureVisible(userLoginSlice);
    await tester.tap(userLoginSlice);
    await tester.pumpAndSettle();

    expect(find.text('UserLoginWarning'), findsOneWidget);
    expect(find.text('UserLoginCondition'), findsOneWidget);
    expect(find.textContaining('UserLogin -> 分支'), findsOneWidget);
    expect(find.textContaining('分支 -- Branch -> LoginSuccess'), findsOneWidget);
    expect(find.text('Map_Find'), findsOneWidget);
    expect(find.text('UserLogin 注释'), findsOneWidget);
    expect(find.text('EventGraphWarning'), findsNothing);
    expect(find.text('EventGraphCondition'), findsNothing);
    expect(find.textContaining('ReceiveBeginPlay -> Initialize'), findsNothing);
    expect(find.text('DoesSaveGameExist'), findsNothing);
    expect(find.text('EventGraph 注释'), findsNothing);
  });

  testWidgets('BlueprintAssetsView requests canvas from selected flow slice', (
    tester,
  ) async {
    String? copiedPrompt;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final data = call.arguments as Map<Object?, Object?>;
            copiedPrompt = data['text'] as String?;
            return null;
          }

          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    String? createdGraphName;
    List<BlueprintControlFlow>? createdFlows;
    final summary = _summary([
      _asset(
        name: 'GM_MainMode',
        displayName: 'GM_MainMode (/Game/BaseC/Mode)',
        assetPath: '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
        packagePath: '/Game/BaseC/Mode',
        parentClass: 'GameModeBase',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlueprintAssetsView(
            summary: summary,
            selectedAsset: summary.assets.first,
            graphPackagePath:
                r'D:\UnrealMap\FantasyProject\Saved\BlueprintBridge',
            logicDetail: const BlueprintLogicDetail(
              available: true,
              message: '已读取 Logic JSON',
              logicPath: 'GM_MainMode_Logic.json',
              entryPoints: [
                BlueprintEntryPoint(
                  graphName: 'EventGraph',
                  name: 'ReceiveBeginPlay',
                  type: 'Event',
                  replication: 'Local',
                  reliable: false,
                ),
                BlueprintEntryPoint(
                  graphName: 'UserLogin',
                  name: 'UserLogin',
                  type: 'Function',
                  replication: 'Local',
                  reliable: false,
                ),
              ],
              controlFlows: [
                BlueprintControlFlow(
                  graphName: 'EventGraph',
                  fromNodeTitle: 'ReceiveBeginPlay',
                  toNodeTitle: 'Initialize',
                  kind: 'then',
                  depth: 0,
                ),
                BlueprintControlFlow(
                  graphName: 'UserLogin',
                  fromNodeTitle: 'UserLogin',
                  toNodeTitle: '分支',
                  kind: 'then',
                  depth: 0,
                ),
                BlueprintControlFlow(
                  graphName: 'UserLogin',
                  fromNodeTitle: '分支',
                  toNodeTitle: 'LoginSuccess',
                  kind: 'Branch',
                  depth: 1,
                ),
              ],
              branchRoutes: [],
              callParameters: [],
              warnings: [],
              commentBoxes: [],
              gameModeDefaults: {},
              callCount: 0,
            ),
            onSelectedAssetChanged: (_) {},
            onImportRequested: () {},
            onCreateCanvasFromFlows: (graphName, flows) {
              createdGraphName = graphName;
              createdFlows = flows;
            },
          ),
        ),
      ),
    );

    final userLoginSlice = find.widgetWithText(ChoiceChip, 'UserLogin');
    await tester.ensureVisible(userLoginSlice);
    await tester.tap(userLoginSlice);
    await tester.pumpAndSettle();
    expect(find.text('生成画布'), findsNothing);
    expect(find.text('查看已有画布'), findsNothing);
    final createButton = find.text('创建画布');
    await tester.ensureVisible(createButton);
    expect(find.text('图例需求'), findsOneWidget);
    expect(find.text('复制此图例提示词'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, '生成一个开门逻辑');
    await tester.pump();

    await tester.tap(find.text('复制此图例提示词'));
    await tester.pumpAndSettle();

    expect(find.text('已复制 AI 图例生成提示词'), findsOneWidget);
    expect(copiedPrompt, contains('用户需求：生成一个开门逻辑'));
    expect(copiedPrompt, contains('GraphName: UserLogin'));

    await tester.tap(createButton);

    expect(createdGraphName, 'UserLogin');
    expect(createdFlows, hasLength(2));
    expect(
      createdFlows?.every((flow) => flow.graphName == 'UserLogin'),
      isTrue,
    );
  });

  testWidgets('BlueprintAssetsView groups canvas drafts under selected asset', (
    tester,
  ) async {
    String? selectedDraftKey;
    final asset = _asset(
      name: 'GM_MainMode',
      displayName: 'GM_MainMode (/Game/BaseC/Mode)',
      assetPath: '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
      packagePath: '/Game/BaseC/Mode',
      parentClass: 'GameModeBase',
    );
    final summary = _summary([
      asset,
      _asset(
        name: 'PC_Main',
        displayName: 'PC_Main (/Game/BaseC/Player)',
        assetPath: '/Game/BaseC/Player/PC_Main.PC_Main',
        packagePath: '/Game/BaseC/Player',
        parentClass: 'PlayerController',
      ),
    ]);
    final drafts = [
      CanvasDraft(
        key: 'all',
        assetName: 'GM_MainMode',
        assetPath: asset.assetPath,
        graphName: '全部执行线',
        document: createSampleGraphDocument(),
      ),
      CanvasDraft(
        key: 'login',
        assetName: 'GM_MainMode',
        assetPath: asset.assetPath,
        graphName: 'UserLogin',
        document: createSampleGraphDocument(),
      ),
      CanvasDraft(
        key: 'pc',
        assetName: 'PC_Main',
        assetPath: '/Game/BaseC/Player/PC_Main.PC_Main',
        graphName: 'BeginPlay',
        document: createSampleGraphDocument(),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlueprintAssetsView(
            summary: summary,
            selectedAsset: asset,
            canvasDrafts: drafts,
            activeCanvasKey: 'login',
            onSelectedAssetChanged: (_) {},
            onImportRequested: () {},
            onCreateCanvasFromFlows: (_, _) {},
            onCanvasDraftSelected: (key) => selectedDraftKey = key,
          ),
        ),
      ),
    );

    expect(find.text('画布草稿'), findsOneWidget);
    expect(find.text('2 张'), findsOneWidget);
    expect(find.text('全部执行线'), findsOneWidget);
    expect(find.text('UserLogin'), findsOneWidget);
    expect(find.text('BeginPlay'), findsNothing);
    expect(find.text('当前'), findsOneWidget);

    await tester.tap(find.text('全部执行线'));

    expect(selectedDraftKey, 'all');
  });

  testWidgets(
    'BlueprintAssetsView opens existing canvas draft for selected slice',
    (tester) async {
      String? selectedDraftKey;
      String? createdGraphName;
      final asset = _asset(
        name: 'GM_MainMode',
        displayName: 'GM_MainMode (/Game/BaseC/Mode)',
        assetPath: '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
        packagePath: '/Game/BaseC/Mode',
        parentClass: 'GameModeBase',
      );
      final summary = _summary([asset]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlueprintAssetsView(
              summary: summary,
              selectedAsset: asset,
              logicDetail: const BlueprintLogicDetail(
                available: true,
                message: '已读取 Logic JSON',
                logicPath: 'GM_MainMode_Logic.json',
                entryPoints: [
                  BlueprintEntryPoint(
                    graphName: 'UserLogin',
                    name: 'UserLogin',
                    type: 'Function',
                    replication: 'Local',
                    reliable: false,
                  ),
                ],
                controlFlows: [
                  BlueprintControlFlow(
                    graphName: 'UserLogin',
                    fromNodeTitle: 'UserLogin',
                    toNodeTitle: '分支',
                    kind: 'then',
                    depth: 0,
                  ),
                ],
                branchRoutes: [],
                callParameters: [],
                warnings: [],
                commentBoxes: [],
                gameModeDefaults: {},
                callCount: 0,
              ),
              canvasDrafts: [
                CanvasDraft(
                  key: 'login',
                  assetName: 'GM_MainMode',
                  assetPath: asset.assetPath,
                  graphName: 'UserLogin',
                  document: createSampleGraphDocument(),
                ),
              ],
              onSelectedAssetChanged: (_) {},
              onImportRequested: () {},
              onCreateCanvasFromFlows: (graphName, _) =>
                  createdGraphName = graphName,
              onCanvasDraftSelected: (key) => selectedDraftKey = key,
            ),
          ),
        ),
      );

      final userLoginSlice = find.widgetWithText(ChoiceChip, 'UserLogin');
      await tester.ensureVisible(userLoginSlice);
      await tester.tap(userLoginSlice);
      await tester.pumpAndSettle();

      expect(find.text('查看画布'), findsOneWidget);
      expect(find.text('创建画布'), findsNothing);
      expect(find.text('查看已有画布'), findsNothing);

      await tester.tap(find.text('查看画布'));

      expect(selectedDraftKey, 'login');
      expect(createdGraphName, isNull);
    },
  );
}

GetTheMeaningImportSummary _summary(List<GetTheMeaningAssetSummary> assets) {
  return GetTheMeaningImportSummary(
    available: true,
    message: '已识别 GetTheMeaning 导出',
    exportPath: 'D:/UnrealMap/FantasyProject/Saved/GetTheMeaningExports',
    assetCount: assets.length,
    blueprintCount: assets.where((asset) => asset.type == 'Blueprint').length,
    widgetBlueprintCount: assets
        .where((asset) => asset.type == 'WidgetBlueprint')
        .length,
    graphNodeCount: 40,
    graphEdgeCount: 55,
    cppClassCount: 25,
    cppStructCount: 16,
    cppEnumCount: 11,
    cppFunctionCount: 194,
    assets: assets,
  );
}

GetTheMeaningAssetSummary _asset({
  required String name,
  String displayName = '',
  String type = 'Blueprint',
  required String assetPath,
  String packagePath = '/Game/BaseC/Mode',
  required String parentClass,
  List<String> variables = const <String>[],
  List<String> events = const <String>[],
  List<String> rpcs = const <String>[],
  List<String> functions = const <String>[],
  List<String> calls = const <String>[],
}) {
  return GetTheMeaningAssetSummary(
    name: name,
    displayName: displayName,
    type: type,
    assetPath: assetPath,
    packagePath: packagePath,
    parentClass: parentClass,
    readablePath: 'ReadableCode.txt',
    logicJsonPath: 'Logic.json',
    variables: variables,
    events: events,
    rpcs: rpcs,
    functions: functions,
    calls: calls,
  );
}
