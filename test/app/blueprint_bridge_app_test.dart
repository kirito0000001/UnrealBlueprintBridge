import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/app/blueprint_bridge_app.dart';
import 'package:unreal_blueprint_bridge/app/bridge_scroll_behavior.dart';
import 'package:unreal_blueprint_bridge/features/workspace/ai_graph_prompt_panel.dart';

void main() {
  testWidgets('BlueprintBridgeApp installs shared smooth scroll behavior', (
    tester,
  ) async {
    await tester.pumpWidget(const BlueprintBridgeApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.scrollBehavior, isA<BridgeScrollBehavior>());
    expect(
      app.scrollBehavior?.getScrollPhysics(
        tester.element(find.byType(MaterialApp)),
      ),
      isA<BouncingScrollPhysics>(),
    );
  });

  testWidgets('BridgeScrollBehavior wraps scrollables for smooth wheel input', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const BridgeScrollBehavior(),
        home: Scaffold(
          body: ListView.builder(
            itemCount: 40,
            itemBuilder: (context, index) =>
                SizedBox(height: 32, child: Text('Item $index')),
          ),
        ),
      ),
    );

    expect(find.byType(SmoothWheelScrollWrapper), findsOneWidget);
  });

  testWidgets('BridgeScrollBehavior animates mouse wheel scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const BridgeScrollBehavior(),
        home: Scaffold(
          body: ListView.builder(
            itemCount: 80,
            itemBuilder: (context, index) =>
                SizedBox(height: 32, child: Text('Item $index')),
          ),
        ),
      ),
    );

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, 0);

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(ListView)),
        scrollDelta: const Offset(0, 240),
        kind: PointerDeviceKind.mouse,
      ),
    );

    expect(scrollable.position.pixels, 0);

    await tester.pump();
    await tester.pump(kBridgeWheelScrollDuration ~/ 2);
    expect(scrollable.position.pixels, greaterThan(0));
    expect(scrollable.position.pixels, lessThan(240));

    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, 240);
  });

  testWidgets('AiGraphPromptPanel exposes copyable AI graph prompt', (
    tester,
  ) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText =
                (call.arguments as Map<Object?, Object?>?)?['text'] as String?;
            return null;
          }

          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiGraphPromptPanel(
            prompt:
                '请阅读 AI_GRAPH_PACKAGE_GUIDE.md，输出 GraphIndex.json，不要修改 Unreal .uasset 文件。',
            triggerPrompt: '触发图例生成：目标工作区「幻杀图例草稿」，需求：<写清楚要画的蓝图逻辑>',
          ),
        ),
      ),
    );

    expect(find.text('AI 图例生成提示词'), findsOneWidget);
    expect(find.text('复制提示词'), findsOneWidget);
    expect(find.text('触发语'), findsOneWidget);
    expect(find.text('触发图例生成：目标工作区「幻杀图例草稿」，需求：<写清楚要画的蓝图逻辑>'), findsOneWidget);
    expect(find.textContaining('完整协议已内置'), findsOneWidget);
    expect(find.textContaining('AI_GRAPH_PACKAGE_GUIDE.md'), findsOneWidget);
    expect(find.textContaining('GraphIndex.json'), findsOneWidget);
    expect(find.textContaining('不要修改 Unreal .uasset 文件'), findsNothing);
    expect(find.byType(Scrollbar), findsNothing);

    await tester.tap(find.text('复制提示词'));
    await tester.pumpAndSettle();

    expect(find.text('已复制 AI 图例生成提示词'), findsOneWidget);
    expect(copiedText, '触发图例生成：目标工作区「幻杀图例草稿」，需求：<写清楚要画的蓝图逻辑>');
  });
}
