import '../../core/models/graph_document.dart';
import '../../core/models/graph_link.dart';
import '../../core/models/graph_node.dart';
import '../../core/models/graph_pin.dart';
import '../../core/models/graph_viewport.dart';

GraphDocument createSampleGraphDocument() {
  final now = DateTime.now();

  return GraphDocument(
    schemaVersion: GraphDocument.currentSchemaVersion,
    graph: GraphMetadata(
      id: 'bp_door_toggle_flow',
      title: 'BP_Door / 开关门逻辑',
      description: 'Actor 蓝图中的门开关流程草稿，可以拖拽节点、缩放和平移。',
      createdAt: now,
      updatedAt: now,
      blueprintType: 'ActorBlueprint',
      parentClass: 'Actor',
      viewport: const GraphViewport(offsetX: 80, offsetY: 72, zoom: 1),
    ),
    nodes: const [
      GraphNode(
        id: 'event_login',
        nodeType: 'Event',
        title: '事件：请求登录',
        description: '玩家点击登录按钮后进入服务器校验。',
        position: GraphNodePosition(x: 40, y: 80),
        size: GraphNodeSize(width: 270, height: 190),
        pins: [
          GraphPin(
            id: 'then',
            direction: GraphPinDirection.output,
            title: 'Then',
            dataType: 'exec',
            allowMultipleLinks: true,
          ),
          GraphPin(
            id: 'user',
            direction: GraphPinDirection.output,
            title: 'User',
            dataType: 'string',
          ),
        ],
      ),
      GraphNode(
        id: 'function_validate_user',
        nodeType: 'Function',
        title: '函数：校验账号',
        description: '检查 UID、密码和玩家存档数据。',
        position: GraphNodePosition(x: 390, y: 64),
        size: GraphNodeSize(width: 290, height: 210),
        pins: [
          GraphPin(
            id: 'exec',
            direction: GraphPinDirection.input,
            title: 'Exec',
            dataType: 'exec',
          ),
          GraphPin(
            id: 'user',
            direction: GraphPinDirection.input,
            title: 'User',
            dataType: 'string',
          ),
          GraphPin(
            id: 'then',
            direction: GraphPinDirection.output,
            title: 'Then',
            dataType: 'exec',
            allowMultipleLinks: true,
          ),
          GraphPin(
            id: 'success',
            direction: GraphPinDirection.output,
            title: 'Success',
            dataType: 'bool',
          ),
        ],
      ),
      GraphNode(
        id: 'branch_login_result',
        nodeType: 'Branch',
        title: '分支：登录结果',
        description: '成功进入大厅，失败返回错误文本。',
        position: GraphNodePosition(x: 790, y: 96),
        size: GraphNodeSize(width: 280, height: 210),
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
      ),
    ],
    links: const [
      GraphLink(
        id: 'link_login_to_validate',
        fromNodeId: 'event_login',
        fromPinId: 'then',
        toNodeId: 'function_validate_user',
        toPinId: 'exec',
        title: '',
        description: '',
        linkType: 'exec',
      ),
      GraphLink(
        id: 'link_validate_to_branch',
        fromNodeId: 'function_validate_user',
        fromPinId: 'then',
        toNodeId: 'branch_login_result',
        toPinId: 'exec',
        title: '',
        description: '',
        linkType: 'exec',
      ),
      GraphLink(
        id: 'link_success_to_condition',
        fromNodeId: 'function_validate_user',
        fromPinId: 'success',
        toNodeId: 'branch_login_result',
        toPinId: 'condition',
        title: '',
        description: '',
        linkType: 'data',
      ),
    ],
  );
}
