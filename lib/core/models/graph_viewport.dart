class GraphViewport {
  const GraphViewport({
    required this.offsetX,
    required this.offsetY,
    required this.zoom,
  });

  factory GraphViewport.initial() {
    return const GraphViewport(offsetX: 0, offsetY: 0, zoom: 1);
  }

  factory GraphViewport.fromJson(Map<String, Object?> json) {
    return GraphViewport(
      offsetX: _readDouble(json['offsetX']),
      offsetY: _readDouble(json['offsetY']),
      zoom: _readDouble(json['zoom'], fallback: 1),
    );
  }

  final double offsetX;
  final double offsetY;
  final double zoom;

  GraphViewport copyWith({double? offsetX, double? offsetY, double? zoom}) {
    return GraphViewport(
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      zoom: zoom ?? this.zoom,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'offsetX': offsetX,
      'offsetY': offsetY,
      'zoom': zoom,
    };
  }

  static double _readDouble(Object? value, {double fallback = 0}) {
    return switch (value) {
      final num number => number.toDouble(),
      _ => fallback,
    };
  }
}
