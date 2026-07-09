import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/graph_document.dart';
import '../../core/models/graph_event.dart';
import '../../core/models/graph_function.dart';
import '../../core/models/graph_node.dart';
import '../../core/models/graph_pin.dart';
import '../../core/models/graph_variable.dart';
import '../../core/platform/ime_control.dart';
import '../../core/services/graph_json_codec.dart';
import '../../core/workspace/canvas_workspace.dart';
import 'canvas/graph_canvas.dart';
import 'canvas/graph_canvas_geometry.dart';
import 'canvas/graph_node_style.dart';
import 'catalog/unreal_node_catalog.dart';
import 'sample_graph_document.dart';

enum _MemberFocusKind { variable, event, function }

class _MemberFocusRequest {
  const _MemberFocusRequest(this.kind, this.name);

  final _MemberFocusKind kind;
  final String name;

  String get cursorKey => '${kind.name}:$name';
}

class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    this.showScaffoldChrome = true,
    this.initialDocument,
    this.canvasDrafts = const <CanvasDraft>[],
    this.activeCanvasKey,
    this.engineNodeBookId = UnrealNodeCatalog.defaultNodeBookId,
    this.onCanvasDraftSelected,
    this.onResetActiveCanvas,
    this.onDocumentChanged,
  });

  final bool showScaffoldChrome;
  final GraphDocument? initialDocument;
  final List<CanvasDraft> canvasDrafts;
  final String? activeCanvasKey;
  final String engineNodeBookId;
  final ValueChanged<String>? onCanvasDraftSelected;
  final VoidCallback? onResetActiveCanvas;
  final ValueChanged<GraphDocument>? onDocumentChanged;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late GraphDocument _document =
      widget.initialDocument ?? createSampleGraphDocument();
  final FocusNode _canvasFocusNode = FocusNode(debugLabel: 'EditorCanvas');
  Set<String> _selectedNodeIds = const {};
  String? _selectedVariableId;
  String? _selectedEventId;
  String? _selectedFunctionId;
  String? _openedFunctionId;
  _RightPanelMode _rightPanelMode = _RightPanelMode.members;
  GraphCanvasPoint? _pendingNodeWorldPosition;
  final Map<String, int> _memberFocusCursor = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _returnFocusToCanvas();
      }
    });
  }

  @override
  void dispose() {
    ImeControl.setEnabled(true);
    _canvasFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextDocument = widget.initialDocument;
    if (nextDocument == null ||
        identical(nextDocument, oldWidget.initialDocument)) {
      return;
    }

    setState(() {
      _document = nextDocument;
      _selectedNodeIds = const {};
      _selectedVariableId = null;
      _selectedEventId = null;
      _selectedFunctionId = null;
      _openedFunctionId = null;
      _rightPanelMode = _RightPanelMode.members;
      _pendingNodeWorldPosition = null;
      _memberFocusCursor.clear();
    });
  }

  GraphNode? get _selectedNode {
    if (_selectedNodeIds.length != 1) {
      return null;
    }

    final selectedNodeId = _selectedNodeIds.single;
    return _document.nodes
        .where((node) => node.id == selectedNodeId)
        .firstOrNull;
  }

  GraphVariable? get _selectedVariable {
    final selectedVariableId = _selectedVariableId;
    if (selectedVariableId == null) {
      return null;
    }

    return _document.variables
        .where((variable) => variable.id == selectedVariableId)
        .firstOrNull;
  }

  GraphFunction? get _selectedFunction {
    final selectedFunctionId = _selectedFunctionId;
    if (selectedFunctionId == null) {
      return null;
    }

    return _document.functions
        .where((function) => function.id == selectedFunctionId)
        .firstOrNull;
  }

  GraphEvent? get _selectedEvent {
    final selectedEventId = _selectedEventId;
    if (selectedEventId == null) {
      return null;
    }

    return _visibleEvents
        .where((event) => event.id == selectedEventId)
        .firstOrNull;
  }

  GraphFunction? get _openedFunction {
    final openedFunctionId = _openedFunctionId;
    if (openedFunctionId == null) {
      return null;
    }

    return _document.functions
        .where((function) => function.id == openedFunctionId)
        .firstOrNull;
  }

  List<GraphEvent> get _visibleEvents {
    if (_document.events.isNotEmpty) {
      return _document.events;
    }

    return _document.nodes
        .where(
          (node) => node.nodeType == 'Event' || node.nodeType == 'CustomEvent',
        )
        .map(
          (node) => GraphEvent(
            id: 'derived_${node.id}',
            name: node.title,
            description: node.description,
            eventType: node.nodeType == 'CustomEvent' ? 'CustomEvent' : 'Event',
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final nodeBook = UnrealNodeCatalog.findNodeBook(widget.engineNodeBookId);

    final body = Column(
      children: [
        if (widget.showScaffoldChrome) _EditorToolbar(colorScheme: colorScheme),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 900;
              if (compact) {
                return _CompactEditorShell(
                  document: _document,
                  nodeBook: nodeBook,
                  selectedNode: _selectedNode,
                  selectedVariable: _selectedVariable,
                  selectedEvent: _selectedEvent,
                  selectedFunction: _selectedFunction,
                  openedFunction: _openedFunction,
                  selectedNodeIds: _selectedNodeIds,
                  rightPanelMode: _rightPanelMode,
                  showJsonPreview: false,
                  events: _visibleEvents,
                  canvasDrafts: widget.canvasDrafts,
                  activeCanvasKey: widget.activeCanvasKey,
                  canvasFocusNode: _canvasFocusNode,
                  onCanvasDraftSelected: widget.onCanvasDraftSelected,
                  onResetActiveCanvas: widget.onResetActiveCanvas,
                  onAddNode: _addNodeFromCatalog,
                  onAddNodeAt: _addNode,
                  onAddVariable: _addVariable,
                  onAddVariableNode: _addVariableNode,
                  onUpdateVariable: _updateVariable,
                  onSelectVariable: _selectVariable,
                  onAddEvent: _addEvent,
                  onAddEventNode: _addEventNode,
                  onUpdateEvent: _updateEvent,
                  onSelectEvent: _selectEvent,
                  onAddFunction: _addFunction,
                  onAddFunctionNode: _addFunctionNode,
                  onUpdateFunction: _updateFunction,
                  onSelectFunction: _selectFunction,
                  onOpenFunctionPanel: _openFunctionPanel,
                  onOpenFunctionNode: _openFunctionFromNode,
                  onCloseFunctionPanel: _closeFunctionPanel,
                  onOpenNodeSearch: _openNodeSearch,
                  onUpdateSelectedNode: _updateSelectedNode,
                  onAutoSizeSelectedComment: _autoSizeSelectedComment,
                  onDeleteSelectedNode: _deleteSelectedNode,
                  onAddExpandablePin: _addExpandablePinToSelectedNode,
                  onDeletePin: _deletePinFromSelectedNode,
                  onFocusMemberNode: _focusMemberNode,
                  onDocumentChanged: _updateDocument,
                  onSelectedNodesChanged: _selectNodes,
                );
              }

              return _DesktopEditorShell(
                document: _document,
                nodeBook: nodeBook,
                selectedNode: _selectedNode,
                selectedVariable: _selectedVariable,
                selectedEvent: _selectedEvent,
                selectedFunction: _selectedFunction,
                openedFunction: _openedFunction,
                selectedNodeIds: _selectedNodeIds,
                rightPanelMode: _rightPanelMode,
                compact: compact,
                showJsonPreview: widget.showScaffoldChrome,
                events: _visibleEvents,
                canvasDrafts: widget.canvasDrafts,
                activeCanvasKey: widget.activeCanvasKey,
                canvasFocusNode: _canvasFocusNode,
                onCanvasDraftSelected: widget.onCanvasDraftSelected,
                onResetActiveCanvas: widget.onResetActiveCanvas,
                onAddNode: _addNodeFromCatalog,
                onAddNodeAt: _addNode,
                onAddVariable: _addVariable,
                onAddVariableNode: _addVariableNode,
                onUpdateVariable: _updateVariable,
                onSelectVariable: _selectVariable,
                onAddEvent: _addEvent,
                onAddEventNode: _addEventNode,
                onUpdateEvent: _updateEvent,
                onSelectEvent: _selectEvent,
                onAddFunction: _addFunction,
                onAddFunctionNode: _addFunctionNode,
                onUpdateFunction: _updateFunction,
                onSelectFunction: _selectFunction,
                onOpenFunctionPanel: _openFunctionPanel,
                onOpenFunctionNode: _openFunctionFromNode,
                onCloseFunctionPanel: _closeFunctionPanel,
                onOpenNodeSearch: _openNodeSearch,
                onUpdateSelectedNode: _updateSelectedNode,
                onAutoSizeSelectedComment: _autoSizeSelectedComment,
                onDeleteSelectedNode: _deleteSelectedNode,
                onAddExpandablePin: _addExpandablePinToSelectedNode,
                onDeletePin: _deletePinFromSelectedNode,
                onFocusMemberNode: _focusMemberNode,
                onDocumentChanged: _updateDocument,
                onSelectedNodesChanged: _selectNodes,
              );
            },
          ),
        ),
        if (widget.showScaffoldChrome) _EditorStatusBar(document: _document),
      ],
    );

    final shortcutsBody = _EditorShortcutHost(
      onDeleteSelection: _deleteSelectedNode,
      child: body,
    );

    if (!widget.showScaffoldChrome) {
      return shortcutsBody;
    }

    return Scaffold(body: SafeArea(child: shortcutsBody));
  }

  void _updateDocument(GraphDocument document) {
    setState(() {
      _document = document;
    });
    widget.onDocumentChanged?.call(document);
  }

  void _selectNodes(Set<String> nodeIds) {
    _returnFocusToCanvas();
    final singleNodeId = nodeIds.length == 1 ? nodeIds.single : null;
    final functionFromCallNode = singleNodeId == null
        ? null
        : _functionFromCallNodeId(singleNodeId);
    setState(() {
      _selectedNodeIds = functionFromCallNode == null
          ? Set.unmodifiable(nodeIds)
          : const {};
      _selectedVariableId = null;
      _selectedEventId = null;
      _selectedFunctionId = functionFromCallNode?.id;
      if (functionFromCallNode == null) {
        _openedFunctionId = null;
      }
      _rightPanelMode = functionFromCallNode != null
          ? _RightPanelMode.functionDetails
          : singleNodeId == null
          ? _RightPanelMode.members
          : _RightPanelMode.details;
      if (singleNodeId != null) {
        _pendingNodeWorldPosition = null;
      }
    });
  }

  void _focusMemberNode(_MemberFocusRequest request) {
    final nodes = _findMemberNodes(request);
    if (nodes.isEmpty) {
      return;
    }

    final cursorKey = request.cursorKey;
    final nextIndex = _memberFocusCursor[cursorKey] ?? 0;
    final focusedIndex = nextIndex % nodes.length;
    _memberFocusCursor[cursorKey] = (focusedIndex + 1) % nodes.length;
    _centerViewportOnMemberNodes(nodes, focusedIndex: focusedIndex);
  }

  List<GraphNode> _findMemberNodes(_MemberFocusRequest request) {
    final nodes = <GraphNode>[];
    for (final node in _document.nodes) {
      final matched = switch (request.kind) {
        _MemberFocusKind.variable => _isVariableNodeFor(node, request.name),
        _MemberFocusKind.event =>
          node.nodeType == 'EventCall' && node.title == request.name,
        _MemberFocusKind.function =>
          node.nodeType == 'FunctionCall' && node.title == request.name,
      };
      if (matched) {
        nodes.add(node);
      }
    }
    return nodes;
  }

  bool _isVariableNodeFor(GraphNode node, String variableName) {
    return (node.nodeType == 'VariableGet' &&
            node.title == 'Get $variableName') ||
        (node.nodeType == 'VariableSet' && node.title == 'Set $variableName') ||
        node.pins.any((pin) => pin.title == variableName);
  }

  void _centerViewportOnMemberNodes(
    List<GraphNode> nodes, {
    int focusedIndex = 0,
  }) {
    final node = nodes[focusedIndex.clamp(0, nodes.length - 1)];
    const canvasWidth = 860.0;
    const canvasHeight = 560.0;
    final effectiveSize = GraphCanvasGeometry.effectiveNodeSize(node);
    final zoom = _document.graph.viewport.zoom;
    final nodeCenterX = node.position.x + effectiveSize.width / 2;
    final nodeCenterY = node.position.y + effectiveSize.height / 2;
    final nextViewport = _document.graph.viewport.copyWith(
      offsetX: canvasWidth / 2 - nodeCenterX * zoom,
      offsetY: canvasHeight / 2 - nodeCenterY * zoom,
    );
    final nextDocument = _document.copyWith(
      graph: _document.graph.copyWith(
        viewport: nextViewport,
        updatedAt: DateTime.now(),
      ),
    );

    setState(() {
      _document = nextDocument;
      _selectedNodeIds = nodes.map((node) => node.id).toSet();
      _pendingNodeWorldPosition = null;
    });
    widget.onDocumentChanged?.call(nextDocument);
  }

  void _addNode(String templateId, {GraphCanvasPoint? worldPosition}) {
    _returnFocusToCanvas();
    final template =
        UnrealNodeCatalog.findInNodeBook(widget.engineNodeBookId, templateId) ??
        UnrealNodeCatalog.findNodeBook(widget.engineNodeBookId).templates.first;
    final createdIndex = _document.nodes.length + 1;
    final nodeId = 'node_${DateTime.now().microsecondsSinceEpoch}';
    final selectedNodes = _document.nodes
        .where((node) => _selectedNodeIds.contains(node.id))
        .toList(growable: false);
    final commentFrame = template.id == 'comment' && selectedNodes.isNotEmpty
        ? GraphCanvasGeometry.commentFrameForNodes(selectedNodes)
        : null;
    final nextNode = GraphNode(
      id: nodeId,
      nodeType: template.nodeType,
      title: template.title,
      description: template.description,
      position: commentFrame != null
          ? GraphNodePosition(x: commentFrame.left, y: commentFrame.top)
          : worldPosition == null
          ? GraphNodePosition(
              x: 120 + (createdIndex - 1) * 34,
              y: 120 + (createdIndex - 1) * 24,
            )
          : GraphNodePosition(x: worldPosition.x, y: worldPosition.y),
      size: commentFrame != null
          ? GraphNodeSize(
              width: commentFrame.width,
              height: commentFrame.height,
            )
          : template.size,
      pins: [
        for (final pin in template.pins)
          pin.copyWith(id: '${nodeId}_${pin.id}'),
      ],
    );

    final nextDocument = _document.copyWith(
      nodes: [..._document.nodes, nextNode],
      graph: _document.graph.copyWith(updatedAt: DateTime.now()),
    );
    setState(() {
      _document = nextDocument;
      _selectedNodeIds = {nodeId};
      _selectedVariableId = null;
      _selectedEventId = null;
      _selectedFunctionId = null;
      _openedFunctionId = null;
      _rightPanelMode = _RightPanelMode.details;
      _pendingNodeWorldPosition = null;
    });
    widget.onDocumentChanged?.call(nextDocument);
  }

  void _addNodeFromCatalog(String templateId) {
    _addNode(templateId, worldPosition: _pendingNodeWorldPosition);
  }

  void _addVariable(GraphVariable variable) {
    final nextDocument = _document.copyWith(
      variables: [..._document.variables, variable],
      graph: _document.graph.copyWith(updatedAt: DateTime.now()),
    );
    setState(() => _document = nextDocument);
    widget.onDocumentChanged?.call(nextDocument);
  }

  void _addVariableNode(
    GraphVariable variable,
    _VariableNodeKind kind, {
    GraphCanvasPoint? worldPosition,
  }) {
    _returnFocusToCanvas();
    final createdIndex = _document.nodes.length + 1;
    final nodeId = 'node_${DateTime.now().microsecondsSinceEpoch}';
    final spawnPosition = worldPosition ?? _pendingNodeWorldPosition;
    final isGetter = kind == _VariableNodeKind.get;
    final nextNode = GraphNode(
      id: nodeId,
      nodeType: isGetter ? 'VariableGet' : 'VariableSet',
      title: '${isGetter ? 'Get' : 'Set'} ${variable.name}',
      description: variable.description.isEmpty
          ? '变量：${variable.name}'
          : variable.description,
      position: spawnPosition == null
          ? GraphNodePosition(
              x: 120 + (createdIndex - 1) * 34,
              y: 120 + (createdIndex - 1) * 24,
            )
          : GraphNodePosition(x: spawnPosition.x, y: spawnPosition.y),
      size: GraphNodeSize(width: isGetter ? 260 : 310, height: 150),
      pins: isGetter
          ? [
              GraphPin(
                id: '${nodeId}_value',
                direction: GraphPinDirection.output,
                title: variable.name,
                dataType: variable.dataType,
              ),
            ]
          : [
              GraphPin(
                id: '${nodeId}_exec',
                direction: GraphPinDirection.input,
                title: 'Exec',
                dataType: 'exec',
              ),
              GraphPin(
                id: '${nodeId}_value',
                direction: GraphPinDirection.input,
                title: variable.name,
                dataType: variable.dataType,
                defaultValue: variable.dataType == 'bool'
                    ? _boolDefaultValue(variable.defaultValue)
                    : variable.defaultValue,
              ),
              GraphPin(
                id: '${nodeId}_then',
                direction: GraphPinDirection.output,
                title: 'Then',
                dataType: 'exec',
                allowMultipleLinks: true,
              ),
            ],
    );

    final nextDocument = _document.copyWith(
      nodes: [..._document.nodes, nextNode],
      graph: _document.graph.copyWith(updatedAt: DateTime.now()),
    );
    setState(() {
      _document = nextDocument;
      _selectedNodeIds = {nodeId};
      _selectedVariableId = null;
      _selectedEventId = null;
      _selectedFunctionId = null;
      _openedFunctionId = null;
      _rightPanelMode = _RightPanelMode.details;
      _pendingNodeWorldPosition = null;
    });
    widget.onDocumentChanged?.call(nextDocument);
  }

  void _updateVariable(GraphVariable nextVariable) {
    final nextVariables = [
      for (final variable in _document.variables)
        if (variable.id == nextVariable.id) nextVariable else variable,
    ];
    final nextDocument = _document.copyWith(
      variables: nextVariables,
      graph: _document.graph.copyWith(updatedAt: DateTime.now()),
    );
    setState(() => _document = nextDocument);
    widget.onDocumentChanged?.call(nextDocument);
  }

  void _selectVariable(GraphVariable variable) {
    _returnFocusToCanvas();
    final memberNodes = _findMemberNodes(
      _MemberFocusRequest(_MemberFocusKind.variable, variable.name),
    );
    setState(() {
      _selectedNodeIds = memberNodes.map((node) => node.id).toSet();
      _selectedVariableId = variable.id;
      _selectedEventId = null;
      _selectedFunctionId = null;
      _rightPanelMode = _RightPanelMode.variableDetails;
      _pendingNodeWorldPosition = null;
    });
  }

  void _addEvent(GraphEvent event) {
    final nextDocument = _document.copyWith(
      events: [..._document.events, event],
      graph: _document.graph.copyWith(updatedAt: DateTime.now()),
    );
    setState(() => _document = nextDocument);
    widget.onDocumentChanged?.call(nextDocument);
  }

  void _updateEvent(GraphEvent nextEvent) {
    final nextEvents = [
      for (final event in _document.events)
        if (event.id == nextEvent.id) nextEvent else event,
    ];
    final nextNodes = [
      for (final node in _document.nodes)
        if (_isEventCallNodeFor(node, nextEvent))
          _eventCallNodeFromEvent(nextEvent, existingNode: node)
        else
          node,
    ];
    final nextDocument = _document.copyWith(
      events: nextEvents,
      nodes: nextNodes,
      graph: _document.graph.copyWith(updatedAt: DateTime.now()),
    );
    setState(() => _document = nextDocument);
    widget.onDocumentChanged?.call(nextDocument);
  }

  void _selectEvent(GraphEvent event) {
    _returnFocusToCanvas();
    final memberNodes = _findMemberNodes(
      _MemberFocusRequest(_MemberFocusKind.event, event.name),
    );
    setState(() {
      _selectedNodeIds = memberNodes.map((node) => node.id).toSet();
      _selectedVariableId = null;
      _selectedEventId = event.id;
      _selectedFunctionId = null;
      _rightPanelMode = _RightPanelMode.eventDetails;
      _pendingNodeWorldPosition = null;
    });
  }

  void _addEventNode(GraphEvent event, {GraphCanvasPoint? worldPosition}) {
    _returnFocusToCanvas();
    final createdIndex = _document.nodes.length + 1;
    final nodeId = 'node_${DateTime.now().microsecondsSinceEpoch}';
    final spawnPosition = worldPosition ?? _pendingNodeWorldPosition;
    final nextNode = _eventCallNodeFromEvent(
      event,
      id: nodeId,
      position: spawnPosition == null
          ? GraphNodePosition(
              x: 120 + (createdIndex - 1) * 34,
              y: 120 + (createdIndex - 1) * 24,
            )
          : GraphNodePosition(x: spawnPosition.x, y: spawnPosition.y),
    );

    final nextDocument = _document.copyWith(
      nodes: [..._document.nodes, nextNode],
      graph: _document.graph.copyWith(updatedAt: DateTime.now()),
    );
    setState(() {
      _document = nextDocument;
      _selectedNodeIds = {nodeId};
      _selectedVariableId = null;
      _selectedEventId = null;
      _selectedFunctionId = null;
      _openedFunctionId = null;
      _rightPanelMode = _RightPanelMode.details;
      _pendingNodeWorldPosition = null;
    });
    widget.onDocumentChanged?.call(nextDocument);
  }

  bool _isEventCallNodeFor(GraphNode node, GraphEvent event) {
    return node.nodeType == 'EventCall' && node.title == event.name;
  }

  GraphNode _eventCallNodeFromEvent(
    GraphEvent event, {
    GraphNode? existingNode,
    String? id,
    GraphNodePosition? position,
  }) {
    final nodeId = existingNode?.id ?? id!;

    return GraphNode(
      id: nodeId,
      nodeType: 'EventCall',
      title: event.name,
      description: event.description.isEmpty
          ? '调用自定义事件：${event.name}'
          : event.description,
      position:
          existingNode?.position ??
          position ??
          const GraphNodePosition(x: 120, y: 120),
      size: const GraphNodeSize(width: 310, height: 150),
      pins: [
        GraphPin(
          id: '${nodeId}_exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
        GraphPin(
          id: '${nodeId}_then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      ],
    );
  }

  void _addFunction(GraphFunction function) {
    final nextDocument = _document.copyWith(
      functions: [..._document.functions, function],
      graph: _document.graph.copyWith(updatedAt: DateTime.now()),
    );
    setState(() => _document = nextDocument);
    widget.onDocumentChanged?.call(nextDocument);
  }

  void _updateFunction(GraphFunction nextFunction) {
    final nextFunctions = [
      for (final function in _document.functions)
        if (function.id == nextFunction.id) nextFunction else function,
    ];
    final nextNodes = [
      for (final node in _document.nodes)
        if (_isFunctionCallNodeFor(node, nextFunction))
          _functionCallNodeFromFunction(nextFunction, existingNode: node)
        else
          node,
    ];
    final validNodePinIds = <String, Set<String>>{
      for (final node in nextNodes)
        node.id: node.pins.map((pin) => pin.id).toSet(),
    };
    final nextLinks = [
      for (final link in _document.links)
        if ((validNodePinIds[link.fromNodeId]?.contains(link.fromPinId) ??
                false) &&
            (validNodePinIds[link.toNodeId]?.contains(link.toPinId) ?? false))
          link,
    ];
    final nextDocument = _document.copyWith(
      functions: nextFunctions,
      nodes: nextNodes,
      links: nextLinks,
      graph: _document.graph.copyWith(updatedAt: DateTime.now()),
    );
    setState(() => _document = nextDocument);
    widget.onDocumentChanged?.call(nextDocument);
  }

  void _selectFunction(GraphFunction function) {
    _returnFocusToCanvas();
    final memberNodes = _findMemberNodes(
      _MemberFocusRequest(_MemberFocusKind.function, function.name),
    );
    setState(() {
      _selectedNodeIds = memberNodes.map((node) => node.id).toSet();
      _selectedVariableId = null;
      _selectedEventId = null;
      _selectedFunctionId = function.id;
      _rightPanelMode = _RightPanelMode.functionDetails;
      _pendingNodeWorldPosition = null;
    });
  }

  void _openFunctionPanel(GraphFunction function) {
    _returnFocusToCanvas();
    setState(() {
      _selectedNodeIds = const {};
      _selectedVariableId = null;
      _selectedEventId = null;
      _selectedFunctionId = function.id;
      _openedFunctionId = function.id;
      _rightPanelMode = _RightPanelMode.members;
      _pendingNodeWorldPosition = null;
    });
  }

  void _closeFunctionPanel() {
    _returnFocusToCanvas();
    setState(() {
      _selectedNodeIds = const {};
      _selectedVariableId = null;
      _selectedEventId = null;
      _selectedFunctionId = null;
      _openedFunctionId = null;
      _rightPanelMode = _RightPanelMode.members;
      _pendingNodeWorldPosition = null;
    });
  }

  void _openFunctionFromNode(GraphNode node) {
    if (node.nodeType != 'FunctionCall') {
      return;
    }

    final function = _functionFromCallNode(node);
    if (function != null) {
      _openFunctionPanel(function);
    }
  }

  GraphFunction? _functionFromCallNodeId(String nodeId) {
    for (final node in _document.nodes) {
      if (node.id == nodeId) {
        return _functionFromCallNode(node);
      }
    }
    return null;
  }

  GraphFunction? _functionFromCallNode(GraphNode node) {
    if (node.nodeType != 'FunctionCall') {
      return null;
    }

    final title = node.title.trim();
    for (final function in _document.functions) {
      if (function.name == title) {
        return function;
      }
    }
    return null;
  }

  void _addFunctionNode(
    GraphFunction function, {
    GraphCanvasPoint? worldPosition,
  }) {
    _returnFocusToCanvas();
    final createdIndex = _document.nodes.length + 1;
    final nodeId = 'node_${DateTime.now().microsecondsSinceEpoch}';
    final spawnPosition = worldPosition ?? _pendingNodeWorldPosition;
    final nextNode = _functionCallNodeFromFunction(
      function,
      id: nodeId,
      position: spawnPosition == null
          ? GraphNodePosition(
              x: 120 + (createdIndex - 1) * 34,
              y: 120 + (createdIndex - 1) * 24,
            )
          : GraphNodePosition(x: spawnPosition.x, y: spawnPosition.y),
    );

    final nextDocument = _document.copyWith(
      nodes: [..._document.nodes, nextNode],
      graph: _document.graph.copyWith(updatedAt: DateTime.now()),
    );
    setState(() {
      _document = nextDocument;
      _selectedNodeIds = {nodeId};
      _selectedVariableId = null;
      _selectedEventId = null;
      _selectedFunctionId = null;
      _openedFunctionId = null;
      _rightPanelMode = _RightPanelMode.details;
      _pendingNodeWorldPosition = null;
    });
    widget.onDocumentChanged?.call(nextDocument);
  }

  bool _isFunctionCallNodeFor(GraphNode node, GraphFunction function) {
    return node.nodeType == 'FunctionCall' && node.title == function.name;
  }

  GraphNode _functionCallNodeFromFunction(
    GraphFunction function, {
    GraphNode? existingNode,
    String? id,
    GraphNodePosition? position,
  }) {
    final nodeId = existingNode?.id ?? id!;
    final pins = <GraphPin>[
      if (!function.pure)
        GraphPin(
          id: '${nodeId}_exec',
          direction: GraphPinDirection.input,
          title: 'Exec',
          dataType: 'exec',
        ),
      for (final input in function.inputs)
        GraphPin(
          id: '${nodeId}_in_${input.id}',
          direction: GraphPinDirection.input,
          title: input.name,
          dataType: input.dataType,
          defaultValue: input.defaultValue,
        ),
      if (!function.pure)
        GraphPin(
          id: '${nodeId}_then',
          direction: GraphPinDirection.output,
          title: 'Then',
          dataType: 'exec',
          allowMultipleLinks: true,
        ),
      for (final output in function.outputs)
        GraphPin(
          id: '${nodeId}_out_${output.id}',
          direction: GraphPinDirection.output,
          title: output.name,
          dataType: output.dataType,
        ),
    ];
    final pinRows = pins.length < 2 ? 2 : pins.length;

    return GraphNode(
      id: nodeId,
      nodeType: 'FunctionCall',
      title: function.name,
      description: function.description.isEmpty
          ? '调用函数：${function.name}'
          : function.description,
      position:
          existingNode?.position ??
          position ??
          const GraphNodePosition(x: 120, y: 120),
      size: GraphNodeSize(
        width: function.pure ? 280 : 320,
        height: 118 + pinRows * 26,
      ),
      pins: pins,
    );
  }

  String _boolDefaultValue(String value) {
    return value.toLowerCase() == 'true' ? 'true' : 'false';
  }

  void _openNodeSearch(Offset _, GraphCanvasPoint worldPosition) {
    _returnFocusToCanvas();
    setState(() {
      _selectedNodeIds = const {};
      _selectedVariableId = null;
      _selectedEventId = null;
      _selectedFunctionId = null;
      _openedFunctionId = null;
      _rightPanelMode = _RightPanelMode.catalog;
      _pendingNodeWorldPosition = worldPosition;
    });
  }

  void _updateSelectedNode(GraphNode nextNode) {
    if (_selectedNodeIds.length != 1) {
      return;
    }
    final nodeId = _selectedNodeIds.single;

    var changed = false;
    final nextNodes = [
      for (final node in _document.nodes)
        if (node.id == nodeId) ...[nextNode] else node,
    ];

    for (var index = 0; index < _document.nodes.length; index++) {
      if (!identical(_document.nodes[index], nextNodes[index])) {
        changed = true;
        break;
      }
    }
    if (!changed) {
      return;
    }

    _replaceDocument(
      _document.copyWith(
        nodes: nextNodes,
        graph: _document.graph.copyWith(updatedAt: DateTime.now()),
      ),
    );
  }

  void _autoSizeSelectedComment() {
    final node = _selectedNode;
    if (node == null || node.nodeType != 'Comment') {
      return;
    }

    final containedIds = GraphCanvasGeometry.nodeIdsInsideComment(
      comment: node,
      nodes: _document.nodes,
    );
    if (containedIds.isEmpty) {
      return;
    }

    final containedNodes = _document.nodes
        .where((candidate) => containedIds.contains(candidate.id))
        .toList(growable: false);
    final frame = GraphCanvasGeometry.commentFrameForNodes(containedNodes);
    _updateSelectedNode(
      node.copyWith(
        position: GraphNodePosition(x: frame.left, y: frame.top),
        size: GraphNodeSize(width: frame.width, height: frame.height),
      ),
    );
  }

  void _deleteSelectedNode() {
    final nodeIds = _selectedNodeIds;
    if (nodeIds.isEmpty) {
      return;
    }

    final nextDocument = _document.copyWith(
      nodes: _document.nodes
          .where((node) => !nodeIds.contains(node.id))
          .toList(growable: false),
      links: _document.links
          .where(
            (link) =>
                !nodeIds.contains(link.fromNodeId) &&
                !nodeIds.contains(link.toNodeId),
          )
          .toList(growable: false),
      graph: _document.graph.copyWith(updatedAt: DateTime.now()),
    );

    setState(() {
      _document = nextDocument;
      _selectedNodeIds = const {};
      _selectedVariableId = null;
      _selectedEventId = null;
      _selectedFunctionId = null;
      _rightPanelMode = _RightPanelMode.members;
      _pendingNodeWorldPosition = null;
    });
    widget.onDocumentChanged?.call(nextDocument);
    _returnFocusToCanvas();
  }

  void _returnFocusToCanvas() {
    ImeControl.setEnabled(false);
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _canvasFocusNode.requestFocus();
      }
    });
  }

  void _addExpandablePinToSelectedNode(ExpandablePinGroup group) {
    final node = _selectedNode;
    if (node == null) {
      return;
    }

    final groupPins = node.pins
        .where((pin) => _isExpandableGroupPin(pin.id, group.idPrefix))
        .toList(growable: false);
    final pinNumber = group.startIndex + groupPins.length;
    final pinId = '${node.id}_${group.idPrefix}_$pinNumber';
    final pin = GraphPin(
      id: pinId,
      direction: group.direction,
      title: '${group.titlePrefix} $pinNumber',
      dataType: group.dataType,
      allowMultipleLinks: group.allowMultipleLinks,
    );
    final nextHeight = node.size.height < 180 ? 180.0 : node.size.height + 18;

    _updateSelectedNode(
      node.copyWith(
        pins: [...node.pins, pin],
        size: node.size.copyWith(height: nextHeight),
      ),
    );
  }

  bool _isExpandableGroupPin(String pinId, String idPrefix) {
    final marker = '${idPrefix}_';
    final markerIndex = pinId.lastIndexOf(marker);
    if (markerIndex < 0) {
      return false;
    }

    return int.tryParse(pinId.substring(markerIndex + marker.length)) != null;
  }

  void _deletePinFromSelectedNode(String pinId) {
    final node = _selectedNode;
    if (node == null) {
      return;
    }

    final nextNode = node.copyWith(
      pins: node.pins.where((pin) => pin.id != pinId).toList(growable: false),
    );
    final nextNodes = [
      for (final current in _document.nodes)
        if (current.id == node.id) nextNode else current,
    ];
    final nextLinks = _document.links
        .where((link) => link.fromPinId != pinId && link.toPinId != pinId)
        .toList(growable: false);

    _replaceDocument(
      _document.copyWith(
        nodes: nextNodes,
        links: nextLinks,
        graph: _document.graph.copyWith(updatedAt: DateTime.now()),
      ),
    );
  }

  void _replaceDocument(GraphDocument document) {
    setState(() {
      _document = document;
    });
    widget.onDocumentChanged?.call(document);
  }
}

