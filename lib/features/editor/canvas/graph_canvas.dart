import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/graph_document.dart';
import '../../../core/models/graph_link.dart';
import '../../../core/models/graph_node.dart';
import '../../../core/models/graph_pin.dart';
import '../../../core/models/graph_viewport.dart';
import 'graph_canvas_geometry.dart';
import 'graph_node_style.dart';

class GraphCanvas extends StatefulWidget {
  const GraphCanvas({
    super.key,
    required this.document,
    required this.selectedNodeIds,
    required this.onDocumentChanged,
    required this.onSelectedNodesChanged,
    this.onOpenNodeSearch,
    this.onShortcutNodeRequested,
    this.onNodeDoubleTapped,
    this.focusNode,
  });

  final GraphDocument document;
  final Set<String> selectedNodeIds;
  final ValueChanged<GraphDocument> onDocumentChanged;
  final ValueChanged<Set<String>> onSelectedNodesChanged;
  final void Function(Offset screenPosition, GraphCanvasPoint worldPosition)?
  onOpenNodeSearch;
  final void Function(String templateId, GraphCanvasPoint worldPosition)?
  onShortcutNodeRequested;
  final ValueChanged<GraphNode>? onNodeDoubleTapped;
  final FocusNode? focusNode;

  @override
  State<GraphCanvas> createState() => _GraphCanvasState();
}

class _GraphCanvasState extends State<GraphCanvas> {
  static const double _edgeAutoPanZone = 96;
  static const double _edgeAutoPanMaxStep = 18;
  static const Duration _edgeAutoPanInterval = Duration(milliseconds: 16);

  late FocusNode _ownedCanvasFocusNode;
  int? _activePointer;
  String? _draggingNodeId;
  GraphCanvasPoint? _nodeGrabOffsetWorld;
  Map<String, GraphNodePosition> _dragStartNodePositions =
      const <String, GraphNodePosition>{};
  GraphCommentResizeHit? _commentResizeHit;
  GraphCanvasPoint? _commentResizeStartWorldPoint;
  GraphCanvasPoint? _panStartScreenPoint;
  GraphViewport? _panStartViewport;
  GraphCanvasPinHit? _linkDragStart;
  GraphCanvasPinHit? _linkDragHover;
  GraphCanvasPoint? _linkDragCurrentWorld;
  bool _linkDragDetachedInput = false;
  GraphCanvasPinHit? _pendingWheelPin;
  GraphNode? _pinWheelNode;
  GraphCanvasPoint? _pinWheelScreenCenter;
  GraphPin? _pinWheelHoverPin;
  bool _linkDragRejected = false;
  bool _isPanning = false;
  bool _secondaryBlankCandidate = false;
  Offset? _secondaryStartGlobalPosition;
  GraphCanvasPoint? _secondaryStartScreenPoint;
  GraphCanvasPoint? _selectionStartScreenPoint;
  GraphCanvasPoint? _selectionCurrentScreenPoint;
  Size _canvasSize = Size.zero;
  Timer? _edgeAutoPanTimer;
  GraphCanvasPoint? _edgeAutoPanPointer;
  String? _lastTapNodeId;
  DateTime? _lastTapTime;
  GraphCanvasPoint? _lastTapScreenPoint;

  GraphViewport get _viewport => widget.document.graph.viewport;
  bool get _isSelecting => _selectionStartScreenPoint != null;
  FocusNode get _canvasFocusNode => widget.focusNode ?? _ownedCanvasFocusNode;
  GraphCanvasPinHit? get _activeConnectionSource =>
      _linkDragStart ??
      _pendingWheelPin ??
      (_pinWheelNode != null && _pinWheelHoverPin != null
          ? GraphCanvasPinHit(node: _pinWheelNode!, pin: _pinWheelHoverPin!)
          : null);

