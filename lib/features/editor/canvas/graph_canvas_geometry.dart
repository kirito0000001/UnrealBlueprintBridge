import 'dart:math' as math;
import 'dart:ui';

import '../../../core/models/graph_node.dart';
import '../../../core/models/graph_pin.dart';
import '../../../core/models/graph_viewport.dart';

class GraphCanvasPoint {
  const GraphCanvasPoint(this.x, this.y);

  final double x;
  final double y;

  GraphCanvasPoint operator +(GraphCanvasPoint other) {
    return GraphCanvasPoint(x + other.x, y + other.y);
  }

  GraphCanvasPoint operator -(GraphCanvasPoint other) {
    return GraphCanvasPoint(x - other.x, y - other.y);
  }

  @override
  bool operator ==(Object other) {
    return other is GraphCanvasPoint && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() {
    return 'GraphCanvasPoint($x, $y)';
  }
}

class GraphCanvasPinHit {
  const GraphCanvasPinHit({required this.node, required this.pin});

  final GraphNode node;
  final GraphPin pin;
}

class GraphCanvasPinDefaultHit {
  const GraphCanvasPinDefaultHit({required this.node, required this.pin});

  final GraphNode node;
  final GraphPin pin;
}

enum GraphCommentResizeHandle {
  left,
  right,
  top,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class GraphCommentResizeHit {
  const GraphCommentResizeHit({required this.node, required this.handle});

  final GraphNode node;
  final GraphCommentResizeHandle handle;
}

class GraphCanvasGeometry {
  const GraphCanvasGeometry._();

  static const double nodeHeaderHeight = 46;
  static const double nodeContentPaddingX = 14;
  static const double nodeContentPaddingTop = 12;
  static const double nodeDescriptionHeight = 44;
  static const double nodeDescriptionPinGap = 12;
  static const double nodeContentPaddingBottom = 14;
  static const double pinSocketExecSize = 14;
  static const double pinSocketDataSize = 11;
  static const double pinHitRadius = 24;
  static const double boolDefaultBoxSize = 16;
  static const double boolDefaultBoxGap = 7;
  static const double boolDefaultHitPadding = 8;
  static const double pinRowHeight = 25;
  static const double pinStartY =
      nodeHeaderHeight +
      nodeContentPaddingTop +
      nodeDescriptionHeight +
      nodeDescriptionPinGap +
      pinRowHeight / 2;
  static const double pinGap = 30;
  static const double nodeMinReadableWidth = 240;
  static const double nodeMaxAutoWidth = 430;
  static const double pinWheelInnerRadius = 54;
  static const double pinWheelOuterRadius = 140;
  static const double pinWheelTouchOuterRadius = 164;
  static const double commentFramePadding = 48;
  static const double commentMinWidth = 160;
  static const double commentMinHeight = 100;
  static const double commentResizeHandleSize = 36;
  static const double commentResizeSidePadding = 18;
  static const double commentResizeOuterPadding = 56;

  static GraphNodeSize effectiveNodeSize(GraphNode node) {
    final rowCount = math.max(
      node.pins.where((pin) => pin.direction == GraphPinDirection.input).length,
      node.pins
          .where((pin) => pin.direction == GraphPinDirection.output)
          .length,
    );
    final pinRowsHeight = rowCount == 0
        ? 0.0
        : pinRowHeight + pinGap * (rowCount - 1);
    final requiredHeight =
        pinStartY + pinRowsHeight - pinRowHeight / 2 + nodeContentPaddingBottom;
    final longestInputTitle = _longestPinTitleLength(
      node,
      GraphPinDirection.input,
    );
    final longestOutputTitle = _longestPinTitleLength(
      node,
      GraphPinDirection.output,
    );
    final widestPairedPinRow = _widestPairedPinRow(node);
    final longestHeaderText = math.max(node.title.length, 12);
    final requiredWidth = math.max(
      nodeMinReadableWidth,
      math.max(
        math.max(
          _estimatedSideWidth(longestInputTitle) +
              _estimatedSideWidth(longestOutputTitle) +
              nodeContentPaddingX * 2,
          widestPairedPinRow,
        ),
        longestHeaderText * 8.5 + 78,
      ),
    );

    return GraphNodeSize(
      width: math.max(
        node.size.width,
        math.min(requiredWidth, nodeMaxAutoWidth),
      ),
      height: math.max(node.size.height, requiredHeight),
    );
  }

