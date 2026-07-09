class GraphLink {
  const GraphLink({
    required this.id,
    required this.fromNodeId,
    required this.fromPinId,
    required this.toNodeId,
    required this.toPinId,
    required this.title,
    required this.description,
    required this.linkType,
  });

  factory GraphLink.fromJson(Map<String, Object?> json) {
    return GraphLink(
      id: json['id'] as String? ?? '',
      fromNodeId: json['fromNodeId'] as String? ?? '',
      fromPinId: json['fromPinId'] as String? ?? '',
      toNodeId: json['toNodeId'] as String? ?? '',
      toPinId: json['toPinId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      linkType: json['linkType'] as String? ?? 'data',
    );
  }

  final String id;
  final String fromNodeId;
  final String fromPinId;
  final String toNodeId;
  final String toPinId;
  final String title;
  final String description;
  final String linkType;

  GraphLink copyWith({
    String? id,
    String? fromNodeId,
    String? fromPinId,
    String? toNodeId,
    String? toPinId,
    String? title,
    String? description,
    String? linkType,
  }) {
    return GraphLink(
      id: id ?? this.id,
      fromNodeId: fromNodeId ?? this.fromNodeId,
      fromPinId: fromPinId ?? this.fromPinId,
      toNodeId: toNodeId ?? this.toNodeId,
      toPinId: toPinId ?? this.toPinId,
      title: title ?? this.title,
      description: description ?? this.description,
      linkType: linkType ?? this.linkType,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'fromNodeId': fromNodeId,
      'fromPinId': fromPinId,
      'toNodeId': toNodeId,
      'toPinId': toPinId,
      'title': title,
      'description': description,
      'linkType': linkType,
    };
  }
}