  @override
  void initState() {
    super.initState();
    _ownedCanvasFocusNode = FocusNode(debugLabel: 'GraphCanvas');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_canvasFocusNode.hasFocus) {
        _canvasFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _stopEdgeAutoPan();
    _ownedCanvasFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeConnectionSource = _activeConnectionSource;

    return Focus(
      focusNode: _canvasFocusNode,
      onKeyEvent: _handleCanvasKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _canvasFocusNode.requestFocus(),
        onLongPressStart: _handleLongPressStart,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerSignal: _handlePointerSignal,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: (_) => _clearDragState(),
          child: MouseRegion(
            cursor: _isPanning
                ? SystemMouseCursors.grabbing
                : SystemMouseCursors.basic,
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _canvasSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );

                  return ColoredBox(
                    color: const Color(0xFFF4F8FD),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GraphCanvasPainter(
                              colorScheme: colorScheme,
                              nodes: widget.document.nodes,
                              links: widget.document.links,
                              viewport: _viewport,
                            ),
                          ),
                        ),
                        if (_selectionRect case final rect?)
                          Positioned.fill(child: _SelectionOverlay(rect: rect)),
                        for (final node in [
                          ...widget.document.nodes.where(
                            (node) => node.nodeType == 'Comment',
                          ),
                          ...widget.document.nodes.where(
                            (node) => node.nodeType != 'Comment',
                          ),
                        ])
                          _PositionedGraphNode(
                            key: ValueKey(node.id),
                            node: node,
                            links: widget.document.links,
                            viewport: _viewport,
                            selected: widget.selectedNodeIds.contains(node.id),
                            compatibleTarget: _isCompatibleTargetNode(
                              node,
                              activeConnectionSource,
                            ),
                          ),
                        if (_linkDragStart != null ||
                            _linkDragRejected ||
                            _linkDragHover != null ||
                            _pendingWheelPin != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _GraphCanvasInteractionPainter(
                                  nodes: widget.document.nodes,
                                  viewport: _viewport,
                                  linkDragStart:
                                      _linkDragStart ?? _pendingWheelPin,
                                  linkDragHover: _linkDragHover,
                                  linkDragCurrentWorld: _linkDragCurrentWorld,
                                  linkDragRejected: _linkDragRejected,
                                ),
                              ),
                            ),
                          ),
                        if (_pinWheelNode != null &&
                            _pinWheelScreenCenter != null)
                          _PinWheelOverlay(
                            node: _pinWheelNode!,
                            center: _pinWheelScreenCenter!,
                            hoveredPinId: _pinWheelHoverPin?.id,
                          ),
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: _CanvasHint(
                            zoom: _viewport.zoom,
                            nodeCount: widget.document.nodes.length,
                            linkCount: widget.document.links.length,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Rect? get _selectionRect {
    final start = _selectionStartScreenPoint;
    final current = _selectionCurrentScreenPoint;
    if (start == null || current == null) {
      return null;
    }

    return Rect.fromPoints(_toOffset(start), _toOffset(current));
  }

  void _handlePointerDown(PointerDownEvent event) {
    _canvasFocusNode.requestFocus();
    if (_activePointer != null) {
      return;
    }

    final screenPoint = _fromOffset(event.localPosition);
    _activePointer = event.pointer;

    if (_pinWheelNode != null && _isPointInsidePinWheel(screenPoint)) {
      _updatePinWheelHover(screenPoint);
      return;
    }

    if ((event.buttons & kPrimaryMouseButton) != 0) {
      final commentResizeHit = GraphCanvasGeometry.hitTestCommentResizeHandle(
        nodes: widget.document.nodes,
        selectedNodeIds: widget.selectedNodeIds,
        screenPoint: screenPoint,
        viewport: _viewport,
      );
      if (commentResizeHit != null) {
        _startCommentResize(commentResizeHit, screenPoint);
        return;
      }

      if (_pendingWheelPin != null) {
        _finishPendingWheelLink(screenPoint);
        _clearDragState();
        return;
      }

      final pinDefaultHit = GraphCanvasGeometry.hitTestPinDefault(
        nodes: widget.document.nodes,
        screenPoint: screenPoint,
        viewport: _viewport,
      );
      if (pinDefaultHit != null) {
        _toggleBoolPinDefault(pinDefaultHit);
        _clearDragState();
        return;
      }

      final pinHit = GraphCanvasGeometry.hitTestPin(
        nodes: widget.document.nodes,
        screenPoint: screenPoint,
        viewport: _viewport,
      );
      if (pinHit != null) {
        _startLinkDrag(pinHit, screenPoint);
        return;
      }
    }

    if ((event.buttons & kSecondaryMouseButton) != 0) {
      final node = GraphCanvasGeometry.hitTestNode(
        nodes: widget.document.nodes,
        screenPoint: screenPoint,
        viewport: _viewport,
      );
      if (node == null) {
        _secondaryBlankCandidate = true;
        _secondaryStartGlobalPosition = event.position;
        _secondaryStartScreenPoint = screenPoint;
      }
      _startViewportPan(screenPoint);
      return;
    }

    if ((event.buttons & kPrimaryMouseButton) != 0) {
      final shortcutTemplateId = _pressedShortcutTemplateId();
      if (shortcutTemplateId != null) {
        final node = GraphCanvasGeometry.hitTestNode(
          nodes: widget.document.nodes,
          screenPoint: screenPoint,
          viewport: _viewport,
        );
        if (node == null) {
          widget.onShortcutNodeRequested?.call(
            shortcutTemplateId,
            GraphCanvasGeometry.screenToWorld(screenPoint, _viewport),
          );
          _clearDragState();
          return;
        }
      }
    }

    final node = GraphCanvasGeometry.hitTestNode(
      nodes: widget.document.nodes,
      screenPoint: screenPoint,
      viewport: _viewport,
    );

    if (node != null) {
      _hidePinWheel();
      if (_consumeNodeDoubleTap(node, screenPoint)) {
        return;
      }
      _startNodeDrag(node, screenPoint);
      return;
    }

    setState(() {
      _pinWheelNode = null;
      _pinWheelScreenCenter = null;
      _pinWheelHoverPin = null;
      _pendingWheelPin = null;
      _selectionStartScreenPoint = screenPoint;
      _selectionCurrentScreenPoint = screenPoint;
    });
    widget.onSelectedNodesChanged(const {});
  }

  KeyEventResult _handleCanvasKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    return _shortcutTemplateIdForPhysicalKey(event.physicalKey) == null
        ? KeyEventResult.ignored
        : KeyEventResult.handled;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }

    final current = _fromOffset(event.localPosition);

    if (_pinWheelNode != null) {
      _updatePinWheelHover(current);
      return;
    }

    if (_isPanning) {
      _updateViewportFromPan(current);
      return;
    }

    if (_linkDragStart != null) {
      _updateLinkDrag(current);
      _updateEdgeAutoPan(current);
      return;
    }

    if (_commentResizeHit != null) {
      _updateCommentResize(current);
      return;
    }

    if (_draggingNodeId != null) {
      _updateNodeFromDrag(current);
      return;
    }

    if (_isSelecting) {
      setState(() => _selectionCurrentScreenPoint = current);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }

    final wasWheelPicking = _pinWheelNode != null;
    final wheelPinSelected = wasWheelPicking
        ? _finishPinWheelPick(_fromOffset(event.localPosition))
        : false;
    if (wasWheelPicking) {
      _activePointer = null;
      if (!wheelPinSelected) {
        _hidePinWheel();
      }
      return;
    }

    final wasLinkDragging = _linkDragStart != null;
    final shouldOpenSearchFromLinkDrop =
        wasLinkDragging && !_linkDragDetachedInput;
    final linkCreated = wasLinkDragging
        ? _finishLinkDrag(_fromOffset(event.localPosition))
        : false;

    if (_isSelecting) {
      _selectNodeInSelection();
    }

    if (_shouldOpenNodeCatalogFromSecondaryClick(event.localPosition)) {
      final startGlobal = _secondaryStartGlobalPosition ?? event.position;
      final startScreen =
          _secondaryStartScreenPoint ?? _fromOffset(event.localPosition);
      widget.onOpenNodeSearch?.call(
        startGlobal,
        GraphCanvasGeometry.screenToWorld(startScreen, _viewport),
      );
    }

    if (shouldOpenSearchFromLinkDrop && !linkCreated) {
      final dropScreen = _fromOffset(event.localPosition);
      widget.onOpenNodeSearch?.call(
        event.position,
        GraphCanvasGeometry.screenToWorld(dropScreen, _viewport),
      );
    }

    _clearDragState(preserveRejectedPulse: wasLinkDragging && !linkCreated);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    final screenPoint = _fromOffset(details.localPosition);
    final node = GraphCanvasGeometry.hitTestNode(
      nodes: widget.document.nodes,
      screenPoint: screenPoint,
      viewport: _viewport,
    );
    if (node != null) {
      _showPinWheel(node);
      return;
    }

    _clearDragState();
    widget.onOpenNodeSearch?.call(
      details.globalPosition,
      GraphCanvasGeometry.screenToWorld(screenPoint, _viewport),
    );
  }

  void _startViewportPan(GraphCanvasPoint screenPoint) {
    _isPanning = true;
    _panStartScreenPoint = screenPoint;
    _panStartViewport = _viewport;
  }

  void _startNodeDrag(GraphNode node, GraphCanvasPoint screenPoint) {
    _draggingNodeId = node.id;
    _nodeGrabOffsetWorld =
        GraphCanvasGeometry.screenToWorld(screenPoint, _viewport) -
        GraphCanvasPoint(node.position.x, node.position.y);
    final dragNodeIds = <String>{node.id};
    if (node.nodeType == 'Comment') {
      dragNodeIds.addAll(
        GraphCanvasGeometry.nodeIdsInsideComment(
          comment: node,
          nodes: widget.document.nodes,
        ),
      );
    }
    _dragStartNodePositions = <String, GraphNodePosition>{
      for (final candidate in widget.document.nodes)
        if (dragNodeIds.contains(candidate.id))
          candidate.id: candidate.position,
    };
    widget.onSelectedNodesChanged({node.id});
  }

  void _startCommentResize(
    GraphCommentResizeHit hit,
    GraphCanvasPoint screenPoint,
  ) {
    _hidePinWheel();
    _commentResizeHit = hit;
    _commentResizeStartWorldPoint = GraphCanvasGeometry.screenToWorld(
      screenPoint,
      _viewport,
    );
    widget.onSelectedNodesChanged({hit.node.id});
  }

  bool _consumeNodeDoubleTap(GraphNode node, GraphCanvasPoint screenPoint) {
    final lastTapTime = _lastTapTime;
    final lastTapNodeId = _lastTapNodeId;
    final lastTapScreenPoint = _lastTapScreenPoint;
    final now = DateTime.now();
    final isDoubleTap =
        lastTapTime != null &&
        lastTapNodeId == node.id &&
        lastTapScreenPoint != null &&
        now.difference(lastTapTime) <= const Duration(milliseconds: 320) &&
        _screenDistance(lastTapScreenPoint, screenPoint) <= 8;

    _lastTapNodeId = node.id;
    _lastTapTime = now;
    _lastTapScreenPoint = screenPoint;

    if (!isDoubleTap) {
      return false;
    }

    _lastTapNodeId = null;
    _lastTapTime = null;
    _lastTapScreenPoint = null;
    _clearDragState();
    widget.onNodeDoubleTapped?.call(node);
    return true;
  }

  void _updateViewportFromPan(GraphCanvasPoint current) {
    final startViewport = _panStartViewport;
    final startPoint = _panStartScreenPoint;
    if (startViewport == null || startPoint == null) {
      return;
    }
    if (_secondaryBlankCandidate && _screenDistance(startPoint, current) > 5) {
      _secondaryBlankCandidate = false;
    }

    _updateViewport(
      GraphCanvasGeometry.viewportFromPan(
        startViewport: startViewport,
        startScreenPoint: startPoint,
        currentScreenPoint: current,
      ),
    );
  }

  void _updateNodeFromDrag(GraphCanvasPoint current) {
    final nodeId = _draggingNodeId;
    final grabOffset = _nodeGrabOffsetWorld;
    if (nodeId == null || grabOffset == null) {
      return;
    }

    final nextPosition = GraphCanvasGeometry.nodePositionFromDrag(
      pointerScreenPoint: current,
      viewport: _viewport,
      grabOffsetWorld: grabOffset,
    );
    _updateNodeDragPositions(nodeId, nextPosition);
  }

  void _updateCommentResize(GraphCanvasPoint current) {
    final hit = _commentResizeHit;
    final startPoint = _commentResizeStartWorldPoint;
    if (hit == null || startPoint == null) {
      return;
    }

    final currentPoint = GraphCanvasGeometry.screenToWorld(current, _viewport);
    final nextNode = GraphCanvasGeometry.resizeCommentFromDrag(
      comment: hit.node,
      handle: hit.handle,
      startWorldPoint: startPoint,
      currentWorldPoint: currentPoint,
    );
    _updateNode(nextNode);
  }

  void _selectNodeInSelection() {
    final selectionRect = _selectionRect;
    if (selectionRect == null) {
      return;
    }

    if (selectionRect.width.abs() < 4 && selectionRect.height.abs() < 4) {
      widget.onSelectedNodesChanged(const {});
      return;
    }

    final normalizedSelection = Rect.fromPoints(
      selectionRect.topLeft,
      selectionRect.bottomRight,
    );

    final selectedNodeIds = <String>{};
    for (final node in widget.document.nodes.reversed) {
      final effectiveSize = GraphCanvasGeometry.effectiveNodeSize(node);
      final topLeft = GraphCanvasGeometry.worldToScreen(
        GraphCanvasPoint(node.position.x, node.position.y),
        _viewport,
      );
      final bottomRight = GraphCanvasGeometry.worldToScreen(
        GraphCanvasPoint(
          node.position.x + effectiveSize.width,
          node.position.y + effectiveSize.height,
        ),
        _viewport,
      );
      final nodeRect = Rect.fromPoints(
        _toOffset(topLeft),
        _toOffset(bottomRight),
      );
      if (normalizedSelection.overlaps(nodeRect)) {
        selectedNodeIds.add(node.id);
      }
    }

    widget.onSelectedNodesChanged(Set.unmodifiable(selectedNodeIds));
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }

    final oldViewport = _viewport;
    final oldZoom = oldViewport.zoom;
    final zoomDirection = event.scrollDelta.dy > 0 ? -1 : 1;
    final zoomFactor = zoomDirection > 0 ? 1.08 : 0.92;
    final newZoom = (oldZoom * zoomFactor).clamp(0.35, 2.4).toDouble();
    if (newZoom == oldZoom) {
      return;
    }

    final local = _fromOffset(event.localPosition);
    final worldBefore = GraphCanvasGeometry.screenToWorld(local, oldViewport);
    final nextViewport = GraphViewport(
      offsetX: local.x - worldBefore.x * newZoom,
      offsetY: local.y - worldBefore.y * newZoom,
      zoom: newZoom,
    );
    _updateViewport(nextViewport);
  }

  void _clearDragState({bool preserveRejectedPulse = false}) {
    _activePointer = null;
    _draggingNodeId = null;
    _nodeGrabOffsetWorld = null;
    _dragStartNodePositions = const <String, GraphNodePosition>{};
    _commentResizeHit = null;
    _commentResizeStartWorldPoint = null;
    _panStartScreenPoint = null;
    _panStartViewport = null;
    _isPanning = false;
    _linkDragStart = null;
    _linkDragHover = null;
    _linkDragCurrentWorld = null;
    _linkDragDetachedInput = false;
    _pendingWheelPin = null;
    _stopEdgeAutoPan();
    _pinWheelNode = null;
    _pinWheelScreenCenter = null;
    _pinWheelHoverPin = null;
    if (!preserveRejectedPulse) {
      _linkDragRejected = false;
    } else {
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (mounted) {
          setState(() => _linkDragRejected = false);
        }
      });
    }
    _secondaryBlankCandidate = false;
    _secondaryStartGlobalPosition = null;
    _secondaryStartScreenPoint = null;
    if (_selectionStartScreenPoint != null ||
        _selectionCurrentScreenPoint != null) {
      setState(() {
        _selectionStartScreenPoint = null;
        _selectionCurrentScreenPoint = null;
      });
    }
  }

  void _updateViewport(GraphViewport viewport) {
    final updated = widget.document.copyWith(
      graph: widget.document.graph.copyWith(
        viewport: viewport,
        updatedAt: DateTime.now(),
      ),
    );
    widget.onDocumentChanged(updated);
  }

  void _startLinkDrag(GraphCanvasPinHit pinHit, GraphCanvasPoint screenPoint) {
    _hidePinWheel();
    final detachedStart = _detachInputLinkForDrag(pinHit);
    final linkStart = detachedStart ?? pinHit;
    widget.onSelectedNodesChanged({linkStart.node.id});
    setState(() {
      _linkDragStart = linkStart;
      _linkDragHover = null;
      _linkDragDetachedInput = detachedStart != null;
      _linkDragRejected = false;
      _linkDragCurrentWorld = GraphCanvasGeometry.screenToWorld(
        screenPoint,
        _viewport,
      );
    });
  }

  GraphCanvasPinHit? _detachInputLinkForDrag(GraphCanvasPinHit pinHit) {
    if (pinHit.pin.direction != GraphPinDirection.input) {
      return null;
    }

    final existingLink = widget.document.links
        .where(
          (link) =>
              link.toNodeId == pinHit.node.id && link.toPinId == pinHit.pin.id,
        )
        .lastOrNull;
    if (existingLink == null) {
      return null;
    }

    final sourceNode = widget.document.nodes
        .where((node) => node.id == existingLink.fromNodeId)
        .firstOrNull;
    final sourcePin = sourceNode?.pins
        .where((pin) => pin.id == existingLink.fromPinId)
        .firstOrNull;
    if (sourceNode == null || sourcePin == null) {
      return null;
    }

    final nextLinks = widget.document.links
        .where((link) => link.id != existingLink.id)
        .toList(growable: false);
    widget.onDocumentChanged(
      widget.document.copyWith(
        links: nextLinks,
        graph: widget.document.graph.copyWith(updatedAt: DateTime.now()),
      ),
    );

    return GraphCanvasPinHit(node: sourceNode, pin: sourcePin);
  }

  void _updateLinkDrag(GraphCanvasPoint screenPoint) {
    final start = _linkDragStart;
    if (start == null) {
      return;
    }

    final hover = _findLinkTarget(screenPoint, start);
    setState(() {
      _linkDragCurrentWorld = GraphCanvasGeometry.screenToWorld(
        screenPoint,
        _viewport,
      );
      _linkDragHover = hover;
      _linkDragRejected =
          hover == null &&
          GraphCanvasGeometry.hitTestNode(
                nodes: widget.document.nodes,
                screenPoint: screenPoint,
                viewport: _viewport,
              ) !=
              null;
    });
  }

  void _updateEdgeAutoPan(GraphCanvasPoint screenPoint) {
    final velocity = _edgeAutoPanVelocity(screenPoint);
    if (velocity == Offset.zero) {
      _stopEdgeAutoPan();
      return;
    }

    _edgeAutoPanPointer = screenPoint;
    _edgeAutoPanTimer ??= Timer.periodic(
      _edgeAutoPanInterval,
      (_) => _tickEdgeAutoPan(),
    );
  }

  void _tickEdgeAutoPan() {
    final pointer = _edgeAutoPanPointer;
    if (pointer == null || _activeConnectionSource == null) {
      _stopEdgeAutoPan();
      return;
    }

    final velocity = _edgeAutoPanVelocity(pointer);
    if (velocity == Offset.zero) {
      _stopEdgeAutoPan();
      return;
    }

    final nextViewport = _viewport.copyWith(
      offsetX: _viewport.offsetX + velocity.dx,
      offsetY: _viewport.offsetY + velocity.dy,
    );
    _updateViewport(nextViewport);

    final currentWorld = _linkDragCurrentWorld;
    if (currentWorld != null) {
      setState(() {
        _linkDragCurrentWorld = GraphCanvasPoint(
          currentWorld.x - velocity.dx / _viewport.zoom,
          currentWorld.y - velocity.dy / _viewport.zoom,
        );
      });
    }
  }

  Offset _edgeAutoPanVelocity(GraphCanvasPoint screenPoint) {
    if (_canvasSize == Size.zero) {
      return Offset.zero;
    }

    final dx =
        _edgeAutoPanAxis(screenPoint.x, _canvasSize.width) *
        _edgeAutoPanMaxStep;
    final dy =
        _edgeAutoPanAxis(screenPoint.y, _canvasSize.height) *
        _edgeAutoPanMaxStep;
    return Offset(dx, dy);
  }

  double _edgeAutoPanAxis(double position, double extent) {
    if (extent <= 0) {
      return 0;
    }
    if (position < _edgeAutoPanZone) {
      return ((_edgeAutoPanZone - position) / _edgeAutoPanZone).clamp(0.0, 1.0);
    }
    if (position > extent - _edgeAutoPanZone) {
      return -((position - (extent - _edgeAutoPanZone)) / _edgeAutoPanZone)
          .clamp(0.0, 1.0);
    }
    return 0;
  }

  void _stopEdgeAutoPan() {
    _edgeAutoPanTimer?.cancel();
    _edgeAutoPanTimer = null;
    _edgeAutoPanPointer = null;
  }

  void _showPinWheel(GraphNode node) {
    final effectiveSize = GraphCanvasGeometry.effectiveNodeSize(node);
    final centerWorld = GraphCanvasPoint(
      node.position.x + effectiveSize.width / 2,
      node.position.y + effectiveSize.height / 2,
    );
    final centerScreen = GraphCanvasGeometry.worldToScreen(
      centerWorld,
      _viewport,
    );
    widget.onSelectedNodesChanged({node.id});
    setState(() {
      _pinWheelNode = node;
      _pinWheelScreenCenter = centerScreen;
      _pinWheelHoverPin = null;
      _pendingWheelPin = null;
      _linkDragRejected = false;
      _draggingNodeId = null;
      _nodeGrabOffsetWorld = null;
    });
  }

  void _hidePinWheel() {
    if (_pinWheelNode == null && _pinWheelScreenCenter == null) {
      return;
    }
    setState(() {
      _pinWheelNode = null;
      _pinWheelScreenCenter = null;
      _pinWheelHoverPin = null;
    });
  }

  void _updatePinWheelHover(GraphCanvasPoint screenPoint) {
    final node = _pinWheelNode;
    final center = _pinWheelScreenCenter;
    if (node == null || center == null) {
      return;
    }

    final nextPin = GraphCanvasGeometry.pinWheelPinAt(
      node: node,
      center: center,
      screenPoint: screenPoint,
    );
    if (nextPin?.id == _pinWheelHoverPin?.id) {
      return;
    }

    setState(() => _pinWheelHoverPin = nextPin);
  }

  bool _finishPinWheelPick(GraphCanvasPoint screenPoint) {
    final node = _pinWheelNode;
    final center = _pinWheelScreenCenter;
    if (node == null || center == null) {
      return false;
    }

    final selectedPin =
        GraphCanvasGeometry.pinWheelPinAt(
          node: node,
          center: center,
          screenPoint: screenPoint,
        ) ??
        _pinWheelHoverPin;
    if (selectedPin == null) {
      return false;
    }

    _selectPinFromWheel(selectedPin, screenPoint);
    return true;
  }

  void _selectPinFromWheel(GraphPin pin, GraphCanvasPoint screenPoint) {
    final node = _pinWheelNode;
    if (node == null) {
      return;
    }

    setState(() {
      _pendingWheelPin = GraphCanvasPinHit(node: node, pin: pin);
      _pinWheelNode = null;
      _pinWheelScreenCenter = null;
      _pinWheelHoverPin = null;
      _linkDragRejected = false;
      _linkDragCurrentWorld = GraphCanvasGeometry.screenToWorld(
        screenPoint,
        _viewport,
      );
    });
  }

  void _finishPendingWheelLink(GraphCanvasPoint screenPoint) {
    final start = _pendingWheelPin;
    if (start == null) {
      return;
    }
    final target = _findLinkTarget(screenPoint, start);
    final normalized = target == null
        ? null
        : GraphCanvasGeometry.normalizeConnection(start, target);
    if (normalized == null) {
      setState(() => _linkDragRejected = true);
      return;
    }
    _createCanvasLink(normalized.from, normalized.to);
  }

  bool _finishLinkDrag(GraphCanvasPoint screenPoint) {
    final start = _linkDragStart;
    if (start == null) {
      return false;
    }

    final target = _findLinkTarget(screenPoint, start);
    final normalized = target == null
        ? null
        : GraphCanvasGeometry.normalizeConnection(start, target);
    if (normalized == null) {
      setState(() {
        _linkDragRejected = true;
      });
      return false;
    }

    _createCanvasLink(normalized.from, normalized.to);
    return true;
  }

  GraphCanvasPinHit? _findLinkTarget(
    GraphCanvasPoint screenPoint,
    GraphCanvasPinHit start,
  ) {
    final pinHit = GraphCanvasGeometry.hitTestPin(
      nodes: widget.document.nodes,
      screenPoint: screenPoint,
      viewport: _viewport,
    );
    if (pinHit != null && GraphCanvasGeometry.canConnectPins(start, pinHit)) {
      return pinHit;
    }

    final nodeHit = GraphCanvasGeometry.hitTestNode(
      nodes: widget.document.nodes,
      screenPoint: screenPoint,
      viewport: _viewport,
    );
    if (nodeHit == null) {
      return null;
    }

    return GraphCanvasGeometry.compatiblePinOnNode(
      source: start,
      targetNode: nodeHit,
    );
  }

  void _createCanvasLink(GraphCanvasPinHit from, GraphCanvasPinHit to) {
    final fromPin = from.pin;
    final toPin = to.pin;
    final duplicate = widget.document.links.any(
      (link) =>
          link.fromNodeId == from.node.id &&
          link.fromPinId == fromPin.id &&
          link.toNodeId == to.node.id &&
          link.toPinId == toPin.id,
    );
    if (duplicate) {
      return;
    }

    final nextLinks =
        widget.document.links
            .where((link) {
              if (toPin.allowMultipleLinks) {
                return true;
              }
              return !(link.toNodeId == to.node.id && link.toPinId == toPin.id);
            })
            .toList(growable: true)
          ..add(
            GraphLink(
              id: 'link_${DateTime.now().microsecondsSinceEpoch}',
              fromNodeId: from.node.id,
              fromPinId: fromPin.id,
              toNodeId: to.node.id,
              toPinId: toPin.id,
              title: '',
              description: '',
              linkType: fromPin.dataType == 'exec' || toPin.dataType == 'exec'
                  ? 'exec'
                  : 'data',
            ),
          );

    widget.onDocumentChanged(
      widget.document.copyWith(
        links: nextLinks,
        graph: widget.document.graph.copyWith(updatedAt: DateTime.now()),
      ),
    );
  }

  void _updateNodePosition(String nodeId, GraphNodePosition position) {
    final updatedNodes = widget.document.nodes
        .map(
          (node) =>
              node.id == nodeId ? node.copyWith(position: position) : node,
        )
        .toList(growable: false);
    final updated = widget.document.copyWith(
      graph: widget.document.graph.copyWith(updatedAt: DateTime.now()),
      nodes: updatedNodes,
    );
    widget.onDocumentChanged(updated);
  }

  void _updateNode(GraphNode nextNode) {
    final updatedNodes = widget.document.nodes
        .map((node) => node.id == nextNode.id ? nextNode : node)
        .toList(growable: false);
    final updated = widget.document.copyWith(
      graph: widget.document.graph.copyWith(updatedAt: DateTime.now()),
      nodes: updatedNodes,
    );
    widget.onDocumentChanged(updated);
  }

  void _updateNodeDragPositions(String nodeId, GraphNodePosition position) {
    final startPositions = _dragStartNodePositions;
    if (startPositions.length <= 1 || !startPositions.containsKey(nodeId)) {
      _updateNodePosition(nodeId, position);
      return;
    }

    final startPosition = startPositions[nodeId]!;
    final deltaX = position.x - startPosition.x;
    final deltaY = position.y - startPosition.y;
    final updatedNodes = widget.document.nodes
        .map((node) {
          final nodeStartPosition = startPositions[node.id];
          if (nodeStartPosition == null) {
            return node;
          }

          return node.copyWith(
            position: GraphNodePosition(
              x: nodeStartPosition.x + deltaX,
              y: nodeStartPosition.y + deltaY,
            ),
          );
        })
        .toList(growable: false);
    final updated = widget.document.copyWith(
      graph: widget.document.graph.copyWith(updatedAt: DateTime.now()),
      nodes: updatedNodes,
    );
    widget.onDocumentChanged(updated);
  }

  void _toggleBoolPinDefault(GraphCanvasPinDefaultHit hit) {
    final updatedNodes = widget.document.nodes
        .map((node) {
          if (node.id != hit.node.id) {
            return node;
          }

          final updatedPins = node.pins
              .map((pin) {
                if (pin.id != hit.pin.id) {
                  return pin;
                }

                final currentValue = pin.defaultValue?.toLowerCase() == 'true';
                return pin.copyWith(defaultValue: (!currentValue).toString());
              })
              .toList(growable: false);

          return node.copyWith(pins: updatedPins);
        })
        .toList(growable: false);

    widget.onSelectedNodesChanged({hit.node.id});
    widget.onDocumentChanged(
      widget.document.copyWith(
        graph: widget.document.graph.copyWith(updatedAt: DateTime.now()),
        nodes: updatedNodes,
      ),
    );
  }

  GraphCanvasPoint _fromOffset(Offset offset) {
    return GraphCanvasPoint(offset.dx, offset.dy);
  }

  Offset _toOffset(GraphCanvasPoint point) {
    return Offset(point.x, point.y);
  }

  bool _shouldOpenNodeCatalogFromSecondaryClick(Offset localPosition) {
    if (!_secondaryBlankCandidate) {
      return false;
    }

    final start = _secondaryStartScreenPoint;
    if (start == null) {
      return false;
    }

    return _screenDistance(start, _fromOffset(localPosition)) <= 5;
  }

  bool _isPointInsidePinWheel(GraphCanvasPoint screenPoint) {
    final center = _pinWheelScreenCenter;
    if (center == null) {
      return false;
    }
    return _screenDistance(center, screenPoint) <= 190;
  }

  bool _isCompatibleTargetNode(
    GraphNode node,
    GraphCanvasPinHit? activeConnectionSource,
  ) {
    if (activeConnectionSource == null ||
        activeConnectionSource.node.id == node.id) {
      return false;
    }

    return GraphCanvasGeometry.compatiblePinOnNode(
          source: activeConnectionSource,
          targetNode: node,
        ) !=
        null;
  }

  double _screenDistance(GraphCanvasPoint a, GraphCanvasPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  String? _pressedShortcutTemplateId() {
    final pressed = HardwareKeyboard.instance.physicalKeysPressed;
    if (pressed.contains(PhysicalKeyboardKey.keyC)) {
      return 'comment';
    }
    if (pressed.contains(PhysicalKeyboardKey.keyB)) {
      return 'branch';
    }
    if (pressed.contains(PhysicalKeyboardKey.keyA)) {
      return 'array_get';
    }
    if (pressed.contains(PhysicalKeyboardKey.keyS)) {
      return 'sequence';
    }
    if (pressed.contains(PhysicalKeyboardKey.keyD)) {
      return 'delay';
    }
    if (pressed.contains(PhysicalKeyboardKey.keyP)) {
      return 'event_begin_play';
    }
    if (pressed.contains(PhysicalKeyboardKey.keyF)) {
      return 'for_each_loop';
    }
    if (pressed.contains(PhysicalKeyboardKey.keyG)) {
      return 'gate';
    }
    if (pressed.contains(PhysicalKeyboardKey.keyO)) {
      return 'do_once';
    }
    if (pressed.contains(PhysicalKeyboardKey.keyM)) {
      return 'multi_gate';
    }
    if (pressed.contains(PhysicalKeyboardKey.keyN)) {
      return 'do_n';
    }
    if (pressed.contains(PhysicalKeyboardKey.keyT)) {
      return 'timeline';
    }
    if (pressed.contains(PhysicalKeyboardKey.keyW)) {
      return 'switch_has_authority';
    }
    if (pressed.contains(PhysicalKeyboardKey.keyV)) {
      return 'get_variable';
    }

    return null;
  }

  String? _shortcutTemplateIdForPhysicalKey(PhysicalKeyboardKey key) {
    if (key == PhysicalKeyboardKey.keyC) {
      return 'comment';
    }
    if (key == PhysicalKeyboardKey.keyB) {
      return 'branch';
    }
    if (key == PhysicalKeyboardKey.keyA) {
      return 'array_get';
    }
    if (key == PhysicalKeyboardKey.keyS) {
      return 'sequence';
    }
    if (key == PhysicalKeyboardKey.keyD) {
      return 'delay';
    }
    if (key == PhysicalKeyboardKey.keyP) {
      return 'event_begin_play';
    }
    if (key == PhysicalKeyboardKey.keyF) {
      return 'for_each_loop';
    }
    if (key == PhysicalKeyboardKey.keyG) {
      return 'gate';
    }
    if (key == PhysicalKeyboardKey.keyO) {
      return 'do_once';
    }
    if (key == PhysicalKeyboardKey.keyM) {
      return 'multi_gate';
    }
    if (key == PhysicalKeyboardKey.keyN) {
      return 'do_n';
    }
    if (key == PhysicalKeyboardKey.keyT) {
      return 'timeline';
    }
    if (key == PhysicalKeyboardKey.keyW) {
      return 'switch_has_authority';
    }
    if (key == PhysicalKeyboardKey.keyV) {
      return 'get_variable';
    }

    return null;
  }
}

