import 'graph_pin.dart';

class GraphNodePosition {
  const GraphNodePosition({required this.x, required this.y});

  factory GraphNodePosition.fromJson(Map<String, Object?> json) {
    return GraphNodePosition(
      x: _readDouble(json['x']),
      y: _readDouble(json['y']),
    );
  }

  final double x;
  final double y;

  Map<String, Object?> toJson() {
    return <String, Object?>{'x': x, 'y': y};
  }

  static double _readDouble(Object? value) {
    return switch (value) {
      final num number => number.toDouble(),
      _ => 0,
    };
  }
}

class GraphNodeSize {
  const GraphNodeSize({required this.width, required this.height});

  factory GraphNodeSize.standard() {
    return const GraphNodeSize(width: 240, height: 140);
  }

  factory GraphNodeSize.fromJson(Map<String, Object?> json) {
    return GraphNodeSize(
      width: _readDouble(json['width'], fallback: 240),
      height: _readDouble(json['height'], fallback: 140),
    );
  }

  final double width;
  final double height;

  Map<String, Object?> toJson() {
    return <String, Object?>{'width': width, 'height': height};
  }

  static double _readDouble(Object? value, {required double fallback}) {
    return switch (value) {
      final num number => number.toDouble(),
      _ => fallback,
    };
  }
}

class GraphNode {
  const GraphNode({
    required this.id,
    required this.nodeType,
    required this.title,
    required this.description,
    required this.position,
    required this.size,
    required this.pins,
  });

  factory GraphNode.fromJson(Map<String, Object?> json) {
    final pinsJson = json['pins'] as List<Object?>? ?? const <Object?>[];

    return GraphNode(
      id: json['id'] as String? ?? '',
      nodeType: json['nodeType'] as String? ?? 'Generic',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      position: GraphNodePosition.fromJson(
        json['position'] as Map<String, Object?>? ?? const <String, Object?>{},
      ),
      size: GraphNodeSize.fromJson(
        json['size'] as Map<String, Object?>? ?? const <String, Object?>{},
      ),
      pins: pinsJson
          .whereType<Map<String, Object?>>()
          .map(GraphPin.fromJson)
          .toList(growable: false),
    );
  }

  final String id;
  final String nodeType;
  final String title;
  final String description;
  final GraphNodePosition position;
  final GraphNodeSize size;
  final List<GraphPin> pins;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'nodeType': nodeType,
      'title': title,
      'description': description,
      'position': position.toJson(),
      'size': size.toJson(),
      'pins': pins.map((pin) => pin.toJson()).toList(growable: false),
    };
  }
}
