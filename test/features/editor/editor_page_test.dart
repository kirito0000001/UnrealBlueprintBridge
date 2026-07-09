import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_document.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_event.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_function.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_link.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_node.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_pin.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_variable.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_viewport.dart';
import 'package:unreal_blueprint_bridge/core/platform/ime_control.dart';
import 'package:unreal_blueprint_bridge/core/workspace/canvas_workspace.dart';
import 'package:unreal_blueprint_bridge/features/editor/canvas/graph_canvas_geometry.dart';
import 'package:unreal_blueprint_bridge/features/editor/editor_page.dart';
import 'package:unreal_blueprint_bridge/features/editor/sample_graph_document.dart';

Future<void> _dragVariableToCanvas(
  WidgetTester tester,
  String variableName,
) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(ValueKey('variable-row-$variableName'))),
  );
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 40));
  await gesture.moveBy(const Offset(-360, 120));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _dragFunctionToCanvas(
  WidgetTester tester,
  String functionName,
) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(ValueKey('function-row-$functionName'))),
  );
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 40));
  await gesture.moveBy(const Offset(-360, 120));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _dragEventToCanvas(WidgetTester tester, String eventName) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(ValueKey('event-row-$eventName'))),
  );
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 40));
  await gesture.moveBy(const Offset(-360, 120));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1280, 800);
    binding.platformDispatcher.views.first.devicePixelRatio = 1;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets('EditorPage hides live JSON preview when embedded', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: createSampleGraphDocument(),
          ),
        ),
      ),
    );

    expect(find.text('JSON 预览'), findsNothing);
    expect(find.text('细节面板'), findsNothing);
    expect(find.text('成员'), findsOneWidget);
    expect(find.text('变量'), findsOneWidget);
  });

  testWidgets('EditorPage uses the right panel like Unreal modes', (
    tester,
  ) async {
    var changedDocument = createSampleGraphDocument();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );

    expect(find.text('成员'), findsOneWidget);
    expect(find.text('节点目录'), findsNothing);
    expect(find.textContaining('细节面板'), findsNothing);

    await tester.tapAt(const Offset(40, 40), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('节点目录'), findsOneWidget);

    await tester.tap(find.text('Branch').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Branch · 细节面板'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.text('成员'), findsOneWidget);
    expect(find.textContaining('细节面板'), findsNothing);
  });

  testWidgets(
    'EditorPage opens node catalog in the side panel from blank canvas',
    (tester) async {
      var changedDocument = createSampleGraphDocument();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPage(
              showScaffoldChrome: false,
              initialDocument: changedDocument,
              onDocumentChanged: (document) => changedDocument = document,
            ),
          ),
        ),
      );

      expect(find.text('节点目录'), findsNothing);

      await tester.tapAt(const Offset(40, 40), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('节点目录'), findsOneWidget);
      expect(find.text('情境关联'), findsOneWidget);
      expect(find.text('Event BeginPlay'), findsOneWidget);
      expect(find.text('Branch'), findsOneWidget);
      expect(find.byType(PopupMenuItem), findsNothing);
      final searchField = tester.widget<TextField>(
        find.byKey(const ValueKey('node-catalog-search-field')),
      );
      expect(searchField.autofocus, isTrue);
      expect(searchField.readOnly, isFalse);

      await tester.tap(find.text('Branch').last);
      await tester.pumpAndSettle();

      expect(
        changedDocument.nodes.any((node) => node.title == 'Branch'),
        isTrue,
      );
      expect(find.textContaining('Branch · 细节面板'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('node-catalog-search-field')),
        findsNothing,
      );
    },
  );

  testWidgets('EditorPage creates graph variables and variable nodes', (
    tester,
  ) async {
    var changedDocument = createSampleGraphDocument().copyWith(
      variables: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('variable-name-field')), findsNothing);
    expect(
      find.byKey(const ValueKey('open-create-variable-dialog')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('open-create-variable-dialog')));
    await tester.pumpAndSettle();

    expect(find.text('创建变量'), findsWidgets);
    expect(find.byKey(const ValueKey('variable-type-dropdown')), findsNothing);
    expect(
      find.byKey(const ValueKey('variable-type-selector')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('variable-type-selector')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('variable-type-option-int')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('variable-type-option-int')));
    await tester.pumpAndSettle();
    expect(find.text('int'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('variable-type-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('variable-type-option-bool')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('variable-name-field')),
      'IsDoorOpen',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('create-variable-button')),
    );
    await tester.tap(find.byKey(const ValueKey('create-variable-button')));
    await tester.pumpAndSettle();

    expect(changedDocument.variables, hasLength(1));
    expect(find.byKey(const ValueKey('variable-name-field')), findsNothing);
    expect(changedDocument.variables.single.name, 'IsDoorOpen');
    expect(changedDocument.variables.single.dataType, 'bool');
    expect(find.text('IsDoorOpen'), findsWidgets);
    expect(
      find.byKey(const ValueKey('create-get-variable-IsDoorOpen')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('create-set-variable-IsDoorOpen')),
      findsNothing,
    );

    await _dragVariableToCanvas(tester, 'IsDoorOpen');
    await tester.pumpAndSettle();

    expect(find.text('获取变量'), findsOneWidget);
    expect(find.text('设置变量'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('variable-drop-menu-get-icon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('variable-drop-menu-set-icon')),
      findsOneWidget,
    );

    await tester.tap(find.text('获取变量'));
    await tester.pumpAndSettle();
    expect(changedDocument.nodes.last.title, 'Get IsDoorOpen');
    expect(changedDocument.nodes.last.nodeType, 'VariableGet');
    expect(changedDocument.nodes.last.pins.single.dataType, 'bool');

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.text('成员'), findsOneWidget);

    await _dragVariableToCanvas(tester, 'IsDoorOpen');
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置变量'));
    await tester.pumpAndSettle();
    expect(changedDocument.nodes.last.title, 'Set IsDoorOpen');
    expect(changedDocument.nodes.last.nodeType, 'VariableSet');
    expect(
      changedDocument.nodes.last.pins.any(
        (pin) =>
            pin.direction == GraphPinDirection.input &&
            pin.dataType == 'bool' &&
            pin.defaultValue == 'false',
      ),
      isTrue,
    );
  });

  testWidgets('EditorPage shows and creates graph events in members', (
    tester,
  ) async {
    var changedDocument = createSampleGraphDocument().copyWith(
      events: const [
        GraphEvent(
          id: 'event_begin_play',
          name: 'Event BeginPlay',
          eventType: 'EngineEvent',
          description: 'Actor 开始运行时触发。',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('事件'), findsOneWidget);
    expect(find.text('Event BeginPlay'), findsOneWidget);
    expect(find.text('EngineEvent'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-create-event-dialog')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('event-name-create-field')),
      '请求切换门',
    );
    await tester.tap(find.byKey(const ValueKey('create-event-button')));
    await tester.pumpAndSettle();

    expect(changedDocument.events, hasLength(2));
    expect(changedDocument.events.last.name, '请求切换门');
    expect(changedDocument.events.last.eventType, 'CustomEvent');
    expect(find.text('请求切换门'), findsOneWidget);
  });

  testWidgets('EditorPage derives member events from event nodes', (
    tester,
  ) async {
    final document = createSampleGraphDocument().copyWith(events: const []);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: document,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('事件'), findsOneWidget);
    expect(find.byKey(const ValueKey('event-row-事件：请求登录')), findsOneWidget);
    expect(find.text('Event'), findsOneWidget);
  });

  testWidgets(
    'EditorPage edits and calls custom events from member interactions',
    (tester) async {
      var changedDocument = createSampleGraphDocument().copyWith(
        events: const [
          GraphEvent(
            id: 'event_toggle_door',
            name: '请求切换门',
            eventType: 'CustomEvent',
            description: '客户端请求服务器切换门状态。',
            rpcType: 'None',
            reliability: 'Unreliable',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPage(
              showScaffoldChrome: false,
              initialDocument: changedDocument,
              onDocumentChanged: (document) => changedDocument = document,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('event-row-请求切换门')));
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();

      expect(find.textContaining('请求切换门 · 事件细节'), findsOneWidget);
      expect(find.text('类型'), findsOneWidget);
      expect(find.text('CustomEvent'), findsWidgets);
      expect(find.text('启用网络调用'), findsNothing);
      expect(
        find.byKey(const ValueKey('event-reliability-dropdown')),
        findsNothing,
      );
      final eventReplicationField = find.byKey(
        const ValueKey('event-replication-dropdown'),
      );
      expect(
        tester.widget(eventReplicationField),
        isA<PopupMenuButton<String>>(),
      );

      await tester.tap(eventReplicationField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('在服务器上运行').last);
      await tester.pumpAndSettle();
      expect(changedDocument.events.single.rpcType, 'RunOnServer');
      expect(changedDocument.events.single.replicates, isTrue);

      await tester.tap(find.byKey(const ValueKey('event-reliable-checkbox')));
      await tester.pumpAndSettle();
      expect(changedDocument.events.single.reliability, 'Reliable');

      await tester.tapAt(const Offset(40, 40));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('event-row-请求切换门')));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byKey(const ValueKey('event-row-请求切换门')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('rename-event-field')),
        '请求开关门',
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-rename-event-button')),
      );
      await tester.pumpAndSettle();

      expect(changedDocument.events.single.name, '请求开关门');

      await tester.tapAt(const Offset(40, 40));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('event-row-请求开关门')), findsOneWidget);

      await _dragEventToCanvas(tester, '请求开关门');
      final callNode = changedDocument.nodes.last;
      expect(callNode.nodeType, 'EventCall');
      expect(callNode.title, '请求开关门');
      expect(callNode.pins.any((pin) => pin.title == 'Exec'), isTrue);
      expect(callNode.pins.any((pin) => pin.title == 'Then'), isTrue);
    },
  );

  testWidgets('EditorPage edits variables from member interactions', (
    tester,
  ) async {
    var changedDocument = createSampleGraphDocument().copyWith(
      variables: const [
        GraphVariable(
          id: 'var_door_open',
          name: 'IsDoorOpen',
          dataType: 'bool',
          defaultValue: 'false',
          replication: 'None',
          exportSource: 'GetTheMeaning',
          exportPath: '/Game/BP_Door.BP_Door_C:IsDoorOpen',
          exportDisplayName: '门是否打开',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('select-variable-IsDoorOpen')));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();

    expect(find.textContaining('IsDoorOpen · 变量细节'), findsOneWidget);
    expect(find.text('GetTheMeaning'), findsOneWidget);
    expect(find.text('/Game/BP_Door.BP_Door_C:IsDoorOpen'), findsOneWidget);
    final replicationField = find.byKey(
      const ValueKey('variable-replication-dropdown'),
    );
    expect(tester.widget(replicationField), isA<PopupMenuButton<String>>());
    expect(
      find.descendant(
        of: replicationField,
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('variable-replication-dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replicated').last);
    await tester.pumpAndSettle();
    expect(changedDocument.variables.single.replication, 'Replicated');

    expect(
      find.byKey(const ValueKey('variable-replication-condition-dropdown')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('variable-detail-name-field')),
      'DoorOpened',
    );
    await tester.pumpAndSettle();

    expect(changedDocument.variables.single.name, 'DoorOpened');
    expect(find.text('DoorOpened'), findsWidgets);
  });

  testWidgets(
    'EditorPage centers the canvas on a member node from details title',
    (tester) async {
      final now = DateTime(2026, 7, 9, 12);
      var changedDocument = GraphDocument(
        schemaVersion: GraphDocument.currentSchemaVersion,
        graph: GraphMetadata(
          id: 'graph_focus_member',
          title: 'Focus Member',
          description: '',
          createdAt: now,
          updatedAt: now,
          viewport: const GraphViewport(offsetX: 0, offsetY: 0, zoom: 1),
        ),
        nodes: const [
          GraphNode(
            id: 'var_get_far',
            nodeType: 'VariableGet',
            title: 'Get IsDoorOpen',
            description: '',
            position: GraphNodePosition(x: 1200, y: 860),
            size: GraphNodeSize(width: 260, height: 150),
            pins: [
              GraphPin(
                id: 'value',
                direction: GraphPinDirection.output,
                title: 'IsDoorOpen',
                dataType: 'bool',
              ),
            ],
          ),
          GraphNode(
            id: 'var_set_far',
            nodeType: 'VariableSet',
            title: 'Set IsDoorOpen',
            description: '',
            position: GraphNodePosition(x: 1480, y: 860),
            size: GraphNodeSize(width: 310, height: 150),
            pins: [
              GraphPin(
                id: 'exec',
                direction: GraphPinDirection.input,
                title: 'Exec',
                dataType: 'exec',
              ),
              GraphPin(
                id: 'value',
                direction: GraphPinDirection.input,
                title: 'IsDoorOpen',
                dataType: 'bool',
              ),
              GraphPin(
                id: 'then',
                direction: GraphPinDirection.output,
                title: 'Then',
                dataType: 'exec',
              ),
            ],
          ),
        ],
        links: const [],
        variables: const [
          GraphVariable(
            id: 'var_door_open',
            name: 'IsDoorOpen',
            dataType: 'bool',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPage(
              showScaffoldChrome: false,
              initialDocument: changedDocument,
              onDocumentChanged: (document) => changedDocument = document,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('select-variable-IsDoorOpen')),
      );
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();

      expect(find.textContaining('IsDoorOpen · 变量细节'), findsOneWidget);
      expect(changedDocument.graph.viewport.offsetX, 0);
      expect(changedDocument.graph.viewport.offsetY, 0);
      expect(find.byKey(const ValueKey('var_get_far')), findsOneWidget);
      expect(find.byKey(const ValueKey('var_set_far')), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('right-panel-header-IsDoorOpen · 变量细节')),
      );
      await tester.pumpAndSettle();

      expect(changedDocument.graph.viewport.offsetX, isNot(0));
      expect(changedDocument.graph.viewport.offsetY, isNot(0));
      expect(changedDocument.graph.viewport.offsetX, closeTo(-900, 1));
      expect(changedDocument.graph.viewport.offsetY, closeTo(-656.5, 1));
      expect(find.textContaining('IsDoorOpen · 变量细节'), findsOneWidget);
      expect(find.byKey(const ValueKey('var_get_far')), findsOneWidget);
      expect(find.byKey(const ValueKey('var_set_far')), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('right-panel-header-IsDoorOpen · 变量细节')),
      );
      await tester.pumpAndSettle();

      expect(changedDocument.graph.viewport.offsetX, closeTo(-1205, 1));
      expect(changedDocument.graph.viewport.offsetY, closeTo(-671.5, 1));
      expect(find.textContaining('IsDoorOpen · 变量细节'), findsOneWidget);
      expect(find.byKey(const ValueKey('var_get_far')), findsOneWidget);
      expect(find.byKey(const ValueKey('var_set_far')), findsOneWidget);
    },
  );

  testWidgets(
    'EditorPage creates functions, edits signatures, and calls them',
    (tester) async {
      var changedDocument = createSampleGraphDocument().copyWith(
        functions: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPage(
              showScaffoldChrome: false,
              initialDocument: changedDocument,
              onDocumentChanged: (document) => changedDocument = document,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('暂无函数'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('open-create-function-dialog')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('function-name-create-field')),
        'OpenDoor',
      );
      await tester.tap(find.byKey(const ValueKey('create-function-button')));
      await tester.pumpAndSettle();

      expect(changedDocument.functions, hasLength(1));
      expect(changedDocument.functions.single.name, 'OpenDoor');
      expect(
        find.byKey(const ValueKey('function-row-OpenDoor')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('function-row-OpenDoor')));
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();
      expect(find.text('OpenDoor · 函数细节'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('add-function-输入-parameter')),
      );
      await tester.tap(find.byKey(const ValueKey('add-function-输入-parameter')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('add-function-输出-parameter')),
      );
      await tester.tap(find.byKey(const ValueKey('add-function-输出-parameter')));
      await tester.pumpAndSettle();

      expect(changedDocument.functions.single.inputs, hasLength(1));
      expect(changedDocument.functions.single.outputs, hasLength(1));

      await tester.tapAt(const Offset(40, 40));
      await tester.pumpAndSettle();
      await _dragFunctionToCanvas(tester, 'OpenDoor');

      final callNode = changedDocument.nodes.last;
      expect(callNode.nodeType, 'FunctionCall');
      expect(callNode.title, 'OpenDoor');
      expect(callNode.pins.any((pin) => pin.title == 'Exec'), isTrue);
      expect(callNode.pins.any((pin) => pin.title == 'Then'), isTrue);
      expect(callNode.pins.any((pin) => pin.title == 'Input 0'), isTrue);
      expect(callNode.pins.any((pin) => pin.title == 'ReturnValue 0'), isTrue);

      final functionCallFinder = find.byKey(ValueKey(callNode.id)).first;
      final functionCallCenter = tester.getCenter(functionCallFinder);
      await tester.tapAt(functionCallCenter);
      await tester.pumpAndSettle();
      expect(find.text('OpenDoor · 函数细节'), findsOneWidget);
      expect(find.text('FunctionCall'), findsNothing);

      await tester.pump(const Duration(milliseconds: 360));
      await tester.tapAt(functionCallCenter);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(functionCallCenter);
      await tester.pumpAndSettle();
      expect(find.text('OpenDoor · 函数图表'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('function-row-OpenDoor')));
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();
      await tester.tap(find.text('纯函数'));
      await tester.pumpAndSettle();

      final pureCallNode = changedDocument.nodes.firstWhere(
        (node) => node.id == callNode.id,
      );
      expect(pureCallNode.pins.any((pin) => pin.title == 'Exec'), isFalse);
      expect(pureCallNode.pins.any((pin) => pin.title == 'Then'), isFalse);
      expect(pureCallNode.pins.any((pin) => pin.title == 'Input 0'), isTrue);
      expect(
        pureCallNode.pins.any((pin) => pin.title == 'ReturnValue 0'),
        isTrue,
      );
    },
  );

  testWidgets(
    'EditorPage opens function panel with double click and returns to members',
    (tester) async {
      final document = createSampleGraphDocument().copyWith(
        functions: const [
          GraphFunction(
            id: 'func_open_door',
            name: 'OpenDoor',
            category: 'Door',
            description: '打开门',
          ),
          GraphFunction(
            id: 'func_close_door',
            name: 'CloseDoor',
            category: 'Door',
            description: '关闭门',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPage(
              showScaffoldChrome: false,
              initialDocument: document,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('function-row-OpenDoor')));
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();
      expect(find.text('OpenDoor · 函数细节'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('back-to-function-panel-button')),
        findsNothing,
      );

      await tester.tapAt(const Offset(40, 40));
      await tester.pumpAndSettle();
      expect(find.text('成员'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('function-row-OpenDoor')));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byKey(const ValueKey('function-row-OpenDoor')));
      await tester.pumpAndSettle();
      expect(find.text('OpenDoor · 函数图表'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('close-function-panel-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('function-workspace-row-CloseDoor')),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(
        find.byKey(const ValueKey('function-workspace-row-CloseDoor')),
      );
      await tester.pumpAndSettle();
      expect(find.text('CloseDoor · 函数图表'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('function-row-CloseDoor')));
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();
      expect(find.text('CloseDoor · 函数细节'), findsOneWidget);
      expect(find.text('CloseDoor'), findsWidgets);
      expect(
        find.byKey(const ValueKey('back-to-function-panel-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('back-to-function-panel-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('CloseDoor · 函数图表'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('close-function-panel-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('成员'), findsOneWidget);
      expect(find.text('OpenDoor · 函数图表'), findsNothing);
      expect(find.text('CloseDoor · 函数图表'), findsNothing);
    },
  );

  testWidgets(
    'EditorPage disables IME on canvas and enables it for text fields',
    (tester) async {
      final imeCalls = <bool>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ImeControl.channel, (call) async {
            if (call.method == 'setEnabled') {
              imeCalls.add(call.arguments as bool);
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ImeControl.channel, null);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPage(
              showScaffoldChrome: false,
              initialDocument: createSampleGraphDocument(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(imeCalls, contains(false));

      await tester.tapAt(const Offset(40, 40), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(imeCalls.last, isTrue);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('node-catalog-search-field')),
            )
            .readOnly,
        isFalse,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('node-catalog-search-field')),
            )
            .readOnly,
        isFalse,
      );
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        contains('NodeCatalogSearch'),
      );

      await tester.tap(find.text('Branch').last);
      await tester.pumpAndSettle();
      expect(imeCalls.last, isFalse);

      await tester.tap(find.byKey(const ValueKey('node-title-field')));
      await tester.pump();
      expect(imeCalls.last, isTrue);

      await tester.tapAt(const Offset(80, 620));
      await tester.pump();
      expect(imeCalls.last, isFalse);
    },
  );

  testWidgets('EditorPage toggles bool pin default values on the canvas', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 9, 12);
    var changedDocument = GraphDocument(
      schemaVersion: GraphDocument.currentSchemaVersion,
      graph: GraphMetadata(
        id: 'graph_bool_defaults',
        title: 'Bool Defaults',
        description: '',
        createdAt: now,
        updatedAt: now,
        viewport: const GraphViewport(offsetX: 0, offsetY: 0, zoom: 1),
      ),
      nodes: const [
        GraphNode(
          id: 'set_bool',
          nodeType: 'VariableSet',
          title: 'Set: IsDoorOpen',
          description: '',
          position: GraphNodePosition(x: 80, y: 80),
          size: GraphNodeSize(width: 300, height: 180),
          pins: [
            GraphPin(
              id: 'exec',
              direction: GraphPinDirection.input,
              title: 'Exec',
              dataType: 'exec',
            ),
            GraphPin(
              id: 'value',
              direction: GraphPinDirection.input,
              title: 'Value',
              dataType: 'bool',
              defaultValue: 'false',
            ),
          ],
        ),
      ],
      links: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );

    final defaultKey = find.byKey(
      const ValueKey('pin-default-bool-set_bool-value'),
    );
    expect(defaultKey, findsOneWidget);
    final defaultCheckbox = find.descendant(
      of: defaultKey,
      matching: find.byType(Checkbox),
    );
    expect(tester.widget<Checkbox>(defaultCheckbox).value, isFalse);

    await tester.tapAt(tester.getCenter(defaultKey));
    await tester.pumpAndSettle();

    final valuePin = changedDocument.nodes.single.pins
        .where((pin) => pin.id == 'value')
        .single;
    expect(valuePin.defaultValue, 'true');
  });

  testWidgets('EditorPage switches between canvas drafts when embedded', (
    tester,
  ) async {
    final loginDocument = createSampleGraphDocument().copyWith(
      graph: createSampleGraphDocument().graph.copyWith(
        title: 'GM_MainMode / UserLogin',
      ),
    );
    final roomDocument = createSampleGraphDocument().copyWith(
      graph: createSampleGraphDocument().graph.copyWith(
        title: 'GM_MainMode / JudgeRoom',
      ),
    );
    final workspace = CanvasWorkspace.empty()
        .upsert(
          CanvasDraft(
            key: 'login',
            assetName: 'GM_MainMode',
            assetPath: '/Game/GM_MainMode',
            graphName: 'UserLogin',
            document: loginDocument,
          ),
        )
        .upsert(
          CanvasDraft(
            key: 'room',
            assetName: 'GM_MainMode',
            assetPath: '/Game/GM_MainMode',
            graphName: 'JudgeRoom',
            document: roomDocument,
          ),
        );
    String? activatedKey;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: workspace.activeDraft?.document,
            canvasDrafts: workspace.orderedDrafts,
            activeCanvasKey: workspace.activeKey,
            onCanvasDraftSelected: (key) => activatedKey = key,
            onResetActiveCanvas: () {},
          ),
        ),
      ),
    );

    expect(find.text('画布草稿'), findsNothing);
    expect(
      find.byKey(const ValueKey('floating-canvas-navigator')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('floating-canvas-navigator')));
    await tester.pumpAndSettle();

    expect(find.text('画布草稿'), findsOneWidget);
    expect(find.text('UserLogin'), findsOneWidget);
    expect(find.text('JudgeRoom'), findsOneWidget);
    expect(find.text('当前'), findsOneWidget);

    await tester.tap(find.text('UserLogin'));

    expect(activatedKey, 'login');
  });

  testWidgets('EditorPage distinguishes drafts with the same graph name', (
    tester,
  ) async {
    final workspace = CanvasWorkspace.empty()
        .upsert(
          CanvasDraft(
            key: 'game_lb_fucs',
            assetName: 'LB_Fucs',
            assetPath: '/Game/BaseC/LB_Fucs.LB_Fucs',
            graphName: '全部执行线',
            document: createSampleGraphDocument(),
          ),
        )
        .upsert(
          CanvasDraft(
            key: 'legacy_lb_fucs',
            assetName: 'LB_Fucs',
            assetPath: 'legacy:flow_lb_fucs_all',
            graphName: '全部执行线',
            document: createSampleGraphDocument(),
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: workspace.activeDraft?.document,
            canvasDrafts: workspace.orderedDrafts,
            activeCanvasKey: workspace.activeKey,
            onCanvasDraftSelected: (_) {},
            onResetActiveCanvas: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('floating-canvas-navigator')));
    await tester.pumpAndSettle();

    expect(find.text('全部执行线'), findsAtLeastNWidgets(2));
    expect(find.text('LB_Fucs'), findsAtLeastNWidgets(2));
    expect(find.text('/Game/BaseC/LB_Fucs.LB_Fucs'), findsOneWidget);
    expect(find.text('旧单画布缓存'), findsOneWidget);
    expect(find.text('当前'), findsOneWidget);
  });

  testWidgets(
    'EditorPage exposes draft switching and reset from floating navigator',
    (tester) async {
      final workspace = CanvasWorkspace.empty()
          .upsert(
            CanvasDraft(
              key: 'login',
              assetName: 'GM_MainMode',
              assetPath: '/Game/GM_MainMode',
              graphName: 'UserLogin',
              document: createSampleGraphDocument(),
            ),
          )
          .upsert(
            CanvasDraft(
              key: 'room',
              assetName: 'GM_MainMode',
              assetPath: '/Game/GM_MainMode',
              graphName: 'JudgeRoom',
              document: createSampleGraphDocument(),
            ),
          );
      String? activatedKey;
      var resetRequested = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPage(
              showScaffoldChrome: false,
              initialDocument: workspace.activeDraft?.document,
              canvasDrafts: workspace.orderedDrafts,
              activeCanvasKey: workspace.activeKey,
              onCanvasDraftSelected: (key) => activatedKey = key,
              onResetActiveCanvas: () => resetRequested = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('floating-canvas-navigator')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('UserLogin'));
      expect(activatedKey, 'login');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('floating-canvas-navigator')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('重置当前画布'));
      expect(resetRequested, isTrue);
    },
  );

  testWidgets('EditorPage uses bottom sheet navigation on compact screens', (
    tester,
  ) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(390, 800);
    binding.platformDispatcher.views.first.devicePixelRatio = 1;

    final workspace = CanvasWorkspace.empty().upsert(
      CanvasDraft(
        key: 'login',
        assetName: 'GM_MainMode',
        assetPath: '/Game/GM_MainMode',
        graphName: 'UserLogin',
        document: createSampleGraphDocument(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: workspace.activeDraft?.document,
            canvasDrafts: workspace.orderedDrafts,
            activeCanvasKey: workspace.activeKey,
            onCanvasDraftSelected: (_) {},
            onResetActiveCanvas: () {},
          ),
        ),
      ),
    );

    expect(find.text('画布草稿'), findsNothing);
    expect(
      find.byKey(const ValueKey('floating-canvas-navigator')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('floating-canvas-navigator')));
    await tester.pumpAndSettle();

    expect(find.text('画布草稿'), findsOneWidget);
    expect(find.text('GM_MainMode / UserLogin'), findsAtLeastNWidgets(1));
    expect(find.text('当前'), findsOneWidget);
  });

  testWidgets('EditorPage edits and deletes selected node', (tester) async {
    GraphDocument? changedDocument;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            initialDocument: createSampleGraphDocument(),
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );

    await tester.tapAt(tester.getCenter(find.text('事件：请求登录').first));
    await tester.pumpAndSettle();

    expect(find.text('事件：请求登录'), findsAtLeastNWidgets(1));
    expect(find.text('删除节点'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('node-title-field')),
      '计算伤害',
    );
    await tester.pumpAndSettle();
    expect(
      changedDocument?.nodes
          .firstWhere((node) => node.id == 'event_login')
          .title,
      '计算伤害',
    );

    await tester.enterText(
      find.byKey(const ValueKey('node-description-field')),
      '临时记录伤害公式',
    );
    await tester.pumpAndSettle();
    expect(
      changedDocument?.nodes
          .firstWhere((node) => node.id == 'event_login')
          .description,
      '临时记录伤害公式',
    );

    expect(find.textContaining('细节面板'), findsWidgets);
    expect(find.text('节点类型来自内置 UE 5.6 节点目录；引脚结构不在细节面板中自由增删。'), findsOneWidget);
    expect(find.byKey(const ValueKey('node-type-dropdown')), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(changedDocument?.nodes.length, 2);
    expect(changedDocument?.nodes.any((node) => node.title == '计算伤害'), isFalse);
    expect(find.textContaining('细节面板'), findsNothing);
  });

  testWidgets('EditorPage deletes selected node with Backspace shortcut', (
    tester,
  ) async {
    GraphDocument? changedDocument;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            initialDocument: createSampleGraphDocument(),
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );

    await tester.tapAt(tester.getCenter(find.text('事件：请求登录').first));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    expect(changedDocument?.nodes.length, 2);
    expect(
      changedDocument?.nodes.any((node) => node.id == 'event_login'),
      isFalse,
    );
    expect(find.textContaining('细节面板'), findsNothing);
  });

  testWidgets('EditorPage creates Branch with physical B plus left click', (
    tester,
  ) async {
    var changedDocument = createSampleGraphDocument();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );

    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.keyB,
      physicalKey: PhysicalKeyboardKey.keyB,
    );
    await tester.tapAt(const Offset(80, 620));
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.keyB,
      physicalKey: PhysicalKeyboardKey.keyB,
    );
    await tester.pumpAndSettle();

    final branch = changedDocument.nodes.last;
    expect(branch.title, 'Branch');
    expect(branch.nodeType, 'Branch');
    expect(branch.position.x, closeTo(0, 0.01));
    expect(branch.position.y, closeTo(548, 0.01));
  });

  testWidgets('EditorPage creates Comment with physical C plus left click', (
    tester,
  ) async {
    var changedDocument = createSampleGraphDocument();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );

    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.keyC,
      physicalKey: PhysicalKeyboardKey.keyC,
    );
    await tester.tapAt(const Offset(120, 620));
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.keyC,
      physicalKey: PhysicalKeyboardKey.keyC,
    );
    await tester.pumpAndSettle();

    final comment = changedDocument.nodes.last;
    expect(comment.title, 'Comment');
    expect(comment.nodeType, 'Comment');
    expect(comment.pins, isEmpty);
  });

  testWidgets(
    'EditorPage creates a comment frame around selected nodes and moves them together',
    (tester) async {
      var changedDocument = createSampleGraphDocument();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPage(
              showScaffoldChrome: false,
              initialDocument: changedDocument,
              onDocumentChanged: (document) => changedDocument = document,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selectionGesture = await tester.startGesture(const Offset(80, 100));
      await selectionGesture.moveTo(const Offset(760, 360));
      await tester.pump();
      await selectionGesture.up();
      await tester.pumpAndSettle();

      final beforeEvent = changedDocument.nodes.firstWhere(
        (node) => node.id == 'event_login',
      );
      final beforeFunction = changedDocument.nodes.firstWhere(
        (node) => node.id == 'function_validate_user',
      );

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyC,
        physicalKey: PhysicalKeyboardKey.keyC,
      );
      await tester.tapAt(const Offset(180, 620));
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.keyC,
        physicalKey: PhysicalKeyboardKey.keyC,
      );
      await tester.pumpAndSettle();

      final comment = changedDocument.nodes.last;
      expect(comment.nodeType, 'Comment');
      expect(comment.position.x, lessThan(beforeEvent.position.x));
      expect(comment.position.y, lessThan(beforeEvent.position.y));
      expect(
        comment.position.x + comment.size.width,
        greaterThan(beforeFunction.position.x + beforeFunction.size.width),
      );
      expect(
        comment.position.y + comment.size.height,
        greaterThan(beforeFunction.position.y + beforeFunction.size.height),
      );

      final dragStart = GraphCanvasGeometry.worldToScreen(
        GraphCanvasPoint(
          comment.position.x + comment.size.width / 2,
          comment.position.y + comment.size.height / 2,
        ),
        changedDocument.graph.viewport,
      );
      final dragGesture = await tester.startGesture(
        Offset(dragStart.x, dragStart.y),
      );
      await dragGesture.moveBy(const Offset(90, 45));
      await tester.pump();
      await dragGesture.up();
      await tester.pumpAndSettle();

      final afterComment = changedDocument.nodes.firstWhere(
        (node) => node.id == comment.id,
      );
      final afterEvent = changedDocument.nodes.firstWhere(
        (node) => node.id == 'event_login',
      );
      final afterFunction = changedDocument.nodes.firstWhere(
        (node) => node.id == 'function_validate_user',
      );

      expect(afterComment.position.x, closeTo(comment.position.x + 90, 0.01));
      expect(afterComment.position.y, closeTo(comment.position.y + 45, 0.01));
      expect(afterEvent.position.x, closeTo(beforeEvent.position.x + 90, 0.01));
      expect(afterEvent.position.y, closeTo(beforeEvent.position.y + 45, 0.01));
      expect(
        afterFunction.position.x,
        closeTo(beforeFunction.position.x + 90, 0.01),
      );
      expect(
        afterFunction.position.y,
        closeTo(beforeFunction.position.y + 45, 0.01),
      );
    },
  );

  testWidgets('EditorPage resizes a selected comment from the corner handle', (
    tester,
  ) async {
    var changedDocument = createSampleGraphDocument();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selectionGesture = await tester.startGesture(const Offset(80, 100));
    await selectionGesture.moveTo(const Offset(760, 360));
    await tester.pump();
    await selectionGesture.up();
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.keyC,
      physicalKey: PhysicalKeyboardKey.keyC,
    );
    await tester.tapAt(const Offset(180, 620));
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.keyC,
      physicalKey: PhysicalKeyboardKey.keyC,
    );
    await tester.pumpAndSettle();

    final beforeComment = changedDocument.nodes.last;
    final beforeEvent = changedDocument.nodes.firstWhere(
      (node) => node.id == 'event_login',
    );
    final bottomRight = GraphCanvasGeometry.worldToScreen(
      GraphCanvasPoint(
        beforeComment.position.x + beforeComment.size.width,
        beforeComment.position.y + beforeComment.size.height,
      ),
      changedDocument.graph.viewport,
    );

    final resizeGesture = await tester.startGesture(
      Offset(bottomRight.x - 2, bottomRight.y - 2),
    );
    await resizeGesture.moveBy(const Offset(100, 60));
    await tester.pump();
    await resizeGesture.up();
    await tester.pumpAndSettle();

    final afterComment = changedDocument.nodes.firstWhere(
      (node) => node.id == beforeComment.id,
    );
    final afterEvent = changedDocument.nodes.firstWhere(
      (node) => node.id == 'event_login',
    );

    expect(afterComment.position.x, beforeComment.position.x);
    expect(afterComment.position.y, beforeComment.position.y);
    expect(afterComment.size.width, closeTo(beforeComment.size.width + 100, 1));
    expect(
      afterComment.size.height,
      closeTo(beforeComment.size.height + 60, 1),
    );
    expect(afterEvent.position.x, beforeEvent.position.x);
    expect(afterEvent.position.y, beforeEvent.position.y);
  });

  testWidgets('EditorPage auto sizes a selected comment to contained nodes', (
    tester,
  ) async {
    final base = createSampleGraphDocument();
    final comment = GraphNode(
      id: 'comment_manual',
      nodeType: 'Comment',
      title: 'Comment',
      description: '用于圈定或说明一段蓝图逻辑。',
      position: const GraphNodePosition(x: 20, y: 20),
      size: const GraphNodeSize(width: 850, height: 450),
      pins: const [],
    );
    var changedDocument = base.copyWith(nodes: [...base.nodes, comment]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final commentCenter = GraphCanvasGeometry.worldToScreen(
      GraphCanvasPoint(
        comment.position.x + comment.size.width - 20,
        comment.position.y + 24,
      ),
      changedDocument.graph.viewport,
    );
    await tester.tapAt(Offset(commentCenter.x, commentCenter.y));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('comment-auto-size-button')));
    await tester.pumpAndSettle();

    final resizedComment = changedDocument.nodes.firstWhere(
      (node) => node.id == comment.id,
    );
    final expectedFrame = GraphCanvasGeometry.commentFrameForNodes(
      base.nodes
          .where(
            (node) => GraphCanvasGeometry.nodeIdsInsideComment(
              comment: comment,
              nodes: base.nodes,
            ).contains(node.id),
          )
          .toList(growable: false),
    );

    expect(resizedComment.position.x, expectedFrame.left);
    expect(resizedComment.position.y, expectedFrame.top);
    expect(resizedComment.size.width, expectedFrame.width);
    expect(resizedComment.size.height, expectedFrame.height);
  });

  testWidgets('EditorPage follows Unreal creation shortcuts for flow nodes', (
    tester,
  ) async {
    var changedDocument = createSampleGraphDocument();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );

    Future<void> pressCreate(
      LogicalKeyboardKey logicalKey,
      PhysicalKeyboardKey physicalKey,
      Offset location,
    ) async {
      await tester.sendKeyDownEvent(logicalKey, physicalKey: physicalKey);
      await tester.tapAt(location);
      await tester.sendKeyUpEvent(logicalKey, physicalKey: physicalKey);
      await tester.pumpAndSettle();
    }

    await pressCreate(
      LogicalKeyboardKey.keyF,
      PhysicalKeyboardKey.keyF,
      const Offset(80, 560),
    );
    expect(changedDocument.nodes.last.title, 'ForEachLoop');

    await pressCreate(
      LogicalKeyboardKey.keyN,
      PhysicalKeyboardKey.keyN,
      const Offset(520, 560),
    );
    expect(changedDocument.nodes.last.title, 'Do N');

    await pressCreate(
      LogicalKeyboardKey.keyP,
      PhysicalKeyboardKey.keyP,
      const Offset(80, 430),
    );
    expect(changedDocument.nodes.last.title, 'Event BeginPlay');

    await pressCreate(
      LogicalKeyboardKey.keyG,
      PhysicalKeyboardKey.keyG,
      const Offset(520, 430),
    );
    expect(changedDocument.nodes.last.title, 'Gate');

    await pressCreate(
      LogicalKeyboardKey.keyA,
      PhysicalKeyboardKey.keyA,
      const Offset(860, 430),
    );
    expect(changedDocument.nodes.last.title, 'Array Get');
  });

  testWidgets('EditorPage keeps pins read-only and creates removable links', (
    tester,
  ) async {
    var changedDocument = createSampleGraphDocument();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(360, 210));
    await tester.pumpAndSettle();

    final eventNode = changedDocument.nodes.firstWhere(
      (node) => node.id == 'event_login',
    );
    expect(eventNode.pins.any((pin) => pin.title == 'Then'), isTrue);
    expect(find.text('添加输入引脚'), findsNothing);
    expect(find.text('添加输出引脚'), findsNothing);
    expect(find.text('连线'), findsNothing);
    expect(find.byKey(const ValueKey('link-from-pin-dropdown')), findsNothing);
    expect(find.byKey(const ValueKey('link-to-pin-dropdown')), findsNothing);
    expect(find.text('创建连线'), findsNothing);
    expect(find.byIcon(Icons.link_off), findsNothing);
    expect(find.byKey(const ValueKey('delete-pin-user')), findsNothing);
    expect(find.textContaining('UE 节点引脚为只读'), findsNothing);
  });

  testWidgets('EditorPage only lets UE expandable nodes add pins', (
    tester,
  ) async {
    var changedDocument = createSampleGraphDocument();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );

    await tester.tapAt(tester.getCenter(find.text('函数：校验账号').first));
    await tester.pumpAndSettle();

    expect(find.text('添加 Then 输出'), findsNothing);

    await tester.tapAt(const Offset(40, 40), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('node-catalog-search-field')),
      'Sequence',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('node-catalog-template-sequence')),
    );
    await tester.pumpAndSettle();

    final sequenceNode = changedDocument.nodes.last;
    expect(sequenceNode.title, 'Sequence');
    expect(
      sequenceNode.pins.where((pin) => pin.title.startsWith('Then')).length,
      2,
    );

    await tester.ensureVisible(find.text('添加 Then 输出'));
    await tester.tap(find.text('添加 Then 输出'));
    await tester.pumpAndSettle();

    final expandedSequence = changedDocument.nodes.last;
    expect(
      expandedSequence.pins.where((pin) => pin.title.startsWith('Then')).length,
      3,
    );
    expect(expandedSequence.pins.last.id.endsWith('then_2'), isTrue);
    expect(expandedSequence.pins.last.title, 'Then 2');

    await tester.ensureVisible(
      find.byKey(ValueKey('delete-pin-${expandedSequence.pins.last.id}')),
    );
    await tester.tap(
      find.byKey(ValueKey('delete-pin-${expandedSequence.pins.last.id}')),
    );
    await tester.pumpAndSettle();

    expect(
      changedDocument.nodes.last.pins
          .where((pin) => pin.title.startsWith('Then'))
          .length,
      2,
    );
  });

  testWidgets(
    'EditorPage creates links by dragging a pin onto a compatible node',
    (tester) async {
      var changedDocument = createSampleGraphDocument().copyWith(
        links: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPage(
              showScaffoldChrome: false,
              initialDocument: changedDocument,
              onDocumentChanged: (document) => changedDocument = document,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sourceNode = changedDocument.nodes.firstWhere(
        (node) => node.id == 'event_login',
      );
      final targetNode = changedDocument.nodes.firstWhere(
        (node) => node.id == 'function_validate_user',
      );
      final viewport = changedDocument.graph.viewport;
      final startWorld = GraphCanvasGeometry.pinWorldPosition(
        sourceNode,
        'then',
      );
      final startScreen = GraphCanvasGeometry.worldToScreen(
        startWorld,
        viewport,
      );
      final targetBody = GraphCanvasGeometry.worldToScreen(
        GraphCanvasPoint(
          targetNode.position.x + 90,
          targetNode.position.y + 80,
        ),
        viewport,
      );

      final gesture = await tester.startGesture(
        Offset(startScreen.x, startScreen.y),
      );
      await gesture.moveTo(Offset(targetBody.x, targetBody.y));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(changedDocument.links.length, 1);
      final link = changedDocument.links.single;
      expect(link.fromNodeId, 'event_login');
      expect(link.fromPinId, 'then');
      expect(link.toNodeId, 'function_validate_user');
      expect(link.toPinId, 'exec');
      expect(link.linkType, 'exec');
    },
  );

  testWidgets('EditorPage selects every node covered by box selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: createSampleGraphDocument(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(const Offset(80, 100));
    await gesture.moveTo(const Offset(800, 380));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('event_login')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('function_validate_user')),
      findsOneWidget,
    );
    expect(find.textContaining('细节面板'), findsNothing);
  });

  testWidgets('EditorPage opens node catalog when a link is dropped on blank', (
    tester,
  ) async {
    var changedDocument = createSampleGraphDocument().copyWith(links: const []);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sourceNode = changedDocument.nodes.firstWhere(
      (node) => node.id == 'event_login',
    );
    final viewport = changedDocument.graph.viewport;
    final startWorld = GraphCanvasGeometry.pinWorldPosition(sourceNode, 'then');
    final startScreen = GraphCanvasGeometry.worldToScreen(startWorld, viewport);
    const dropScreen = Offset(760, 520);
    final dropWorld = GraphCanvasGeometry.screenToWorld(
      GraphCanvasPoint(dropScreen.dx, dropScreen.dy),
      viewport,
    );

    final gesture = await tester.startGesture(
      Offset(startScreen.x, startScreen.y),
    );
    await gesture.moveTo(dropScreen);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('节点目录'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('node-catalog-search-field')),
      findsOneWidget,
    );

    await tester.tap(find.text('Branch').last);
    await tester.pumpAndSettle();

    final branchNode = changedDocument.nodes.last;
    expect(branchNode.title, 'Branch');
    expect(branchNode.position.x, closeTo(dropWorld.x, 0.001));
    expect(branchNode.position.y, closeTo(dropWorld.y, 0.001));
  });

  testWidgets('EditorPage highlights compatible nodes while dragging a link', (
    tester,
  ) async {
    var changedDocument = createSampleGraphDocument().copyWith(links: const []);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sourceNode = changedDocument.nodes.firstWhere(
      (node) => node.id == 'event_login',
    );
    final viewport = changedDocument.graph.viewport;
    final startWorld = GraphCanvasGeometry.pinWorldPosition(sourceNode, 'then');
    final startScreen = GraphCanvasGeometry.worldToScreen(startWorld, viewport);

    final gesture = await tester.startGesture(
      Offset(startScreen.x, startScreen.y),
    );
    await gesture.moveTo(Offset(startScreen.x + 80, startScreen.y));
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey('compatible-target-node-function_validate_user'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('compatible-target-arrow-function_validate_user'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('compatible-target-node-event_login')),
      findsNothing,
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'EditorPage auto pans the canvas while dragging a link near edge',
    (tester) async {
      var changedDocument = createSampleGraphDocument().copyWith(
        links: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPage(
              showScaffoldChrome: false,
              initialDocument: changedDocument,
              onDocumentChanged: (document) => changedDocument = document,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sourceNode = changedDocument.nodes.firstWhere(
        (node) => node.id == 'event_login',
      );
      final startViewport = changedDocument.graph.viewport;
      final startWorld = GraphCanvasGeometry.pinWorldPosition(
        sourceNode,
        'then',
      );
      final startScreen = GraphCanvasGeometry.worldToScreen(
        startWorld,
        startViewport,
      );

      final gesture = await tester.startGesture(
        Offset(startScreen.x, startScreen.y),
      );
      await gesture.moveTo(const Offset(1210, 380));
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        changedDocument.graph.viewport.offsetX,
        lessThan(startViewport.offsetX),
      );

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('EditorPage replaces existing input link from canvas drag', (
    tester,
  ) async {
    var changedDocument = createSampleGraphDocument();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sourceNode = changedDocument.nodes.firstWhere(
      (node) => node.id == 'event_login',
    );
    final targetNode = changedDocument.nodes.firstWhere(
      (node) => node.id == 'function_validate_user',
    );
    final viewport = changedDocument.graph.viewport;
    final startWorld = GraphCanvasGeometry.pinWorldPosition(sourceNode, 'user');
    final startScreen = GraphCanvasGeometry.worldToScreen(startWorld, viewport);
    final targetWorld = GraphCanvasGeometry.pinWorldPosition(
      targetNode,
      'user',
    );
    final targetScreen = GraphCanvasGeometry.worldToScreen(
      targetWorld,
      viewport,
    );

    final gesture = await tester.startGesture(
      Offset(startScreen.x, startScreen.y),
    );
    await gesture.moveTo(Offset(targetScreen.x, targetScreen.y));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final userLinks = changedDocument.links
        .where(
          (link) =>
              link.toNodeId == 'function_validate_user' &&
              link.toPinId == 'user',
        )
        .toList(growable: false);
    expect(userLinks.length, 1);
    expect(userLinks.single.fromNodeId, 'event_login');
    expect(userLinks.single.fromPinId, 'user');
  });

  testWidgets('EditorPage disconnects a linked input when dragged to blank', (
    tester,
  ) async {
    var changedDocument = createSampleGraphDocument().copyWith(
      links: [
        ...createSampleGraphDocument().links,
        const GraphLink(
          id: 'link_login_user_to_validate_user',
          fromNodeId: 'event_login',
          fromPinId: 'user',
          toNodeId: 'function_validate_user',
          toPinId: 'user',
          title: '',
          description: '',
          linkType: 'data',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPage(
            showScaffoldChrome: false,
            initialDocument: changedDocument,
            onDocumentChanged: (document) => changedDocument = document,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final inputNode = changedDocument.nodes.firstWhere(
      (node) => node.id == 'function_validate_user',
    );
    final viewport = changedDocument.graph.viewport;
    final inputWorld = GraphCanvasGeometry.pinWorldPosition(inputNode, 'user');
    final inputScreen = GraphCanvasGeometry.worldToScreen(inputWorld, viewport);

    final gesture = await tester.startGesture(
      Offset(inputScreen.x, inputScreen.y),
    );
    await gesture.moveTo(const Offset(120, 520));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      changedDocument.links.any(
        (link) =>
            link.toNodeId == 'function_validate_user' && link.toPinId == 'user',
      ),
      isFalse,
    );
  });

  testWidgets(
    'EditorPage reroutes a linked input when dragged to another pin',
    (tester) async {
      var changedDocument = createSampleGraphDocument().copyWith(
        links: [
          ...createSampleGraphDocument().links.where(
            (link) => link.id != 'link_success_to_condition',
          ),
          const GraphLink(
            id: 'link_login_user_to_condition',
            fromNodeId: 'event_login',
            fromPinId: 'user',
            toNodeId: 'branch_login_result',
            toPinId: 'condition',
            title: '',
            description: '',
            linkType: 'data',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPage(
              showScaffoldChrome: false,
              initialDocument: changedDocument,
              onDocumentChanged: (document) => changedDocument = document,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sourceInputNode = changedDocument.nodes.firstWhere(
        (node) => node.id == 'branch_login_result',
      );
      final targetInputNode = changedDocument.nodes.firstWhere(
        (node) => node.id == 'function_validate_user',
      );
      final viewport = changedDocument.graph.viewport;
      final sourceInputWorld = GraphCanvasGeometry.pinWorldPosition(
        sourceInputNode,
        'condition',
      );
      final sourceInputScreen = GraphCanvasGeometry.worldToScreen(
        sourceInputWorld,
        viewport,
      );
      final targetInputWorld = GraphCanvasGeometry.pinWorldPosition(
        targetInputNode,
        'user',
      );
      final targetInputScreen = GraphCanvasGeometry.worldToScreen(
        targetInputWorld,
        viewport,
      );

      final gesture = await tester.startGesture(
        Offset(sourceInputScreen.x, sourceInputScreen.y),
      );
      await gesture.moveTo(Offset(targetInputScreen.x, targetInputScreen.y));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        changedDocument.links.any(
          (link) =>
              link.toNodeId == 'branch_login_result' &&
              link.toPinId == 'condition',
        ),
        isFalse,
      );
      final reroutedLinks = changedDocument.links
          .where(
            (link) =>
                link.fromNodeId == 'event_login' &&
                link.fromPinId == 'user' &&
                link.toNodeId == 'function_validate_user' &&
                link.toPinId == 'user',
          )
          .toList(growable: false);
      expect(reroutedLinks.length, 1);
    },
  );

  testWidgets(
    'EditorPage opens a radial pin picker from node long press and connects from it',
    (tester) async {
      var changedDocument = createSampleGraphDocument().copyWith(
        links: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPage(
              showScaffoldChrome: false,
              initialDocument: changedDocument,
              onDocumentChanged: (document) => changedDocument = document,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final wheelGesture = await tester.startGesture(const Offset(230, 250));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 40));

      expect(find.byKey(const ValueKey('pin-wheel')), findsOneWidget);

      await wheelGesture.moveTo(const Offset(334, 196));
      await tester.pump();
      await wheelGesture.up();
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('compatible-target-node-function_validate_user'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('compatible-target-arrow-function_validate_user'),
        ),
        findsOneWidget,
      );

      final targetNode = changedDocument.nodes.firstWhere(
        (node) => node.id == 'function_validate_user',
      );
      final targetBody = GraphCanvasGeometry.worldToScreen(
        GraphCanvasPoint(
          targetNode.position.x + 90,
          targetNode.position.y + 80,
        ),
        changedDocument.graph.viewport,
      );

      await tester.tapAt(Offset(targetBody.x, targetBody.y));
      await tester.pumpAndSettle();

      expect(changedDocument.links.length, 1);
      expect(changedDocument.links.single.fromPinId, 'then');
      expect(changedDocument.links.single.toPinId, 'exec');
    },
  );
}
