import '../../../core/models/graph_node.dart';
import '../../../core/models/graph_pin.dart';

class UnrealNodeTemplate {
  const UnrealNodeTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.nodeType,
    required this.pins,
    this.size = const GraphNodeSize(width: 290, height: 170),
    this.expandablePinGroups = const <ExpandablePinGroup>[],
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final String nodeType;
  final List<GraphPin> pins;
  final GraphNodeSize size;
  final List<ExpandablePinGroup> expandablePinGroups;
}

class ExpandablePinGroup {
  const ExpandablePinGroup({
    required this.idPrefix,
    required this.titlePrefix,
    required this.direction,
    required this.dataType,
    required this.actionLabel,
    this.allowMultipleLinks = false,
    this.startIndex = 0,
  });

  final String idPrefix;
  final String titlePrefix;
  final GraphPinDirection direction;
  final String dataType;
  final String actionLabel;
  final bool allowMultipleLinks;
  final int startIndex;
}

class EngineNodeBook {
  const EngineNodeBook({
    required this.id,
    required this.displayName,
    required this.engineVersion,
    required this.description,
    required this.templates,
  });

  final String id;
  final String displayName;
  final String engineVersion;
  final String description;
  final List<UnrealNodeTemplate> templates;

  UnrealNodeTemplate? find(String idOrNodeType) {
    for (final template in templates) {
      if (template.id == idOrNodeType || template.nodeType == idOrNodeType) {
        return template;
      }
    }
    return null;
  }
}

class UnrealNodeCatalog {
  const UnrealNodeCatalog._();

  static const nodeBooks = <EngineNodeBook>[
    EngineNodeBook(
      id: 'unreal_5_6',
      displayName: 'Unreal Engine 5.6',
      engineVersion: 'UE 5.6',
      description: '内置 UE 5.6 蓝图节点本，作为当前默认节点来源。',
      templates: _unreal56Templates,
    ),
  ];

  static const defaultNodeBookId = 'unreal_5_6';

  static EngineNodeBook get defaultNodeBook => findNodeBook(defaultNodeBookId);

  static EngineNodeBook findNodeBook(String id) {
    for (final nodeBook in nodeBooks) {
      if (nodeBook.id == id) {
        return nodeBook;
      }
    }
    return nodeBooks.first;
  }

  static List<UnrealNodeTemplate> get templates => defaultNodeBook.templates;

  static UnrealNodeTemplate? findInNodeBook(
    String nodeBookId,
    String idOrNodeType,
  ) {
    return findNodeBook(nodeBookId).find(idOrNodeType);
  }

  static UnrealNodeTemplate? findTemplateForNode(
    String nodeBookId,
    GraphNode node,
  ) {
    final nodeBook = findNodeBook(nodeBookId);
    for (final template in nodeBook.templates) {
      if (template.title == node.title && template.nodeType == node.nodeType) {
        return template;
      }
    }
    for (final template in nodeBook.templates) {
      if (template.id == node.nodeType || template.nodeType == node.nodeType) {
        return template;
      }
    }
    return null;
  }

