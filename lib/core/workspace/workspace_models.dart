enum WorkspaceStorageKind {
  unrealSaved,
  appPrivate;

  static WorkspaceStorageKind fromJson(Object? value) {
    return switch (value) {
      'appPrivate' => WorkspaceStorageKind.appPrivate,
      _ => WorkspaceStorageKind.unrealSaved,
    };
  }
}

class WorkspaceLocation {
  const WorkspaceLocation({
    required this.name,
    required this.workspacePath,
    required this.storageKind,
  });

  factory WorkspaceLocation.forDesktopUnrealProject({
    required String unrealProjectPath,
  }) {
    final normalized = unrealProjectPath.replaceAll('/', r'\');
    final separatorIndex = normalized.lastIndexOf(r'\');
    final projectFolder = separatorIndex >= 0
        ? normalized.substring(0, separatorIndex)
        : '';
    final fileName = separatorIndex >= 0
        ? normalized.substring(separatorIndex + 1)
        : normalized;
    final projectName = _stripExtension(fileName);

    return WorkspaceLocation(
      name: projectName,
      workspacePath:
          '$projectFolder\\Saved\\BlueprintBridge\\$projectName.ubbridge',
      storageKind: WorkspaceStorageKind.unrealSaved,
    );
  }

  factory WorkspaceLocation.forMobileWorkspace({
    required String appWorkspaceRoot,
    required String projectName,
  }) {
    final root = appWorkspaceRoot.endsWith('/')
        ? appWorkspaceRoot.substring(0, appWorkspaceRoot.length - 1)
        : appWorkspaceRoot;

    return WorkspaceLocation(
      name: projectName,
      workspacePath: '$root/$projectName.ubbridge',
      storageKind: WorkspaceStorageKind.appPrivate,
    );
  }

  final String name;
  final String workspacePath;
  final WorkspaceStorageKind storageKind;

  static String _stripExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return fileName;
    }

    return fileName.substring(0, dotIndex);
  }
}

class WorkspaceSummary {
  const WorkspaceSummary({
    required this.id,
    required this.name,
    required this.workspacePath,
    required this.unrealProjectPath,
    required this.getTheMeaningExportPath,
    required this.lastOpenedAt,
  });

  factory WorkspaceSummary.fromJson(Map<String, Object?> json) {
    return WorkspaceSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      workspacePath: json['workspacePath'] as String? ?? '',
      unrealProjectPath: json['unrealProjectPath'] as String? ?? '',
      getTheMeaningExportPath: json['getTheMeaningExportPath'] as String? ?? '',
      lastOpenedAt: json['lastOpenedAt'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String workspacePath;
  final String unrealProjectPath;
  final String getTheMeaningExportPath;
  final String lastOpenedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'workspacePath': workspacePath,
      'unrealProjectPath': unrealProjectPath,
      'getTheMeaningExportPath': getTheMeaningExportPath,
      'lastOpenedAt': lastOpenedAt,
    };
  }
}

class BridgeAppSettings {
  const BridgeAppSettings({
    this.engineNodeBookId = 'unreal_5_6',
    this.updateManifestUrl = '',
  });

  factory BridgeAppSettings.fromJson(Map<String, Object?> json) {
    return BridgeAppSettings(
      engineNodeBookId: json['engineNodeBookId'] as String? ?? 'unreal_5_6',
      updateManifestUrl: json['updateManifestUrl'] as String? ?? '',
    );
  }

  final String engineNodeBookId;
  final String updateManifestUrl;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'engineNodeBookId': engineNodeBookId,
      'updateManifestUrl': updateManifestUrl,
    };
  }
}

class BridgeAppState {
  const BridgeAppState({
    required this.lastWorkspaceId,
    required this.recentWorkspaces,
    this.settings = const BridgeAppSettings(),
  });

  factory BridgeAppState.fromJson(Map<String, Object?> json) {
    final recentJson =
        json['recentWorkspaces'] as List<Object?>? ?? const <Object?>[];
    final settingsJson =
        json['settings'] as Map<String, Object?>? ?? const <String, Object?>{};

    return BridgeAppState(
      lastWorkspaceId: json['lastWorkspaceId'] as String? ?? '',
      recentWorkspaces: recentJson
          .whereType<Map<String, Object?>>()
          .map(WorkspaceSummary.fromJson)
          .toList(growable: false),
      settings: BridgeAppSettings.fromJson(settingsJson),
    );
  }

