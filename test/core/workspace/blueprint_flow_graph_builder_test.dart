import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/workspace/blueprint_flow_graph_builder.dart';
import 'package:unreal_blueprint_bridge/core/workspace/blueprint_logic_detail_service.dart';

void main() {
  test(
    'BlueprintFlowGraphBuilder converts control flows to graph document',
    () {
      const builder = BlueprintFlowGraphBuilder();

      final document = builder.build(
        assetName: 'GM_PtoP',
        graphName: 'PlayerLogin',
        flows: const [
          BlueprintControlFlow(
            graphName: 'PlayerLogin',
            fromNodeTitle: 'PlayerLogin',
            toNodeTitle: '分支',
            kind: 'then',
            depth: 0,
          ),
          BlueprintControlFlow(
            graphName: 'PlayerLogin',
            fromNodeTitle: '分支',
            toNodeTitle: '类型转换为 PS_PtoP',
            kind: 'Branch',
            depth: 1,
          ),
          BlueprintControlFlow(
            graphName: 'PlayerLogin',
            fromNodeTitle: '分支',
            toNodeTitle: 'ROC Anyone Login',
            kind: 'Branch',
            depth: 1,
          ),
        ],
      );

      expect(document.graph.title, 'GM_PtoP / PlayerLogin');
      expect(document.nodes.map((node) => node.title), [
        'PlayerLogin',
        '分支',
        '类型转换为 PS_PtoP',
        'ROC Anyone Login',
      ]);
      expect(document.nodes[0].nodeType, 'Event');
      expect(document.nodes[1].nodeType, 'Branch');
      expect(
        document.nodes[2].position.x,
        greaterThan(document.nodes[1].position.x),
      );
      expect(
        document.nodes[2].position.y,
        greaterThan(document.nodes[0].position.y),
      );
      expect(document.links, hasLength(3));
      expect(document.links.first.linkType, 'exec');
      expect(document.links[1].title, 'Branch');
      expect(document.links[1].fromPinId, 'true');
      expect(document.links[2].fromPinId, 'false');
    },
  );

  test('BlueprintFlowGraphBuilder returns an empty graph for empty flows', () {
    const builder = BlueprintFlowGraphBuilder();

    final document = builder.build(
      assetName: 'Card',
      graphName: 'PreConstruct',
      flows: const [],
    );

    expect(document.graph.title, 'Card / PreConstruct');
    expect(document.nodes, isEmpty);
    expect(document.links, isEmpty);
  });

  test('BlueprintFlowGraphBuilder uses stable source title for a slice', () {
    const builder = BlueprintFlowGraphBuilder();

    final first = builder.build(
      assetName: 'GM_MainMode',
      graphName: 'UserLogin',
      flows: const [
        BlueprintControlFlow(
          graphName: 'UserLogin',
          fromNodeTitle: 'UserLogin',
          toNodeTitle: '分支',
          kind: 'then',
          depth: 0,
        ),
      ],
    );
    final second = builder.build(
      assetName: 'GM_MainMode',
      graphName: 'UserLogin',
      flows: const [
        BlueprintControlFlow(
          graphName: 'UserLogin',
          fromNodeTitle: 'UserLogin',
          toNodeTitle: '分支',
          kind: 'then',
          depth: 0,
        ),
      ],
    );

    expect(first.graph.title, 'GM_MainMode / UserLogin');
    expect(second.graph.title, first.graph.title);
  });
}