  static Rect commentFrameForNodes(List<GraphNode> nodes) {
    if (nodes.isEmpty) {
      return Rect.zero;
    }

    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;

    for (final node in nodes) {
      final size = effectiveNodeSize(node);
      left = math.min(left, node.position.x);
      top = math.min(top, node.position.y);
      right = math.max(right, node.position.x + size.width);
      bottom = math.max(bottom, node.position.y + size.height);
    }

    return Rect.fromLTRB(
      left - commentFramePadding,
      top - commentFramePadding,
      right + commentFramePadding,
      bottom + commentFramePadding,
    );
  }

  static Set<String> nodeIdsInsideComment({
    required GraphNode comment,
    required List<GraphNode> nodes,
  }) {
    if (comment.nodeType != 'Comment') {
      return const <String>{};
    }

    final commentSize = effectiveNodeSize(comment);
    final commentRect = Rect.fromLTWH(
      comment.position.x,
      comment.position.y,
      commentSize.width,
      commentSize.height,
    );
    final containedIds = <String>{};

    for (final node in nodes) {
      if (node.id == comment.id || node.nodeType == 'Comment') {
        continue;
      }

      final nodeSize = effectiveNodeSize(node);
      final nodeRect = Rect.fromLTWH(
        node.position.x,
        node.position.y,
        nodeSize.width,
        nodeSize.height,
      );
      if (commentRect.contains(nodeRect.topLeft) &&
          commentRect.contains(nodeRect.bottomRight)) {
        containedIds.add(node.id);
      }
    }

    return Set.unmodifiable(containedIds);
  }

  static GraphCommentResizeHit? hitTestCommentResizeHandle({
    required List<GraphNode> nodes,
    required Set<String> selectedNodeIds,
    required GraphCanvasPoint screenPoint,
    required GraphViewport viewport,
  }) {
    if (selectedNodeIds.isEmpty) {
      return null;
    }

    final worldPoint = screenToWorld(screenPoint, viewport);
    final cornerSize = commentResizeHandleSize / viewport.zoom;
    final sidePadding = commentResizeSidePadding / viewport.zoom;
    final outerPadding = commentResizeOuterPadding / viewport.zoom;

    for (final node in nodes.reversed) {
      if (node.nodeType != 'Comment' || !selectedNodeIds.contains(node.id)) {
        continue;
      }

      final size = effectiveNodeSize(node);
      final left = node.position.x;
      final top = node.position.y;
      final right = left + size.width;
      final bottom = top + size.height;
      if (worldPoint.x < left - outerPadding ||
          worldPoint.x > right + outerPadding ||
          worldPoint.y < top - outerPadding ||
          worldPoint.y > bottom + outerPadding) {
        continue;
      }

      final nearLeft =
          worldPoint.x >= left - outerPadding &&
          worldPoint.x <= left + cornerSize;
      final nearRight =
          worldPoint.x >= right - cornerSize &&
          worldPoint.x <= right + outerPadding;
      final nearTop =
          worldPoint.y >= top - outerPadding &&
          worldPoint.y <= top + cornerSize;
      final nearBottom =
          worldPoint.y >= bottom - cornerSize &&
          worldPoint.y <= bottom + outerPadding;

      if (nearLeft && nearTop) {
        return GraphCommentResizeHit(
          node: node,
          handle: GraphCommentResizeHandle.topLeft,
        );
      }
      if (nearRight && nearTop) {
        return GraphCommentResizeHit(
          node: node,
          handle: GraphCommentResizeHandle.topRight,
        );
      }
      if (nearLeft && nearBottom) {
        return GraphCommentResizeHit(
          node: node,
          handle: GraphCommentResizeHandle.bottomLeft,
        );
      }
      if (nearRight && nearBottom) {
        return GraphCommentResizeHit(
          node: node,
          handle: GraphCommentResizeHandle.bottomRight,
        );
      }

      final insideVerticalSideBand =
          worldPoint.y >= top + cornerSize &&
          worldPoint.y <= bottom - cornerSize;
      final insideHorizontalSideBand =
          worldPoint.x >= left + cornerSize &&
          worldPoint.x <= right - cornerSize;
      final nearSideLeft =
          insideVerticalSideBand &&
          worldPoint.x >= left - outerPadding &&
          worldPoint.x <= left + sidePadding;
      final nearSideRight =
          insideVerticalSideBand &&
          worldPoint.x >= right - sidePadding &&
          worldPoint.x <= right + outerPadding;
      final nearSideTop =
          insideHorizontalSideBand &&
          worldPoint.y >= top - outerPadding &&
          worldPoint.y <= top + sidePadding;
      final nearSideBottom =
          insideHorizontalSideBand &&
          worldPoint.y >= bottom - sidePadding &&
          worldPoint.y <= bottom + outerPadding;
      if (nearSideLeft) {
        return GraphCommentResizeHit(
          node: node,
          handle: GraphCommentResizeHandle.left,
        );
      }
      if (nearSideRight) {
        return GraphCommentResizeHit(
          node: node,
          handle: GraphCommentResizeHandle.right,
        );
      }
      if (nearSideTop) {
        return GraphCommentResizeHit(
          node: node,
          handle: GraphCommentResizeHandle.top,
        );
      }
      if (nearSideBottom) {
        return GraphCommentResizeHit(
          node: node,
          handle: GraphCommentResizeHandle.bottom,
        );
      }
    }

    return null;
  }