class _DeleteSelectionIntent extends Intent {
  const _DeleteSelectionIntent();
}

class _EditorShortcutHost extends StatelessWidget {
  const _EditorShortcutHost({
    required this.onDeleteSelection,
    required this.child,
  });

  final VoidCallback onDeleteSelection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.delete): _DeleteSelectionIntent(),
        SingleActivator(LogicalKeyboardKey.backspace): _DeleteSelectionIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _DeleteSelectionIntent: CallbackAction<_DeleteSelectionIntent>(
            onInvoke: (_) {
              onDeleteSelection();
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

enum _RightPanelMode {
  members,
  details,
  variableDetails,
  eventDetails,
  functionDetails,
  catalog,
}

enum _VariableNodeKind { get, set }

typedef _VariableNodeCreator =
    void Function(
      GraphVariable variable,
      _VariableNodeKind kind, {
      GraphCanvasPoint? worldPosition,
    });

typedef _FunctionNodeCreator =
    void Function(GraphFunction function, {GraphCanvasPoint? worldPosition});

typedef _EventNodeCreator =
    void Function(GraphEvent event, {GraphCanvasPoint? worldPosition});

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xF4FFFFFF),
        border: const Border(bottom: BorderSide(color: Color(0xFFD7E7F8))),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_tree_outlined),
          const SizedBox(width: 12),
          Text('虚幻：蓝图连结', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('新建'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDBEAFE),
              foregroundColor: const Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.folder_open),
            label: const Text('打开'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopEditorShell extends StatelessWidget {
  const _DesktopEditorShell({
    required this.document,
    required this.nodeBook,
    required this.selectedNode,
    required this.selectedVariable,
    required this.selectedEvent,
    required this.selectedFunction,
    required this.openedFunction,
    required this.selectedNodeIds,
    required this.rightPanelMode,
    required this.compact,
    required this.showJsonPreview,
    required this.events,
    required this.canvasDrafts,
    required this.activeCanvasKey,
    required this.canvasFocusNode,
    required this.onCanvasDraftSelected,
    required this.onResetActiveCanvas,
    required this.onAddNode,
    required this.onAddNodeAt,
    required this.onAddVariable,
    required this.onAddVariableNode,
    required this.onUpdateVariable,
    required this.onSelectVariable,
    required this.onAddEvent,
    required this.onAddEventNode,
    required this.onUpdateEvent,
    required this.onSelectEvent,
    required this.onAddFunction,
    required this.onAddFunctionNode,
    required this.onUpdateFunction,
    required this.onSelectFunction,
    required this.onOpenFunctionPanel,
    required this.onOpenFunctionNode,
    required this.onCloseFunctionPanel,
    required this.onOpenNodeSearch,
    required this.onUpdateSelectedNode,
    required this.onAutoSizeSelectedComment,
    required this.onDeleteSelectedNode,
    required this.onAddExpandablePin,
    required this.onDeletePin,
    required this.onFocusMemberNode,
    required this.onDocumentChanged,
    required this.onSelectedNodesChanged,
  });

  final GraphDocument document;
  final EngineNodeBook nodeBook;
  final GraphNode? selectedNode;
  final GraphVariable? selectedVariable;
  final GraphEvent? selectedEvent;
  final GraphFunction? selectedFunction;
  final GraphFunction? openedFunction;
  final Set<String> selectedNodeIds;
  final _RightPanelMode rightPanelMode;
  final bool compact;
  final bool showJsonPreview;
  final List<GraphEvent> events;
  final List<CanvasDraft> canvasDrafts;
  final String? activeCanvasKey;
  final FocusNode canvasFocusNode;
  final ValueChanged<String>? onCanvasDraftSelected;
  final VoidCallback? onResetActiveCanvas;
  final void Function(String templateId) onAddNode;
  final void Function(String templateId, {GraphCanvasPoint? worldPosition})
  onAddNodeAt;
  final ValueChanged<GraphVariable> onAddVariable;
  final _VariableNodeCreator onAddVariableNode;
  final ValueChanged<GraphVariable> onUpdateVariable;
  final ValueChanged<GraphVariable> onSelectVariable;
  final ValueChanged<GraphEvent> onAddEvent;
  final _EventNodeCreator onAddEventNode;
  final ValueChanged<GraphEvent> onUpdateEvent;
  final ValueChanged<GraphEvent> onSelectEvent;
  final ValueChanged<GraphFunction> onAddFunction;
  final _FunctionNodeCreator onAddFunctionNode;
  final ValueChanged<GraphFunction> onUpdateFunction;
  final ValueChanged<GraphFunction> onSelectFunction;
  final ValueChanged<GraphFunction> onOpenFunctionPanel;
  final ValueChanged<GraphNode> onOpenFunctionNode;
  final VoidCallback onCloseFunctionPanel;
  final void Function(Offset screenPosition, GraphCanvasPoint worldPosition)
  onOpenNodeSearch;
  final ValueChanged<GraphNode> onUpdateSelectedNode;
  final VoidCallback onAutoSizeSelectedComment;
  final VoidCallback onDeleteSelectedNode;
  final ValueChanged<ExpandablePinGroup> onAddExpandablePin;
  final ValueChanged<String> onDeletePin;
  final ValueChanged<_MemberFocusRequest> onFocusMemberNode;
  final ValueChanged<GraphDocument> onDocumentChanged;
  final ValueChanged<Set<String>> onSelectedNodesChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (openedFunction != null) {
                return _FunctionGraphPanel(
                  openedFunction: openedFunction!,
                  functions: document.functions,
                  onBack: onCloseFunctionPanel,
                  onFunctionSelected: onSelectFunction,
                  onFunctionOpened: onOpenFunctionPanel,
                );
              }

              return DragTarget<GraphEvent>(
                onAcceptWithDetails: (details) => onAddEventNode(
                  details.data,
                  worldPosition: _dropWorldPosition(
                    context,
                    details.offset,
                    constraints.biggest,
                  ),
                ),
                builder: (context, eventCandidates, rejectedEvents) {
                  return DragTarget<GraphFunction>(
                    onAcceptWithDetails: (details) => onAddFunctionNode(
                      details.data,
                      worldPosition: _dropWorldPosition(
                        context,
                        details.offset,
                        constraints.biggest,
                      ),
                    ),
                    builder: (context, functionCandidates, rejectedFunctions) {
                      return DragTarget<GraphVariable>(
                        onAcceptWithDetails: (details) => _showVariableDropMenu(
                          context,
                          details.data,
                          details.offset,
                          constraints.biggest,
                        ),
                        builder:
                            (context, variableCandidates, rejectedVariables) {
                              final draggingMember =
                                  eventCandidates.isNotEmpty ||
                                  functionCandidates.isNotEmpty ||
                                  variableCandidates.isNotEmpty;
                              return Stack(
                                children: [
                                  Positioned.fill(
                                    child: GraphCanvas(
                                      document: document,
                                      selectedNodeIds: selectedNodeIds,
                                      focusNode: canvasFocusNode,
                                      onDocumentChanged: onDocumentChanged,
                                      onSelectedNodesChanged:
                                          onSelectedNodesChanged,
                                      onNodeDoubleTapped: onOpenFunctionNode,
                                      onOpenNodeSearch: onOpenNodeSearch,
                                      onShortcutNodeRequested:
                                          (templateId, worldPosition) =>
                                              onAddNodeAt(
                                                templateId,
                                                worldPosition: worldPosition,
                                              ),
                                    ),
                                  ),
                                  if (draggingMember)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF60A5FA,
                                            ).withValues(alpha: 0.08),
                                            border: Border.all(
                                              color: const Color(0xFF3B82F6),
                                              width: 1.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (canvasDrafts.isNotEmpty)
                                    Positioned(
                                      right: 18,
                                      bottom: 18,
                                      child: SizedBox(
                                        width: 270,
                                        height: 62,
                                        child: _FloatingCanvasNavigator(
                                          activeDraft: _activeDraft,
                                          drafts: canvasDrafts,
                                          activeKey: activeCanvasKey,
                                          onDraftSelected:
                                              onCanvasDraftSelected,
                                          onResetActiveCanvas:
                                              onResetActiveCanvas,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 340,
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: SizedBox(
                width: 340,
                child: _RightSidePanel(
                  mode: rightPanelMode,
                  document: document,
                  nodeBook: nodeBook,
                  selectedNode: selectedNode,
                  selectedVariable: selectedVariable,
                  selectedEvent: selectedEvent,
                  selectedFunction: selectedFunction,
                  openedFunction: openedFunction,
                  showJsonPreview: showJsonPreview,
                  variables: document.variables,
                  functions: document.functions,
                  events: events,
                  onTemplateSelected: onAddNode,
                  onVariableCreated: onAddVariable,
                  onVariableNodeSelected: onAddVariableNode,
                  onVariableChanged: onUpdateVariable,
                  onVariableSelected: onSelectVariable,
                  onEventCreated: onAddEvent,
                  onEventNodeSelected: onAddEventNode,
                  onEventChanged: onUpdateEvent,
                  onEventSelected: onSelectEvent,
                  onFunctionCreated: onAddFunction,
                  onFunctionNodeSelected: onAddFunctionNode,
                  onFunctionChanged: onUpdateFunction,
                  onFunctionSelected: onSelectFunction,
                  onFunctionOpened: onOpenFunctionPanel,
                  onFunctionPanelClosed: onCloseFunctionPanel,
                  onNodeChanged: onUpdateSelectedNode,
                  onAutoSizeComment: onAutoSizeSelectedComment,
                  onAddExpandablePin: onAddExpandablePin,
                  onDeletePin: onDeletePin,
                  onFocusMemberNode: onFocusMemberNode,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  GraphCanvasPoint _dropWorldPosition(
    BuildContext context,
    Offset globalPosition,
    Size size,
  ) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(globalPosition);
    final clamped = Offset(
      local.dx.clamp(0, size.width).toDouble(),
      local.dy.clamp(0, size.height).toDouble(),
    );
    return GraphCanvasGeometry.screenToWorld(
      GraphCanvasPoint(clamped.dx, clamped.dy),
      document.graph.viewport,
    );
  }

  CanvasDraft? get _activeDraft {
    final key = activeCanvasKey;
    if (key == null) {
      return null;
    }

    for (final draft in canvasDrafts) {
      if (draft.key == key) {
        return draft;
      }
    }

    return null;
  }

  Future<void> _showVariableDropMenu(
    BuildContext context,
    GraphVariable variable,
    Offset globalOffset,
    Size canvasSize,
  ) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final local = box.globalToLocal(globalOffset);
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > canvasSize.width ||
        local.dy > canvasSize.height) {
      return;
    }
    final worldPosition = _dropWorldPosition(context, globalOffset, canvasSize);

    final selectedKind = await showMenu<_VariableNodeKind>(
      context: context,
      color: const Color(0xFFFAFCFF),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFD7E7F8)),
      ),
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
      position: RelativeRect.fromLTRB(
        globalOffset.dx,
        globalOffset.dy,
        globalOffset.dx,
        globalOffset.dy,
      ),
      items: [
        PopupMenuItem(
          value: _VariableNodeKind.get,
          height: 42,
          padding: EdgeInsets.zero,
          child: _VariableDropMenuItem(
            iconKey: const ValueKey('variable-drop-menu-get-icon'),
            icon: Icons.input_rounded,
            color: const Color(0xFF2563EB),
            label: '获取变量',
          ),
        ),
        PopupMenuItem(
          value: _VariableNodeKind.set,
          height: 42,
          padding: EdgeInsets.zero,
          child: _VariableDropMenuItem(
            iconKey: const ValueKey('variable-drop-menu-set-icon'),
            icon: Icons.output_rounded,
            color: const Color(0xFF16A34A),
            label: '设置变量',
          ),
        ),
      ],
    );
    if (selectedKind == null) {
      return;
    }

    onAddVariableNode(variable, selectedKind, worldPosition: worldPosition);
  }
}

class _VariableDropMenuItem extends StatelessWidget {
  const _VariableDropMenuItem({
    required this.iconKey,
    required this.icon,
    required this.color,
    required this.label,
  });

  final Key iconKey;
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        children: [
          Container(
            key: iconKey,
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: color.withValues(alpha: 0.34)),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF102033),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingCanvasNavigator extends StatelessWidget {
  const _FloatingCanvasNavigator({
    required this.activeDraft,
    required this.drafts,
    required this.activeKey,
    required this.onDraftSelected,
    required this.onResetActiveCanvas,
  });

  final CanvasDraft? activeDraft;
  final List<CanvasDraft> drafts;
  final String? activeKey;
  final ValueChanged<String>? onDraftSelected;
  final VoidCallback? onResetActiveCanvas;

  @override
  Widget build(BuildContext context) {
    final draft = activeDraft;

    return Material(
      key: const ValueKey('floating-canvas-navigator'),
      color: Colors.white.withValues(alpha: 0.96),
      elevation: 12,
      shadowColor: const Color(0xFF1E3A8A).withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFBFDBFE)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: '画布导航',
        child: InkWell(
          onTap: () => _showDraftSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF38BDF8)],
                    ),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft == null
                            ? '画布导航'
                            : '${draft.assetName} / ${draft.graphName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF102033),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${drafts.length} 张草稿',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF526276),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_up, color: Color(0xFF2563EB)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDraftSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF8FBFF),
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.dashboard_customize_outlined,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '画布草稿',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF102033),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    _DraftCountPill(count: drafts.length),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: drafts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final draft = drafts[index];

                      return _CanvasDraftTile(
                        draft: draft,
                        selected: draft.key == activeKey,
                        onTap: onDraftSelected == null
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                onDraftSelected?.call(draft.key);
                              },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onResetActiveCanvas == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onResetActiveCanvas?.call();
                        },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('重置当前画布'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CanvasDraftTile extends StatelessWidget {
  const _CanvasDraftTile({
    required this.draft,
    required this.selected,
    required this.onTap,
  });

  final CanvasDraft draft;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = draft.graphName.trim().isEmpty
        ? draft.assetName
        : draft.graphName;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE),
          width: selected ? 1.4 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: selected ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF2563EB)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF38BDF8)],
                    ),
                  ),
                  child: const Icon(
                    Icons.polyline_outlined,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: const Color(0xFF102033),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 6),
                            const _CurrentDraftPill(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _assetLabel(draft.assetName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _pathLabel(draft.assetPath),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF526276),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _assetLabel(String assetName) {
    return assetName.trim().isEmpty ? '未记录蓝图资产' : assetName;
  }

  String _pathLabel(String assetPath) {
    if (assetPath.startsWith('legacy:')) {
      return '旧单画布缓存';
    }

    return assetPath.isEmpty ? '未记录来源' : assetPath;
  }
}

class _CurrentDraftPill extends StatelessWidget {
  const _CurrentDraftPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          '当前',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF2563EB),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _DraftCountPill extends StatelessWidget {
  const _DraftCountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          count.toString(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF2563EB),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CompactEditorShell extends StatelessWidget {
  const _CompactEditorShell({
    required this.document,
    required this.nodeBook,
    required this.selectedNode,
    required this.selectedVariable,
    required this.selectedEvent,
    required this.selectedFunction,
    required this.openedFunction,
    required this.selectedNodeIds,
    required this.rightPanelMode,
    required this.showJsonPreview,
    required this.events,
    required this.canvasDrafts,
    required this.activeCanvasKey,
    required this.canvasFocusNode,
    required this.onCanvasDraftSelected,
    required this.onResetActiveCanvas,
    required this.onAddNode,
    required this.onAddNodeAt,
    required this.onAddVariable,
    required this.onAddVariableNode,
    required this.onUpdateVariable,
    required this.onSelectVariable,
    required this.onAddEvent,
    required this.onAddEventNode,
    required this.onUpdateEvent,
    required this.onSelectEvent,
    required this.onAddFunction,
    required this.onAddFunctionNode,
    required this.onUpdateFunction,
    required this.onSelectFunction,
    required this.onOpenFunctionPanel,
    required this.onOpenFunctionNode,
    required this.onCloseFunctionPanel,
    required this.onOpenNodeSearch,
    required this.onUpdateSelectedNode,
    required this.onAutoSizeSelectedComment,
    required this.onDeleteSelectedNode,
    required this.onAddExpandablePin,
    required this.onDeletePin,
    required this.onFocusMemberNode,
    required this.onDocumentChanged,
    required this.onSelectedNodesChanged,
  });

  final GraphDocument document;
  final EngineNodeBook nodeBook;
  final GraphNode? selectedNode;
  final GraphVariable? selectedVariable;
  final GraphEvent? selectedEvent;
  final GraphFunction? selectedFunction;
  final GraphFunction? openedFunction;
  final Set<String> selectedNodeIds;
  final _RightPanelMode rightPanelMode;
  final bool showJsonPreview;
  final List<GraphEvent> events;
  final List<CanvasDraft> canvasDrafts;
  final String? activeCanvasKey;
  final FocusNode canvasFocusNode;
  final ValueChanged<String>? onCanvasDraftSelected;
  final VoidCallback? onResetActiveCanvas;
  final void Function(String templateId) onAddNode;
  final void Function(String templateId, {GraphCanvasPoint? worldPosition})
  onAddNodeAt;
  final ValueChanged<GraphVariable> onAddVariable;
  final _VariableNodeCreator onAddVariableNode;
  final ValueChanged<GraphVariable> onUpdateVariable;
  final ValueChanged<GraphVariable> onSelectVariable;
  final ValueChanged<GraphEvent> onAddEvent;
  final _EventNodeCreator onAddEventNode;
  final ValueChanged<GraphEvent> onUpdateEvent;
  final ValueChanged<GraphEvent> onSelectEvent;
  final ValueChanged<GraphFunction> onAddFunction;
  final _FunctionNodeCreator onAddFunctionNode;
  final ValueChanged<GraphFunction> onUpdateFunction;
  final ValueChanged<GraphFunction> onSelectFunction;
  final ValueChanged<GraphFunction> onOpenFunctionPanel;
  final ValueChanged<GraphNode> onOpenFunctionNode;
  final VoidCallback onCloseFunctionPanel;
  final void Function(Offset screenPosition, GraphCanvasPoint worldPosition)
  onOpenNodeSearch;
  final ValueChanged<GraphNode> onUpdateSelectedNode;
  final VoidCallback onAutoSizeSelectedComment;
  final VoidCallback onDeleteSelectedNode;
  final ValueChanged<ExpandablePinGroup> onAddExpandablePin;
  final ValueChanged<String> onDeletePin;
  final ValueChanged<_MemberFocusRequest> onFocusMemberNode;
  final ValueChanged<GraphDocument> onDocumentChanged;
  final ValueChanged<Set<String>> onSelectedNodesChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: openedFunction == null
              ? GraphCanvas(
                  document: document,
                  selectedNodeIds: selectedNodeIds,
                  focusNode: canvasFocusNode,
                  onDocumentChanged: onDocumentChanged,
                  onSelectedNodesChanged: onSelectedNodesChanged,
                  onNodeDoubleTapped: onOpenFunctionNode,
                  onOpenNodeSearch: onOpenNodeSearch,
                  onShortcutNodeRequested: (templateId, worldPosition) =>
                      onAddNodeAt(templateId, worldPosition: worldPosition),
                )
              : _FunctionGraphPanel(
                  openedFunction: openedFunction!,
                  functions: document.functions,
                  onBack: onCloseFunctionPanel,
                  onFunctionSelected: onSelectFunction,
                  onFunctionOpened: onOpenFunctionPanel,
                ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton.filledTonal(
                    onPressed: () => onOpenNodeSearch(
                      Offset.zero,
                      GraphCanvasPoint(120, 120),
                    ),
                    icon: const Icon(Icons.add_box_outlined),
                    tooltip: '节点目录',
                  ),
                  IconButton.filledTonal(
                    onPressed: () {},
                    icon: const Icon(Icons.tune),
                    tooltip: '检查器',
                  ),
                  IconButton.filledTonal(
                    onPressed: () {},
                    icon: const Icon(Icons.hub_outlined),
                    tooltip: '连线',
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          top: 0,
          right: 0,
          bottom: 0,
          width: 320,
          child: SafeArea(
            left: false,
            child: _RightSidePanel(
              mode: rightPanelMode,
              document: document,
              nodeBook: nodeBook,
              selectedNode: selectedNode,
              selectedVariable: selectedVariable,
              selectedEvent: selectedEvent,
              selectedFunction: selectedFunction,
              openedFunction: openedFunction,
              showJsonPreview: showJsonPreview,
              variables: document.variables,
              functions: document.functions,
              events: events,
              onTemplateSelected: onAddNode,
              onVariableCreated: onAddVariable,
              onVariableNodeSelected: onAddVariableNode,
              onVariableChanged: onUpdateVariable,
              onVariableSelected: onSelectVariable,
              onEventCreated: onAddEvent,
              onEventNodeSelected: onAddEventNode,
              onEventChanged: onUpdateEvent,
              onEventSelected: onSelectEvent,
              onFunctionCreated: onAddFunction,
              onFunctionNodeSelected: onAddFunctionNode,
              onFunctionChanged: onUpdateFunction,
              onFunctionSelected: onSelectFunction,
              onFunctionOpened: onOpenFunctionPanel,
              onFunctionPanelClosed: onCloseFunctionPanel,
              onNodeChanged: onUpdateSelectedNode,
              onAutoSizeComment: onAutoSizeSelectedComment,
              onAddExpandablePin: onAddExpandablePin,
              onDeletePin: onDeletePin,
              onFocusMemberNode: onFocusMemberNode,
            ),
          ),
        ),
        if (canvasDrafts.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 82,
            child: SizedBox(
              width: 246,
              height: 62,
              child: _FloatingCanvasNavigator(
                activeDraft: _activeDraft,
                drafts: canvasDrafts,
                activeKey: activeCanvasKey,
                onDraftSelected: onCanvasDraftSelected,
                onResetActiveCanvas: onResetActiveCanvas,
              ),
            ),
          ),
      ],
    );
  }

  CanvasDraft? get _activeDraft {
    final key = activeCanvasKey;
    if (key == null) {
      return null;
    }

    for (final draft in canvasDrafts) {
      if (draft.key == key) {
        return draft;
      }
    }

    return null;
  }
}