class _SelectionOverlay extends StatelessWidget {
  const _SelectionOverlay({required this.rect});

  final Rect rect;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _SelectionOverlayPainter(rect: rect)),
    );
  }
}

class _SelectionOverlayPainter extends CustomPainter {
  const _SelectionOverlayPainter({required this.rect});

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.10);
    final borderPaint = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.82)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final normalized = Rect.fromPoints(rect.topLeft, rect.bottomRight);
    canvas
      ..drawRect(normalized, fillPaint)
      ..drawRect(normalized, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SelectionOverlayPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}

class _PositionedGraphNode extends StatelessWidget {
  const _PositionedGraphNode({
    super.key,
    required this.node,
    required this.links,
    required this.viewport,
    required this.selected,
    required this.compatibleTarget,
  });

  final GraphNode node;
  final List<GraphLink> links;
  final GraphViewport viewport;
  final bool selected;
  final bool compatibleTarget;

  @override
  Widget build(BuildContext context) {
    final position = GraphCanvasGeometry.worldToScreen(
      GraphCanvasPoint(node.position.x, node.position.y),
      viewport,
    );
    final effectiveSize = GraphCanvasGeometry.effectiveNodeSize(node);

    return Positioned(
      left: position.x,
      top: position.y,
      child: AnimatedScale(
        scale: selected ? 1.018 : 1,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOutCubic,
        child: Transform.scale(
          alignment: Alignment.topLeft,
          scale: viewport.zoom,
          child: SizedBox(
            width: effectiveSize.width,
            height: effectiveSize.height,
            child: IgnorePointer(
              child: _GraphNodeCard(
                node: node,
                links: links,
                selected: selected,
                compatibleTarget: compatibleTarget,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GraphNodeCard extends StatelessWidget {
  const _GraphNodeCard({
    required this.node,
    required this.links,
    required this.selected,
    required this.compatibleTarget,
  });

  final GraphNode node;
  final List<GraphLink> links;
  final bool selected;
  final bool compatibleTarget;

  @override
  Widget build(BuildContext context) {
    if (node.nodeType == 'Comment') {
      return _CommentFrameCard(node: node, selected: selected);
    }

    final nodeColor = _nodeHeaderColor(node);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: selected || compatibleTarget ? 1 : 0),
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      builder: (context, highlightT, child) {
        final selectedT = selected ? highlightT : 0.0;
        final compatibleT = compatibleTarget ? highlightT : 0.0;
        final radius = BorderRadius.circular(12);
        final borderColor = Color.lerp(
          const Color(0xFFCBD5E1),
          const Color(0xFF2563EB),
          math.max(selectedT, compatibleT * 0.72),
        )!;
        final backgroundColor = Color.lerp(
          const Color(0xF5FFFFFF),
          const Color(0xFFFFFFFF),
          math.max(selectedT, compatibleT),
        )!;
        final headerStart = Color.lerp(nodeColor, Colors.white, 0.10)!;
        final headerEnd = Color.lerp(nodeColor, const Color(0xFF60A5FA), 0.48)!;
        final headerHighlightStart = Color.lerp(nodeColor, Colors.white, 0.24)!;
        final headerHighlightEnd = Color.lerp(
          nodeColor,
          const Color(0xFFBAE6FD),
          0.58,
        )!;
        final headerColor = Color.lerp(headerStart, headerEnd, selectedT)!;
        final headerHighlight = Color.lerp(
          headerHighlightStart,
          headerHighlightEnd,
          selectedT,
        )!;

        return Stack(
          key: compatibleTarget
              ? ValueKey('compatible-target-node-${node.id}')
              : null,
          clipBehavior: Clip.none,
          children: [
            if (compatibleTarget)
              Positioned(
                key: ValueKey('compatible-target-arrow-${node.id}'),
                top: -34 - 5 * compatibleT,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: compatibleT,
                  child: const _CompatibleTargetArrow(),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: radius,
                border: Border.all(color: borderColor, width: 1 + selectedT),
                boxShadow: [
                  if (compatibleT > 0)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.72 * compatibleT),
                      blurRadius: 32 + 18 * compatibleT,
                      spreadRadius: 8 + 8 * compatibleT,
                      offset: Offset.zero,
                    ),
                  if (compatibleT > 0)
                    BoxShadow(
                      color: const Color(
                        0xFFBAE6FD,
                      ).withValues(alpha: 0.42 * compatibleT),
                      blurRadius: 54,
                      spreadRadius: 10 * compatibleT,
                      offset: Offset.zero,
                    ),
                  BoxShadow(
                    color: const Color(
                      0xFF1E3A8A,
                    ).withValues(alpha: 0.12 + 0.16 * selectedT),
                    blurRadius: 18 + 26 * selectedT,
                    spreadRadius: selectedT * 3,
                    offset: Offset(0, 10 + 5 * selectedT),
                  ),
                  BoxShadow(
                    color: const Color(
                      0xFF38BDF8,
                    ).withValues(alpha: 0.04 + 0.30 * selectedT),
                    blurRadius: 46,
                    spreadRadius: 2 + 8 * selectedT,
                    offset: Offset.zero,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: GraphCanvasGeometry.nodeHeaderHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [headerColor, headerHighlight],
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                GraphNodeStyle.icon(node.nodeType),
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  node.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height:
                                      GraphCanvasGeometry.nodeDescriptionHeight,
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      node.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF526276),
                                            height: 1.35,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: _PinRows(node: node, links: links),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _nodeHeaderColor(GraphNode node) {
    if (node.nodeType == 'FunctionCall') {
      final hasExecPin = node.pins.any((pin) => pin.dataType == 'exec');
      return GraphNodeStyle.functionHeaderColor(pure: !hasExecPin);
    }
    if (node.nodeType == 'VariableGet' || node.nodeType == 'VariableSet') {
      for (final pin in node.pins) {
        if (pin.dataType != 'exec') {
          return GraphNodeStyle.variableColor(pin.dataType);
        }
      }
    }
    return GraphNodeStyle.headerColor(node.nodeType);
  }
}

class _CommentFrameCard extends StatelessWidget {
  const _CommentFrameCard({required this.node, required this.selected});

  final GraphNode node;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: selected ? 1 : 0),
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      builder: (context, selectedT, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7C2).withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFFEAB308),
                const Color(0xFF38BDF8),
                selectedT,
              )!,
              width: 1.4 + selectedT,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: const Color(
                    0xFF38BDF8,
                  ).withValues(alpha: 0.28 * selectedT),
                  blurRadius: 34,
                  spreadRadius: 4,
                ),
              BoxShadow(
                color: const Color(0xFF78350F).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE68A).withValues(alpha: 0.82),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    node.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF713F12),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (node.description.isNotEmpty)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 44,
                  child: Text(
                    node.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF854D0E),
                      height: 1.35,
                    ),
                  ),
                ),
              if (selected) ...[
                for (final alignment in const [
                  Alignment.topLeft,
                  Alignment.topCenter,
                  Alignment.topRight,
                  Alignment.centerLeft,
                  Alignment.centerRight,
                  Alignment.bottomLeft,
                  Alignment.bottomCenter,
                  Alignment.bottomRight,
                ])
                  Align(
                    alignment: alignment,
                    child: Transform.translate(
                      offset: Offset(alignment.x * 5, alignment.y * 5),
                      child: const _CommentResizeGrip(),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CommentResizeGrip extends StatelessWidget {
  const _CommentResizeGrip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.46),
            blurRadius: 14,
            spreadRadius: 1.5,
          ),
        ],
      ),
      child: const SizedBox(width: 16, height: 16),
    );
  }
}

class _CompatibleTargetArrow extends StatelessWidget {
  const _CompatibleTargetArrow();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.72),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.80),
              blurRadius: 20,
              spreadRadius: 6,
            ),
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.44),
              blurRadius: 26,
              spreadRadius: 5,
            ),
          ],
        ),
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF0369A1),
            size: 31,
          ),
        ),
      ),
    );
  }
}