  static GraphNode resizeCommentFromDrag({
    required GraphNode comment,
    required GraphCommentResizeHandle handle,
    required GraphCanvasPoint startWorldPoint,
    required GraphCanvasPoint currentWorldPoint,
  }) {
    final dx = currentWorldPoint.x - startWorldPoint.x;
    final dy = currentWorldPoint.y - startWorldPoint.y;
    var left = comment.position.x;
    var top = comment.position.y;
    var right = comment.position.x + comment.size.width;
    var bottom = comment.position.y + comment.size.height;

    switch (handle) {
      case GraphCommentResizeHandle.left:
        left += dx;
      case GraphCommentResizeHandle.right:
        right += dx;
      case GraphCommentResizeHandle.top:
        top += dy;
      case GraphCommentResizeHandle.bottom:
        bottom += dy;
      case GraphCommentResizeHandle.topLeft:
        left += dx;
        top += dy;
      case GraphCommentResizeHandle.topRight:
        right += dx;
        top += dy;
      case GraphCommentResizeHandle.bottomLeft:
        left += dx;
        bottom += dy;
      case GraphCommentResizeHandle.bottomRight:
        right += dx;
        bottom += dy;
    }

    if (right - left < commentMinWidth) {
      switch (handle) {
        case GraphCommentResizeHandle.left ||
            GraphCommentResizeHandle.topLeft ||
            GraphCommentResizeHandle.bottomLeft:
          left = right - commentMinWidth;
        case GraphCommentResizeHandle.right ||
            GraphCommentResizeHandle.topRight ||
            GraphCommentResizeHandle.bottomRight:
          right = left + commentMinWidth;
        case GraphCommentResizeHandle.top || GraphCommentResizeHandle.bottom:
          right = left + commentMinWidth;
      }
    }
    if (bottom - top < commentMinHeight) {
      switch (handle) {
        case GraphCommentResizeHandle.top ||
            GraphCommentResizeHandle.topLeft ||
            GraphCommentResizeHandle.topRight:
          top = bottom - commentMinHeight;
        case GraphCommentResizeHandle.bottom ||
            GraphCommentResizeHandle.bottomLeft ||
            GraphCommentResizeHandle.bottomRight:
          bottom = top + commentMinHeight;
        case GraphCommentResizeHandle.left || GraphCommentResizeHandle.right:
          bottom = top + commentMinHeight;
      }
    }

    return comment.copyWith(
      position: GraphNodePosition(x: left, y: top),
      size: GraphNodeSize(width: right - left, height: bottom - top),
    );
  }

  static int _longestPinTitleLength(
    GraphNode node,
    GraphPinDirection direction,
  ) {
    return node.pins
        .where((pin) => pin.direction == direction)
        .fold(0, (longest, pin) => math.max(longest, pin.title.length));
  }

  static double _estimatedSideWidth(int titleLength) {
    const socketAndGap = 27.0;
    const minimumSide = 104.0;
    return math.max(minimumSide, socketAndGap + titleLength * 7.8);
  }

  static double _widestPairedPinRow(GraphNode node) {
    final inputs = node.pins
        .where((pin) => pin.direction == GraphPinDirection.input)
        .toList(growable: false);
    final outputs = node.pins
        .where((pin) => pin.direction == GraphPinDirection.output)
        .toList(growable: false);
    final rowCount = math.min(inputs.length, outputs.length);
    var widest = 0.0;

    for (var index = 0; index < rowCount; index++) {
      widest = math.max(
        widest,
        _estimatedPairedSideWidth(inputs[index].title.length) +
            _estimatedPairedSideWidth(outputs[index].title.length) +
            nodeContentPaddingX * 2,
      );
    }

    return widest;
  }