class _RightSidePanel extends StatelessWidget {
  const _RightSidePanel({
    required this.mode,
    required this.document,
    required this.nodeBook,
    required this.selectedNode,
    required this.selectedVariable,
    required this.selectedEvent,
    required this.selectedFunction,
    required this.openedFunction,
    required this.showJsonPreview,
    required this.variables,
    required this.functions,
    required this.events,
    required this.onTemplateSelected,
    required this.onVariableCreated,
    required this.onVariableNodeSelected,
    required this.onVariableChanged,
    required this.onVariableSelected,
    required this.onEventCreated,
    required this.onEventNodeSelected,
    required this.onEventChanged,
    required this.onEventSelected,
    required this.onFunctionCreated,
    required this.onFunctionNodeSelected,
    required this.onFunctionChanged,
    required this.onFunctionSelected,
    required this.onFunctionOpened,
    required this.onFunctionPanelClosed,
    required this.onNodeChanged,
    required this.onAutoSizeComment,
    required this.onAddExpandablePin,
    required this.onDeletePin,
    required this.onFocusMemberNode,
  });

  final _RightPanelMode mode;
  final GraphDocument document;
  final EngineNodeBook nodeBook;
  final GraphNode? selectedNode;
  final GraphVariable? selectedVariable;
  final GraphEvent? selectedEvent;
  final GraphFunction? selectedFunction;
  final GraphFunction? openedFunction;
  final bool showJsonPreview;
  final List<GraphVariable> variables;
  final List<GraphFunction> functions;
  final List<GraphEvent> events;
  final ValueChanged<String> onTemplateSelected;
  final ValueChanged<GraphVariable> onVariableCreated;
  final _VariableNodeCreator onVariableNodeSelected;
  final ValueChanged<GraphVariable> onVariableChanged;
  final ValueChanged<GraphVariable> onVariableSelected;
  final ValueChanged<GraphEvent> onEventCreated;
  final _EventNodeCreator onEventNodeSelected;
  final ValueChanged<GraphEvent> onEventChanged;
  final ValueChanged<GraphEvent> onEventSelected;
  final ValueChanged<GraphFunction> onFunctionCreated;
  final _FunctionNodeCreator onFunctionNodeSelected;
  final ValueChanged<GraphFunction> onFunctionChanged;
  final ValueChanged<GraphFunction> onFunctionSelected;
  final ValueChanged<GraphFunction> onFunctionOpened;
  final VoidCallback onFunctionPanelClosed;
  final ValueChanged<GraphNode> onNodeChanged;
  final VoidCallback onAutoSizeComment;
  final ValueChanged<ExpandablePinGroup> onAddExpandablePin;
  final ValueChanged<String> onDeletePin;
  final ValueChanged<_MemberFocusRequest> onFocusMemberNode;

