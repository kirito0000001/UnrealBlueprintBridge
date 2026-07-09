enum GraphPinDirection {
  input,
  output;

  static GraphPinDirection fromJson(Object? value) {
    return switch (value) {
      'output' => GraphPinDirection.output,
      _ => GraphPinDirection.input,
    };
  }
}

class GraphPin {
  const GraphPin({
    required this.id,
    required this.direction,
    required this.title,
    required this.dataType,
    this.allowMultipleLinks = false,
    this.defaultValue,
  });

  factory GraphPin.fromJson(Map<String, Object?> json) {
    return GraphPin(
      id: json['id'] as String? ?? '',
      direction: GraphPinDirection.fromJson(json['direction']),
      title: json['title'] as String? ?? '',
      dataType: json['dataType'] as String? ?? 'custom',
      allowMultipleLinks: json['allowMultipleLinks'] as bool? ?? false,
      defaultValue: json['defaultValue'] as String?,
    );
  }

  final String id;
  final GraphPinDirection direction;
  final String title;
  final String dataType;
  final bool allowMultipleLinks;
  final String? defaultValue;

  GraphPin copyWith({
    String? id,
    GraphPinDirection? direction,
    String? title,
    String? dataType,
    bool? allowMultipleLinks,
    String? defaultValue,
  }) {
    return GraphPin(
      id: id ?? this.id,
      direction: direction ?? this.direction,
      title: title ?? this.title,
      dataType: dataType ?? this.dataType,
      allowMultipleLinks: allowMultipleLinks ?? this.allowMultipleLinks,
      defaultValue: defaultValue ?? this.defaultValue,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'direction': direction.name,
      'title': title,
      'dataType': dataType,
      'allowMultipleLinks': allowMultipleLinks,
      if (defaultValue != null) 'defaultValue': defaultValue,
    };
  }
}
