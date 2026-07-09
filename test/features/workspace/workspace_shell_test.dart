import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/workspace/workspace_models.dart';
import 'package:unreal_blueprint_bridge/features/workspace/workspace_shell.dart';

void main() {
  test(
    'Workspace sidebar omits reserved graph-map entry for first version',
    () {
      expect(
        WorkspaceSection.values.map((section) => section.label),
        isNot(contains('图谱')),
      );
    },
  );

  testWidgets('Workspace overview scrolls to bottom info on short windows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(18),
            child: WorkspaceOverviewView(
              workspace: WorkspaceSummary(
                id: 'fantasyproject',
                name: 'FantasyProject',
                workspacePath:
                    r'D:\UnrealMap\FantasyProject\Saved\BlueprintBridge\FantasyProject.ubbridge',
                unrealProjectPath:
                    r'D:\UnrealMap\FantasyProject\FantasyProject.uproject',
                getTheMeaningExportPath:
                    r'D:\UnrealMap\FantasyProject\Saved\GetTheMeaningExports',
                lastOpenedAt: '2026-07-08T20:00:00+08:00',
              ),
              importSummary: null,
              appStatePath:
                  r'C:\Users\liuyu\AppData\Roaming\UnrealBlueprintBridge\app_state.json',
              graphPackagePath:
                  r'D:\UnrealMap\FantasyProject\Saved\BlueprintBridge',
              graphExportPath:
                  r'C:\Users\liuyu\AppData\Roaming\UnrealBlueprintBridge\graph_exports_fantasyproject',
              aiGraphPrompt: 'AI_GRAPH_PACKAGE_GUIDE.md / GraphIndex.json',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();

    expect(tester.getBottomLeft(find.text('GetTheMeaning')).dy, lessThan(360));
  });

  test('Project workspace top bar omits inner global settings button', () {
    final source = File(
      'lib/features/workspace/workspace_shell.dart',
    ).readAsStringSync();
    final topBarSource = source.substring(
      source.indexOf('class _WorkspaceTopBar'),
      source.indexOf('enum _CanvasDraftCommand'),
    );

    expect(topBarSource, isNot(contains("tooltip: '整体设置'")));
    expect(topBarSource, isNot(contains('Icons.tune_outlined')));
  });

  test('Sidebar draft items expose blueprint context menu commands', () {
    final source = File(
      'lib/features/workspace/workspace_shell.dart',
    ).readAsStringSync();
    final draftItemSource = source.substring(
      source.indexOf('class _SidebarDraftItem'),
      source.indexOf('class _SidebarEmptyDraftItem'),
    );

    expect(draftItemSource, contains('onSecondaryTapDown'));
    expect(draftItemSource, contains('onResetBlueprint'));
    expect(draftItemSource, contains('onRename'));
    expect(draftItemSource, contains('onOpenFolder'));
    expect(draftItemSource, contains('onDelete'));
    expect(source, contains("_SidebarDraftCommand.resetBlueprint => '重置蓝图'"));
    expect(source, contains("_SidebarDraftCommand.rename => '重命名'"));
    expect(source, contains("_SidebarDraftCommand.openFolder => '打开文件夹'"));
    expect(source, contains("_SidebarDraftCommand.delete => '删除蓝图'"));
  });
}