  @override
  Widget build(BuildContext context) {
    final node = selectedNode;
    final variable = selectedVariable;
    final event = selectedEvent;
    final function = selectedFunction;
    final contentKey = ValueKey(
      'right-panel-${mode.name}-${node?.id ?? variable?.id ?? event?.id ?? function?.id ?? openedFunction?.id ?? 'none'}',
    );
    final currentFunctionPanel = openedFunction;
    final content = switch (mode) {
      _RightPanelMode.members => _MembersPanel(
        graph: document.graph,
        variables: variables,
        functions: functions,
        events: events,
        onVariableCreated: onVariableCreated,
        onVariableNodeSelected: onVariableNodeSelected,
        onVariableChanged: onVariableChanged,
        onVariableSelected: onVariableSelected,
        onEventCreated: onEventCreated,
        onEventNodeSelected: onEventNodeSelected,
        onEventChanged: onEventChanged,
        onEventSelected: onEventSelected,
        onFunctionCreated: onFunctionCreated,
        onFunctionNodeSelected: onFunctionNodeSelected,
        onFunctionChanged: onFunctionChanged,
        onFunctionSelected: onFunctionSelected,
        onFunctionOpened: onFunctionOpened,
      ),
      _RightPanelMode.variableDetails when variable != null =>
        _VariableInspectorPanel(
          variable: variable,
          onVariableChanged: onVariableChanged,
          onFocusNode: () => onFocusMemberNode(
            _MemberFocusRequest(_MemberFocusKind.variable, variable.name),
          ),
        ),
      _RightPanelMode.eventDetails when event != null => _EventInspectorPanel(
        event: event,
        onEventChanged: onEventChanged,
        onFocusNode: () => onFocusMemberNode(
          _MemberFocusRequest(_MemberFocusKind.event, event.name),
        ),
      ),
      _RightPanelMode.functionDetails when function != null =>
        _FunctionInspectorPanel(
          function: function,
          openedFunction: currentFunctionPanel,
          onBack: currentFunctionPanel == null
              ? null
              : () {
                  onFunctionOpened(currentFunctionPanel);
                },
          onFunctionChanged: onFunctionChanged,
          onFocusNode: () => onFocusMemberNode(
            _MemberFocusRequest(_MemberFocusKind.function, function.name),
          ),
        ),
      _RightPanelMode.catalog => _NodeCatalogPanel(
        nodeBook: nodeBook,
        onTemplateSelected: onTemplateSelected,
      ),
      _RightPanelMode.details when node != null => _InspectorPanel(
        document: document,
        nodeBook: nodeBook,
        selectedNode: node,
        showJsonPreview: showJsonPreview,
        onNodeChanged: onNodeChanged,
        onAutoSizeComment: onAutoSizeComment,
        onAddExpandablePin: onAddExpandablePin,
        onDeletePin: onDeletePin,
      ),
      _ => _MembersPanel(
        graph: document.graph,
        variables: variables,
        functions: functions,
        events: events,
        onVariableCreated: onVariableCreated,
        onVariableNodeSelected: onVariableNodeSelected,
        onVariableChanged: onVariableChanged,
        onVariableSelected: onVariableSelected,
        onEventCreated: onEventCreated,
        onEventNodeSelected: onEventNodeSelected,
        onEventChanged: onEventChanged,
        onEventSelected: onEventSelected,
        onFunctionCreated: onFunctionCreated,
        onFunctionNodeSelected: onFunctionNodeSelected,
        onFunctionChanged: onFunctionChanged,
        onFunctionSelected: onFunctionSelected,
        onFunctionOpened: onFunctionOpened,
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF0F3F8FF),
        border: const Border(left: BorderSide(color: Color(0xFFD7E7F8))),
      ),
      padding: const EdgeInsets.all(16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        child: KeyedSubtree(key: contentKey, child: content),
      ),
    );
  }
}