  factory BridgeAppState.sample() {
    return const BridgeAppState(
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
        WorkspaceSummary(
          id: 'prototype',
          name: 'Prototype',
          workspacePath:
              r'D:\UnrealMap\Prototype\Saved\BlueprintBridge\Prototype.ubbridge',
          unrealProjectPath: r'D:\UnrealMap\Prototype\Prototype.uproject',
          getTheMeaningExportPath: '',
          lastOpenedAt: '2026-07-06T20:00:00+08:00',
        ),
      ],
    );
  }

  final String lastWorkspaceId;
  final List<WorkspaceSummary> recentWorkspaces;
  final BridgeAppSettings settings;

  BridgeAppState copyWith({
    String? lastWorkspaceId,
    List<WorkspaceSummary>? recentWorkspaces,
    BridgeAppSettings? settings,
  }) {
    return BridgeAppState(
      lastWorkspaceId: lastWorkspaceId ?? this.lastWorkspaceId,
      recentWorkspaces: recentWorkspaces ?? this.recentWorkspaces,
      settings: settings ?? this.settings,
    );
  }

  BridgeAppState bindDesktopUnrealProject({
    required String unrealProjectPath,
    required DateTime openedAt,
  }) {
    final normalizedProjectPath = unrealProjectPath.trim().replaceAll(
      '/',
      r'\',
    );
    final location = WorkspaceLocation.forDesktopUnrealProject(
      unrealProjectPath: normalizedProjectPath,
    );
    final id = _workspaceIdFromName(location.name);
    final projectFolder = _parentPath(normalizedProjectPath);
    final summary = WorkspaceSummary(
      id: id,
      name: location.name,
      workspacePath: location.workspacePath,
      unrealProjectPath: normalizedProjectPath,
      getTheMeaningExportPath: '$projectFolder\\Saved\\GetTheMeaningExports',
      lastOpenedAt: openedAt.toIso8601String(),
    );
    final remaining = recentWorkspaces
        .where(
          (workspace) =>
              workspace.id != id &&
              workspace.unrealProjectPath.toLowerCase() !=
                  normalizedProjectPath.toLowerCase(),
        )
        .toList(growable: false);

    return BridgeAppState(
      lastWorkspaceId: id,
      recentWorkspaces: [summary, ...remaining],
      settings: settings,
    );
  }

  BridgeAppState createDraftWorkspace({
    required String projectName,
    required String appWorkspaceRoot,
    required DateTime openedAt,
  }) {
    final normalizedName = projectName.trim().isEmpty
        ? '未命名草稿'
        : projectName.trim();
    final location = WorkspaceLocation.forMobileWorkspace(
      appWorkspaceRoot: appWorkspaceRoot,
      projectName: normalizedName,
    );
    final id = 'draft_${_workspaceIdFromName(normalizedName)}';
    final summary = WorkspaceSummary(
      id: id,
      name: normalizedName,
      workspacePath: location.workspacePath,
      unrealProjectPath: '',
      getTheMeaningExportPath: '',
      lastOpenedAt: openedAt.toIso8601String(),
    );
    final remaining = recentWorkspaces
        .where((workspace) => workspace.id != id)
        .toList(growable: false);

    return BridgeAppState(
      lastWorkspaceId: id,
      recentWorkspaces: [summary, ...remaining],
      settings: settings,
    );
  }

  WorkspaceSummary? get currentWorkspace {
    for (final workspace in recentWorkspaces) {
      if (workspace.id == lastWorkspaceId) {
        return workspace;
      }
    }

    return recentWorkspaces.firstOrNull;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'lastWorkspaceId': lastWorkspaceId,
      'settings': settings.toJson(),
      'recentWorkspaces': recentWorkspaces
          .map((workspace) => workspace.toJson())
          .toList(growable: false),
    };
  }

  static String _workspaceIdFromName(String name) {
    final normalized = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return normalized.isEmpty ? 'workspace' : normalized;
  }

  static String _parentPath(String path) {
    final separatorIndex = path.lastIndexOf(r'\');
    if (separatorIndex <= 0) {
      return '';
    }

    return path.substring(0, separatorIndex);
  }
}
