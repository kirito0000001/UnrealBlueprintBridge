class GraphFunctionParameter {
  const GraphFunctionParameter({
    required this.id,
    required this.name,
    required this.dataType,
    this.defaultValue = '',
    this.description = '',
  });

  factory GraphFunctionParameter.fromJson(Map<String, Object?> json) {
    return GraphFunctionParameter(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      dataType: json['dataType'] as String? ?? 'bool',
      defaultValue: json['defaultValue'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String dataType;
  final String defaultValue;
  final String description;

  GraphFunctionParameter copyWith({
    String? id,
    String? name,
    String? dataType,
    String? defaultValue,
    String? description,
  }) {
    return GraphFunctionParameter(
      id: id ?? this.id,
      name: name ?? this.name,
      dataType: dataType ?? this.dataType,
      defaultValue: defaultValue ?? this.defaultValue,
      description: description ?? this.description,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'dataType': dataType,
      'defaultValue': defaultValue,
      'description': description,
    };
  }
}

class GraphFunction {
  const GraphFunction({
    required this.id,
    required this.name,
    this.pure = false,
    this.category = '',
    this.description = '',
    this.inputs = const <GraphFunctionParameter>[],
    this.outputs = const <GraphFunctionParameter>[],
    this.exportSource = '',
    this.exportPath = '',
    this.exportDisplayName = '',
  });

  factory GraphFunction.fromJson(Map<String, Object?> json) {
    final inputsJson = json['inputs'] as List<Object?>? ?? const <Object?>[];
    final outputsJson = json['outputs'] as List<Object?>? ?? const <Object?>[];

    return GraphFunction(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pure: json['pure'] as bool? ?? false,
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      inputs: inputsJson
          .whereType<Map<String, Object?>>()
          .map(GraphFunctionParameter.fromJson)
          .toList(growable: false),
      outputs: outputsJson
          .whereType<Map<String, Object?>>()
          .map(GraphFunctionParameter.fromJson)
          .toList(growable: false),
      exportSource: json['exportSource'] as String? ?? '',
      exportPath: json['exportPath'] as String? ?? '',
      exportDisplayName: json['exportDisplayName'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final bool pure;
  final String category;
  final String description;
  final List<GraphFunctionParameter> inputs;
  final List<GraphFunctionParameter> outputs;
  final String exportSource;
  final String exportPath;
  final String exportDisplayName;

  GraphFunction copyWith({
    String? id,
    String? name,
    bool? pure,
    String? category,
    String? description,
    List<GraphFunctionParameter>? inputs,
    List<GraphFunctionParameter>? outputs,
    String? exportSource,
    String? exportPath,
    String? exportDisplayName,
  }) {
    return GraphFunction(
      id: id ?? this.id,
      name: name ?? this.name,
      pure: pure ?? this.pure,
      category: category ?? this.category,
      description: description ?? this.description,
      inputs: inputs ?? this.inputs,
      outputs: outputs ?? this.outputs,
      exportSource: exportSource ?? this.exportSource,
      exportPath: exportPath ?? this.exportPath,
      exportDisplayName: exportDisplayName ?? this.exportDisplayName,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'pure': pure,
      'category': category,
      'description': description,
      'inputs': inputs.map((input) => input.toJson()).toList(growable: false),
      'outputs': outputs
          .map((output) => output.toJson())
          .toList(growable: false),
      'exportSource': exportSource,
      'exportPath': exportPath,
      'exportDisplayName': exportDisplayName,
    };
  }
}