class _MembersPanel extends StatelessWidget {
  const _MembersPanel({
    required this.graph,
    required this.variables,
    required this.functions,
    required this.events,
    required this.onVariableCreated,
    required this.onVariableNodeSelected,
    required this.onVariableChanged,
    required this.onVariableSelected,
    required this.onEventCreated,
    required this.onEventNodeSelected,
    required this.onEventChanged,
    required this.onEventSelected,
    required this.onFunctionCreated,
    required this.onFunctionNodeSelected,
    required this.onFunctionChanged,
    required this.onFunctionSelected,
    required this.onFunctionOpened,
  });

  final GraphMetadata graph;
  final List<GraphVariable> variables;
  final List<GraphFunction> functions;
  final List<GraphEvent> events;
  final ValueChanged<GraphVariable> onVariableCreated;
  final _VariableNodeCreator onVariableNodeSelected;
  final ValueChanged<GraphVariable> onVariableChanged;
  final ValueChanged<GraphVariable> onVariableSelected;
  final ValueChanged<GraphEvent> onEventCreated;
  final _EventNodeCreator onEventNodeSelected;
  final ValueChanged<GraphEvent> onEventChanged;
  final ValueChanged<GraphEvent> onEventSelected;
  final ValueChanged<GraphFunction> onFunctionCreated;
  final _FunctionNodeCreator onFunctionNodeSelected;
  final ValueChanged<GraphFunction> onFunctionChanged;
  final ValueChanged<GraphFunction> onFunctionSelected;
  final ValueChanged<GraphFunction> onFunctionOpened;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RightPanelHeader(
          icon: Icons.account_tree_outlined,
          title: '成员',
          subtitle: '变量 / 函数 / UI / 动画',
        ),
        const SizedBox(height: 14),
        _BlueprintAssetInfoCard(graph: graph),
        const SizedBox(height: 12),
        Expanded(
          child: Scrollbar(
            child: ListView(
              children: [
                _VariableCatalogSection(
                  variables: variables,
                  onVariableCreated: onVariableCreated,
                  onVariableNodeSelected: onVariableNodeSelected,
                  onVariableChanged: onVariableChanged,
                  onVariableSelected: onVariableSelected,
                ),
                const SizedBox(height: 12),
                _FunctionCatalogSection(
                  functions: functions,
                  onFunctionCreated: onFunctionCreated,
                  onFunctionNodeSelected: onFunctionNodeSelected,
                  onFunctionChanged: onFunctionChanged,
                  onFunctionSelected: onFunctionSelected,
                  onFunctionOpened: onFunctionOpened,
                ),
                const SizedBox(height: 12),
                _EventCatalogSection(
                  events: events,
                  onEventCreated: onEventCreated,
                  onEventNodeSelected: onEventNodeSelected,
                  onEventChanged: onEventChanged,
                  onEventSelected: onEventSelected,
                ),
                const SizedBox(height: 12),
                const _MemberPlaceholderSection(
                  icon: Icons.widgets_outlined,
                  title: 'UI',
                  description: '后续显示控件、界面蓝图和绑定入口。',
                ),
                const SizedBox(height: 12),
                const _MemberPlaceholderSection(
                  icon: Icons.movie_filter_outlined,
                  title: '动画',
                  description: '后续显示动画事件、时间轴和过渡相关草稿。',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberPlaceholderSection extends StatelessWidget {
  const _MemberPlaceholderSection({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E7F8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                      height: 1.28,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlueprintAssetInfoCard extends StatelessWidget {
  const _BlueprintAssetInfoCard({required this.graph});

  final GraphMetadata graph;

  @override
  Widget build(BuildContext context) {
    final blueprintType = graph.blueprintType.trim().isEmpty
        ? '未标注蓝图类型'
        : graph.blueprintType.trim();
    final parentClass = graph.parentClass.trim().isEmpty
        ? '未标注父类'
        : graph.parentClass.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_tree_outlined,
                  size: 17,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    blueprintType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF102033),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '父类：$parentClass',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF334155),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              graph.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF526276),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeCatalogPanel extends StatefulWidget {
  const _NodeCatalogPanel({
    required this.nodeBook,
    required this.onTemplateSelected,
  });

  final EngineNodeBook nodeBook;
  final ValueChanged<String> onTemplateSelected;

  @override
  State<_NodeCatalogPanel> createState() => _NodeCatalogPanelState();
}

class _NodeCatalogPanelState extends State<_NodeCatalogPanel> {
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'NodeCatalogSearch');
  String _query = '';
  bool _contextSensitive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ImeControl.setEnabled(true);
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templates = _filteredTemplates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RightPanelHeader(
          icon: Icons.add_box_outlined,
          title: '节点目录',
          subtitle: widget.nodeBook.displayName,
        ),
        const SizedBox(height: 14),
        _ContextSensitiveToggle(
          value: _contextSensitive,
          onChanged: (value) => setState(() => _contextSensitive = value),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('node-catalog-search-field'),
          focusNode: _searchFocusNode,
          autofocus: true,
          onTap: () => ImeControl.setEnabled(true),
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search, size: 18),
            hintText: '搜索节点名、分类或说明',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Scrollbar(
            child: ListView.separated(
              itemCount: templates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final template = templates[index];
                return _NodeCatalogTile(
                  template: template,
                  onTap: () => widget.onTemplateSelected(template.id),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<UnrealNodeTemplate> get _filteredTemplates {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.nodeBook.templates;
    }

    return [
      for (final template in widget.nodeBook.templates)
        if ('${template.title} ${template.category} ${template.description} ${template.nodeType}'
            .toLowerCase()
            .contains(query))
          template,
    ];
  }
}

class _VariableInspectorPanel extends StatelessWidget {
  const _VariableInspectorPanel({
    required this.variable,
    required this.onVariableChanged,
    required this.onFocusNode,
  });

  static const _replicationModes = <String>['None', 'Replicated', 'RepNotify'];

  final GraphVariable variable;
  final ValueChanged<GraphVariable> onVariableChanged;
  final VoidCallback onFocusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RightPanelHeader(
          icon: Icons.data_object,
          title: '${variable.name} · 变量细节',
          subtitle: variable.dataType,
          onTap: onFocusNode,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Scrollbar(
            child: ListView(
              children: [
                TextFormField(
                  key: const ValueKey('variable-detail-name-field'),
                  initialValue: variable.name,
                  onTap: () => ImeControl.setEnabled(true),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '变量名',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      onVariableChanged(variable.copyWith(name: value.trim())),
                ),
                const SizedBox(height: 10),
                _InspectorValue(label: '类型', value: variable.dataType),
                const SizedBox(height: 10),
                _VariableReplicationSelector(
                  value: variable.replication,
                  values: _replicationModes,
                  label: '网络复制',
                  widgetKey: const ValueKey('variable-replication-dropdown'),
                  onChanged: (value) =>
                      onVariableChanged(variable.copyWith(replication: value)),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey('variable-detail-default-field'),
                  initialValue: variable.defaultValue,
                  onTap: () => ImeControl.setEnabled(true),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '默认值',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      onVariableChanged(variable.copyWith(defaultValue: value)),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey('variable-detail-category-field'),
                  initialValue: variable.category,
                  onTap: () => ImeControl.setEnabled(true),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '分类',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      onVariableChanged(variable.copyWith(category: value)),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey('variable-detail-description-field'),
                  initialValue: variable.description,
                  onTap: () => ImeControl.setEnabled(true),
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '说明',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      onVariableChanged(variable.copyWith(description: value)),
                ),
                const SizedBox(height: 14),
                _VariableExportSection(variable: variable),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FunctionInspectorPanel extends StatelessWidget {
  const _FunctionInspectorPanel({
    required this.function,
    required this.openedFunction,
    required this.onBack,
    required this.onFunctionChanged,
    required this.onFocusNode,
  });

  static const _dataTypes = <String>[
    'bool',
    'int',
    'float',
    'string',
    'text',
    'object',
    'Actor',
  ];

  final GraphFunction function;
  final GraphFunction? openedFunction;
  final VoidCallback? onBack;
  final ValueChanged<GraphFunction> onFunctionChanged;
  final VoidCallback onFocusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onBack != null) ...[
              IconButton.filledTonal(
                key: const ValueKey('back-to-function-panel-button'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回函数面板',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFDBEAFE),
                  foregroundColor: const Color(0xFF1D4ED8),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: _RightPanelHeader(
                icon: Icons.functions,
                title: '${function.name} · 函数细节',
                subtitle: 'Function Signature',
                onTap: onFocusNode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Scrollbar(
            child: ListView(
              children: [
                TextFormField(
                  key: const ValueKey('function-name-field'),
                  initialValue: function.name,
                  onTap: () => ImeControl.setEnabled(true),
                  decoration: const InputDecoration(
                    labelText: '函数名',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      onFunctionChanged(function.copyWith(name: value.trim())),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    value: function.pure,
                    onChanged: (value) =>
                        onFunctionChanged(function.copyWith(pure: value)),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('纯函数'),
                    subtitle: const Text('纯函数不会生成执行输入和 Then 输出'),
                  ),
                ),
                TextFormField(
                  initialValue: function.category,
                  onTap: () => ImeControl.setEnabled(true),
                  decoration: const InputDecoration(
                    labelText: '分类',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      onFunctionChanged(function.copyWith(category: value)),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: function.description,
                  onTap: () => ImeControl.setEnabled(true),
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '说明',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      onFunctionChanged(function.copyWith(description: value)),
                ),
                const SizedBox(height: 14),
                _FunctionParameterSection(
                  title: '输入',
                  emptyText: '暂无输入参数',
                  parameters: function.inputs,
                  dataTypes: _dataTypes,
                  onAdd: () => onFunctionChanged(
                    function.copyWith(
                      inputs: [
                        ...function.inputs,
                        _newFunctionParameter('Input', function.inputs.length),
                      ],
                    ),
                  ),
                  onChanged: (parameters) =>
                      onFunctionChanged(function.copyWith(inputs: parameters)),
                ),
                const SizedBox(height: 12),
                _FunctionParameterSection(
                  title: '输出',
                  emptyText: '暂无输出参数',
                  parameters: function.outputs,
                  dataTypes: _dataTypes,
                  onAdd: () => onFunctionChanged(
                    function.copyWith(
                      outputs: [
                        ...function.outputs,
                        _newFunctionParameter(
                          'ReturnValue',
                          function.outputs.length,
                        ),
                      ],
                    ),
                  ),
                  onChanged: (parameters) =>
                      onFunctionChanged(function.copyWith(outputs: parameters)),
                ),
                const SizedBox(height: 12),
                _FunctionExportSection(function: function),
              ],
            ),
          ),
        ),
      ],
    );
  }

  GraphFunctionParameter _newFunctionParameter(String prefix, int index) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return GraphFunctionParameter(
      id: '${prefix.toLowerCase()}_${now}_$index',
      name: '$prefix $index',
      dataType: 'bool',
      defaultValue: 'false',
    );
  }
}

class _EventInspectorPanel extends StatelessWidget {
  const _EventInspectorPanel({
    required this.event,
    required this.onEventChanged,
    required this.onFocusNode,
  });

  static const _rpcTypes = <String>[
    'None',
    'RunOnServer',
    'RunOnOwningClient',
    'NetMulticast',
  ];
  static const _rpcDisplayNames = <String, String>{
    'None': '不复制',
    'RunOnServer': '在服务器上运行',
    'RunOnOwningClient': '在拥有客户端上运行',
    'NetMulticast': '多播',
  };

  final GraphEvent event;
  final ValueChanged<GraphEvent> onEventChanged;
  final VoidCallback onFocusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RightPanelHeader(
          icon: Icons.bolt_rounded,
          title: '${event.name} · 事件细节',
          subtitle: event.eventType,
          onTap: onFocusNode,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Scrollbar(
            child: ListView(
              children: [
                TextFormField(
                  key: const ValueKey('event-detail-name-field'),
                  initialValue: event.name,
                  onTap: () => ImeControl.setEnabled(true),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '事件名',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      onEventChanged(event.copyWith(name: value.trim())),
                ),
                const SizedBox(height: 10),
                _InspectorValue(label: '类型', value: event.eventType),
                const SizedBox(height: 10),
                _PlainOptionSelector(
                  value: event.rpcType,
                  values: _rpcTypes,
                  displayNames: _rpcDisplayNames,
                  label: '复制',
                  widgetKey: const ValueKey('event-replication-dropdown'),
                  onChanged: (value) => onEventChanged(
                    event.copyWith(rpcType: value, replicates: value != 'None'),
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    key: const ValueKey('event-reliable-checkbox'),
                    value: event.reliability == 'Reliable',
                    onChanged: (value) => onEventChanged(
                      event.copyWith(
                        reliability: value == true ? 'Reliable' : 'Unreliable',
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('可靠'),
                    subtitle: const Text('对应蓝图自定义事件的 Reliable'),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: event.category,
                  onTap: () => ImeControl.setEnabled(true),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '分类',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      onEventChanged(event.copyWith(category: value)),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: event.description,
                  onTap: () => ImeControl.setEnabled(true),
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '说明',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      onEventChanged(event.copyWith(description: value)),
                ),
                const SizedBox(height: 14),
                _EventExportSection(event: event),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EventExportSection extends StatelessWidget {
  const _EventExportSection({required this.event});

  final GraphEvent event;

  @override
  Widget build(BuildContext context) {
    return _VariableExportSection(
      variable: GraphVariable(
        id: event.id,
        name: event.name,
        dataType: event.eventType,
        category: event.category,
        description: event.description,
        exportSource: event.exportSource,
        exportPath: event.exportPath,
        exportDisplayName: event.exportDisplayName,
      ),
    );
  }
}

class _FunctionGraphPanel extends StatelessWidget {
  const _FunctionGraphPanel({
    required this.openedFunction,
    required this.functions,
    required this.onBack,
    required this.onFunctionSelected,
    required this.onFunctionOpened,
  });

  final GraphFunction openedFunction;
  final List<GraphFunction> functions;
  final VoidCallback onBack;
  final ValueChanged<GraphFunction> onFunctionSelected;
  final ValueChanged<GraphFunction> onFunctionOpened;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEEF5FF),
      child: Column(
        children: [
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: Color(0xF6FFFFFF),
              border: Border(bottom: BorderSide(color: Color(0xFFD7E7F8))),
            ),
            child: Row(
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('close-function-panel-button'),
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: '返回事件图表',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFDBEAFE),
                    foregroundColor: const Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF38BDF8)],
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.functions,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${openedFunction.name} · 函数图表',
                        key: ValueKey(
                          'function-workspace-title-${openedFunction.name}',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF102033),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        '当前正在编辑独立函数，右侧仍可单击函数查看细节、双击切换函数。',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF526276),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                const Positioned.fill(child: _FunctionWorkspaceGrid()),
                Positioned(
                  top: 18,
                  right: 18,
                  child: _FunctionWorkspaceSwitcher(
                    currentFunction: openedFunction,
                    functions: functions,
                    onFunctionSelected: onFunctionSelected,
                    onFunctionOpened: onFunctionOpened,
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF1D4ED8,
                            ).withValues(alpha: 0.12),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.account_tree_outlined,
                              size: 34,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              openedFunction.name,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '函数内部节点图表会在这里编辑。现在先把“进入函数”拆成独立工作区，后续再接函数自己的节点数据。',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFF526276),
                                    height: 1.4,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FunctionWorkspaceGrid extends StatelessWidget {
  const _FunctionWorkspaceGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _FunctionWorkspaceGridPainter());
  }
}

class _FunctionWorkspaceSwitcher extends StatelessWidget {
  const _FunctionWorkspaceSwitcher({
    required this.currentFunction,
    required this.functions,
    required this.onFunctionSelected,
    required this.onFunctionOpened,
  });

  final GraphFunction currentFunction;
  final List<GraphFunction> functions;
  final ValueChanged<GraphFunction> onFunctionSelected;
  final ValueChanged<GraphFunction> onFunctionOpened;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 238, maxHeight: 280),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFDBFE)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.12),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.functions,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '函数入口',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Scrollbar(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: functions.length,
                    itemBuilder: (context, index) {
                      final function = functions[index];
                      return _FunctionWorkspaceSwitchRow(
                        function: function,
                        selected: function.id == currentFunction.id,
                        onFunctionSelected: onFunctionSelected,
                        onFunctionOpened: onFunctionOpened,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FunctionWorkspaceSwitchRow extends StatefulWidget {
  const _FunctionWorkspaceSwitchRow({
    required this.function,
    required this.selected,
    required this.onFunctionSelected,
    required this.onFunctionOpened,
  });

  final GraphFunction function;
  final bool selected;
  final ValueChanged<GraphFunction> onFunctionSelected;
  final ValueChanged<GraphFunction> onFunctionOpened;

  @override
  State<_FunctionWorkspaceSwitchRow> createState() =>
      _FunctionWorkspaceSwitchRowState();
}

class _FunctionWorkspaceSwitchRowState
    extends State<_FunctionWorkspaceSwitchRow> {
  Timer? _singleTapTimer;

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        key: ValueKey('function-workspace-row-${widget.function.name}'),
        borderRadius: BorderRadius.circular(8),
        onTap: _scheduleSelectFunction,
        onDoubleTap: _openFunction,
        child: Ink(
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFFDBEAFE)
                : Colors.white.withValues(alpha: 0.54),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected
                  ? const Color(0xFF60A5FA)
                  : const Color(0xFFD7E7F8),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                Icon(
                  widget.selected ? Icons.radio_button_checked : Icons.circle,
                  size: 14,
                  color: widget.selected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF93A4B8),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    widget.function.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF102033),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleSelectFunction() {
    _singleTapTimer?.cancel();
    _singleTapTimer = Timer(const Duration(milliseconds: 180), () {
      widget.onFunctionSelected(widget.function);
    });
  }

  void _openFunction() {
    _singleTapTimer?.cancel();
    widget.onFunctionOpened(widget.function);
  }
}

class _FunctionWorkspaceGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBFD7F4).withValues(alpha: 0.42)
      ..strokeWidth = 1;
    const step = 24.0;

    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FunctionWorkspaceGridPainter oldDelegate) {
    return false;
  }
}

class _FunctionParameterSection extends StatelessWidget {
  const _FunctionParameterSection({
    required this.title,
    required this.emptyText,
    required this.parameters,
    required this.dataTypes,
    required this.onAdd,
    required this.onChanged,
  });

  final String title;
  final String emptyText;
  final List<GraphFunctionParameter> parameters;
  final List<String> dataTypes;
  final VoidCallback onAdd;
  final ValueChanged<List<GraphFunctionParameter>> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E7F8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  key: ValueKey('add-function-$title-parameter'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 16),
                  tooltip: '添加$title参数',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(30, 30),
                    fixedSize: const Size(30, 30),
                    padding: EdgeInsets.zero,
                    backgroundColor: const Color(0xFFDBEAFE),
                    foregroundColor: const Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
            if (parameters.isEmpty) ...[
              const SizedBox(height: 6),
              Text(
                emptyText,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
              ),
            ],
            for (var index = 0; index < parameters.length; index++) ...[
              const SizedBox(height: 8),
              _FunctionParameterRow(
                parameter: parameters[index],
                dataTypes: dataTypes,
                onChanged: (parameter) {
                  final next = [...parameters];
                  next[index] = parameter;
                  onChanged(next);
                },
                onDelete: () {
                  final next = [...parameters]..removeAt(index);
                  onChanged(next);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FunctionParameterRow extends StatelessWidget {
  const _FunctionParameterRow({
    required this.parameter,
    required this.dataTypes,
    required this.onChanged,
    required this.onDelete,
  });

  final GraphFunctionParameter parameter;
  final List<String> dataTypes;
  final ValueChanged<GraphFunctionParameter> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: GraphNodeStyle.variableTint(parameter.dataType, alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: GraphNodeStyle.variableColor(
            parameter.dataType,
          ).withValues(alpha: 0.20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: parameter.name,
                    onTap: () => ImeControl.setEnabled(true),
                    decoration: const InputDecoration(
                      labelText: '名称',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        onChanged(parameter.copyWith(name: value.trim())),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.close, size: 17),
                  tooltip: '删除参数',
                ),
              ],
            ),
            const SizedBox(height: 8),
            _VariableTypeSelector(
              widgetKey: ValueKey('function-parameter-type-${parameter.id}'),
              dataTypes: dataTypes,
              value: parameter.dataType,
              onChanged: (value) => onChanged(
                parameter.copyWith(
                  dataType: value,
                  defaultValue: value == 'bool' ? 'false' : '',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FunctionExportSection extends StatelessWidget {
  const _FunctionExportSection({required this.function});

  final GraphFunction function;

  @override
  Widget build(BuildContext context) {
    if (function.exportSource.isEmpty &&
        function.exportPath.isEmpty &&
        function.exportDisplayName.isEmpty) {
      return const SizedBox.shrink();
    }

    return _VariableExportSection(
      variable: GraphVariable(
        id: function.id,
        name: function.name,
        dataType: 'function',
        exportSource: function.exportSource,
        exportPath: function.exportPath,
        exportDisplayName: function.exportDisplayName,
      ),
    );
  }
}

class _VariableReplicationSelector extends StatelessWidget {
  const _VariableReplicationSelector({
    required this.value,
    required this.values,
    required this.label,
    required this.widgetKey,
    required this.onChanged,
  });

  final String value;
  final List<String> values;
  final String label;
  final Key widgetKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PlainOptionSelector(
      value: value,
      values: values,
      label: label,
      widgetKey: widgetKey,
      onChanged: onChanged,
    );
  }
}

class _PlainOptionSelector extends StatelessWidget {
  const _PlainOptionSelector({
    required this.value,
    required this.values,
    required this.label,
    required this.widgetKey,
    required this.onChanged,
    this.displayNames = const <String, String>{},
  });

  final String value;
  final List<String> values;
  final String label;
  final Key widgetKey;
  final ValueChanged<String> onChanged;
  final Map<String, String> displayNames;

  @override
  Widget build(BuildContext context) {
    final selectedValue = values.contains(value) ? value : values.first;
    final selectedLabel = _displayLabel(selectedValue);

    return PopupMenuButton<String>(
      key: widgetKey,
      tooltip: label,
      initialValue: selectedValue,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      color: const Color(0xFFFAFCFF),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFD7E7F8)),
      ),
      itemBuilder: (context) => [
        for (final mode in values)
          PopupMenuItem<String>(
            key: ValueKey('plain-option-$mode'),
            value: mode,
            height: 38,
            padding: EdgeInsets.zero,
            child: _PlainMenuOption(
              label: _displayLabel(mode),
              selected: mode == selectedValue,
            ),
          ),
      ],
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF102033),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF526276),
            ),
          ],
        ),
      ),
    );
  }

  String _displayLabel(String value) {
    return displayNames[value] ?? value;
  }
}

class _PlainMenuOption extends StatelessWidget {
  const _PlainMenuOption({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 34,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFE6F1FF)
            : Colors.white.withValues(alpha: 0.0),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? const Color(0xFFB9D8FF) : Colors.transparent,
          width: selected ? 1.2 : 1,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF102033),
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _VariableExportSection extends StatelessWidget {
  const _VariableExportSection({required this.variable});

  final GraphVariable variable;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E7F8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '导出数据',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _InspectorValue(
              label: '来源',
              value: variable.exportSource.isEmpty
                  ? '未记录'
                  : variable.exportSource,
            ),
            _InspectorValue(
              label: '路径',
              value: variable.exportPath.isEmpty ? '未记录' : variable.exportPath,
            ),
            _InspectorValue(
              label: '显示',
              value: variable.exportDisplayName.isEmpty
                  ? '未记录'
                  : variable.exportDisplayName,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextSensitiveToggle extends StatelessWidget {
  const _ContextSensitiveToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: value,
                  onChanged: (checked) => onChanged(checked ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  activeColor: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '情境关联',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF102033),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 17,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariableCatalogSection extends StatefulWidget {
  const _VariableCatalogSection({
    required this.variables,
    required this.onVariableCreated,
    required this.onVariableNodeSelected,
    required this.onVariableChanged,
    required this.onVariableSelected,
  });

  final List<GraphVariable> variables;
  final ValueChanged<GraphVariable> onVariableCreated;
  final _VariableNodeCreator onVariableNodeSelected;
  final ValueChanged<GraphVariable> onVariableChanged;
  final ValueChanged<GraphVariable> onVariableSelected;

  @override
  State<_VariableCatalogSection> createState() =>
      _VariableCatalogSectionState();
}

class _VariableCatalogSectionState extends State<_VariableCatalogSection> {
  static const _dataTypes = <String>[
    'bool',
    'int',
    'float',
    'string',
    'object',
    'Actor',
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E7F8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.data_object,
                  size: 18,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '变量',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('open-create-variable-dialog'),
                  onPressed: _openCreateVariableDialog,
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: '创建变量',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    fixedSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                    backgroundColor: const Color(0xFFDBEAFE),
                    foregroundColor: const Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
            if (widget.variables.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '暂无变量',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
              ),
            ],
            if (widget.variables.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final variable in widget.variables)
                _VariableCatalogRow(
                  variable: variable,
                  onVariableNodeSelected: widget.onVariableNodeSelected,
                  onVariableChanged: widget.onVariableChanged,
                  onVariableSelected: widget.onVariableSelected,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateVariableDialog() async {
    final variable = await showDialog<GraphVariable>(
      context: context,
      builder: (context) => const _CreateVariableDialog(dataTypes: _dataTypes),
    );
    if (variable != null) {
      widget.onVariableCreated(variable);
    }
  }
}

class _FunctionCatalogSection extends StatefulWidget {
  const _FunctionCatalogSection({
    required this.functions,
    required this.onFunctionCreated,
    required this.onFunctionNodeSelected,
    required this.onFunctionChanged,
    required this.onFunctionSelected,
    required this.onFunctionOpened,
  });

  final List<GraphFunction> functions;
  final ValueChanged<GraphFunction> onFunctionCreated;
  final _FunctionNodeCreator onFunctionNodeSelected;
  final ValueChanged<GraphFunction> onFunctionChanged;
  final ValueChanged<GraphFunction> onFunctionSelected;
  final ValueChanged<GraphFunction> onFunctionOpened;

  @override
  State<_FunctionCatalogSection> createState() =>
      _FunctionCatalogSectionState();
}

class _FunctionCatalogSectionState extends State<_FunctionCatalogSection> {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E7F8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.functions, size: 18, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '函数',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('open-create-function-dialog'),
                  onPressed: _openCreateFunctionDialog,
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: '创建函数',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    fixedSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                    backgroundColor: const Color(0xFFDBEAFE),
                    foregroundColor: const Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
            if (widget.functions.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '暂无函数',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
              ),
            ],
            if (widget.functions.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final function in widget.functions)
                _FunctionCatalogRow(
                  function: function,
                  onFunctionNodeSelected: widget.onFunctionNodeSelected,
                  onFunctionChanged: widget.onFunctionChanged,
                  onFunctionSelected: widget.onFunctionSelected,
                  onFunctionOpened: widget.onFunctionOpened,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateFunctionDialog() async {
    final function = await showDialog<GraphFunction>(
      context: context,
      builder: (context) => const _CreateFunctionDialog(),
    );
    if (function != null) {
      widget.onFunctionCreated(function);
    }
  }
}

class _CreateFunctionDialog extends StatefulWidget {
  const _CreateFunctionDialog();

  @override
  State<_CreateFunctionDialog> createState() => _CreateFunctionDialogState();
}

class _CreateFunctionDialogState extends State<_CreateFunctionDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _pure = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ImeControl.setEnabled(true);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建函数'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('function-name-create-field'),
              controller: _nameController,
              autofocus: true,
              onTap: () => ImeControl.setEnabled(true),
              decoration: const InputDecoration(
                isDense: true,
                labelText: '函数名',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                value: _pure,
                onChanged: (value) => setState(() => _pure = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('纯函数'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          key: const ValueKey('create-function-button'),
          onPressed: _submit,
          icon: const Icon(Icons.add),
          label: const Text('创建函数'),
        ),
      ],
    );
  }

  void _submit() {
    final rawName = _nameController.text.trim();
    if (rawName.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      GraphFunction(
        id: 'func_${DateTime.now().microsecondsSinceEpoch}',
        name: rawName,
        pure: _pure,
      ),
    );
  }
}

class _FunctionCatalogRow extends StatefulWidget {
  const _FunctionCatalogRow({
    required this.function,
    required this.onFunctionNodeSelected,
    required this.onFunctionChanged,
    required this.onFunctionSelected,
    required this.onFunctionOpened,
  });

  final GraphFunction function;
  final _FunctionNodeCreator onFunctionNodeSelected;
  final ValueChanged<GraphFunction> onFunctionChanged;
  final ValueChanged<GraphFunction> onFunctionSelected;
  final ValueChanged<GraphFunction> onFunctionOpened;

  @override
  State<_FunctionCatalogRow> createState() => _FunctionCatalogRowState();
}

class _FunctionCatalogRowState extends State<_FunctionCatalogRow> {
  Timer? _singleTapTimer;

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = _FunctionMemberRowContent(function: widget.function);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: LongPressDraggable<GraphFunction>(
          data: widget.function,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2563EB)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(padding: const EdgeInsets.all(8), child: row),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.45, child: row),
          child: InkWell(
            key: ValueKey('function-row-${widget.function.name}'),
            borderRadius: BorderRadius.circular(8),
            onTap: _scheduleSelectFunction,
            onDoubleTap: _openFunction,
            child: Ink(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              child: row,
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleSelectFunction() {
    _singleTapTimer?.cancel();
    _singleTapTimer = Timer(const Duration(milliseconds: 180), () {
      widget.onFunctionSelected(widget.function);
    });
  }

  void _openFunction() {
    _singleTapTimer?.cancel();
    widget.onFunctionOpened(widget.function);
  }
}

class _FunctionMemberRowContent extends StatelessWidget {
  const _FunctionMemberRowContent({required this.function});

  final GraphFunction function;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.functions, size: 16, color: Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              function.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            function.pure ? 'Pure' : 'Exec',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF2563EB),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCatalogSection extends StatefulWidget {
  const _EventCatalogSection({
    required this.events,
    required this.onEventCreated,
    required this.onEventNodeSelected,
    required this.onEventChanged,
    required this.onEventSelected,
  });

  final List<GraphEvent> events;
  final ValueChanged<GraphEvent> onEventCreated;
  final _EventNodeCreator onEventNodeSelected;
  final ValueChanged<GraphEvent> onEventChanged;
  final ValueChanged<GraphEvent> onEventSelected;

  @override
  State<_EventCatalogSection> createState() => _EventCatalogSectionState();
}

class _EventCatalogSectionState extends State<_EventCatalogSection> {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E7F8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '事件',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('open-create-event-dialog'),
                  onPressed: _openCreateEventDialog,
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: '创建事件',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    fixedSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                    backgroundColor: const Color(0xFFFEE2E2),
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            if (widget.events.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '暂无事件',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
              ),
            ],
            if (widget.events.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final event in widget.events)
                _EventCatalogRow(
                  event: event,
                  onEventNodeSelected: widget.onEventNodeSelected,
                  onEventChanged: widget.onEventChanged,
                  onEventSelected: widget.onEventSelected,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateEventDialog() async {
    final event = await showDialog<GraphEvent>(
      context: context,
      builder: (context) => const _CreateEventDialog(),
    );
    if (event != null) {
      widget.onEventCreated(event);
    }
  }
}

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog();

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final TextEditingController _nameController = TextEditingController();
  String _rpcType = 'None';
  String _reliability = 'Unreliable';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ImeControl.setEnabled(true);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建事件'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('event-name-create-field'),
              controller: _nameController,
              autofocus: true,
              onTap: () => ImeControl.setEnabled(true),
              decoration: const InputDecoration(
                isDense: true,
                labelText: '事件名',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            _PlainOptionSelector(
              value: _rpcType,
              values: _EventInspectorPanel._rpcTypes,
              displayNames: _EventInspectorPanel._rpcDisplayNames,
              label: '复制',
              widgetKey: const ValueKey('create-event-replication-dropdown'),
              onChanged: (value) => setState(() => _rpcType = value),
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                key: const ValueKey('create-event-reliable-checkbox'),
                value: _reliability == 'Reliable',
                onChanged: (value) => setState(() {
                  _reliability = value == true ? 'Reliable' : 'Unreliable';
                }),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('可靠'),
                subtitle: const Text('对应蓝图自定义事件的 Reliable'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          key: const ValueKey('create-event-button'),
          onPressed: _submit,
          icon: const Icon(Icons.add),
          label: const Text('创建事件'),
        ),
      ],
    );
  }

  void _submit() {
    final rawName = _nameController.text.trim();
    if (rawName.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      GraphEvent(
        id: 'event_${DateTime.now().microsecondsSinceEpoch}',
        name: rawName,
        eventType: 'CustomEvent',
        replicates: _rpcType != 'None',
        rpcType: _rpcType,
        reliability: _reliability,
      ),
    );
  }
}

class _EventCatalogRow extends StatefulWidget {
  const _EventCatalogRow({
    required this.event,
    required this.onEventNodeSelected,
    required this.onEventChanged,
    required this.onEventSelected,
  });

  final GraphEvent event;
  final _EventNodeCreator onEventNodeSelected;
  final ValueChanged<GraphEvent> onEventChanged;
  final ValueChanged<GraphEvent> onEventSelected;

  @override
  State<_EventCatalogRow> createState() => _EventCatalogRowState();
}

class _EventCatalogRowState extends State<_EventCatalogRow> {
  Timer? _singleTapTimer;

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = _EventMemberRowContent(event: widget.event);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: LongPressDraggable<GraphEvent>(
          data: widget.event,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2563EB)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(padding: const EdgeInsets.all(8), child: row),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.45, child: row),
          child: InkWell(
            key: ValueKey('event-row-${widget.event.name}'),
            borderRadius: BorderRadius.circular(8),
            onTap: _scheduleSelectEvent,
            onDoubleTap: () => _renameEvent(context),
            child: Ink(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              child: row,
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleSelectEvent() {
    _singleTapTimer?.cancel();
    _singleTapTimer = Timer(const Duration(milliseconds: 180), () {
      widget.onEventSelected(widget.event);
    });
  }

  Future<void> _renameEvent(BuildContext context) async {
    _singleTapTimer?.cancel();
    final controller = TextEditingController(text: widget.event.name);
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名事件'),
        content: TextField(
          key: const ValueKey('rename-event-field'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            isDense: true,
            labelText: '事件名',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirm-rename-event-button'),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('重命名'),
          ),
        ],
      ),
    );

    if (nextName == null || nextName.isEmpty || nextName == widget.event.name) {
      return;
    }

    widget.onEventChanged(widget.event.copyWith(name: nextName));
  }
}

class _EventMemberRowContent extends StatelessWidget {
  const _EventMemberRowContent({required this.event});

  final GraphEvent event;

  @override
  Widget build(BuildContext context) {
    final networkLabel = event.rpcType == 'None'
        ? event.eventType
        : '${event.rpcType} / ${event.reliability}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              event.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              networkLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFFDC2626),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateVariableDialog extends StatefulWidget {
  const _CreateVariableDialog({required this.dataTypes});

  final List<String> dataTypes;

  @override
  State<_CreateVariableDialog> createState() => _CreateVariableDialogState();
}

class _CreateVariableDialogState extends State<_CreateVariableDialog> {
  final TextEditingController _nameController = TextEditingController();
  String _dataType = 'bool';
  bool _boolDefaultValue = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ImeControl.setEnabled(true);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建变量'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('variable-name-field'),
              controller: _nameController,
              autofocus: true,
              onTap: () => ImeControl.setEnabled(true),
              decoration: const InputDecoration(
                isDense: true,
                labelText: '变量名',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 10),
            _VariableTypeSelector(
              widgetKey: const ValueKey('variable-type-selector'),
              dataTypes: widget.dataTypes,
              value: _dataType,
              onChanged: (value) => setState(() => _dataType = value),
            ),
            if (_dataType == 'bool') ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _boolDefaultValue,
                onChanged: (value) =>
                    setState(() => _boolDefaultValue = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('默认值为 True'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          key: const ValueKey('create-variable-button'),
          onPressed: _submit,
          icon: const Icon(Icons.add),
          label: const Text('创建变量'),
        ),
      ],
    );
  }

  void _submit() {
    final rawName = _nameController.text.trim();
    if (rawName.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      GraphVariable(
        id: 'var_${DateTime.now().microsecondsSinceEpoch}',
        name: rawName,
        dataType: _dataType,
        defaultValue: _dataType == 'bool' ? _boolDefaultValue.toString() : '',
      ),
    );
  }
}

class _VariableTypeSelector extends StatelessWidget {
  const _VariableTypeSelector({
    this.widgetKey,
    required this.dataTypes,
    required this.value,
    required this.onChanged,
  });

  final Key? widgetKey;
  final List<String> dataTypes;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: widgetKey,
      tooltip: '选择变量类型',
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      color: const Color(0xFFFAFCFF),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFD7E7F8)),
      ),
      itemBuilder: (context) => [
        for (final dataType in dataTypes)
          PopupMenuItem<String>(
            key: ValueKey('variable-type-option-$dataType'),
            value: dataType,
            height: 38,
            padding: EdgeInsets.zero,
            child: _VariableTypeOption(
              label: dataType,
              selected: dataType == value,
            ),
          ),
      ],
      child: InputDecorator(
        decoration: const InputDecoration(
          isDense: true,
          labelText: '类型',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF102033),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF526276),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariableTypeOption extends StatelessWidget {
  const _VariableTypeOption({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final typeColor = GraphNodeStyle.variableColor(label);
    final backgroundAlpha = selected ? 0.18 : 0.08;
    final borderAlpha = selected ? 0.46 : 0.20;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 34,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: GraphNodeStyle.variableTint(label, alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: typeColor.withValues(alpha: borderAlpha),
          width: selected ? 1.2 : 1,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: selected
              ? Color.lerp(typeColor, const Color(0xFF0F172A), 0.22)
              : const Color(0xFF102033),
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _VariableCatalogRow extends StatefulWidget {
  const _VariableCatalogRow({
    required this.variable,
    required this.onVariableNodeSelected,
    required this.onVariableChanged,
    required this.onVariableSelected,
  });

  final GraphVariable variable;
  final _VariableNodeCreator onVariableNodeSelected;
  final ValueChanged<GraphVariable> onVariableChanged;
  final ValueChanged<GraphVariable> onVariableSelected;

  @override
  State<_VariableCatalogRow> createState() => _VariableCatalogRowState();
}

class _VariableCatalogRowState extends State<_VariableCatalogRow> {
  Timer? _singleTapTimer;

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = _VariableMemberRowContent(variable: widget.variable);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: GestureDetector(
        key: ValueKey('variable-row-${widget.variable.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: _scheduleSelectVariable,
        onDoubleTap: () => _renameVariable(context),
        child: Listener(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: LongPressDraggable<GraphVariable>(
              data: widget.variable,
              feedback: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: 220,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF22C55E)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF0F172A,
                          ).withValues(alpha: 0.16),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: row,
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.45, child: row),
              child: InkWell(
                key: ValueKey('select-variable-${widget.variable.name}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => widget.onVariableSelected(widget.variable),
                onDoubleTap: () => _renameVariable(context),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: row,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleSelectVariable() {
    _singleTapTimer?.cancel();
    _singleTapTimer = Timer(const Duration(milliseconds: 180), () {
      widget.onVariableSelected(widget.variable);
    });
  }

  Future<void> _renameVariable(BuildContext context) async {
    _singleTapTimer?.cancel();
    final controller = TextEditingController(text: widget.variable.name);
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名变量'),
        content: TextField(
          key: const ValueKey('rename-variable-field'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            isDense: true,
            labelText: '变量名',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirm-rename-variable-button'),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('重命名'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (nextName == null ||
        nextName.isEmpty ||
        nextName == widget.variable.name) {
      return;
    }

    widget.onVariableChanged(widget.variable.copyWith(name: nextName));
  }
}

class _VariableMemberRowContent extends StatelessWidget {
  const _VariableMemberRowContent({required this.variable});

  final GraphVariable variable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      child: Row(
        children: [
          Icon(
            GraphNodeStyle.icon('Variable'),
            size: 16,
            color: GraphNodeStyle.pinColor(variable.dataType),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              variable.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            variable.dataType,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF526276),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeCatalogTile extends StatelessWidget {
  const _NodeCatalogTile({required this.template, required this.onTap});

  final UnrealNodeTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nodeColor = GraphNodeStyle.headerColor(template.nodeType);

    return Material(
      key: ValueKey('node-catalog-template-${template.id}'),
      color: Colors.white.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD7E7F8)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: nodeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  GraphNodeStyle.icon(template.nodeType),
                  size: 17,
                  color: nodeColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            template.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: const Color(0xFF102033),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CatalogCategoryPill(label: template.category),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      template.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF526276),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogCategoryPill extends StatelessWidget {
  const _CatalogCategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF1E40AF),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
    required this.document,
    required this.nodeBook,
    required this.selectedNode,
    required this.showJsonPreview,
    required this.onNodeChanged,
    required this.onAutoSizeComment,
    required this.onAddExpandablePin,
    required this.onDeletePin,
  });

  final GraphDocument document;
  final EngineNodeBook nodeBook;
  final GraphNode selectedNode;
  final bool showJsonPreview;
  final ValueChanged<GraphNode> onNodeChanged;
  final VoidCallback onAutoSizeComment;
  final ValueChanged<ExpandablePinGroup> onAddExpandablePin;
  final ValueChanged<String> onDeletePin;

  @override
  Widget build(BuildContext context) {
    final node = selectedNode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RightPanelHeader(
          icon: Icons.tune,
          title: '${node.title} · 细节面板',
          subtitle: node.nodeType,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              child: _SelectedNodeDetails(
                key: ValueKey(node.id),
                node: node,
                nodeBook: nodeBook,
                document: document,
                onNodeChanged: onNodeChanged,
                onAutoSizeComment: onAutoSizeComment,
                onAddExpandablePin: onAddExpandablePin,
                onDeletePin: onDeletePin,
              ),
            ),
          ),
        ),
        if (showJsonPreview) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 190,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('JSON 预览', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Expanded(child: _JsonPreview(document: document)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RightPanelHeader extends StatelessWidget {
  const _RightPanelHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF38BDF8)],
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF102033),
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF526276),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return Tooltip(
      message: '定位到图表节点',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('right-panel-header-$title'),
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(2), child: content),
        ),
      ),
    );
  }
}

class _SelectedNodeDetails extends StatelessWidget {
  const _SelectedNodeDetails({
    super.key,
    required this.node,
    required this.nodeBook,
    required this.document,
    required this.onNodeChanged,
    required this.onAutoSizeComment,
    required this.onAddExpandablePin,
    required this.onDeletePin,
  });

  final GraphNode node;
  final EngineNodeBook nodeBook;
  final GraphDocument document;
  final ValueChanged<GraphNode> onNodeChanged;
  final VoidCallback onAutoSizeComment;
  final ValueChanged<ExpandablePinGroup> onAddExpandablePin;
  final ValueChanged<String> onDeletePin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: const ValueKey('node-title-field'),
          initialValue: node.title,
          onTap: () => ImeControl.setEnabled(true),
          decoration: const InputDecoration(
            labelText: '标题',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => onNodeChanged(node.copyWith(title: value)),
        ),
        const SizedBox(height: 10),
        _NodeTemplateSummary(node: node, nodeBook: nodeBook),
        if (node.nodeType == 'Comment') ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('comment-auto-size-button'),
              onPressed: onAutoSizeComment,
              icon: const Icon(Icons.fit_screen_rounded),
              label: const Text('自动贴合内部节点'),
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextFormField(
          key: const ValueKey('node-description-field'),
          initialValue: node.description,
          onTap: () => ImeControl.setEnabled(true),
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '说明',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (value) =>
              onNodeChanged(node.copyWith(description: value)),
        ),
        const SizedBox(height: 12),
        _InspectorValue(
          label: '位置',
          value:
              'x ${node.position.x.toStringAsFixed(1)}, y ${node.position.y.toStringAsFixed(1)}',
        ),
        _InspectorValue(
          label: '尺寸',
          value:
              '${node.size.width.toStringAsFixed(0)} x ${node.size.height.toStringAsFixed(0)}',
        ),
        _InspectorValue(label: '引脚', value: '${node.pins.length}'),
        const SizedBox(height: 10),
        _PinEditorSection(
          node: node,
          nodeBook: nodeBook,
          onAddExpandablePin: onAddExpandablePin,
          onDeletePin: onDeletePin,
        ),
      ],
    );
  }
}

class _PinEditorSection extends StatelessWidget {
  const _PinEditorSection({
    required this.node,
    required this.nodeBook,
    required this.onAddExpandablePin,
    required this.onDeletePin,
  });

  final GraphNode node;
  final EngineNodeBook nodeBook;
  final ValueChanged<ExpandablePinGroup> onAddExpandablePin;
  final ValueChanged<String> onDeletePin;

  @override
  Widget build(BuildContext context) {
    final template = UnrealNodeCatalog.findTemplateForNode(nodeBook.id, node);
    final templatePinIds =
        template?.pins.map((pin) => pin.id).toSet() ?? const <String>{};
    final expandableGroups =
        template?.expandablePinGroups ?? const <ExpandablePinGroup>[];
    final inputs = node.pins
        .where((pin) => pin.direction == GraphPinDirection.input)
        .toList(growable: false);
    final outputs = node.pins
        .where((pin) => pin.direction == GraphPinDirection.output)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('引脚', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final pin in [...inputs, ...outputs])
          _PinEditorRow(
            pin: pin,
            canDelete:
                template != null &&
                !_isTemplatePin(node.id, pin.id, templatePinIds) &&
                _isExpandablePin(pin.id, expandableGroups),
            onDeletePin: onDeletePin,
          ),
        if (expandableGroups.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final group in expandableGroups)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton.icon(
                key: ValueKey('add-expandable-pin-${group.idPrefix}'),
                onPressed: () => onAddExpandablePin(group),
                icon: Icon(
                  group.direction == GraphPinDirection.input
                      ? Icons.input
                      : Icons.output,
                  size: 16,
                ),
                label: Text(group.actionLabel),
              ),
            ),
        ],
      ],
    );
  }

  bool _isTemplatePin(String nodeId, String pinId, Set<String> templatePinIds) {
    if (templatePinIds.contains(pinId)) {
      return true;
    }

    final prefix = '${nodeId}_';
    if (pinId.startsWith(prefix)) {
      return templatePinIds.contains(pinId.substring(prefix.length));
    }

    return false;
  }

  bool _isExpandablePin(String pinId, List<ExpandablePinGroup> groups) {
    for (final group in groups) {
      final marker = '${group.idPrefix}_';
      final markerIndex = pinId.lastIndexOf(marker);
      if (markerIndex < 0) {
        continue;
      }
      if (int.tryParse(pinId.substring(markerIndex + marker.length)) != null) {
        return true;
      }
    }

    return false;
  }
}

class _NodeTemplateSummary extends StatelessWidget {
  const _NodeTemplateSummary({required this.node, required this.nodeBook});

  final GraphNode node;
  final EngineNodeBook nodeBook;

  @override
  Widget build(BuildContext context) {
    final template = UnrealNodeCatalog.findTemplateForNode(nodeBook.id, node);
    final matched = template != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: matched ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: matched ? const Color(0xFFBFDBFE) : const Color(0xFFFED7AA),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InspectorValue(label: '节点', value: node.nodeType),
            _InspectorValue(
              label: '目录',
              value: template?.category ?? '未匹配 UE 节点',
            ),
            Text(
              matched
                  ? '节点类型来自内置 UE 5.6 节点目录；引脚结构不在细节面板中自由增删。'
                  : '这是旧草稿或 AI 生成的自定义节点，后续建议替换为 UE 5.6 目录节点。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: matched
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFF9A3412),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinEditorRow extends StatelessWidget {
  const _PinEditorRow({
    required this.pin,
    required this.canDelete,
    required this.onDeletePin,
  });

  final GraphPin pin;
  final bool canDelete;
  final ValueChanged<String> onDeletePin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            pin.direction == GraphPinDirection.input
                ? Icons.arrow_back
                : Icons.arrow_forward,
            size: 16,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${pin.title} / ${pin.dataType}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (canDelete)
            IconButton(
              key: ValueKey('delete-pin-${pin.id}'),
              onPressed: () => onDeletePin(pin.id),
              icon: const Icon(Icons.close, size: 15),
              tooltip: '删除扩展引脚',
              visualDensity: VisualDensity.compact,
            )
          else
            Tooltip(
              message: 'UE 节点引脚为只读',
              child: Icon(
                Icons.lock_outline,
                size: 15,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
        ],
      ),
    );
  }
}

class _InspectorValue extends StatelessWidget {
  const _InspectorValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _JsonPreview extends StatelessWidget {
  const _JsonPreview({required this.document});

  final GraphDocument document;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const codec = GraphJsonCodec();
    final json = codec.encode(document);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7E7F8)),
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            json,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorStatusBar extends StatelessWidget {
  const _EditorStatusBar({required this.document});

  final GraphDocument document;

  @override
  Widget build(BuildContext context) {
    final zoom = (document.graph.viewport.zoom * 100).round();

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xF4FFFFFF),
        border: const Border(top: BorderSide(color: Color(0xFFD7E7F8))),
      ),
      child: Row(
        children: [
          Text(
            document.graph.title,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const Spacer(),
          Text(
            '节点 ${document.nodes.length} · 连线 ${document.links.length} · 缩放 $zoom%',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