class _PinRows extends StatelessWidget {
  const _PinRows({required this.node, required this.links});

  final GraphNode node;
  final List<GraphLink> links;

  @override
  Widget build(BuildContext context) {
    final inputs = node.pins
        .where((pin) => pin.direction == GraphPinDirection.input)
        .toList(growable: false);
    final outputs = node.pins
        .where((pin) => pin.direction == GraphPinDirection.output)
        .toList(growable: false);
    final rowCount = math.max(inputs.length, outputs.length);

    return Column(
      children: [
        for (var index = 0; index < rowCount; index++)
          Padding(
            padding: EdgeInsets.only(bottom: index == rowCount - 1 ? 0 : 5),
            child: SizedBox(
              height: GraphCanvasGeometry.pinGap - 5,
              child: _PinRow(
                nodeId: node.id,
                input: index < inputs.length ? inputs[index] : null,
                output: index < outputs.length ? outputs[index] : null,
                isPinConnected: _isPinConnected,
              ),
            ),
          ),
      ],
    );
  }

  bool _isPinConnected(GraphPin pin) {
    return links.any((link) {
      return switch (pin.direction) {
        GraphPinDirection.input =>
          link.toNodeId == node.id && link.toPinId == pin.id,
        GraphPinDirection.output =>
          link.fromNodeId == node.id && link.fromPinId == pin.id,
      };
    });
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({
    required this.nodeId,
    required this.input,
    required this.output,
    required this.isPinConnected,
  });

  final String nodeId;
  final GraphPin? input;
  final GraphPin? output;
  final bool Function(GraphPin pin) isPinConnected;

  @override
  Widget build(BuildContext context) {
    final inputPin = input;
    final outputPin = output;
    final canUseFullWidth = GraphCanvasGeometry.pinRowCanUseFullWidth(
      input: inputPin,
      output: outputPin,
    );

    if (canUseFullWidth && inputPin != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _PinLabel(
          nodeId: nodeId,
          pin: inputPin,
          connected: isPinConnected(inputPin),
          alignment: TextAlign.left,
        ),
      );
    }

    if (canUseFullWidth && outputPin != null) {
      return Align(
        alignment: Alignment.centerRight,
        child: _PinLabel(
          nodeId: nodeId,
          pin: outputPin,
          connected: isPinConnected(outputPin),
          alignment: TextAlign.right,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: inputPin != null
              ? _PinLabel(
                  nodeId: nodeId,
                  pin: inputPin,
                  connected: isPinConnected(inputPin),
                  alignment: TextAlign.left,
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: outputPin != null
              ? _PinLabel(
                  nodeId: nodeId,
                  pin: outputPin,
                  connected: isPinConnected(outputPin),
                  alignment: TextAlign.right,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _PinLabel extends StatelessWidget {
  const _PinLabel({
    required this.nodeId,
    required this.pin,
    required this.connected,
    required this.alignment,
  });

  final String nodeId;
  final GraphPin pin;
  final bool connected;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    final color = GraphNodeStyle.pinColor(pin.dataType);
    final isInput = alignment == TextAlign.left;
    final boolDefaultValue = _boolDefaultValue(pin);
    final showBoolDefault = isInput && boolDefaultValue != null;

    return Row(
      mainAxisAlignment: isInput
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: [
        if (isInput)
          _PinSocket(
            color: color,
            exec: pin.dataType == 'exec',
            input: true,
            connected: connected,
          ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: isInput
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.end,
              children: [
                if (showBoolDefault)
                  _BoolPinDefaultCheckbox(
                    key: ValueKey('pin-default-bool-$nodeId-${pin.id}'),
                    value: boolDefaultValue,
                  ),
                if (showBoolDefault) const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    pin.title,
                    textAlign: alignment,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isInput)
          _PinSocket(
            color: color,
            exec: pin.dataType == 'exec',
            input: false,
            connected: connected,
          ),
      ],
    );
  }

  bool? _boolDefaultValue(GraphPin pin) {
    if (pin.direction != GraphPinDirection.input ||
        pin.dataType != 'bool' ||
        pin.defaultValue == null) {
      return null;
    }

    return pin.defaultValue!.toLowerCase() == 'true';
  }
}

class _BoolPinDefaultCheckbox extends StatelessWidget {
  const _BoolPinDefaultCheckbox({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: GraphCanvasGeometry.boolDefaultBoxSize,
      height: GraphCanvasGeometry.boolDefaultBoxSize,
      child: Checkbox(
        value: value,
        onChanged: null,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: const BorderSide(color: Color(0xFF991B1B), width: 1.4),
        fillColor: WidgetStateProperty.resolveWith(
          (_) => value ? const Color(0xFFDC2626) : Colors.white,
        ),
        checkColor: Colors.white,
      ),
    );
  }
}

class _PinSocket extends StatelessWidget {
  const _PinSocket({
    required this.color,
    required this.exec,
    required this.input,
    required this.connected,
  });

  final Color color;
  final bool exec;
  final bool input;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: exec ? 14 : 11,
      height: exec ? 14 : 11,
      child: CustomPaint(
        painter: _PinSocketPainter(
          color: color,
          exec: exec,
          input: input,
          connected: connected,
        ),
      ),
    );
  }
}

class _PinSocketPainter extends CustomPainter {
  const _PinSocketPainter({
    required this.color,
    required this.exec,
    required this.input,
    required this.connected,
  });

  final Color color;
  final bool exec;
  final bool input;
  final bool connected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final effectiveFillColor = exec ? Colors.white : color;
    final effectiveBorderColor = exec ? const Color(0xFF1D4ED8) : color;
    final fillPaint = Paint()
      ..color = connected ? effectiveFillColor : Colors.white
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = effectiveBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = connected ? 1.8 : 1.6
      ..strokeJoin = StrokeJoin.round;

    if (connected) {
      canvas.drawCircle(
        center,
        size.shortestSide * 0.56,
        Paint()
          ..color = effectiveBorderColor.withValues(alpha: exec ? 0.28 : 0.24)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    if (exec) {
      final path = Path();
      if (input) {
        path
          ..moveTo(size.width * 0.28, size.height * 0.18)
          ..lineTo(size.width * 0.78, size.height * 0.50)
          ..lineTo(size.width * 0.28, size.height * 0.82)
          ..close();
      } else {
        path
          ..moveTo(size.width * 0.22, size.height * 0.18)
          ..lineTo(size.width * 0.72, size.height * 0.50)
          ..lineTo(size.width * 0.22, size.height * 0.82)
          ..close();
      }
      canvas
        ..drawPath(path, fillPaint)
        ..drawPath(path, borderPaint);
      return;
    }

    canvas
      ..drawCircle(center, size.shortestSide * 0.38, fillPaint)
      ..drawCircle(center, size.shortestSide * 0.38, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PinSocketPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.exec != exec ||
        oldDelegate.input != input ||
        oldDelegate.connected != connected;
  }
}

class _PinWheelOverlay extends StatelessWidget {
  const _PinWheelOverlay({
    required this.node,
    required this.center,
    required this.hoveredPinId,
  });

  final GraphNode node;
  final GraphCanvasPoint center;
  final String? hoveredPinId;

  static const double _extent = 360;
  static const double _radius = _extent / 2;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const ValueKey('pin-wheel'),
      left: center.x - _radius,
      top: center.y - _radius,
      width: _extent,
      height: _extent,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _PinWheelPainter(
            node: node,
            hoveredPinId: hoveredPinId,
            textStyle:
                Theme.of(context).textTheme.labelSmall ??
                const TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }
}

class _PinWheelPainter extends CustomPainter {
  const _PinWheelPainter({
    required this.node,
    required this.hoveredPinId,
    required this.textStyle,
  });

  final GraphNode node;
  final String? hoveredPinId;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final inputs = node.pins
        .where((pin) => pin.direction == GraphPinDirection.input)
        .toList(growable: false);
    final outputs = node.pins
        .where((pin) => pin.direction == GraphPinDirection.output)
        .toList(growable: false);

    _paintOuterGlow(canvas, center);
    _paintHalf(canvas, center, inputs, inputSide: true);
    _paintHalf(canvas, center, outputs, inputSide: false);
    _paintCenter(canvas, center);
    _paintLabels(canvas, center, inputs, inputSide: true);
    _paintLabels(canvas, center, outputs, inputSide: false);
  }

  void _paintOuterGlow(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      GraphCanvasGeometry.pinWheelOuterRadius + 8,
      Paint()
        ..color = const Color(0xFF2563EB).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  void _paintHalf(
    Canvas canvas,
    Offset center,
    List<GraphPin> pins, {
    required bool inputSide,
  }) {
    if (pins.isEmpty) {
      return;
    }

    final startAngle = -math.pi / 2;
    final sweep = (inputSide ? -math.pi : math.pi) / pins.length;
    for (var index = 0; index < pins.length; index++) {
      final pin = pins[index];
      final segmentStart = startAngle + sweep * index;
      final color = GraphNodeStyle.pinColor(pin.dataType);
      final hovered = pin.id == hoveredPinId;
      final path = _ringSegmentPath(center, segmentStart, sweep);
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = hovered
            ? color.withValues(alpha: 0.34)
            : const Color(0xFFFFFFFF).withValues(alpha: 0.78);
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hovered ? 2.2 : 1
        ..color = hovered
            ? color.withValues(alpha: 0.84)
            : const Color(0xFF93C5FD).withValues(alpha: 0.46);

      if (hovered) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12
            ..color = color.withValues(alpha: 0.24)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
      }

      canvas
        ..drawPath(path, fillPaint)
        ..drawPath(path, borderPaint);
    }
  }

  void _paintCenter(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      GraphCanvasGeometry.pinWheelInnerRadius - 4,
      Paint()
        ..shader =
            const RadialGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFEFF6FF)],
            ).createShader(
              Rect.fromCircle(
                center: center,
                radius: GraphCanvasGeometry.pinWheelInnerRadius,
              ),
            ),
    );
    canvas.drawCircle(
      center,
      GraphCanvasGeometry.pinWheelInnerRadius - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = const Color(0xFF2563EB).withValues(alpha: 0.34),
    );

    final iconPainter = TextPainter(
      text: TextSpan(
        text: node.title,
        style: textStyle.copyWith(
          color: const Color(0xFF0F172A),
          fontWeight: FontWeight.w800,
          height: 1.08,
        ),
      ),
      maxLines: 3,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      ellipsis: '...',
    )..layout(maxWidth: GraphCanvasGeometry.pinWheelInnerRadius * 1.45);
    iconPainter.paint(
      canvas,
      center - Offset(iconPainter.width / 2, iconPainter.height / 2),
    );
  }

  void _paintLabels(
    Canvas canvas,
    Offset center,
    List<GraphPin> pins, {
    required bool inputSide,
  }) {
    if (pins.isEmpty) {
      return;
    }

    final startAngle = -math.pi / 2;
    final sweep = (inputSide ? -math.pi : math.pi) / pins.length;
    for (var index = 0; index < pins.length; index++) {
      final pin = pins[index];
      final angle = startAngle + sweep * (index + 0.5);
      final color = GraphNodeStyle.pinColor(pin.dataType);
      final hovered = pin.id == hoveredPinId;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final labelCenter =
          center + direction * (GraphCanvasGeometry.pinWheelOuterRadius + 20);
      final labelWidth = hovered ? 118.0 : 104.0;
      final painter = TextPainter(
        text: TextSpan(
          text: pin.title,
          style: textStyle.copyWith(
            color: hovered ? const Color(0xFF0F172A) : const Color(0xFF334155),
            fontWeight: hovered ? FontWeight.w900 : FontWeight.w800,
            fontSize: hovered ? 12 : 11,
          ),
        ),
        maxLines: 1,
        textAlign: inputSide ? TextAlign.right : TextAlign.left,
        textDirection: TextDirection.ltr,
        ellipsis: '...',
      )..layout(maxWidth: labelWidth);
      final labelOffset = Offset(
        inputSide ? labelCenter.dx - painter.width : labelCenter.dx,
        labelCenter.dy - painter.height / 2,
      );

      canvas.drawCircle(
        center + direction * (GraphCanvasGeometry.pinWheelOuterRadius - 24),
        pin.dataType == 'exec' ? 5.5 : 4.5,
        Paint()..color = color.withValues(alpha: hovered ? 1 : 0.76),
      );
      painter.paint(canvas, labelOffset);
    }
  }

  Path _ringSegmentPath(Offset center, double startAngle, double sweep) {
    const gap = 0.012;
    final sign = sweep.sign;
    final outerRect = Rect.fromCircle(
      center: center,
      radius: GraphCanvasGeometry.pinWheelOuterRadius,
    );
    final innerRect = Rect.fromCircle(
      center: center,
      radius: GraphCanvasGeometry.pinWheelInnerRadius,
    );
    final effectiveStart = startAngle + gap * sign;
    final effectiveSweep = sweep - gap * 2 * sign;
    return Path()
      ..arcTo(outerRect, effectiveStart, effectiveSweep, false)
      ..arcTo(
        innerRect,
        effectiveStart + effectiveSweep,
        -effectiveSweep,
        false,
      )
      ..close();
  }

  @override
  bool shouldRepaint(covariant _PinWheelPainter oldDelegate) {
    return oldDelegate.node != node ||
        oldDelegate.hoveredPinId != hoveredPinId ||
        oldDelegate.textStyle != textStyle;
  }
}

class _GraphCanvasPainter extends CustomPainter {
  const _GraphCanvasPainter({
    required this.colorScheme,
    required this.nodes,
    required this.links,
    required this.viewport,
  });

  final ColorScheme colorScheme;
  final List<GraphNode> nodes;
  final List<GraphLink> links;
  final GraphViewport viewport;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF4F8FD), Color(0xFFE2F0FC), Color(0xFFF1F5FB)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    _paintGrid(canvas, size);
    _paintLinks(canvas);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final smallPaint = Paint()
      ..color = const Color(0xFF93C5FD).withValues(alpha: 0.26)
      ..strokeWidth = 1;
    final largePaint = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.14)
      ..strokeWidth = 1.1;

