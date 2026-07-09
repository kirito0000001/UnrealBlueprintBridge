import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_document.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_node.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_viewport.dart';
import 'package:unreal_blueprint_bridge/core/workspace/canvas_workspace.dart';

void main() {
  test('CanvasWorkspace renames a draft and updates the graph title', () {
    final workspace = CanvasWorkspace.empty().upsert(
      CanvasDraft(
        key: 'door',
        assetName: 'BP_Door',
        assetPath: '/Game/BP_Door.BP_Door',
        graphName: '开关门逻辑',
        document: _document('BP_Door / 开关门逻辑'),
      ),
    );

    final renamed = workspace.renameDraft('door', '门交互开关逻辑');

    expect(renamed.drafts['door']?.graphName, '门交互开关逻辑');
    expect(renamed.drafts['door']?.document.graph.title, 'BP_Door / 门交互开关逻辑');
    expect(renamed.activeKey, 'door');
  });

  test(
    'CanvasWorkspace removes a draft and falls back to another active key',
    () {
      final workspace = CanvasWorkspace.empty()
          .upsert(
            CanvasDraft(
              key: 'door',
              assetName: 'BP_Door',
              assetPath: '/Game/BP_Door.BP_Door',
              graphName: '门交互开关逻辑',
              document: _document('BP_Door / 门交互开关逻辑'),
            ),
          )
          .upsert(
            CanvasDraft(
              key: 'draft',
              assetName: '幻杀图例草稿',
              assetPath: 'draft://幻杀图例草稿',
              graphName: '开关门逻辑',
              document: _document('幻杀图例草稿 / 开关门逻辑'),
            ),
          );

      final removed = workspace.removeDraft('draft');

      expect(removed.drafts.containsKey('draft'), isFalse);
      expect(removed.drafts.containsKey('door'), isTrue);
      expect(removed.activeKey, 'door');
    },
  );
}

GraphDocument _document(String title) {
  final now = DateTime.parse('2026-07-09T12:00:00+08:00');

  return GraphDocument(
    schemaVersion: GraphDocument.currentSchemaVersion,
    graph: GraphMetadata(
      id: title,
      title: title,
      description: '',
      createdAt: now,
      updatedAt: now,
      viewport: const GraphViewport(offsetX: 0, offsetY: 0, zoom: 1),
    ),
    nodes: const <GraphNode>[],
    links: const [],
  );
}