  static double _estimatedPairedSideWidth(int titleLength) {
    const socketAndGap = 31.0;
    const minimumSide = 104.0;
    return math.max(minimumSide, socketAndGap + titleLength * 11.5);
  }

  static bool pinRowCanUseFullWidth({
    required GraphPin? input,
    required GraphPin? output,
  }) {
    return input == null || output == null;
  }

  static GraphPin? pinWheelPinAt({
    required GraphNode node,
    required GraphCanvasPoint center,
    required GraphCanvasPoint screenPoint,
  }) {
    final dx = screenPoint.x - center.x;
    final dy = screenPoint.y - center.y;
    final radius = math.sqrt(dx * dx + dy * dy);
    if (radius < pinWheelInnerRadius || radius > pinWheelTouchOuterRadius) {
      return null;
    }

    final pins = node.pins
        .where(
          (pin) => dx < 0
              ? pin.direction == GraphPinDirection.input
              : pin.direction == GraphPinDirection.output,
        )
        .toList(growable: false);
    if (pins.isEmpty) {
      return null;
    }

    final outwardX = dx < 0 ? -dx : dx;
    final angleFromSideCenter = math.atan2(dy, outwardX);
    final verticalFraction = ((angleFromSideCenter + math.pi / 2) / math.pi)
        .clamp(0.0, 0.999999);
    final index = (verticalFraction * pins.length).floor().clamp(
      0,
      pins.length - 1,
    );

    return pins[index];
  }

  static GraphCanvasPoint worldToScreen(
    GraphCanvasPoint point,
    GraphViewport viewport,
  ) {
    return GraphCanvasPoint(
      point.x * viewport.zoom + viewport.offsetX,
      point.y * viewport.zoom + viewport.offsetY,
    );
  }

  static GraphCanvasPoint screenToWorld(
    GraphCanvasPoint point,
    GraphViewport viewport,
  ) {
    return GraphCanvasPoint(
      (point.x - viewport.offsetX) / viewport.zoom,
      (point.y - viewport.offsetY) / viewport.zoom,
    );
  }

  static GraphNodePosition nodePositionFromDrag({
    required GraphCanvasPoint pointerScreenPoint,
    required GraphViewport viewport,
    required GraphCanvasPoint grabOffsetWorld,
  }) {
    final pointerWorld = screenToWorld(pointerScreenPoint, viewport);

    return GraphNodePosition(
      x: pointerWorld.x - grabOffsetWorld.x,
      y: pointerWorld.y - grabOffsetWorld.y,
    );
  }

  static GraphViewport viewportFromPan({
    required GraphViewport startViewport,
    required GraphCanvasPoint startScreenPoint,
    required GraphCanvasPoint currentScreenPoint,
  }) {
    final delta = currentScreenPoint - startScreenPoint;

    return startViewport.copyWith(
      offsetX: startViewport.offsetX + delta.x,
      offsetY: startViewport.offsetY + delta.y,
    );
  }

  static GraphCanvasPoint pinWorldPosition(GraphNode node, String pinId) {
    final effectiveSize = effectiveNodeSize(node);
    final pin = node.pins
        .where((candidate) => candidate.id == pinId)
        .firstOrNull;
    if (pin == null) {
      return GraphCanvasPoint(
        node.position.x + effectiveSize.width / 2,
        node.position.y + nodeHeaderHeight,
      );
    }

    final pinsInDirection = node.pins
        .where((candidate) => candidate.direction == pin.direction)
        .toList(growable: false);
    final index = pinsInDirection.indexWhere(
      (candidate) => candidate.id == pinId,
    );
    final socketSize = pin.dataType == 'exec'
        ? pinSocketExecSize
        : pinSocketDataSize;
    final socketRadius = socketSize / 2;
    final y = node.position.y + pinStartY + pinGap * index.clamp(0, 99);
    final x = pin.direction == GraphPinDirection.input
        ? node.position.x + nodeContentPaddingX + socketRadius
        : node.position.x +
              effectiveSize.width -
              nodeContentPaddingX -
              socketRadius;

    return GraphCanvasPoint(x, y);
  }

  static Rect? pinDefaultWorldRect(GraphNode node, String pinId) {
    final pin = node.pins
        .where((candidate) => candidate.id == pinId)
        .firstOrNull;
    if (pin == null ||
        pin.direction != GraphPinDirection.input ||
        pin.dataType != 'bool' ||
        pin.defaultValue == null) {
      return null;
    }

    final pinPosition = pinWorldPosition(node, pin.id);
    final left = pinPosition.x + pinSocketDataSize / 2 + boolDefaultBoxGap;
    final top = pinPosition.y - boolDefaultBoxSize / 2;

    return Rect.fromLTWH(left, top, boolDefaultBoxSize, boolDefaultBoxSize);
  }