    const worldStep = 32.0;
    final screenStep = worldStep * viewport.zoom;
    if (screenStep < 8) {
      return;
    }

    final startX = viewport.offsetX % screenStep;
    final startY = viewport.offsetY % screenStep;

    var verticalIndex = 0;
    for (var x = startX; x <= size.width; x += screenStep) {
      final paint = verticalIndex % 4 == 0 ? largePaint : smallPaint;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      verticalIndex++;
    }

    var horizontalIndex = 0;
    for (var y = startY; y <= size.height; y += screenStep) {
      final paint = horizontalIndex % 4 == 0 ? largePaint : smallPaint;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      horizontalIndex++;
    }
  }

  void _paintLinks(Canvas canvas) {
    final nodeById = {for (final node in nodes) node.id: node};

    for (final link in links) {
      final fromNode = nodeById[link.fromNodeId];
      final toNode = nodeById[link.toNodeId];
      if (fromNode == null || toNode == null) {
        continue;
      }

      final from = GraphCanvasGeometry.worldToScreen(
        GraphCanvasGeometry.pinWorldPosition(fromNode, link.fromPinId),
        viewport,
      );
      final to = GraphCanvasGeometry.worldToScreen(
        GraphCanvasGeometry.pinWorldPosition(toNode, link.toPinId),
        viewport,
      );
      final path = _circuitPath(from, to);
      final linkColor = _linkColor(link, fromNode);
      final underGlowPaint = Paint()
        ..color =
            (link.linkType == 'exec' ? const Color(0xFF2563EB) : linkColor)
                .withValues(alpha: link.linkType == 'exec' ? 0.36 : 0.30)
        ..strokeWidth = link.linkType == 'exec' ? 13 : 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      final glowPaint = Paint()
        ..color =
            (link.linkType == 'exec' ? const Color(0xFF60A5FA) : linkColor)
                .withValues(alpha: link.linkType == 'exec' ? 0.34 : 0.24)
        ..strokeWidth = link.linkType == 'exec' ? 8 : 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final paint = Paint()
        ..color = link.linkType == 'exec'
            ? const Color(0xFF111827)
            : linkColor.withValues(alpha: 0.94)
        ..strokeWidth = link.linkType == 'exec' ? 3.3 : 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas
        ..drawPath(path, underGlowPaint)
        ..drawPath(path, glowPaint)
        ..drawPath(path, paint);
    }
  }

  Path _circuitPath(GraphCanvasPoint from, GraphCanvasPoint to) {
    final dx = to.x - from.x;
    final direction = dx >= 0 ? 1.0 : -1.0;
    final lead = math
        .min(dx.abs() * 0.22, 58 * viewport.zoom)
        .clamp(18 * viewport.zoom, 58 * viewport.zoom);
    final fromLeadX = from.x + lead * direction;
    final toLeadX = to.x - lead * direction;
    final remainingDx = toLeadX - fromLeadX;
    final dy = to.y - from.y;
    final diagonal = math.min(
      math.min(remainingDx.abs() / 2, dy.abs() / 2),
      72 * viewport.zoom,
    );
    final diagonalX = diagonal * direction;
    final diagonalY = dy == 0 ? 0.0 : diagonal * dy.sign;

    final path = Path()
      ..moveTo(from.x, from.y)
      ..lineTo(fromLeadX, from.y);

    if (diagonal <= 1) {
      path.lineTo(toLeadX, to.y);
    } else {
      final firstDiagonalEnd = GraphCanvasPoint(
        fromLeadX + diagonalX,
        from.y + diagonalY,
      );
      final secondDiagonalStart = GraphCanvasPoint(
        toLeadX - diagonalX,
        to.y - diagonalY,
      );
      path
        ..lineTo(firstDiagonalEnd.x, firstDiagonalEnd.y)
        ..lineTo(secondDiagonalStart.x, secondDiagonalStart.y)
        ..lineTo(toLeadX, to.y);
    }

    path.lineTo(to.x, to.y);

    return path;
  }

  Color _linkColor(GraphLink link, GraphNode fromNode) {
    if (link.linkType == 'exec') {
      return const Color(0xFF111827);
    }

    final fromPin = fromNode.pins
        .where((pin) => pin.id == link.fromPinId)
        .firstOrNull;

    return GraphNodeStyle.pinColor(fromPin?.dataType ?? 'object');
  }

  @override
  bool shouldRepaint(covariant _GraphCanvasPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme ||
        oldDelegate.nodes != nodes ||
        oldDelegate.links != links ||
        oldDelegate.viewport != viewport;
  }
}

