class GraphVariable {
  const GraphVariable({
    required this.id,
    required this.name,
    required this.dataType,
    this.defaultValue = '',
    this.category = '',
    this.description = '',
    this.replication = 'None',
    this.exportSource = '',
    this.exportPath = '',
    this.exportDisplayName = '',
  });

  factory GraphVariable.fromJson(Map<String, Object?> json) {
    return GraphVariable(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      dataType: json['dataType'] as String? ?? 'bool',
      defaultValue: json['defaultValue'] as String? ?? '',
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      replication: json['replication'] as String? ?? 'None',
      exportSource: json['exportSource'] as String? ?? '',
      exportPath: json['exportPath'] as String? ?? '',
      exportDisplayName: json['exportDisplayName'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String dataType;
  final String defaultValue;
  final String category;
  final String description;
  final String replication;
  final String exportSource;
  final String exportPath;
  final String exportDisplayName;

  GraphVariable copyWith({
    String? id,
    String? name,
    String? dataType,
    String? defaultValue,
    String? category,
    String? description,
    String? replication,
    String? exportSource,
    String? exportPath,
    String? exportDisplayName,
  }) {
    return GraphVariable(
      id: id ?? this.id,
      name: name ?? this.name,
      dataType: dataType ?? this.dataType,
      defaultValue: defaultValue ?? this.defaultValue,
      category: category ?? this.category,
      description: description ?? this.description,
      replication: replication ?? this.replication,
      exportSource: exportSource ?? this.exportSource,
      exportPath: exportPath ?? this.exportPath,
      exportDisplayName: exportDisplayName ?? this.exportDisplayName,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'dataType': dataType,
      'defaultValue': defaultValue,
      'category': category,
      'description': description,
      'replication': replication,
      'exportSource': exportSource,
      'exportPath': exportPath,
      'exportDisplayName': exportDisplayName,
    };
  }
}
