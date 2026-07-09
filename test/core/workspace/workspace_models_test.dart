import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/workspace/workspace_models.dart';

void main() {
  test(
    'WorkspaceLocation resolves PC workspace beside Unreal project Saved folder',
    () {
      final location = WorkspaceLocation.forDesktopUnrealProject(
        unrealProjectPath:
            r'D:\UnrealMap\FantasyProject\FantasyProject.uproject',
      );

      expect(location.name, 'FantasyProject');
      expect(
        location.workspacePath,
        r'D:\UnrealMap\FantasyProject\Saved\BlueprintBridge\FantasyProject.ubbridge',
      );
      expect(location.storageKind, WorkspaceStorageKind.unrealSaved);
    },
  );

  test('WorkspaceLocation resolves mobile workspace under app workspace root', () {
    final location = WorkspaceLocation.forMobileWorkspace(
      appWorkspaceRoot:
          '/storage/emulated/0/Android/data/com.TFAC.unreal_blueprint_bridge/files/workspaces',
      projectName: 'FantasyProject',
    );

    expect(
      location.workspacePath,
      '/storage/emulated/0/Android/data/com.TFAC.unreal_blueprint_bridge/files/workspaces/FantasyProject.ubbridge',
    );
    expect(location.storageKind, WorkspaceStorageKind.appPrivate);
  });

  test('BridgeAppState keeps current workspace and recent workspaces', () {
    const fantasy = WorkspaceSummary(
      id: 'fantasy_project',
      name: 'FantasyProject',
      workspacePath:
          r'D:\UnrealMap\FantasyProject\Saved\BlueprintBridge\FantasyProject.ubbridge',
      unrealProjectPath: r'D:\UnrealMap\FantasyProject\FantasyProject.uproject',
      getTheMeaningExportPath:
          r'D:\UnrealMap\FantasyProject\Saved\GetTheMeaningExports',
      lastOpenedAt: '2026-07-07T14:00:00+08:00',
    );
    const prototype = WorkspaceSummary(
      id: 'prototype',
      name: 'Prototype',
      workspacePath:
          r'D:\UnrealMap\Prototype\Saved\BlueprintBridge\Prototype.ubbridge',
      unrealProjectPath: r'D:\UnrealMap\Prototype\Prototype.uproject',
      getTheMeaningExportPath: '',
      lastOpenedAt: '2026-07-06T20:00:00+08:00',
    );

    final state = BridgeAppState(
      lastWorkspaceId: fantasy.id,
      recentWorkspaces: const [fantasy, prototype],
    );

    expect(state.currentWorkspace?.name, 'FantasyProject');
    expect(state.recentWorkspaces, hasLength(2));
    expect(state.toJson()['lastWorkspaceId'], fantasy.id);
    expect(state.settings.engineNodeBookId, 'unreal_5_6');
  });

  test('BridgeAppState saves selected engine node book setting', () {
    final state =
        const BridgeAppState(
          lastWorkspaceId: '',
          recentWorkspaces: [],
        ).copyWith(
          settings: const BridgeAppSettings(
            engineNodeBookId: 'unreal_5_6',
            updateManifestUrl: 'https://example.com/update.json',
          ),
        );

    final decoded = BridgeAppState.fromJson(state.toJson());

    expect(decoded.settings.engineNodeBookId, 'unreal_5_6');
    expect(
      decoded.settings.updateManifestUrl,
      'https://example.com/update.json',
    );
  });

  test('BridgeAppState binds desktop Unreal project as current workspace', () {
    const prototype = WorkspaceSummary(
      id: 'prototype',
      name: 'Prototype',
      workspacePath:
          r'D:\UnrealMap\Prototype\Saved\BlueprintBridge\Prototype.ubbridge',
      unrealProjectPath: r'D:\UnrealMap\Prototype\Prototype.uproject',
      getTheMeaningExportPath: '',
      lastOpenedAt: '2026-07-06T20:00:00+08:00',
    );

    const state = BridgeAppState(
      lastWorkspaceId: 'prototype',
      recentWorkspaces: [prototype],
    );

    final updated = state.bindDesktopUnrealProject(
      unrealProjectPath: r'D:\UnrealMap\FantasyProject\FantasyProject.uproject',
      openedAt: DateTime.parse('2026-07-08T12:00:00+08:00'),
    );

    expect(updated.lastWorkspaceId, 'fantasyproject');
    expect(updated.currentWorkspace?.name, 'FantasyProject');
    expect(
      updated.currentWorkspace?.workspacePath,
      r'D:\UnrealMap\FantasyProject\Saved\BlueprintBridge\FantasyProject.ubbridge',
    );
    expect(
      updated.currentWorkspace?.getTheMeaningExportPath,
      r'D:\UnrealMap\FantasyProject\Saved\GetTheMeaningExports',
    );
    expect(updated.recentWorkspaces.map((item) => item.id), [
      'fantasyproject',
      'prototype',
    ]);
  });

  test('BridgeAppState rebinding existing Unreal project moves it to front', () {
    const fantasy = WorkspaceSummary(
      id: 'fantasyproject',
      name: 'FantasyProject',
      workspacePath:
          r'D:\UnrealMap\FantasyProject\Saved\BlueprintBridge\FantasyProject.ubbridge',
      unrealProjectPath: r'D:\UnrealMap\FantasyProject\FantasyProject.uproject',
      getTheMeaningExportPath:
          r'D:\UnrealMap\FantasyProject\Saved\GetTheMeaningExports',
      lastOpenedAt: '2026-07-07T14:00:00+08:00',
    );
    const prototype = WorkspaceSummary(
      id: 'prototype',
      name: 'Prototype',
      workspacePath:
          r'D:\UnrealMap\Prototype\Saved\BlueprintBridge\Prototype.ubbridge',
      unrealProjectPath: r'D:\UnrealMap\Prototype\Prototype.uproject',
      getTheMeaningExportPath: '',
      lastOpenedAt: '2026-07-06T20:00:00+08:00',
    );

    const state = BridgeAppState(
      lastWorkspaceId: 'prototype',
      recentWorkspaces: [prototype, fantasy],
    );

    final updated = state.bindDesktopUnrealProject(
      unrealProjectPath: r'D:\UnrealMap\FantasyProject\FantasyProject.uproject',
      openedAt: DateTime.parse('2026-07-08T12:00:00+08:00'),
    );

    expect(updated.recentWorkspaces, hasLength(2));
    expect(updated.recentWorkspaces.first.id, 'fantasyproject');
    expect(updated.recentWorkspaces.last.id, 'prototype');
  });

  test(
    'BridgeAppState creates draft workspace under app private workspace root',
    () {
      const state = BridgeAppState(lastWorkspaceId: '', recentWorkspaces: []);

      final updated = state.createDraftWorkspace(
        projectName: '角色技能草稿',
        appWorkspaceRoot:
            r'C:\Users\liuyu\AppData\Roaming\UnrealBlueprintBridge\Drafts',
        openedAt: DateTime.parse('2026-07-08T13:00:00+08:00'),
      );

      expect(updated.lastWorkspaceId, 'draft_角色技能草稿');
      expect(updated.currentWorkspace?.name, '角色技能草稿');
      expect(
        updated.currentWorkspace?.workspacePath,
        r'C:\Users\liuyu\AppData\Roaming\UnrealBlueprintBridge\Drafts/角色技能草稿.ubbridge',
      );
      expect(updated.currentWorkspace?.unrealProjectPath, isEmpty);
      expect(updated.currentWorkspace?.getTheMeaningExportPath, isEmpty);
    },
  );
}