class _GraphCanvasInteractionPainter extends CustomPainter {
  const _GraphCanvasInteractionPainter({
    required this.nodes,
    required this.viewport,
    required this.linkDragStart,
    required this.linkDragHover,
    required this.linkDragCurrentWorld,
    required this.linkDragRejected,
  });

  final List<GraphNode> nodes;
  final GraphViewport viewport;
  final GraphCanvasPinHit? linkDragStart;
  final GraphCanvasPinHit? linkDragHover;
  final GraphCanvasPoint? linkDragCurrentWorld;
  final bool linkDragRejected;

  @override
  void paint(Canvas canvas, Size size) {
    final start = linkDragStart;
    final currentWorld = linkDragCurrentWorld;
    if (start != null && currentWorld != null) {
      _paintDragLink(canvas, start, currentWorld);
    }

    final hover = linkDragHover;
    if (hover != null) {
      _paintPinHalo(
        canvas,
        hover,
        GraphNodeStyle.pinColor(hover.pin.dataType),
        0.34,
      );
    }

    if (linkDragRejected && start != null) {
      _paintPinHalo(canvas, start, const Color(0xFFEF4444), 0.36);
    }
  }

  void _paintDragLink(
    Canvas canvas,
    GraphCanvasPinHit start,
    GraphCanvasPoint currentWorld,
  ) {
    final startWorld = GraphCanvasGeometry.pinWorldPosition(
      start.node,
      start.pin.id,
    );
    final from = GraphCanvasGeometry.worldToScreen(startWorld, viewport);
    final to = linkDragHover == null
        ? GraphCanvasGeometry.worldToScreen(currentWorld, viewport)
        : GraphCanvasGeometry.worldToScreen(
            GraphCanvasGeometry.pinWorldPosition(
              linkDragHover!.node,
              linkDragHover!.pin.id,
            ),
            viewport,
          );
    final color = linkDragRejected
        ? const Color(0xFFEF4444)
        : start.pin.dataType == 'exec'
        ? const Color(0xFF111827)
        : GraphNodeStyle.pinColor(start.pin.dataType);
    final glowColor = start.pin.dataType == 'exec'
        ? const Color(0xFF2563EB)
        : color;
    final path = _circuitPath(from, to);

    canvas
      ..drawPath(
        path,
        Paint()
          ..color = glowColor.withValues(alpha: linkDragRejected ? 0.20 : 0.34)
          ..strokeWidth = start.pin.dataType == 'exec' ? 13 : 9
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      )
      ..drawPath(
        path,
        Paint()
          ..color = glowColor.withValues(alpha: 0.24)
          ..strokeWidth = start.pin.dataType == 'exec' ? 8 : 6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.92)
          ..strokeWidth = start.pin.dataType == 'exec' ? 3.2 : 2.6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(
        Offset(to.x, to.y),
        4.5,
        Paint()..color = color.withValues(alpha: 0.92),
      );

    _paintPinHalo(canvas, start, color, 0.26);
  }

