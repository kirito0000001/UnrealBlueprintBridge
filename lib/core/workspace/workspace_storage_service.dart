import 'dart:convert';
import 'dart:io';

import '../models/graph_document.dart';
import '../services/graph_json_codec.dart';
import 'canvas_workspace.dart';
import 'get_the_meaning_import_service.dart';
import 'workspace_models.dart';

class WorkspaceStorageService {
  const WorkspaceStorageService({required this.appDataDirectory});

  final Directory appDataDirectory;

  File get appStateFile {
    return File(
      '${appDataDirectory.path}${Platform.pathSeparator}app_state.json',
    );
  }

  File importSummaryFile(String workspaceId) {
    final safeId = _safeFileName(workspaceId);
    return File(
      '${appDataDirectory.path}${Platform.pathSeparator}import_summary_$safeId.json',
    );
  }

  File canvasDocumentFile(String workspaceId) {
    final safeId = _safeFileName(workspaceId);
    return File(
      '${appDataDirectory.path}${Platform.pathSeparator}canvas_document_$safeId.json',
    );
  }

  File canvasWorkspaceFile(String workspaceId) {
    final safeId = _safeFileName(workspaceId);
    return File(
      '${appDataDirectory.path}${Platform.pathSeparator}canvas_workspace_$safeId.json',
    );
  }

  Directory graphExportDirectory(String workspaceId) {
    final safeId = _safeFileName(workspaceId);
    return Directory(
      '${appDataDirectory.path}${Platform.pathSeparator}graph_exports_$safeId',
    );
  }

  Future<BridgeAppState> loadAppState() async {
    final content = await appStateFile.readAsString();
    final json = jsonDecode(content) as Map<String, Object?>;

    return BridgeAppState.fromJson(json);
  }

  Future<BridgeAppState> loadOrCreateInitialState() async {
    if (await appStateFile.exists()) {
      return loadAppState();
    }

    final state = BridgeAppState.sample();
    await saveAppState(state);

    return state;
  }

  Future<void> saveAppState(BridgeAppState state) async {
    if (!await appDataDirectory.exists()) {
      await appDataDirectory.create(recursive: true);
    }

    const encoder = JsonEncoder.withIndent('  ');
    await appStateFile.writeAsString(encoder.convert(state.toJson()));
  }

  Future<GetTheMeaningImportSummary?> loadImportSummary(
    String workspaceId,
  ) async {
    final file = importSummaryFile(workspaceId);
    if (!await file.exists()) {
      return null;
    }

    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, Object?>;

    return GetTheMeaningImportSummary.fromJson(json);
  }

  Future<void> saveImportSummary(
    String workspaceId,
    GetTheMeaningImportSummary summary,
  ) async {
    if (!await appDataDirectory.exists()) {
      await appDataDirectory.create(recursive: true);
    }

    const encoder = JsonEncoder.withIndent('  ');
    await importSummaryFile(
      workspaceId,
    ).writeAsString(encoder.convert(summary.toJson()));
  }

  Future<GraphDocument?> loadCanvasDocument(String workspaceId) async {
    final file = canvasDocumentFile(workspaceId);
    if (!await file.exists()) {
      return null;
    }

    const codec = GraphJsonCodec();
    return codec.decode(await file.readAsString());
  }

  Future<void> saveCanvasDocument(
    String workspaceId,
    GraphDocument document,
  ) async {
    if (!await appDataDirectory.exists()) {
      await appDataDirectory.create(recursive: true);
    }

    const codec = GraphJsonCodec();
    await canvasDocumentFile(workspaceId).writeAsString(codec.encode(document));
  }

  Future<CanvasWorkspace> loadCanvasWorkspace(String workspaceId) async {
    final file = canvasWorkspaceFile(workspaceId);
    if (await file.exists()) {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, Object?>;

      return CanvasWorkspace.fromJson(json);
    }

    final legacyDocument = await loadCanvasDocument(workspaceId);
    if (legacyDocument == null) {
      return CanvasWorkspace.empty();
    }

    final graphName = _graphNameFromTitle(legacyDocument.graph.title);
    final draft = CanvasDraft(
      key: canvasDraftKey(
        assetPath: 'legacy:${legacyDocument.graph.id}',
        graphName: graphName,
      ),
      assetName: _assetNameFromTitle(legacyDocument.graph.title),
      assetPath: 'legacy:${legacyDocument.graph.id}',
      graphName: graphName,
      document: legacyDocument,
    );

    return CanvasWorkspace.empty().upsert(draft);
  }

  Future<void> saveCanvasWorkspace(
    String workspaceId,
    CanvasWorkspace workspace,
  ) async {
    if (!await appDataDirectory.exists()) {
      await appDataDirectory.create(recursive: true);
    }

    const encoder = JsonEncoder.withIndent('  ');
    await canvasWorkspaceFile(
      workspaceId,
    ).writeAsString(encoder.convert(workspace.toJson()));
  }

  Future<File> exportGraphDocument({
    required String workspaceId,
    required String fileName,
    required GraphDocument document,
  }) async {
    final directory = graphExportDirectory(workspaceId);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    const codec = GraphJsonCodec();
    final safeName = _safeJsonFileName(fileName);
    final file = File('${directory.path}${Platform.pathSeparator}$safeName');
    await file.writeAsString(codec.encode(document));

    return file;
  }

  Future<GraphDocument> importGraphDocument(File file) async {
    const codec = GraphJsonCodec();
    return codec.decode(await file.readAsString());
  }

  String _safeFileName(String value) {
    final normalized = value.trim().replaceAll(
      RegExp(r'[^A-Za-z0-9_.-]+'),
      '_',
    );
    if (normalized.isEmpty) {
      return 'workspace';
    }

    return normalized;
  }

  String _safeJsonFileName(String value) {
    final trimmed = value.trim().isEmpty ? 'graph.json' : value.trim();
    final withoutExtension = trimmed.toLowerCase().endsWith('.json')
        ? trimmed.substring(0, trimmed.length - 5)
        : trimmed;
    final normalized = withoutExtension
        .replaceAll(RegExp(r'[<>:"/\\|?*\r\n\t]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final fileName = normalized.isEmpty ? 'graph' : normalized;

    return '$fileName.json';
  }

  String _assetNameFromTitle(String title) {
    final parts = title.split('/');
    return parts.first.trim().isEmpty ? 'Canvas' : parts.first.trim();
  }

  String _graphNameFromTitle(String title) {
    final parts = title.split('/');
    if (parts.length < 2 || parts.last.trim().isEmpty) {
      return '全部执行线';
    }

    return parts.last.trim();
  }
}
