import 'dart:convert';
import 'dart:io';

import '../models/graph_document.dart';
import '../models/graph_link.dart';
import '../models/graph_node.dart';
import '../models/graph_pin.dart';
import '../models/graph_viewport.dart';
import '../services/graph_json_codec.dart';
import 'canvas_workspace.dart';

class BlueprintBridgeGraphPackageResult {
  const BlueprintBridgeGraphPackageResult({
    required this.available,
    required this.message,
    required this.workspace,
    required this.importedCount,
    required this.warnings,
  });

  final bool available;
  final String message;
  final CanvasWorkspace workspace;
  final int importedCount;
  final List<String> warnings;
}

class BlueprintBridgeGraphPackageWriteResult {
  const BlueprintBridgeGraphPackageWriteResult({
    required this.indexFile,
    required this.graphFiles,
  });

  final File indexFile;
  final List<File> graphFiles;
}

class BlueprintBridgeGraphIndexEntry {
  const BlueprintBridgeGraphIndexEntry({
    required this.assetName,
    required this.assetPath,
    required this.graphName,
    required this.file,
    required this.title,
  });

  factory BlueprintBridgeGraphIndexEntry.fromJson(Map<String, Object?> json) {
    final title = json['title'] as String? ?? '';
    final graphName =
        json['graphName'] as String? ?? _graphNameFromTitle(title);
    final assetPath = json['assetPath'] as String? ?? '';

    return BlueprintBridgeGraphIndexEntry(
      assetName: json['assetName'] as String? ?? _assetNameFromTitle(title),
      assetPath: assetPath,
      graphName: graphName.isEmpty ? '全部执行线' : graphName,
      file: json['file'] as String? ?? '',
      title: title,
    );
  }

  final String assetName;
  final String assetPath;
  final String graphName;
  final String file;
  final String title;

  static String _assetNameFromTitle(String title) {
    final parts = title.split('/');
    return parts.first.trim().isEmpty ? 'GraphPackage' : parts.first.trim();
  }

  static String _graphNameFromTitle(String title) {
    final parts = title.split('/');
    if (parts.length < 2) {
      return title.trim();
    }

    return parts.last.trim();
  }
}

class BlueprintBridgeGraphPackageService {
  const BlueprintBridgeGraphPackageService();