  void _paintPinHalo(
    Canvas canvas,
    GraphCanvasPinHit hit,
    Color color,
    double alpha,
  ) {
    final position = GraphCanvasGeometry.worldToScreen(
      GraphCanvasGeometry.pinWorldPosition(hit.node, hit.pin.id),
      viewport,
    );
    final center = Offset(position.x, position.y);
    canvas
      ..drawCircle(
        center,
        16,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      )
      ..drawCircle(
        center,
        9,
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
  }

  Path _circuitPath(GraphCanvasPoint from, GraphCanvasPoint to) {
    final dx = to.x - from.x;
    final direction = dx >= 0 ? 1.0 : -1.0;
    final lead = math
        .min(dx.abs() * 0.22, 58 * viewport.zoom)
        .clamp(18 * viewport.zoom, 58 * viewport.zoom);
    final fromLeadX = from.x + lead * direction;
    final toLeadX = to.x - lead * direction;
    final remainingDx = toLeadX - fromLeadX;
    final dy = to.y - from.y;
    final diagonal = math.min(
      math.min(remainingDx.abs() / 2, dy.abs() / 2),
      72 * viewport.zoom,
    );
    final diagonalX = diagonal * direction;
    final diagonalY = dy == 0 ? 0.0 : diagonal * dy.sign;
    final path = Path()
      ..moveTo(from.x, from.y)
      ..lineTo(fromLeadX, from.y);

    if (diagonal <= 1) {
      path.lineTo(toLeadX, to.y);
    } else {
      path
        ..lineTo(fromLeadX + diagonalX, from.y + diagonalY)
        ..lineTo(toLeadX - diagonalX, to.y - diagonalY)
        ..lineTo(toLeadX, to.y);
    }

    return path..lineTo(to.x, to.y);
  }

  @override
  bool shouldRepaint(covariant _GraphCanvasInteractionPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.viewport != viewport ||
        oldDelegate.linkDragStart != linkDragStart ||
        oldDelegate.linkDragHover != linkDragHover ||
        oldDelegate.linkDragCurrentWorld != linkDragCurrentWorld ||
        oldDelegate.linkDragRejected != linkDragRejected;
  }
}

class _CanvasHint extends StatelessWidget {
  const _CanvasHint({
    required this.zoom,
    required this.nodeCount,
    required this.linkCount,
  });

  final double zoom;
  final int nodeCount;
  final int linkCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          '节点 $nodeCount · 连线 $linkCount · 缩放 ${(zoom * 100).round()}%',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
