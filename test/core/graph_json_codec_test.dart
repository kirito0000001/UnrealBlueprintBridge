import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_document.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_event.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_function.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_link.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_node.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_pin.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_variable.dart';
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
        blueprintType: 'ActorBlueprint',
        parentClass: 'Actor',
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
            GraphPin(
              id: 'condition',
              direction: GraphPinDirection.input,
              title: 'Condition',
              dataType: 'bool',
              defaultValue: 'true',
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
      variables: const [
        GraphVariable(
          id: 'var_is_door_open',
          name: 'IsDoorOpen',
          dataType: 'bool',
          defaultValue: 'false',
          category: 'Door',
          description: '门是否打开。',
          replication: 'Replicated',
          exportSource: 'GetTheMeaning',
          exportPath: '/Game/BP_Door.BP_Door_C:IsDoorOpen',
          exportDisplayName: '门是否打开',
        ),
      ],
      functions: const [
        GraphFunction(
          id: 'func_open_door',
          name: 'OpenDoor',
          category: 'Door',
          description: '打开门并返回是否成功。',
          inputs: [
            GraphFunctionParameter(
              id: 'target',
              name: 'Target',
              dataType: 'Actor',
              description: '门 Actor。',
            ),
          ],
          outputs: [
            GraphFunctionParameter(
              id: 'success',
              name: 'Success',
              dataType: 'bool',
              defaultValue: 'false',
            ),
          ],
          exportSource: 'GetTheMeaning',
          exportPath: '/Game/BP_Door.BP_Door_C:OpenDoor',
          exportDisplayName: '打开门',
        ),
      ],
      events: const [
        GraphEvent(
          id: 'event_toggle_door',
          name: '请求切换门',
          category: 'Door',
          description: '玩家交互后请求切换门状态。',
          eventType: 'CustomEvent',
          replicates: true,
          rpcType: 'RunOnServer',
          reliability: 'Reliable',
          exportSource: 'GetTheMeaning',
          exportPath: '/Game/BP_Door.BP_Door_C:请求切换门',
          exportDisplayName: '请求切换门',
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
    expect(decoded.graph.blueprintType, 'ActorBlueprint');
    expect(decoded.graph.parentClass, 'Actor');
    expect(decoded.nodes, hasLength(2));
    expect(decoded.nodes.first.pins.single.allowMultipleLinks, isTrue);
    expect(decoded.nodes.last.pins.last.defaultValue, 'true');
    expect(decoded.variables, hasLength(1));
    expect(decoded.variables.single.id, 'var_is_door_open');
    expect(decoded.variables.single.name, 'IsDoorOpen');
    expect(decoded.variables.single.dataType, 'bool');
    expect(decoded.variables.single.defaultValue, 'false');
    expect(decoded.variables.single.replication, 'Replicated');
    expect(decoded.variables.single.exportSource, 'GetTheMeaning');
    expect(
      decoded.variables.single.exportPath,
      '/Game/BP_Door.BP_Door_C:IsDoorOpen',
    );
    expect(decoded.variables.single.exportDisplayName, '门是否打开');
    expect(decoded.functions, hasLength(1));
    expect(decoded.functions.single.id, 'func_open_door');
    expect(decoded.functions.single.name, 'OpenDoor');
    expect(decoded.functions.single.category, 'Door');
    expect(decoded.functions.single.inputs.single.name, 'Target');
    expect(decoded.functions.single.inputs.single.dataType, 'Actor');
    expect(decoded.functions.single.outputs.single.name, 'Success');
    expect(decoded.functions.single.outputs.single.dataType, 'bool');
    expect(decoded.functions.single.exportDisplayName, '打开门');
    expect(decoded.events, hasLength(1));
    expect(decoded.events.single.id, 'event_toggle_door');
    expect(decoded.events.single.name, '请求切换门');
    expect(decoded.events.single.category, 'Door');
    expect(decoded.events.single.eventType, 'CustomEvent');
    expect(decoded.events.single.replicates, isTrue);
    expect(decoded.events.single.rpcType, 'RunOnServer');
    expect(decoded.events.single.reliability, 'Reliable');
    expect(decoded.events.single.exportDisplayName, '请求切换门');
    expect(decoded.links, hasLength(1));
    expect(decoded.links.single.fromNodeId, 'node_event_login');
  });
}