  static const _unreal56Templates = <UnrealNodeTemplate>[
    UnrealNodeTemplate(
      id: 'comment',
      title: 'Comment',
      category: '注释',
      description: '用于圈定或说明一段蓝图逻辑。',
      nodeType: 'Comment',
      pins: [],
      size: GraphNodeSize(width: 360, height: 150),
    ),
    UnrealNodeTemplate(
      id: 'event_begin_play',
      title: 'Event BeginPlay',
      category: '事件',
      description: 'Actor 开始运行时触发。',
      nodeType: 'Event',
      pins: [
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 290, height: 150),
    ),
    UnrealNodeTemplate(
      id: 'event_tick',
      title: 'Event Tick',
      category: '事件',
      description: '每帧触发，通常带 Delta Seconds。',
      nodeType: 'Event',
      pins: [
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'delta_seconds',
          direction: GraphPinDirection.output,
          title: 'Delta Seconds',
          dataType: 'real',
        ),
      ],
      size: GraphNodeSize(width: 310, height: 180),
    ),
    UnrealNodeTemplate(
      id: 'custom_event',
      title: 'Custom Event',
      category: '事件',
      description: '自定义事件入口。',
      nodeType: 'CustomEvent',
      pins: [
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 290, height: 150),
    ),
    UnrealNodeTemplate(
      id: 'branch',
      title: 'Branch',
      category: '流程控制',
      description: '根据 Condition 在 True / False 执行路径间分支。',
      nodeType: 'Branch',
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
          defaultValue: 'false',
        ),
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
      ],
      size: GraphNodeSize(width: 290, height: 200),
    ),
    UnrealNodeTemplate(
      id: 'sequence',
      title: 'Sequence',
      category: '流程控制',
      description: '按顺序触发多个执行输出。',
      nodeType: 'FlowControl',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'then_0',
          direction: GraphPinDirection.output,
          title: 'Then 0',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'then_1',
          direction: GraphPinDirection.output,
          title: 'Then 1',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 290, height: 190),
      expandablePinGroups: [
        ExpandablePinGroup(
          idPrefix: 'then',
          titlePrefix: 'Then',
          direction: GraphPinDirection.output,
          dataType: 'exec',
          actionLabel: '添加 Then 输出',
          allowMultipleLinks: true,
        ),
      ],
    ),
    UnrealNodeTemplate(
      id: 'gate',
      title: 'Gate',
      category: '流程控制',
      description: '按 Open / Close 状态控制 Enter 是否从 Exit 输出。',
      nodeType: 'FlowControl',
      pins: [
        GraphPin(
          id: 'enter',
          direction: GraphPinDirection.input,
          title: 'Enter',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'open',
          direction: GraphPinDirection.input,
          title: 'Open',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'close',
          direction: GraphPinDirection.input,
          title: 'Close',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'toggle',
          direction: GraphPinDirection.input,
          title: 'Toggle',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'exit',
          direction: GraphPinDirection.output,
          title: 'Exit',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 330, height: 250),
    ),
    UnrealNodeTemplate(
      id: 'do_once',
      title: 'DoOnce',
      category: '流程控制',
      description: '只允许执行一次，Reset 后可以再次执行。',
      nodeType: 'FlowControl',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'reset',
          direction: GraphPinDirection.input,
          title: 'Reset',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'completed',
          direction: GraphPinDirection.output,
          title: 'Completed',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 300, height: 190),
    ),
    UnrealNodeTemplate(
      id: 'do_n',
      title: 'Do N',
      category: '流程控制',
      description: '允许执行 N 次，Reset 后重新计数。',
      nodeType: 'FlowControl',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'n',
          direction: GraphPinDirection.input,
          title: 'N',
          dataType: 'int',
        ),
        GraphPin(
          id: 'reset',
          direction: GraphPinDirection.input,
          title: 'Reset',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'counter',
          direction: GraphPinDirection.output,
          title: 'Counter',
          dataType: 'int',
        ),
        GraphPin(
          id: 'exit',
          direction: GraphPinDirection.output,
          title: 'Exit',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 330, height: 230),
      expandablePinGroups: [
        ExpandablePinGroup(
          idPrefix: 'out',
          titlePrefix: 'Out',
          direction: GraphPinDirection.output,
          dataType: 'exec',
          actionLabel: '添加 Out 输出',
          allowMultipleLinks: true,
        ),
      ],
    ),
    UnrealNodeTemplate(
      id: 'multi_gate',
      title: 'MultiGate',
      category: '流程控制',
      description: '在多个输出间按顺序或随机触发。',
      nodeType: 'FlowControl',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'reset',
          direction: GraphPinDirection.input,
          title: 'Reset',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'out_0',
          direction: GraphPinDirection.output,
          title: 'Out 0',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'out_1',
          direction: GraphPinDirection.output,
          title: 'Out 1',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'out_2',
          direction: GraphPinDirection.output,
          title: 'Out 2',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 330, height: 230),
      expandablePinGroups: [
        ExpandablePinGroup(
          idPrefix: 'case',
          titlePrefix: 'Case',
          direction: GraphPinDirection.output,
          dataType: 'exec',
          actionLabel: '添加 Case 输出',
          allowMultipleLinks: true,
        ),
      ],
    ),
    UnrealNodeTemplate(
      id: 'flip_flop',
      title: 'FlipFlop',
      category: '流程控制',
      description: '交替触发 A / B 输出。',
      nodeType: 'FlowControl',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'a',
          direction: GraphPinDirection.output,
          title: 'A',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'b',
          direction: GraphPinDirection.output,
          title: 'B',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'is_a',
          direction: GraphPinDirection.output,
          title: 'Is A',
          dataType: 'bool',
        ),
      ],
      size: GraphNodeSize(width: 300, height: 200),
    ),
    UnrealNodeTemplate(
      id: 'for_loop',
      title: 'ForLoop',
      category: '流程控制',
      description: '从 First Index 到 Last Index 循环执行。',
      nodeType: 'FlowControl',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'first_index',
          direction: GraphPinDirection.input,
          title: 'First Index',
          dataType: 'int',
        ),
        GraphPin(
          id: 'last_index',
          direction: GraphPinDirection.input,
          title: 'Last Index',
          dataType: 'int',
        ),
        GraphPin(
          id: 'loop_body',
          direction: GraphPinDirection.output,
          title: 'Loop Body',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'index',
          direction: GraphPinDirection.output,
          title: 'Index',
          dataType: 'int',
        ),
        GraphPin(
          id: 'completed',
          direction: GraphPinDirection.output,
          title: 'Completed',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 330, height: 250),
    ),
    UnrealNodeTemplate(
      id: 'for_each_loop',
      title: 'ForEachLoop',
      category: '流程控制',
      description: '遍历数组元素。',
      nodeType: 'FlowControl',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'array',
          direction: GraphPinDirection.input,
          title: 'Array',
          dataType: 'array',
        ),
        GraphPin(
          id: 'loop_body',
          direction: GraphPinDirection.output,
          title: 'Loop Body',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'array_element',
          direction: GraphPinDirection.output,
          title: 'Array Element',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'array_index',
          direction: GraphPinDirection.output,
          title: 'Array Index',
          dataType: 'int',
        ),
        GraphPin(
          id: 'completed',
          direction: GraphPinDirection.output,
          title: 'Completed',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 350, height: 250),
    ),
    UnrealNodeTemplate(
      id: 'while_loop',
      title: 'WhileLoop',
      category: '流程控制',
      description: '条件为 true 时循环执行。',
      nodeType: 'FlowControl',
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
          id: 'loop_body',
          direction: GraphPinDirection.output,
          title: 'Loop Body',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'completed',
          direction: GraphPinDirection.output,
          title: 'Completed',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 320, height: 210),
    ),
    UnrealNodeTemplate(
      id: 'switch_on_int',
      title: 'Switch on Int',
      category: '流程控制',
      description: '根据 int 值分流。',
      nodeType: 'FlowControl',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'selection',
          direction: GraphPinDirection.input,
          title: 'Selection',
          dataType: 'int',
        ),
        GraphPin(
          id: 'default',
          direction: GraphPinDirection.output,
          title: 'Default',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'case_0',
          direction: GraphPinDirection.output,
          title: '0',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'case_1',
          direction: GraphPinDirection.output,
          title: '1',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 330, height: 230),
    ),
    UnrealNodeTemplate(
      id: 'switch_on_string',
      title: 'Switch on String',
      category: '流程控制',
      description: '根据 string 值分流。',
      nodeType: 'FlowControl',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'selection',
          direction: GraphPinDirection.input,
          title: 'Selection',
          dataType: 'string',
        ),
        GraphPin(
          id: 'default',
          direction: GraphPinDirection.output,
          title: 'Default',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'case_a',
          direction: GraphPinDirection.output,
          title: 'Case A',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'case_b',
          direction: GraphPinDirection.output,
          title: 'Case B',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 340, height: 230),
      expandablePinGroups: [
        ExpandablePinGroup(
          idPrefix: 'case',
          titlePrefix: 'Case',
          direction: GraphPinDirection.output,
          dataType: 'exec',
          actionLabel: '添加 Case 输出',
          allowMultipleLinks: true,
        ),
      ],
    ),
    UnrealNodeTemplate(
      id: 'switch_on_enum',
      title: 'Switch on Enum',
      category: '流程控制',
      description: '根据枚举值分流。',
      nodeType: 'FlowControl',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'selection',
          direction: GraphPinDirection.input,
          title: 'Selection',
          dataType: 'enum',
        ),
        GraphPin(
          id: 'default',
          direction: GraphPinDirection.output,
          title: 'Default',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'entry_a',
          direction: GraphPinDirection.output,
          title: 'Entry A',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'entry_b',
          direction: GraphPinDirection.output,
          title: 'Entry B',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 340, height: 230),
      expandablePinGroups: [
        ExpandablePinGroup(
          idPrefix: 'entry',
          titlePrefix: 'Entry',
          direction: GraphPinDirection.output,
          dataType: 'exec',
          actionLabel: '添加 Entry 输出',
          allowMultipleLinks: true,
        ),
      ],
    ),
    UnrealNodeTemplate(
      id: 'select',
      title: 'Select',
      category: '流程控制',
      description: '根据索引或布尔条件选择一个数据输出。',
      nodeType: 'FlowControl',
      pins: [
        GraphPin(
          id: 'index',
          direction: GraphPinDirection.input,
          title: 'Index',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'option_0',
          direction: GraphPinDirection.input,
          title: 'Option 0',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'option_1',
          direction: GraphPinDirection.input,
          title: 'Option 1',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'wildcard',
        ),
      ],
      size: GraphNodeSize(width: 330, height: 210),
      expandablePinGroups: [
        ExpandablePinGroup(
          idPrefix: 'option',
          titlePrefix: 'Option',
          direction: GraphPinDirection.input,
          dataType: 'wildcard',
          actionLabel: '添加 Option 输入',
        ),
      ],
    ),
    UnrealNodeTemplate(
      id: 'delay',
      title: 'Delay',
      category: '流程控制',
      description: '等待指定 Duration 后继续执行。',
      nodeType: 'Latent',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'duration',
          direction: GraphPinDirection.input,
          title: 'Duration',
          dataType: 'real',
        ),
        GraphPin(
          id: 'completed',
          direction: GraphPinDirection.output,
          title: 'Completed',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 300, height: 185),
    ),
    UnrealNodeTemplate(
      id: 'retriggerable_delay',
      title: 'Retriggerable Delay',
      category: '流程控制',
      description: '重复触发会重置等待时间。',
      nodeType: 'Latent',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'duration',
          direction: GraphPinDirection.input,
          title: 'Duration',
          dataType: 'real',
        ),
        GraphPin(
          id: 'completed',
          direction: GraphPinDirection.output,
          title: 'Completed',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 330, height: 185),
    ),
    UnrealNodeTemplate(
      id: 'timeline',
      title: 'Timeline',
      category: '时间轴',
      description: '按时间输出曲线、事件和完成回调。',
      nodeType: 'Timeline',
      pins: [
        GraphPin(
          id: 'play',
          direction: GraphPinDirection.input,
          title: 'Play',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'play_from_start',
          direction: GraphPinDirection.input,
          title: 'Play from Start',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'stop',
          direction: GraphPinDirection.input,
          title: 'Stop',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'reverse',
          direction: GraphPinDirection.input,
          title: 'Reverse',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'update',
          direction: GraphPinDirection.output,
          title: 'Update',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'finished',
          direction: GraphPinDirection.output,
          title: 'Finished',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'alpha',
          direction: GraphPinDirection.output,
          title: 'Alpha',
          dataType: 'float',
        ),
      ],
      size: GraphNodeSize(width: 360, height: 290),
    ),
    UnrealNodeTemplate(
      id: 'print_string',
      title: 'Print String',
      category: '开发工具',
      description: '在屏幕或日志中输出字符串。',
      nodeType: 'FunctionCall',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'in_string',
          direction: GraphPinDirection.input,
          title: 'In String',
          dataType: 'string',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 310, height: 190),
    ),
    UnrealNodeTemplate(
      id: 'function_call',
      title: 'Function Call',
      category: '函数',
      description: '调用蓝图或 C++ 函数。',
      nodeType: 'FunctionCall',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 290, height: 150),
    ),
    UnrealNodeTemplate(
      id: 'pure_function',
      title: 'Pure Function',
      category: '函数',
      description: '无执行引脚的纯函数调用。',
      nodeType: 'FunctionCall',
      pins: [
        GraphPin(
          id: 'input',
          direction: GraphPinDirection.input,
          title: 'Input',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'wildcard',
        ),
      ],
      size: GraphNodeSize(width: 280, height: 150),
    ),
    UnrealNodeTemplate(
      id: 'get_bool_variable',
      title: 'Get Bool Variable',
      category: '变量',
      description: '读取 Bool 类型变量。',
      nodeType: 'VariableGet',
      pins: [
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.output,
          title: 'Bool',
          dataType: 'bool',
        ),
      ],
      size: GraphNodeSize(width: 260, height: 130),
    ),
    UnrealNodeTemplate(
      id: 'set_bool_variable',
      title: 'Set Bool Variable',
      category: '变量',
      description: '写入 Bool 类型变量。',
      nodeType: 'VariableSet',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.input,
          title: 'Bool',
          dataType: 'bool',
          defaultValue: 'false',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 310, height: 180),
    ),
    UnrealNodeTemplate(
      id: 'get_int_variable',
      title: 'Get Integer Variable',
      category: '变量',
      description: '读取 Integer 类型变量。',
      nodeType: 'VariableGet',
      pins: [
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.output,
          title: 'Integer',
          dataType: 'int',
        ),
      ],
      size: GraphNodeSize(width: 260, height: 130),
    ),
    UnrealNodeTemplate(
      id: 'set_int_variable',
      title: 'Set Integer Variable',
      category: '变量',
      description: '写入 Integer 类型变量。',
      nodeType: 'VariableSet',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.input,
          title: 'Integer',
          dataType: 'int',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 310, height: 180),
    ),
    UnrealNodeTemplate(
      id: 'get_float_variable',
      title: 'Get Float Variable',
      category: '变量',
      description: '读取 Float 类型变量。',
      nodeType: 'VariableGet',
      pins: [
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.output,
          title: 'Float',
          dataType: 'float',
        ),
      ],
      size: GraphNodeSize(width: 260, height: 130),
    ),
    UnrealNodeTemplate(
      id: 'set_float_variable',
      title: 'Set Float Variable',
      category: '变量',
      description: '写入 Float 类型变量。',
      nodeType: 'VariableSet',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.input,
          title: 'Float',
          dataType: 'float',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 310, height: 180),
    ),
    UnrealNodeTemplate(
      id: 'get_string_variable',
      title: 'Get String Variable',
      category: '变量',
      description: '读取 String 类型变量。',
      nodeType: 'VariableGet',
      pins: [
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.output,
          title: 'String',
          dataType: 'string',
        ),
      ],
      size: GraphNodeSize(width: 260, height: 130),
    ),
    UnrealNodeTemplate(
      id: 'set_string_variable',
      title: 'Set String Variable',
      category: '变量',
      description: '写入 String 类型变量。',
      nodeType: 'VariableSet',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.input,
          title: 'String',
          dataType: 'string',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 310, height: 180),
    ),
    UnrealNodeTemplate(
      id: 'get_text_variable',
      title: 'Get Text Variable',
      category: '变量',
      description: '读取 Text 类型变量。',
      nodeType: 'VariableGet',
      pins: [
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.output,
          title: 'Text',
          dataType: 'text',
        ),
      ],
      size: GraphNodeSize(width: 260, height: 130),
    ),
    UnrealNodeTemplate(
      id: 'set_text_variable',
      title: 'Set Text Variable',
      category: '变量',
      description: '写入 Text 类型变量。',
      nodeType: 'VariableSet',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.input,
          title: 'Text',
          dataType: 'text',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 310, height: 180),
    ),
    UnrealNodeTemplate(
      id: 'get_name_variable',
      title: 'Get Name Variable',
      category: '变量',
      description: '读取 Name 类型变量。',
      nodeType: 'VariableGet',
      pins: [
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.output,
          title: 'Name',
          dataType: 'name',
        ),
      ],
      size: GraphNodeSize(width: 260, height: 130),
    ),
    UnrealNodeTemplate(
      id: 'set_name_variable',
      title: 'Set Name Variable',
      category: '变量',
      description: '写入 Name 类型变量。',
      nodeType: 'VariableSet',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.input,
          title: 'Name',
          dataType: 'name',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 310, height: 180),
    ),
    UnrealNodeTemplate(
      id: 'get_vector_variable',
      title: 'Get Vector Variable',
      category: '变量',
      description: '读取 Vector 类型变量。',
      nodeType: 'VariableGet',
      pins: [
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.output,
          title: 'Vector',
          dataType: 'vector',
        ),
      ],
      size: GraphNodeSize(width: 260, height: 130),
    ),
    UnrealNodeTemplate(
      id: 'set_vector_variable',
      title: 'Set Vector Variable',
      category: '变量',
      description: '写入 Vector 类型变量。',
      nodeType: 'VariableSet',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.input,
          title: 'Vector',
          dataType: 'vector',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 310, height: 180),
    ),
    UnrealNodeTemplate(
      id: 'get_rotator_variable',
      title: 'Get Rotator Variable',
      category: '变量',
      description: '读取 Rotator 类型变量。',
      nodeType: 'VariableGet',
      pins: [
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.output,
          title: 'Rotator',
          dataType: 'rotator',
        ),
      ],
      size: GraphNodeSize(width: 260, height: 130),
    ),
    UnrealNodeTemplate(
      id: 'set_rotator_variable',
      title: 'Set Rotator Variable',
      category: '变量',
      description: '写入 Rotator 类型变量。',
      nodeType: 'VariableSet',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.input,
          title: 'Rotator',
          dataType: 'rotator',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 310, height: 180),
    ),
    UnrealNodeTemplate(
      id: 'get_transform_variable',
      title: 'Get Transform Variable',
      category: '变量',
      description: '读取 Transform 类型变量。',
      nodeType: 'VariableGet',
      pins: [
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.output,
          title: 'Transform',
          dataType: 'transform',
        ),
      ],
      size: GraphNodeSize(width: 260, height: 130),
    ),
    UnrealNodeTemplate(
      id: 'set_transform_variable',
      title: 'Set Transform Variable',
      category: '变量',
      description: '写入 Transform 类型变量。',
      nodeType: 'VariableSet',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.input,
          title: 'Transform',
          dataType: 'transform',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 310, height: 180),
    ),
    UnrealNodeTemplate(
      id: 'get_object_variable',
      title: 'Get Object Variable',
      category: '变量',
      description: '读取 Object 类型变量。',
      nodeType: 'VariableGet',
      pins: [
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.output,
          title: 'Object',
          dataType: 'object',
        ),
      ],
      size: GraphNodeSize(width: 260, height: 130),
    ),
    UnrealNodeTemplate(
      id: 'set_object_variable',
      title: 'Set Object Variable',
      category: '变量',
      description: '写入 Object 类型变量。',
      nodeType: 'VariableSet',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.input,
          title: 'Object',
          dataType: 'object',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 310, height: 180),
    ),
    UnrealNodeTemplate(
      id: 'get_actor_variable',
      title: 'Get Actor Variable',
      category: '变量',
      description: '读取 Actor 类型变量。',
      nodeType: 'VariableGet',
      pins: [
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.output,
          title: 'Actor',
          dataType: 'Actor',
        ),
      ],
      size: GraphNodeSize(width: 260, height: 130),
    ),
    UnrealNodeTemplate(
      id: 'set_actor_variable',
      title: 'Set Actor Variable',
      category: '变量',
      description: '写入 Actor 类型变量。',
      nodeType: 'VariableSet',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.input,
          title: 'Actor',
          dataType: 'Actor',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 310, height: 180),
    ),
    UnrealNodeTemplate(
      id: 'get_class_variable',
      title: 'Get Class Variable',
      category: '变量',
      description: '读取 Class 类型变量。',
      nodeType: 'VariableGet',
      pins: [
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.output,
          title: 'Class',
          dataType: 'class',
        ),
      ],
      size: GraphNodeSize(width: 260, height: 130),
    ),
    UnrealNodeTemplate(
      id: 'set_class_variable',
      title: 'Set Class Variable',
      category: '变量',
      description: '写入 Class 类型变量。',
      nodeType: 'VariableSet',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.input,
          title: 'Class',
          dataType: 'class',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 310, height: 180),
    ),
    UnrealNodeTemplate(
      id: 'get_variable',
      title: 'Get Variable',
      category: '变量',
      description: '读取变量值。',
      nodeType: 'VariableGet',
      pins: [
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.output,
          title: 'Value',
          dataType: 'wildcard',
        ),
      ],
      size: GraphNodeSize(width: 240, height: 130),
    ),
    UnrealNodeTemplate(
      id: 'set_variable',
      title: 'Set Variable',
      category: '变量',
      description: '写入变量值。',
      nodeType: 'VariableSet',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.input,
          title: 'Value',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 290, height: 170),
    ),
    UnrealNodeTemplate(
      id: 'array_get',
      title: 'Array Get',
      category: '容器',
      description: '读取数组指定 Index 的元素。',
      nodeType: 'Container',
      pins: [
        GraphPin(
          id: 'target_array',
          direction: GraphPinDirection.input,
          title: 'Target Array',
          dataType: 'array',
        ),
        GraphPin(
          id: 'index',
          direction: GraphPinDirection.input,
          title: 'Index',
          dataType: 'int',
        ),
        GraphPin(
          id: 'item',
          direction: GraphPinDirection.output,
          title: 'Item',
          dataType: 'wildcard',
        ),
      ],
      size: GraphNodeSize(width: 320, height: 180),
    ),
    UnrealNodeTemplate(
      id: 'array_add',
      title: 'Array Add',
      category: '容器',
      description: '向数组末尾添加元素并返回索引。',
      nodeType: 'Container',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'target_array',
          direction: GraphPinDirection.input,
          title: 'Target Array',
          dataType: 'array',
        ),
        GraphPin(
          id: 'item',
          direction: GraphPinDirection.input,
          title: 'Item',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'index',
          direction: GraphPinDirection.output,
          title: 'Index',
          dataType: 'int',
        ),
      ],
      size: GraphNodeSize(width: 340, height: 230),
    ),
    UnrealNodeTemplate(
      id: 'array_remove',
      title: 'Array Remove Item',
      category: '容器',
      description: '从数组移除匹配元素。',
      nodeType: 'Container',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'target_array',
          direction: GraphPinDirection.input,
          title: 'Target Array',
          dataType: 'array',
        ),
        GraphPin(
          id: 'item',
          direction: GraphPinDirection.input,
          title: 'Item',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'removed',
          direction: GraphPinDirection.output,
          title: 'Removed',
          dataType: 'bool',
        ),
      ],
      size: GraphNodeSize(width: 350, height: 230),
    ),
    UnrealNodeTemplate(
      id: 'array_length',
      title: 'Array Length',
      category: '容器',
      description: '返回数组长度。',
      nodeType: 'Container',
      pins: [
        GraphPin(
          id: 'target_array',
          direction: GraphPinDirection.input,
          title: 'Target Array',
          dataType: 'array',
        ),
        GraphPin(
          id: 'length',
          direction: GraphPinDirection.output,
          title: 'Length',
          dataType: 'int',
        ),
      ],
      size: GraphNodeSize(width: 300, height: 150),
    ),
    UnrealNodeTemplate(
      id: 'map_find',
      title: 'Map Find',
      category: '容器',
      description: '按 Key 查找 Map 中的值。',
      nodeType: 'Container',
      pins: [
        GraphPin(
          id: 'target_map',
          direction: GraphPinDirection.input,
          title: 'Target Map',
          dataType: 'map',
        ),
        GraphPin(
          id: 'key',
          direction: GraphPinDirection.input,
          title: 'Key',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.output,
          title: 'Value',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'found',
          direction: GraphPinDirection.output,
          title: 'Found',
          dataType: 'bool',
        ),
      ],
      size: GraphNodeSize(width: 340, height: 210),
    ),
    UnrealNodeTemplate(
      id: 'map_add',
      title: 'Map Add',
      category: '容器',
      description: '向 Map 写入 Key / Value。',
      nodeType: 'Container',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'target_map',
          direction: GraphPinDirection.input,
          title: 'Target Map',
          dataType: 'map',
        ),
        GraphPin(
          id: 'key',
          direction: GraphPinDirection.input,
          title: 'Key',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.input,
          title: 'Value',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 350, height: 240),
    ),
    UnrealNodeTemplate(
      id: 'map_remove',
      title: 'Map Remove',
      category: '容器',
      description: '按 Key 从 Map 移除条目。',
      nodeType: 'Container',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'target_map',
          direction: GraphPinDirection.input,
          title: 'Target Map',
          dataType: 'map',
        ),
        GraphPin(
          id: 'key',
          direction: GraphPinDirection.input,
          title: 'Key',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'removed',
          direction: GraphPinDirection.output,
          title: 'Removed',
          dataType: 'bool',
        ),
      ],
      size: GraphNodeSize(width: 350, height: 230),
    ),
    UnrealNodeTemplate(
      id: 'set_add',
      title: 'Set Add',
      category: '容器',
      description: '向 Set 添加元素。',
      nodeType: 'Container',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'target_set',
          direction: GraphPinDirection.input,
          title: 'Target Set',
          dataType: 'set',
        ),
        GraphPin(
          id: 'item',
          direction: GraphPinDirection.input,
          title: 'Item',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'added',
          direction: GraphPinDirection.output,
          title: 'Added',
          dataType: 'bool',
        ),
      ],
      size: GraphNodeSize(width: 330, height: 220),
    ),
    UnrealNodeTemplate(
      id: 'set_contains',
      title: 'Set Contains',
      category: '容器',
      description: '检查 Set 是否包含元素。',
      nodeType: 'Container',
      pins: [
        GraphPin(
          id: 'target_set',
          direction: GraphPinDirection.input,
          title: 'Target Set',
          dataType: 'set',
        ),
        GraphPin(
          id: 'item',
          direction: GraphPinDirection.input,
          title: 'Item',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'contains',
          direction: GraphPinDirection.output,
          title: 'Contains',
          dataType: 'bool',
        ),
      ],
      size: GraphNodeSize(width: 330, height: 180),
    ),
    UnrealNodeTemplate(
      id: 'spawn_actor_from_class',
      title: 'Spawn Actor from Class',
      category: '对象/Actor',
      description: '按 Class 在指定 Transform 生成 Actor。',
      nodeType: 'Spawn',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'class',
          direction: GraphPinDirection.input,
          title: 'Class',
          dataType: 'class',
        ),
        GraphPin(
          id: 'spawn_transform',
          direction: GraphPinDirection.input,
          title: 'Spawn Transform',
          dataType: 'transform',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'Actor',
        ),
      ],
      size: GraphNodeSize(width: 360, height: 230),
    ),
    UnrealNodeTemplate(
      id: 'destroy_actor',
      title: 'Destroy Actor',
      category: '对象/Actor',
      description: '销毁目标 Actor。',
      nodeType: 'Object',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'target',
          direction: GraphPinDirection.input,
          title: 'Target',
          dataType: 'Actor',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 300, height: 170),
    ),
    UnrealNodeTemplate(
      id: 'get_actor_location',
      title: 'Get Actor Location',
      category: '对象/Actor',
      description: '读取 Actor 世界坐标。',
      nodeType: 'Object',
      pins: [
        GraphPin(
          id: 'target',
          direction: GraphPinDirection.input,
          title: 'Target',
          dataType: 'Actor',
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'vector',
        ),
      ],
      size: GraphNodeSize(width: 310, height: 160),
    ),
    UnrealNodeTemplate(
      id: 'set_actor_location',
      title: 'Set Actor Location',
      category: '对象/Actor',
      description: '设置 Actor 世界坐标。',
      nodeType: 'Object',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'target',
          direction: GraphPinDirection.input,
          title: 'Target',
          dataType: 'Actor',
        ),
        GraphPin(
          id: 'new_location',
          direction: GraphPinDirection.input,
          title: 'New Location',
          dataType: 'vector',
        ),
        GraphPin(
          id: 'sweep',
          direction: GraphPinDirection.input,
          title: 'Sweep',
          dataType: 'bool',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 360, height: 230),
    ),
    UnrealNodeTemplate(
      id: 'cast_to_actor',
      title: 'Cast To Actor',
      category: '类型转换',
      description: '把 Object 尝试转换为 Actor。',
      nodeType: 'Cast',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'object',
          direction: GraphPinDirection.input,
          title: 'Object',
          dataType: 'object',
        ),
        GraphPin(
          id: 'cast_succeeded',
          direction: GraphPinDirection.output,
          title: 'Cast Succeeded',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'cast_failed',
          direction: GraphPinDirection.output,
          title: 'Cast Failed',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'as_actor',
          direction: GraphPinDirection.output,
          title: 'As Actor',
          dataType: 'Actor',
        ),
      ],
      size: GraphNodeSize(width: 350, height: 230),
    ),
    UnrealNodeTemplate(
      id: 'is_valid',
      title: 'Is Valid',
      category: '对象/Actor',
      description: '检查对象引用是否有效。',
      nodeType: 'Object',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'input_object',
          direction: GraphPinDirection.input,
          title: 'Input Object',
          dataType: 'object',
        ),
        GraphPin(
          id: 'is_valid',
          direction: GraphPinDirection.output,
          title: 'Is Valid',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'is_not_valid',
          direction: GraphPinDirection.output,
          title: 'Is Not Valid',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 340, height: 210),
    ),
    UnrealNodeTemplate(
      id: 'create_widget',
      title: 'Create Widget',
      category: 'UI',
      description: '创建指定 Widget Class 的控件实例。',
      nodeType: 'Widget',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'class',
          direction: GraphPinDirection.input,
          title: 'Class',
          dataType: 'class',
        ),
        GraphPin(
          id: 'owning_player',
          direction: GraphPinDirection.input,
          title: 'Owning Player',
          dataType: 'object',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'widget',
        ),
      ],
      size: GraphNodeSize(width: 360, height: 230),
    ),
    UnrealNodeTemplate(
      id: 'add_to_viewport',
      title: 'Add to Viewport',
      category: 'UI',
      description: '把 Widget 添加到屏幕视口。',
      nodeType: 'Widget',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'target',
          direction: GraphPinDirection.input,
          title: 'Target',
          dataType: 'widget',
        ),
        GraphPin(
          id: 'z_order',
          direction: GraphPinDirection.input,
          title: 'ZOrder',
          dataType: 'int',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 330, height: 210),
    ),
    UnrealNodeTemplate(
      id: 'remove_from_parent',
      title: 'Remove from Parent',
      category: 'UI',
      description: '从父级或视口移除 Widget。',
      nodeType: 'Widget',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'target',
          direction: GraphPinDirection.input,
          title: 'Target',
          dataType: 'widget',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 320, height: 170),
    ),
    UnrealNodeTemplate(
      id: 'switch_has_authority',
      title: 'Switch Has Authority',
      category: '网络',
      description: '根据当前是否为服务器权威分流。',
      nodeType: 'Network',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'authority',
          direction: GraphPinDirection.output,
          title: 'Authority',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
        GraphPin(
          id: 'remote',
          direction: GraphPinDirection.output,
          title: 'Remote',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 320, height: 190),
    ),
    UnrealNodeTemplate(
      id: 'run_on_server',
      title: 'Run on Server Event',
      category: '网络',
      description: '客户端请求服务器执行的 RPC 事件。',
      nodeType: 'Network',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 310, height: 160),
    ),
    UnrealNodeTemplate(
      id: 'multicast_event',
      title: 'Multicast Event',
      category: '网络',
      description: '服务器广播到所有客户端执行的 RPC 事件。',
      nodeType: 'Network',
      pins: [
        GraphPin(
          id: 'exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: 'then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
      size: GraphNodeSize(width: 310, height: 160),
    ),
    UnrealNodeTemplate(
      id: 'add_float',
      title: 'Float + Float',
      category: '数学',
      description: '常用数值运算节点。',
      nodeType: 'Math',
      pins: [
        GraphPin(
          id: 'a',
          direction: GraphPinDirection.input,
          title: 'A',
          dataType: 'float',
        ),
        GraphPin(
          id: 'b',
          direction: GraphPinDirection.input,
          title: 'B',
          dataType: 'float',
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'float',
        ),
      ],
      size: GraphNodeSize(width: 300, height: 170),
    ),
    UnrealNodeTemplate(
      id: 'subtract_float',
      title: 'Float - Float',
      category: '数学',
      description: '常用数值运算节点。',
      nodeType: 'Math',
      pins: [
        GraphPin(
          id: 'a',
          direction: GraphPinDirection.input,
          title: 'A',
          dataType: 'float',
        ),
        GraphPin(
          id: 'b',
          direction: GraphPinDirection.input,
          title: 'B',
          dataType: 'float',
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'float',
        ),
      ],
      size: GraphNodeSize(width: 300, height: 170),
    ),
    UnrealNodeTemplate(
      id: 'multiply_float',
      title: 'Float * Float',
      category: '数学',
      description: '常用数值运算节点。',
      nodeType: 'Math',
      pins: [
        GraphPin(
          id: 'a',
          direction: GraphPinDirection.input,
          title: 'A',
          dataType: 'float',
        ),
        GraphPin(
          id: 'b',
          direction: GraphPinDirection.input,
          title: 'B',
          dataType: 'float',
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'float',
        ),
      ],
      size: GraphNodeSize(width: 300, height: 170),
    ),
    UnrealNodeTemplate(
      id: 'divide_float',
      title: 'Float / Float',
      category: '数学',
      description: '常用数值运算节点。',
      nodeType: 'Math',
      pins: [
        GraphPin(
          id: 'a',
          direction: GraphPinDirection.input,
          title: 'A',
          dataType: 'float',
        ),
        GraphPin(
          id: 'b',
          direction: GraphPinDirection.input,
          title: 'B',
          dataType: 'float',
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'float',
        ),
      ],
      size: GraphNodeSize(width: 300, height: 170),
    ),
    UnrealNodeTemplate(
      id: 'add_int',
      title: 'Integer + Integer',
      category: '数学',
      description: '常用数值运算节点。',
      nodeType: 'Math',
      pins: [
        GraphPin(
          id: 'a',
          direction: GraphPinDirection.input,
          title: 'A',
          dataType: 'int',
        ),
        GraphPin(
          id: 'b',
          direction: GraphPinDirection.input,
          title: 'B',
          dataType: 'int',
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'int',
        ),
      ],
      size: GraphNodeSize(width: 300, height: 170),
    ),
    UnrealNodeTemplate(
      id: 'equal_equal',
      title: 'Equal ==',
      category: '比较',
      description: '比较两个值是否相等。',
      nodeType: 'Operator',
      pins: [
        GraphPin(
          id: 'a',
          direction: GraphPinDirection.input,
          title: 'A',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'b',
          direction: GraphPinDirection.input,
          title: 'B',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'bool',
        ),
      ],
      size: GraphNodeSize(width: 300, height: 170),
    ),
    UnrealNodeTemplate(
      id: 'not_equal',
      title: 'Not Equal !=',
      category: '比较',
      description: '比较两个值是否不相等。',
      nodeType: 'Operator',
      pins: [
        GraphPin(
          id: 'a',
          direction: GraphPinDirection.input,
          title: 'A',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'b',
          direction: GraphPinDirection.input,
          title: 'B',
          dataType: 'wildcard',
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'bool',
        ),
      ],
      size: GraphNodeSize(width: 300, height: 170),
    ),
    UnrealNodeTemplate(
      id: 'greater_float',
      title: 'Float > Float',
      category: '比较',
      description: '检查 A 是否大于 B。',
      nodeType: 'Operator',
      pins: [
        GraphPin(
          id: 'a',
          direction: GraphPinDirection.input,
          title: 'A',
          dataType: 'float',
        ),
        GraphPin(
          id: 'b',
          direction: GraphPinDirection.input,
          title: 'B',
          dataType: 'float',
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'bool',
        ),
      ],
      size: GraphNodeSize(width: 300, height: 170),
    ),
    UnrealNodeTemplate(
      id: 'boolean_and',
      title: 'Boolean AND',
      category: '布尔',
      description: '两个条件都为 true 时返回 true。',
      nodeType: 'Operator',
      pins: [
        GraphPin(
          id: 'a',
          direction: GraphPinDirection.input,
          title: 'A',
          dataType: 'bool',
          defaultValue: 'false',
        ),
        GraphPin(
          id: 'b',
          direction: GraphPinDirection.input,
          title: 'B',
          dataType: 'bool',
          defaultValue: 'false',
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'bool',
        ),
      ],
      size: GraphNodeSize(width: 300, height: 170),
    ),
    UnrealNodeTemplate(
      id: 'boolean_or',
      title: 'Boolean OR',
      category: '布尔',
      description: '任一条件为 true 时返回 true。',
      nodeType: 'Operator',
      pins: [
        GraphPin(
          id: 'a',
          direction: GraphPinDirection.input,
          title: 'A',
          dataType: 'bool',
          defaultValue: 'false',
        ),
        GraphPin(
          id: 'b',
          direction: GraphPinDirection.input,
          title: 'B',
          dataType: 'bool',
          defaultValue: 'false',
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'bool',
        ),
      ],
      size: GraphNodeSize(width: 300, height: 170),
    ),
    UnrealNodeTemplate(
      id: 'boolean_not',
      title: 'Boolean NOT',
      category: '布尔',
      description: '反转布尔值。',
      nodeType: 'Operator',
      pins: [
        GraphPin(
          id: 'value',
          direction: GraphPinDirection.input,
          title: 'Value',
          dataType: 'bool',
          defaultValue: 'false',
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'bool',
        ),
      ],
      size: GraphNodeSize(width: 280, height: 150),
    ),
    UnrealNodeTemplate(
      id: 'append_string',
      title: 'Append String',
      category: '字符串',
      description: '拼接两个字符串。',
      nodeType: 'String',
      pins: [
        GraphPin(
          id: 'a',
          direction: GraphPinDirection.input,
          title: 'A',
          dataType: 'string',
        ),
        GraphPin(
          id: 'b',
          direction: GraphPinDirection.input,
          title: 'B',
          dataType: 'string',
        ),
        GraphPin(
          id: 'return_value',
          direction: GraphPinDirection.output,
          title: 'Return Value',
          dataType: 'string',
        ),
      ],
      size: GraphNodeSize(width: 320, height: 170),
    ),
    UnrealNodeTemplate(
      id: 'format_text',
      title: 'Format Text',
      category: '文本',
      description: '按格式参数生成 Text。',
      nodeType: 'Text',
      pins: [
        GraphPin(
          id: 'format',
          direction: GraphPinDirection.input,
          title: 'Format',
          dataType: 'text',
        ),
        GraphPin(
          id: 'result',
          direction: GraphPinDirection.output,
          title: 'Result',
          dataType: 'text',
        ),
      ],
      size: GraphNodeSize(width: 320, height: 150),
      expandablePinGroups: [
        ExpandablePinGroup(
          idPrefix: 'arg',
          titlePrefix: 'Arg',
          direction: GraphPinDirection.input,
          dataType: 'text',
          actionLabel: '添加格式参数',
        ),
      ],
    ),
  ];

  static UnrealNodeTemplate? find(String idOrNodeType) {
    return defaultNodeBook.find(idOrNodeType);
  }

  static UnrealNodeTemplate get fallback => templates.first;
}
