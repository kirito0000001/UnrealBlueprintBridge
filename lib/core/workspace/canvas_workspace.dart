import '../models/graph_document.dart';

class CanvasDraft {
  const CanvasDraft({
    required this.key,
    required this.assetName,
    required this.assetPath,
    required this.graphName,
    required this.document,
  });

  factory CanvasDraft.fromJson(Map<String, Object?> json) {
    return CanvasDraft(
      key: json['key'] as String? ?? '',
      assetName: json['assetName'] as String? ?? '',
      assetPath: json['assetPath'] as String? ?? '',
      graphName: json['graphName'] as String? ?? '',
      document: GraphDocument.fromJson(
        json['document'] as Map<String, Object?>? ?? const <String, Object?>{},
      ),
    );
  }

  final String key;
  final String assetName;
  final String assetPath;
  final String graphName;
  final GraphDocument document;

  CanvasDraft copyWith({
    String? key,
    String? assetName,
    String? assetPath,
    String? graphName,
    GraphDocument? document,
  }) {
    return CanvasDraft(
      key: key ?? this.key,
      assetName: assetName ?? this.assetName,
      assetPath: assetPath ?? this.assetPath,
      graphName: graphName ?? this.graphName,
      document: document ?? this.document,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'key': key,
      'assetName': assetName,
      'assetPath': assetPath,
      'graphName': graphName,
      'document': document.toJson(),
    };
  }
}

class CanvasWorkspace {
  const CanvasWorkspace({required this.activeKey, required this.drafts});

  factory CanvasWorkspace.empty() {
    return const CanvasWorkspace(
      activeKey: null,
      drafts: <String, CanvasDraft>{},
    );
  }

  factory CanvasWorkspace.fromJson(Map<String, Object?> json) {
    final drafts = <String, CanvasDraft>{};
    final draftsJson = json['drafts'];

    if (draftsJson is List<Object?>) {
      for (final item in draftsJson.whereType<Map<String, Object?>>()) {
        final draft = CanvasDraft.fromJson(item);
        if (draft.key.isNotEmpty) {
          drafts[draft.key] = draft;
        }
      }
    }

    final activeKey = json['activeKey'] as String?;

    return CanvasWorkspace(
      activeKey: activeKey != null && drafts.containsKey(activeKey)
          ? activeKey
          : drafts.keys.firstOrNull,
      drafts: drafts,
    );
  }

  final String? activeKey;
  final Map<String, CanvasDraft> drafts;

  CanvasDraft? get activeDraft {
    final key = activeKey;
    if (key == null) {
      return null;
    }

    return drafts[key];
  }

  List<CanvasDraft> get orderedDrafts {
    return drafts.values.toList(growable: false)..sort((a, b) {
      final assetCompare = a.assetName.compareTo(b.assetName);
      if (assetCompare != 0) {
        return assetCompare;
      }

      return a.graphName.compareTo(b.graphName);
    });
  }

  CanvasWorkspace activate(String key) {
    if (!drafts.containsKey(key)) {
      return this;
    }

    return copyWith(activeKey: key);
  }

  CanvasWorkspace upsert(CanvasDraft draft, {bool activateDraft = true}) {
    final updatedDrafts = Map<String, CanvasDraft>.of(drafts)
      ..[draft.key] = draft;

    return CanvasWorkspace(
      activeKey: activateDraft ? draft.key : activeKey ?? draft.key,
      drafts: updatedDrafts,
    );
  }

  CanvasWorkspace updateActiveDocument(GraphDocument document) {
    final key = activeKey;
    if (key == null) {
      return this;
    }

    final draft = drafts[key];
    if (draft == null) {
      return this;
    }

    return upsert(draft.copyWith(document: document));
  }

  CanvasWorkspace renameDraft(String key, String graphName) {
    final draft = drafts[key];
    final nextGraphName = graphName.trim();
    if (draft == null || nextGraphName.isEmpty) {
      return this;
    }

    final title = draft.assetName.trim().isEmpty
        ? nextGraphName
        : '${draft.assetName} / $nextGraphName';
    final updatedDraft = draft.copyWith(
      graphName: nextGraphName,
      document: draft.document.copyWith(
        graph: draft.document.graph.copyWith(
          title: title,
          updatedAt: DateTime.now(),
        ),
      ),
    );

    return upsert(updatedDraft, activateDraft: activeKey == key);
  }

  CanvasWorkspace removeDraft(String key) {
    if (!drafts.containsKey(key)) {
      return this;
    }

    final updatedDrafts = Map<String, CanvasDraft>.of(drafts)..remove(key);
    final nextActiveKey = activeKey == key
        ? updatedDrafts.keys.firstOrNull
        : activeKey;

    return CanvasWorkspace(activeKey: nextActiveKey, drafts: updatedDrafts);
  }

  CanvasWorkspace copyWith({
    String? activeKey,
    Map<String, CanvasDraft>? drafts,
  }) {
    final nextDrafts = drafts ?? this.drafts;
    final nextActiveKey = activeKey ?? this.activeKey;

    return CanvasWorkspace(
      activeKey: nextActiveKey != null && nextDrafts.containsKey(nextActiveKey)
          ? nextActiveKey
          : nextDrafts.keys.firstOrNull,
      drafts: nextDrafts,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': 1,
      'activeKey': activeKey,
      'drafts': orderedDrafts.map((draft) => draft.toJson()).toList(),
    };
  }
}

String canvasDraftKey({required String assetPath, required String graphName}) {
  final normalizedAsset = assetPath.trim().isEmpty
      ? 'unknown_asset'
      : assetPath;
  final normalizedGraph = graphName.trim().isEmpty ? '全部执行线' : graphName;

  return '$normalizedAsset::$normalizedGraph';
}