  static GraphCanvasPinDefaultHit? hitTestPinDefault({
    required List<GraphNode> nodes,
    required GraphCanvasPoint screenPoint,
    required GraphViewport viewport,
  }) {
    final worldPoint = screenToWorld(screenPoint, viewport);

    for (final node in nodes.reversed) {
      for (final pin in node.pins) {
        final rect = pinDefaultWorldRect(node, pin.id);
        if (rect == null) {
          continue;
        }
        final hitRect = rect.inflate(boolDefaultHitPadding);
        if (hitRect.contains(Offset(worldPoint.x, worldPoint.y))) {
          return GraphCanvasPinDefaultHit(node: node, pin: pin);
        }
      }
    }

    return null;
  }

  static GraphCanvasPinHit? hitTestPin({
    required List<GraphNode> nodes,
    required GraphCanvasPoint screenPoint,
    required GraphViewport viewport,
  }) {
    final worldPoint = screenToWorld(screenPoint, viewport);
    GraphCanvasPinHit? bestHit;
    var bestDistance = double.infinity;

    for (final node in nodes.reversed) {
      for (final pin in node.pins) {
        final pinPosition = pinWorldPosition(node, pin.id);
        final distance = _distance(worldPoint, pinPosition);
        if (distance <= pinHitRadius && distance < bestDistance) {
          bestHit = GraphCanvasPinHit(node: node, pin: pin);
          bestDistance = distance;
        }
      }
    }

    return bestHit;
  }

  static GraphCanvasPinHit? compatiblePinOnNode({
    required GraphCanvasPinHit source,
    required GraphNode targetNode,
  }) {
    GraphCanvasPinHit? bestHit;
    var bestScore = 999999;

    for (final pin in targetNode.pins) {
      final candidate = GraphCanvasPinHit(node: targetNode, pin: pin);
      if (!canConnectPins(source, candidate)) {
        continue;
      }
      final score = _pinCompatibilityScore(source.pin, pin);
      if (score < bestScore) {
        bestHit = candidate;
        bestScore = score;
      }
    }

    return bestHit;
  }

  static bool canConnectPins(GraphCanvasPinHit a, GraphCanvasPinHit b) {
    if (a.node.id == b.node.id) {
      return false;
    }
    if (a.pin.direction == b.pin.direction) {
      return false;
    }

    return _pinTypesCompatible(a.pin, b.pin);
  }

  static ({GraphCanvasPinHit from, GraphCanvasPinHit to})? normalizeConnection(
    GraphCanvasPinHit a,
    GraphCanvasPinHit b,
  ) {
    if (!canConnectPins(a, b)) {
      return null;
    }

    return a.pin.direction == GraphPinDirection.output
        ? (from: a, to: b)
        : (from: b, to: a);
  }

  static GraphNode? hitTestNode({
    required List<GraphNode> nodes,
    required GraphCanvasPoint screenPoint,
    required GraphViewport viewport,
  }) {
    final worldPoint = screenToWorld(screenPoint, viewport);
    final commentHits = <GraphNode>[];

    for (final node in nodes.reversed) {
      final effectiveSize = effectiveNodeSize(node);
      final withinX =
          worldPoint.x >= node.position.x &&
          worldPoint.x <= node.position.x + effectiveSize.width;
      final withinY =
          worldPoint.y >= node.position.y &&
          worldPoint.y <= node.position.y + effectiveSize.height;
      if (withinX && withinY) {
        if (node.nodeType == 'Comment') {
          commentHits.add(node);
        } else {
          return node;
        }
      }
    }

    return commentHits.firstOrNull;
  }

  static double _distance(GraphCanvasPoint a, GraphCanvasPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  static bool _pinTypesCompatible(GraphPin a, GraphPin b) {
    if (a.dataType == b.dataType) {
      return true;
    }
    if (a.dataType == 'Actor' && b.dataType == 'object') {
      return true;
    }
    if (a.dataType == 'object' && b.dataType == 'Actor') {
      return true;
    }
    return false;
  }

  static int _pinCompatibilityScore(GraphPin source, GraphPin candidate) {
    if (source.dataType == candidate.dataType) {
      return 0;
    }
    return 10;
  }
}
