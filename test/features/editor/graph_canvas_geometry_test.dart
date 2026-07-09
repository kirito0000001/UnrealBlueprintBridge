import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_node.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_pin.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_viewport.dart';
import 'package:unreal_blueprint_bridge/features/editor/canvas/graph_canvas_geometry.dart';

void main() {
  test('GraphCanvas avoids global pressed node state for click feedback', () {
    final source = File(
      'lib/features/editor/canvas/graph_canvas.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('_pressedNodeId')));
    expect(source, isNot(contains('_nodePressTimer')));
    expect(source, isNot(contains('final pressT = pressed ?')));
    expect(source, isNot(contains("ValueKey('selected-node-")));
    expect(source, contains('scale: selected ? 1.018 : 1'));
  });

  test('GraphCanvasGeometry converts between world and screen coordinates', () {
    const viewport = GraphViewport(offsetX: 24, offsetY: -12, zoom: 1.5);
    const world = GraphCanvasPoint(100, 80);

    final screen = GraphCanvasGeometry.worldToScreen(world, viewport);
    final roundTrip = GraphCanvasGeometry.screenToWorld(screen, viewport);

    expect(screen.x, 174);
    expect(screen.y, 108);
    expect(roundTrip.x, world.x);
    expect(roundTrip.y, world.y);
  });

  test('GraphCanvasGeometry places input and output pins on node edges', () {
    const node = GraphNode(
      id: 'node_branch',
      nodeType: 'Branch',
      title: 'Branch',
      description: '',
      position: GraphNodePosition(x: 200, y: 100),
      size: GraphNodeSize(width: 240, height: 150),
      pins: [
        GraphPin(
          id: 'exec_in',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'condition',
          direction: GraphPinDirection.input,
          title: 'Condition',
          dataType: 'bool',
        ),
        GraphPin(
          id: 'true',
          direction: GraphPinDirection.output,
          title: 'True',
          dataType: 'exec',
        ),
      ],
    );

    final execIn = GraphCanvasGeometry.pinWorldPosition(node, 'exec_in');
    final condition = GraphCanvasGeometry.pinWorldPosition(node, 'condition');
    final trueOut = GraphCanvasGeometry.pinWorldPosition(node, 'true');

    expect(execIn, const GraphCanvasPoint(221, 226.5));
    expect(condition, const GraphCanvasPoint(219.5, 256.5));
    expect(trueOut, const GraphCanvasPoint(419, 226.5));
  });

  test('GraphCanvasGeometry expands node size to fit pin rows and labels', () {
    const node = GraphNode(
      id: 'node_get_is_door_open',
      nodeType: 'VariableGet',
      title: 'Get: IsDoorOpen',
      description: '读取门是否已经打开。',
      position: GraphNodePosition(x: 100, y: 80),
      size: GraphNodeSize(width: 240, height: 145),
      pins: [
        GraphPin(
          id: 'target',
          direction: GraphPinDirection.input,
          title: 'Target',
          dataType: 'Actor',
        ),
        GraphPin(
          id: 'self',
          direction: GraphPinDirection.input,
          title: 'Self',
          dataType: 'object',
        ),
        GraphPin(
          id: 'is_door_open',
          direction: GraphPinDirection.output,
          title: 'Is Door Open',
          dataType: 'bool',
        ),
      ],
    );

    final effectiveSize = GraphCanvasGeometry.effectiveNodeSize(node);

    expect(effectiveSize.width, greaterThanOrEqualTo(300));
    expect(effectiveSize.height, greaterThanOrEqualTo(181));
  });

  test('GraphCanvasGeometry places output pins on the effective node edge', () {
    const node = GraphNode(
      id: 'node_get_is_door_open',
      nodeType: 'VariableGet',
      title: 'Get: IsDoorOpen',
      description: '读取门是否已经打开。',
      position: GraphNodePosition(x: 100, y: 80),
      size: GraphNodeSize(width: 240, height: 145),
      pins: [
        GraphPin(
          id: 'target',
          direction: GraphPinDirection.input,
          title: 'Target',
          dataType: 'Actor',
        ),
        GraphPin(
          id: 'is_door_open',
          direction: GraphPinDirection.output,
          title: 'Is Door Open',
          dataType: 'bool',
        ),
      ],
    );

    final effectiveSize = GraphCanvasGeometry.effectiveNodeSize(node);
    final output = GraphCanvasGeometry.pinWorldPosition(node, 'is_door_open');

    expect(
      output.x,
      node.position.x +
          effectiveSize.width -
          GraphCanvasGeometry.nodeContentPaddingX -
          GraphCanvasGeometry.pinSocketDataSize / 2,
    );
  });

  test('GraphCanvasGeometry hit tests pins with touch friendly radius', () {
    const viewport = GraphViewport(offsetX: 0, offsetY: 0, zoom: 1);
    const node = GraphNode(
      id: 'node_branch',
      nodeType: 'Branch',
      title: 'Branch',
      description: '',
      position: GraphNodePosition(x: 200, y: 100),
      size: GraphNodeSize(width: 240, height: 150),
      pins: [
        GraphPin(
          id: 'condition',
          direction: GraphPinDirection.input,
          title: 'Condition',
          dataType: 'bool',
        ),
      ],
    );

    final pinPosition = GraphCanvasGeometry.pinWorldPosition(node, 'condition');
    final hit = GraphCanvasGeometry.hitTestPin(
      nodes: [node],
      screenPoint: GraphCanvasPoint(pinPosition.x + 14, pinPosition.y + 2),
      viewport: viewport,
    );

    expect(hit?.node.id, 'node_branch');
    expect(hit?.pin.id, 'condition');
  });

  test(
    'GraphCanvasGeometry picks a compatible node pin when dropping on node',
    () {
      const outputNode = GraphNode(
        id: 'source',
        nodeType: 'VariableGet',
        title: 'Get: IsDoorOpen',
        description: '',
        position: GraphNodePosition(x: 100, y: 100),
        size: GraphNodeSize(width: 300, height: 160),
        pins: [
          GraphPin(
            id: 'value',
            direction: GraphPinDirection.output,
            title: 'Is Door Open',
            dataType: 'bool',
          ),
        ],
      );
      const branchNode = GraphNode(
        id: 'branch',
        nodeType: 'Branch',
        title: 'Branch',
        description: '',
        position: GraphNodePosition(x: 500, y: 100),
        size: GraphNodeSize(width: 260, height: 190),
        pins: [
          GraphPin(
            id: 'exec',
            direction: GraphPinDirection.input,
            title: 'Exec',
            dataType: 'exec',
          ),
          GraphPin(
            id: 'condition',
            direction: GraphPinDirection.input,
            title: 'Condition',
            dataType: 'bool',
          ),
        ],
      );
      final start = GraphCanvasPinHit(
        node: outputNode,
        pin: outputNode.pins[0],
      );

      final target = GraphCanvasGeometry.compatiblePinOnNode(
        source: start,
        targetNode: branchNode,
      );

      expect(target?.pin.id, 'condition');
    },
  );

  test('GraphCanvasGeometry rejects incompatible and same-node links', () {
    const node = GraphNode(
      id: 'branch',
      nodeType: 'Branch',
      title: 'Branch',
      description: '',
      position: GraphNodePosition(x: 500, y: 100),
      size: GraphNodeSize(width: 260, height: 190),
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'condition',
          direction: GraphPinDirection.input,
          title: 'Condition',
          dataType: 'bool',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.output,
          title: 'Value',
          dataType: 'bool',
        ),
      ],
    );

    expect(
      GraphCanvasGeometry.canConnectPins(
        GraphCanvasPinHit(node: node, pin: node.pins[0]),
        GraphCanvasPinHit(node: node, pin: node.pins[2]),
      ),
      isFalse,
    );
    expect(
      GraphCanvasGeometry.canConnectPins(
        GraphCanvasPinHit(node: node, pin: node.pins[1]),
        GraphCanvasPinHit(node: node, pin: node.pins[0]),
      ),
      isFalse,
    );
  });

  test('GraphCanvasGeometry lets single-sided pin rows use the full width', () {
    const output = GraphPin(
      id: 'is_door_open',
      direction: GraphPinDirection.output,
      title: 'Is Door Open',
      dataType: 'bool',
    );
    const input = GraphPin(
      id: 'target',
      direction: GraphPinDirection.input,
      title: 'Target',
      dataType: 'Actor',
    );

    expect(
      GraphCanvasGeometry.pinRowCanUseFullWidth(input: null, output: output),
      isTrue,
    );
    expect(
      GraphCanvasGeometry.pinRowCanUseFullWidth(input: input, output: output),
      isFalse,
    );
  });

  test('GraphCanvasGeometry selects pin wheel pins by half-ring direction', () {
    const node = GraphNode(
      id: 'node_branch',
      nodeType: 'Branch',
      title: 'Branch',
      description: '',
      position: GraphNodePosition(x: 200, y: 100),
      size: GraphNodeSize(width: 240, height: 150),
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'condition',
          direction: GraphPinDirection.input,
          title: 'Condition',
          dataType: 'bool',
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
    );
    const center = GraphCanvasPoint(320, 220);

    final topLeft = GraphCanvasGeometry.pinWheelPinAt(
      node: node,
      center: center,
      screenPoint: const GraphCanvasPoint(250, 155),
    );
    final bottomLeft = GraphCanvasGeometry.pinWheelPinAt(
      node: node,
      center: center,
      screenPoint: const GraphCanvasPoint(250, 285),
    );
    final topRight = GraphCanvasGeometry.pinWheelPinAt(
      node: node,
      center: center,
      screenPoint: const GraphCanvasPoint(390, 155),
    );
    final bottomRight = GraphCanvasGeometry.pinWheelPinAt(
      node: node,
      center: center,
      screenPoint: const GraphCanvasPoint(390, 285),
    );
    final centerHole = GraphCanvasGeometry.pinWheelPinAt(
      node: node,
      center: center,
      screenPoint: const GraphCanvasPoint(320, 220),
    );

    expect(topLeft?.id, 'exec');
    expect(bottomLeft?.id, 'condition');
    expect(topRight?.id, 'true');
    expect(bottomRight?.id, 'false');
    expect(centerHole, isNull);
  });

  test('GraphCanvasGeometry hit tests topmost node first', () {
    const viewport = GraphViewport(offsetX: 0, offsetY: 0, zoom: 1);
    const nodes = [
      GraphNode(
        id: 'back',
        nodeType: 'Generic',
        title: 'Back',
        description: '',
        position: GraphNodePosition(x: 100, y: 100),
        size: GraphNodeSize(width: 240, height: 140),
        pins: [],
      ),
      GraphNode(
        id: 'front',
        nodeType: 'Generic',
        title: 'Front',
        description: '',
        position: GraphNodePosition(x: 120, y: 120),
        size: GraphNodeSize(width: 240, height: 140),
        pins: [],
      ),
    ];

    final hit = GraphCanvasGeometry.hitTestNode(
      nodes: nodes,
      screenPoint: const GraphCanvasPoint(130, 130),
      viewport: viewport,
    );

    expect(hit?.id, 'front');
  });

  test('GraphCanvasGeometry keeps dragged node anchored under pointer', () {
    const viewport = GraphViewport(offsetX: 20, offsetY: 30, zoom: 1.25);
    const grabOffset = GraphCanvasPoint(80, 34);

    final nextPosition = GraphCanvasGeometry.nodePositionFromDrag(
      pointerScreenPoint: const GraphCanvasPoint(270, 164),
      viewport: viewport,
      grabOffsetWorld: grabOffset,
    );

    expect(nextPosition.x, 120);
    expect(nextPosition.y, 73.2);
  });

  test(
    'GraphCanvasGeometry pans from the original viewport and drag start',
    () {
      const viewport = GraphViewport(offsetX: 80, offsetY: 72, zoom: 0.95);

      final nextViewport = GraphCanvasGeometry.viewportFromPan(
        startViewport: viewport,
        startScreenPoint: const GraphCanvasPoint(200, 180),
        currentScreenPoint: const GraphCanvasPoint(260, 150),
      );

      expect(nextViewport.offsetX, 140);
      expect(nextViewport.offsetY, 42);
      expect(nextViewport.zoom, 0.95);
    },
  );

  test('GraphCanvasGeometry creates a padded comment frame around nodes', () {
    const nodes = [
      GraphNode(
        id: 'event',
        nodeType: 'Event',
        title: '事件',
        description: '',
        position: GraphNodePosition(x: 120, y: 80),
        size: GraphNodeSize(width: 260, height: 150),
        pins: [],
      ),
      GraphNode(
        id: 'branch',
        nodeType: 'Branch',
        title: '分支',
        description: '',
        position: GraphNodePosition(x: 480, y: 210),
        size: GraphNodeSize(width: 280, height: 180),
        pins: [],
      ),
    ];

    final frame = GraphCanvasGeometry.commentFrameForNodes(nodes);

    expect(frame.left, 72);
    expect(frame.top, 32);
    expect(frame.right, 808);
    expect(frame.bottom, 438);
  });

  test('GraphCanvasGeometry finds nodes fully contained by a comment', () {
    const comment = GraphNode(
      id: 'comment',
      nodeType: 'Comment',
      title: '注释',
      description: '',
      position: GraphNodePosition(x: 80, y: 40),
      size: GraphNodeSize(width: 760, height: 430),
      pins: [],
    );
    const inside = GraphNode(
      id: 'inside',
      nodeType: 'Branch',
      title: '内部节点',
      description: '',
      position: GraphNodePosition(x: 140, y: 120),
      size: GraphNodeSize(width: 260, height: 160),
      pins: [],
    );
    const partial = GraphNode(
      id: 'partial',
      nodeType: 'FunctionCall',
      title: '压边节点',
      description: '',
      position: GraphNodePosition(x: 760, y: 390),
      size: GraphNodeSize(width: 260, height: 160),
      pins: [],
    );

    final containedIds = GraphCanvasGeometry.nodeIdsInsideComment(
      comment: comment,
      nodes: [comment, inside, partial],
    );

    expect(containedIds, {'inside'});
  });

  test(
    'GraphCanvasGeometry prefers regular nodes over containing comments',
    () {
      const viewport = GraphViewport(offsetX: 0, offsetY: 0, zoom: 1);
      const comment = GraphNode(
        id: 'comment',
        nodeType: 'Comment',
        title: '注释',
        description: '',
        position: GraphNodePosition(x: 80, y: 40),
        size: GraphNodeSize(width: 760, height: 430),
        pins: [],
      );
      const innerNode = GraphNode(
        id: 'inner',
        nodeType: 'Branch',
        title: '内部节点',
        description: '',
        position: GraphNodePosition(x: 140, y: 120),
        size: GraphNodeSize(width: 260, height: 160),
        pins: [],
      );

      final hit = GraphCanvasGeometry.hitTestNode(
        nodes: [innerNode, comment],
        screenPoint: const GraphCanvasPoint(180, 150),
        viewport: viewport,
      );

      expect(hit?.id, 'inner');
    },
  );

  test('GraphCanvasGeometry detects and resizes comment handles', () {
    const viewport = GraphViewport(offsetX: 0, offsetY: 0, zoom: 1);
    const comment = GraphNode(
      id: 'comment',
      nodeType: 'Comment',
      title: '注释',
      description: '',
      position: GraphNodePosition(x: 80, y: 40),
      size: GraphNodeSize(width: 520, height: 300),
      pins: [],
    );

    final hit = GraphCanvasGeometry.hitTestCommentResizeHandle(
      nodes: [comment],
      selectedNodeIds: {'comment'},
      screenPoint: const GraphCanvasPoint(598, 338),
      viewport: viewport,
    );

    expect(hit?.node.id, 'comment');
    expect(hit?.handle, GraphCommentResizeHandle.bottomRight);

    final resized = GraphCanvasGeometry.resizeCommentFromDrag(
      comment: comment,
      handle: GraphCommentResizeHandle.bottomRight,
      startWorldPoint: const GraphCanvasPoint(600, 340),
      currentWorldPoint: const GraphCanvasPoint(690, 385),
    );

    expect(resized.position.x, 80);
    expect(resized.position.y, 40);
    expect(resized.size.width, 610);
    expect(resized.size.height, 345);
  });

  test('GraphCanvasGeometry uses a larger comment corner touch target', () {
    const viewport = GraphViewport(offsetX: 0, offsetY: 0, zoom: 1);
    const comment = GraphNode(
      id: 'comment',
      nodeType: 'Comment',
      title: '注释',
      description: '',
      position: GraphNodePosition(x: 80, y: 40),
      size: GraphNodeSize(width: 520, height: 300),
      pins: [],
    );

    final hit = GraphCanvasGeometry.hitTestCommentResizeHandle(
      nodes: [comment],
      selectedNodeIds: {'comment'},
      screenPoint: const GraphCanvasPoint(575, 315),
      viewport: viewport,
    );

    expect(hit?.node.id, 'comment');
    expect(hit?.handle, GraphCommentResizeHandle.bottomRight);
  });

  test(
    'GraphCanvasGeometry lets comment corner handles extend outside frame',
    () {
      const viewport = GraphViewport(offsetX: 0, offsetY: 0, zoom: 1);
      const comment = GraphNode(
        id: 'comment',
        nodeType: 'Comment',
        title: '注释',
        description: '',
        position: GraphNodePosition(x: 80, y: 40),
        size: GraphNodeSize(width: 520, height: 300),
        pins: [],
      );

      final hit = GraphCanvasGeometry.hitTestCommentResizeHandle(
        nodes: [comment],
        selectedNodeIds: {'comment'},
        screenPoint: const GraphCanvasPoint(625, 365),
        viewport: viewport,
      );

      expect(hit?.node.id, 'comment');
      expect(hit?.handle, GraphCommentResizeHandle.bottomRight);
    },
  );

  test(
    'GraphCanvasGeometry lets comment corner handles reach a wide outside area',
    () {
      const viewport = GraphViewport(offsetX: 0, offsetY: 0, zoom: 1);
      const comment = GraphNode(
        id: 'comment',
        nodeType: 'Comment',
        title: '注释',
        description: '',
        position: GraphNodePosition(x: 80, y: 40),
        size: GraphNodeSize(width: 520, height: 300),
        pins: [],
      );

      final hit = GraphCanvasGeometry.hitTestCommentResizeHandle(
        nodes: [comment],
        selectedNodeIds: {'comment'},
        screenPoint: const GraphCanvasPoint(650, 390),
        viewport: viewport,
      );

      expect(hit?.node.id, 'comment');
      expect(hit?.handle, GraphCommentResizeHandle.bottomRight);
    },
  );

  test(
    'GraphCanvasGeometry lets comment side handles extend outside frame',
    () {
      const viewport = GraphViewport(offsetX: 0, offsetY: 0, zoom: 1);
      const comment = GraphNode(
        id: 'comment',
        nodeType: 'Comment',
        title: '注释',
        description: '',
        position: GraphNodePosition(x: 80, y: 40),
        size: GraphNodeSize(width: 520, height: 300),
        pins: [],
      );

      final hit = GraphCanvasGeometry.hitTestCommentResizeHandle(
        nodes: [comment],
        selectedNodeIds: {'comment'},
        screenPoint: const GraphCanvasPoint(65, 180),
        viewport: viewport,
      );

      expect(hit?.node.id, 'comment');
      expect(hit?.handle, GraphCommentResizeHandle.left);
    },
  );

  test('GraphCanvasGeometry resizes comment from the left edge', () {
    const comment = GraphNode(
      id: 'comment',
      nodeType: 'Comment',
      title: '注释',
      description: '',
      position: GraphNodePosition(x: 80, y: 40),
      size: GraphNodeSize(width: 520, height: 300),
      pins: [],
    );

    final resized = GraphCanvasGeometry.resizeCommentFromDrag(
      comment: comment,
      handle: GraphCommentResizeHandle.left,
      startWorldPoint: const GraphCanvasPoint(80, 180),
      currentWorldPoint: const GraphCanvasPoint(120, 180),
    );

    expect(resized.position.x, 120);
    expect(resized.position.y, 40);
    expect(resized.size.width, 480);
    expect(resized.size.height, 300);
  });
}
