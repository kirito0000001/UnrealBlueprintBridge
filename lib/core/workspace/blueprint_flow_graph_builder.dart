import '../models/graph_document.dart';
import '../models/graph_link.dart';
import '../models/graph_node.dart';
import '../models/graph_pin.dart';
import '../models/graph_viewport.dart';
import 'blueprint_logic_detail_service.dart';

class BlueprintFlowGraphBuilder {
  const BlueprintFlowGraphBuilder();

  GraphDocument build({
    required String assetName,
    required String graphName,
    required List<BlueprintControlFlow> flows,
    String blueprintType = '',
    String parentClass = '',
  }) {
    final now = DateTime.now();
    final normalizedAsset = assetName.trim().isEmpty ? 'Blueprint' : assetName;
    final normalizedGraph = graphName.trim().isEmpty ? 'Flow' : graphName;
    final orderedTitles = _orderedNodeTitles(flows);
    final branchOutputCounts = <String, int>{};

    return GraphDocument(
      schemaVersion: GraphDocument.currentSchemaVersion,
      graph: GraphMetadata(
        id: _safeId('flow_${normalizedAsset}_$normalizedGraph'),
        title: '$normalizedAsset / $normalizedGraph',
        description: '由蓝图执行线预览生成的草稿图。',
        createdAt: now,
        updatedAt: now,
        viewport: const GraphViewport(offsetX: 70, offsetY: 64, zoom: 0.86),
        blueprintType: _normalizedBlueprintType(blueprintType),
        parentClass: parentClass,
      ),
      nodes: [
        for (var index = 0; index < orderedTitles.length; index++)
          _nodeForTitle(
            title: orderedTitles[index],
            index: index,
            depth: _depthForTitle(orderedTitles[index], flows),
            isFirst: index == 0,
            isBranch: _isBranchTitle(orderedTitles[index], flows),
          ),
      ],
      links: [
        for (var index = 0; index < flows.length; index++)
          _linkForFlow(
            flow: flows[index],
            index: index,
            branchOutputCounts: branchOutputCounts,
          ),
      ],
    );
  }

  List<String> _orderedNodeTitles(List<BlueprintControlFlow> flows) {
    final seen = <String>{};
    final titles = <String>[];
    for (final flow in flows) {
      for (final title in [flow.fromNodeTitle, flow.toNodeTitle]) {
        final normalized = _compactNodeTitle(title);
        if (normalized.isNotEmpty && seen.add(normalized)) {
          titles.add(normalized);
        }
      }
    }

    return titles;
  }

  GraphNode _nodeForTitle({
    required String title,
    required int index,
    required int depth,
    required bool isFirst,
    required bool isBranch,
  }) {
    return GraphNode(
      id: _nodeId(title),
      nodeType: isBranch
          ? 'Branch'
          : isFirst
          ? 'Event'
          : 'Function',
      title: title,
      description: isBranch ? '由分支执行线生成。' : '由蓝图执行线生成。',
      position: GraphNodePosition(
        x: 80 + index * 320,
        y: 90 + depth.clamp(0, 8) * 120,
      ),
      size: GraphNodeSize.standard(),
      pins: [
        if (!isFirst)
          const GraphPin(
            id: 'exec_in',
            direction: GraphPinDirection.input,
            title: 'Exec',
            dataType: 'exec',
          ),
        if (isBranch) ...const [
          GraphPin(
            id: 'true',
            direction: GraphPinDirection.output,
            title: 'True',
            dataType: 'exec',
            allowMultipleLinks: true,
          ),
          GraphPin(
            id: 'false',
            direction: GraphPinDirection.output,
            title: 'False',
            dataType: 'exec',
            allowMultipleLinks: true,
          ),
        ] else
          const GraphPin(
            id: 'then',
            direction: GraphPinDirection.output,
            title: 'Then',
            dataType: 'exec',
            allowMultipleLinks: true,
          ),
      ],
    );
  }

  GraphLink _linkForFlow({
    required BlueprintControlFlow flow,
    required int index,
    required Map<String, int> branchOutputCounts,
  }) {
    final fromTitle = _compactNodeTitle(flow.fromNodeTitle);
    final toTitle = _compactNodeTitle(flow.toNodeTitle);
    final kind = flow.kind.trim();
    final isBranch = kind == 'Branch';
    final fromPinId = isBranch
        ? _nextBranchPin(fromTitle, branchOutputCounts)
        : 'then';

    return GraphLink(
      id: _safeId('link_${index}_${fromTitle}_$toTitle'),
      fromNodeId: _nodeId(fromTitle),
      fromPinId: fromPinId,
      toNodeId: _nodeId(toTitle),
      toPinId: 'exec_in',
      title: kind == 'then' ? '' : kind,
      description: '$fromTitle -> $toTitle',
      linkType: 'exec',
    );
  }

  String _nextBranchPin(String fromTitle, Map<String, int> branchOutputCounts) {
    final nextIndex = branchOutputCounts.update(
      fromTitle,
      (value) => value + 1,
      ifAbsent: () => 0,
    );
    return nextIndex == 0 ? 'true' : 'false';
  }

  bool _isBranchTitle(String title, List<BlueprintControlFlow> flows) {
    return flows.any(
      (flow) =>
          _compactNodeTitle(flow.fromNodeTitle) == title &&
          flow.kind.trim() == 'Branch',
    );
  }

  int _depthForTitle(String title, List<BlueprintControlFlow> flows) {
    for (final flow in flows) {
      if (_compactNodeTitle(flow.fromNodeTitle) == title) {
        return flow.depth;
      }
      if (_compactNodeTitle(flow.toNodeTitle) == title) {
        return flow.depth + 1;
      }
    }

    return 0;
  }

  String _nodeId(String title) {
    return _safeId('node_$title');
  }

  String _compactNodeTitle(String title) {
    return title
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join(' / ');
  }

  String _safeId(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_\u4e00-\u9fa5]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (normalized.isEmpty) {
      return 'node';
    }

    return normalized;
  }

  String _normalizedBlueprintType(String value) {
    return switch (value.trim()) {
      'Blueprint' => 'ActorBlueprint',
      'WidgetBlueprint' => 'WidgetBlueprint',
      final other when other.isNotEmpty => other,
      _ => '',
    };
  }
}
