class GraphEvent {
  const GraphEvent({
    required this.id,
    required this.name,
    this.category = '',
    this.description = '',
    this.eventType = 'CustomEvent',
    this.replicates = false,
    this.rpcType = 'None',
    this.reliability = 'Unreliable',
    this.exportSource = '',
    this.exportPath = '',
    this.exportDisplayName = '',
  });

  factory GraphEvent.fromJson(Map<String, Object?> json) {
    return GraphEvent(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      eventType: json['eventType'] as String? ?? 'CustomEvent',
      replicates: json['replicates'] as bool? ?? false,
      rpcType: json['rpcType'] as String? ?? 'None',
      reliability: json['reliability'] as String? ?? 'Unreliable',
      exportSource: json['exportSource'] as String? ?? '',
      exportPath: json['exportPath'] as String? ?? '',
      exportDisplayName: json['exportDisplayName'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String category;
  final String description;
  final String eventType;
  final bool replicates;
  final String rpcType;
  final String reliability;
  final String exportSource;
  final String exportPath;
  final String exportDisplayName;

  GraphEvent copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    String? eventType,
    bool? replicates,
    String? rpcType,
    String? reliability,
    String? exportSource,
    String? exportPath,
    String? exportDisplayName,
  }) {
    return GraphEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      replicates: replicates ?? this.replicates,
      rpcType: rpcType ?? this.rpcType,
      reliability: reliability ?? this.reliability,
      exportSource: exportSource ?? this.exportSource,
      exportPath: exportPath ?? this.exportPath,
      exportDisplayName: exportDisplayName ?? this.exportDisplayName,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'eventType': eventType,
      'replicates': replicates,
      'rpcType': rpcType,
      'reliability': reliability,
      'exportSource': exportSource,
      'exportPath': exportPath,
      'exportDisplayName': exportDisplayName,
    };
  }
}