  Future<BlueprintBridgeGraphPackageWriteResult> writeExamplePackage(
    Directory root,
  ) async {
    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    final graphsDirectory = Directory(
      '${root.path}${Platform.pathSeparator}Graphs',
    );
    if (!await graphsDirectory.exists()) {
      await graphsDirectory.create(recursive: true);
    }

    final graphFile = File(
      '${graphsDirectory.path}${Platform.pathSeparator}ExampleBlueprint_ExampleFlow.json',
    );
    final indexFile = File(
      '${root.path}${Platform.pathSeparator}GraphIndex.json',
    );

    const codec = GraphJsonCodec();
    await graphFile.writeAsString(codec.encode(_buildExampleDocument()));

    const encoder = JsonEncoder.withIndent('  ');
    await indexFile.writeAsString(
      encoder.convert(<String, Object?>{
        'schemaVersion': 1,
        'graphs': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'example_blueprint_example_flow',
            'title': 'ExampleBlueprint / ExampleFlow',
            'assetName': 'ExampleBlueprint',
            'assetPath':
                '/Game/BlueprintBridge/Examples/ExampleBlueprint.ExampleBlueprint',
            'graphName': 'ExampleFlow',
            'source': 'app-template',
            'purpose': 'example',
            'file': 'Graphs/ExampleBlueprint_ExampleFlow.json',
          },
        ],
      }),
    );

    return BlueprintBridgeGraphPackageWriteResult(
      indexFile: indexFile,
      graphFiles: <File>[graphFile],
    );
  }

  Future<BlueprintBridgeGraphPackageResult> loadPackage(Directory root) async {
    final indexFile = File(
      '${root.path}${Platform.pathSeparator}GraphIndex.json',
    );
    if (!await indexFile.exists()) {
      return BlueprintBridgeGraphPackageResult(
        available: false,
        message: '没有找到 GraphIndex.json',
        workspace: CanvasWorkspace.empty(),
        importedCount: 0,
        warnings: const <String>[],
      );
    }

    final warnings = <String>[];
    final entries = await _readEntries(indexFile, warnings);
    var workspace = CanvasWorkspace.empty();
    const codec = GraphJsonCodec();

    for (final entry in entries) {
      if (entry.file.trim().isEmpty) {
        warnings.add('${entry.titleOrGraphName} 缺少 file 字段');
        continue;
      }

      final graphFile = File(_resolveRelativePath(root, entry.file));
      if (!await graphFile.exists()) {
        warnings.add('图文件不存在：${entry.file}');
        continue;
      }

      try {
        final document = codec.decode(await graphFile.readAsString());
        final draft = CanvasDraft(
          key: canvasDraftKey(
            assetPath: entry.effectiveAssetPath(graphFile),
            graphName: entry.graphName,
          ),
          assetName: entry.effectiveAssetName,
          assetPath: entry.effectiveAssetPath(graphFile),
          graphName: entry.graphName,
          document: document,
        );
        workspace = workspace.upsert(draft);
      } on FormatException catch (error) {
        warnings.add('图文件格式错误：${entry.file}，${error.message}');
      } on FileSystemException catch (error) {
        warnings.add('图文件读取失败：${entry.file}，${error.message}');
      }
    }

    final importedCount = workspace.drafts.length;
    return BlueprintBridgeGraphPackageResult(
      available: importedCount > 0,
      message: importedCount > 0 ? '已导入 $importedCount 个图包草稿' : '没有导入任何图包草稿',
      workspace: workspace,
      importedCount: importedCount,
      warnings: warnings,
    );
  }

  Future<BlueprintBridgeGraphPackageResult> loadPackageFromIndexFile(
    File indexFile,
  ) async {
    if (!await indexFile.exists()) {
      return BlueprintBridgeGraphPackageResult(
        available: false,
        message: '没有找到 GraphIndex.json',
        workspace: CanvasWorkspace.empty(),
        importedCount: 0,
        warnings: const <String>[],
      );
    }

    return loadPackage(indexFile.parent);
  }

  Future<GraphDocument?> loadOriginalDocumentForDraft({
    required Directory root,
    required CanvasDraft draft,
  }) async {
    final indexFile = File(
      '${root.path}${Platform.pathSeparator}GraphIndex.json',
    );
    if (!await indexFile.exists()) {
      return null;
    }

    final warnings = <String>[];
    final entries = await _readEntries(indexFile, warnings);
    const codec = GraphJsonCodec();

    for (final entry in entries) {
      if (entry.file.trim().isEmpty) {
        continue;
      }

      final graphFile = File(_resolveRelativePath(root, entry.file));
      final key = canvasDraftKey(
        assetPath: entry.effectiveAssetPath(graphFile),
        graphName: entry.graphName,
      );
      final assetAndGraphMatch =
          entry.effectiveAssetPath(graphFile) == draft.assetPath &&
          entry.graphName == draft.graphName;
      if (key != draft.key && !assetAndGraphMatch) {
        continue;
      }
      if (!await graphFile.exists()) {
        return null;
      }

      try {
        return codec.decode(await graphFile.readAsString());
      } on FormatException {
        return null;
      } on FileSystemException {
        return null;
      }
    }

    return null;
  }

  Future<List<BlueprintBridgeGraphIndexEntry>> _readEntries(
    File indexFile,
    List<String> warnings,
  ) async {
    try {
      final decoded = jsonDecode(await indexFile.readAsString());
      if (decoded is! Map<String, Object?>) {
        warnings.add('GraphIndex.json 根节点必须是对象');
        return const <BlueprintBridgeGraphIndexEntry>[];
      }

      final graphsJson = decoded['graphs'];
      if (graphsJson is! List<Object?>) {
        warnings.add('GraphIndex.json 缺少 graphs 数组');
        return const <BlueprintBridgeGraphIndexEntry>[];
      }

      return graphsJson
          .whereType<Map<String, Object?>>()
          .map(BlueprintBridgeGraphIndexEntry.fromJson)
          .toList(growable: false);
    } on FormatException catch (error) {
      warnings.add('GraphIndex.json 格式错误：${error.message}');
      return const <BlueprintBridgeGraphIndexEntry>[];
    } on FileSystemException catch (error) {
      warnings.add('GraphIndex.json 读取失败：${error.message}');
      return const <BlueprintBridgeGraphIndexEntry>[];
    }
  }

  String _resolveRelativePath(Directory root, String relativePath) {
    final normalized = relativePath
        .replaceAll('\\', Platform.pathSeparator)
        .replaceAll('/', Platform.pathSeparator);

    return '${root.path}${Platform.pathSeparator}$normalized';
  }

  GraphDocument _buildExampleDocument() {
    final now = DateTime.now();

    return GraphDocument(
      schemaVersion: GraphDocument.currentSchemaVersion,
      graph: GraphMetadata(
        id: 'example_blueprint_example_flow',
        title: 'ExampleBlueprint / ExampleFlow',
        description: 'BlueprintBridge 图包协议示例：入口、Branch、成功路径、失败路径。',
        createdAt: now,
        updatedAt: now,
        viewport: const GraphViewport(offsetX: 48, offsetY: 48, zoom: 0.9),
      ),
      nodes: const <GraphNode>[
        GraphNode(
          id: 'node_event_start',
          nodeType: 'Event',
          title: 'Event: ExampleStart',
          description: '示例入口节点。真实图包可以替换成函数、事件或 RPC 入口。',
          position: GraphNodePosition(x: 80, y: 140),
          size: GraphNodeSize(width: 260, height: 150),
          pins: <GraphPin>[
            GraphPin(
              id: 'then',
              direction: GraphPinDirection.output,
              title: 'Then',
              dataType: 'exec',
            ),
          ],
        ),
        GraphNode(
          id: 'node_branch_has_data',
          nodeType: 'Branch',
          title: 'Branch: Has Data?',
          description: '示例条件判断。True 和 False 会分别连接到不同路径。',
          position: GraphNodePosition(x: 420, y: 140),
          size: GraphNodeSize(width: 270, height: 170),
          pins: <GraphPin>[
            GraphPin(
              id: 'exec_in',
              direction: GraphPinDirection.input,
              title: 'Exec',
              dataType: 'exec',
            ),
            GraphPin(
              id: 'true',
              direction: GraphPinDirection.output,
              title: 'True',
              dataType: 'exec',
            ),
            GraphPin(
              id: 'false',
              direction: GraphPinDirection.output,
              title: 'False',
              dataType: 'exec',
            ),
          ],
        ),
        GraphNode(
          id: 'node_success',
          nodeType: 'FunctionCall',
          title: 'Call: Build Success Result',
          description: 'True 路径示例节点。这里可以记录调用函数、参数、默认值或说明。',
          position: GraphNodePosition(x: 780, y: 70),
          size: GraphNodeSize(width: 280, height: 150),
          pins: <GraphPin>[
            GraphPin(
              id: 'exec_in',
              direction: GraphPinDirection.input,
              title: 'Exec',
              dataType: 'exec',
            ),
          ],
        ),
        GraphNode(
          id: 'node_failure',
          nodeType: 'FunctionCall',
          title: 'Call: Show Error Message',
          description: 'False 路径示例节点。用于展示失败分支或提示信息。',
          position: GraphNodePosition(x: 780, y: 250),
          size: GraphNodeSize(width: 280, height: 150),
          pins: <GraphPin>[
            GraphPin(
              id: 'exec_in',
              direction: GraphPinDirection.input,
              title: 'Exec',
              dataType: 'exec',
            ),
          ],
        ),
      ],
      links: const <GraphLink>[
        GraphLink(
          id: 'link_start_branch',
          fromNodeId: 'node_event_start',
          fromPinId: 'then',
          toNodeId: 'node_branch_has_data',
          toPinId: 'exec_in',
          title: '',
          description: '',
          linkType: 'exec',
        ),
        GraphLink(
          id: 'link_branch_success',
          fromNodeId: 'node_branch_has_data',
          fromPinId: 'true',
          toNodeId: 'node_success',
          toPinId: 'exec_in',
          title: 'True',
          description: '条件成立时进入成功路径。',
          linkType: 'exec',
        ),
        GraphLink(
          id: 'link_branch_failure',
          fromNodeId: 'node_branch_has_data',
          fromPinId: 'false',
          toNodeId: 'node_failure',
          toPinId: 'exec_in',
          title: 'False',
          description: '条件不成立时进入失败路径。',
          linkType: 'exec',
        ),
      ],
    );
  }
}

extension on BlueprintBridgeGraphIndexEntry {
  String get effectiveAssetName {
    if (assetName.trim().isNotEmpty) {
      return assetName.trim();
    }

    return 'GraphPackage';
  }

  String get titleOrGraphName {
    if (title.trim().isNotEmpty) {
      return title.trim();
    }

    return graphName;
  }

  String effectiveAssetPath(File graphFile) {
    if (assetPath.trim().isNotEmpty) {
      return assetPath.trim();
    }

    return 'graph-package:${graphFile.path}';
  }
}
