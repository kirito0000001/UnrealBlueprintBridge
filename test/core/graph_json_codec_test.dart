import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_document.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_link.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_node.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_pin.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_viewport.dart';
import 'package:unreal_blueprint_bridge/core/services/graph_json_codec.dart';

void main() {
  test('GraphJsonCodec preserves graph metadata, nodes, pins, and links', () {
    final document = GraphDocument(
      schemaVersion: 1,
      graph: GraphMetadata(
        id: 'graph_login',
        title: 'Login Flow',
        description: '登录流程草稿',
        createdAt: DateTime.parse('2026-07-07T12:00:00+08:00'),
        updatedAt: DateTime.parse('2026-07-07T12:20:00+08:00'),
        viewport: const GraphViewport(offsetX: 12, offsetY: -8, zoom: 1.25),
      ),
      nodes: const [
        GraphNode(
          id: 'node_event_login',
          nodeType: 'Event',
          title: 'Login Request',
          description: '玩家请求登录。',
          position: GraphNodePosition(x: 120, y: 80),
          size: GraphNodeSize(width: 240, height: 140),
          pins: [
            GraphPin(
              id: 'exec_out',
              direction: GraphPinDirection.output,
              title: 'Then',
              dataType: 'exec',
              allowMultipleLinks: true,
            ),
          ],
        ),
        GraphNode(
          id: 'node_check_user',
          nodeType: 'Function',
          title: 'Check User',
          description: '验证用户信息。',
          position: GraphNodePosition(x: 420, y: 80),
          size: GraphNodeSize(width: 240, height: 140),
          pins: [
            GraphPin(
              id: 'exec_in',
              direction: GraphPinDirection.input,
              title: 'Exec',
              dataType: 'exec',
            ),
          ],
        ),
      ],
      links: const [
        GraphLink(
          id: 'link_001',
          fromNodeId: 'node_event_login',
          fromPinId: 'exec_out',
          toNodeId: 'node_check_user',
          toPinId: 'exec_in',
          title: '',
          description: '',
          linkType: 'exec',
        ),
      ],
    );

    const codec = GraphJsonCodec();

    final encoded = codec.encode(document);
    final decoded = codec.decode(encoded);

    expect(decoded.schemaVersion, 1);
    expect(decoded.graph.title, 'Login Flow');
    expect(decoded.graph.description, '登录流程草稿');
    expect(decoded.graph.viewport.zoom, 1.25);
    expect(decoded.nodes, hasLength(2));
    expect(decoded.nodes.first.pins.single.allowMultipleLinks, isTrue);
    expect(decoded.links, hasLength(1));
    expect(decoded.links.single.fromNodeId, 'node_event_login');
  });
}
