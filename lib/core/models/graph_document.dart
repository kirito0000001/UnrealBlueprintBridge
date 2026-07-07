import 'graph_link.dart';
import 'graph_node.dart';
import 'graph_viewport.dart';

class GraphMetadata {
  const GraphMetadata({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.viewport,
  });

  factory GraphMetadata.empty() {
    final now = DateTime.now();

    return GraphMetadata(
      id: 'graph_${now.millisecondsSinceEpoch}',
      title: 'Untitled Graph',
      description: '',
      createdAt: now,
      updatedAt: now,
      viewport: GraphViewport.initial(),
    );
  }

  factory GraphMetadata.fromJson(Map<String, Object?> json) {
    return GraphMetadata(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Graph',
      description: json['description'] as String? ?? '',
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
      viewport: GraphViewport.fromJson(
        json['viewport'] as Map<String, Object?>? ?? const <String, Object?>{},
      ),
    );
  }

  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final GraphViewport viewport;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'viewport': viewport.toJson(),
    };
  }

  static DateTime _readDate(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class GraphDocument {
  const GraphDocument({
    required this.schemaVersion,
    required this.graph,
    required this.nodes,
    required this.links,
  });

  factory GraphDocument.empty() {
    return GraphDocument(
      schemaVersion: currentSchemaVersion,
      graph: GraphMetadata.empty(),
      nodes: const <GraphNode>[],
      links: const <GraphLink>[],
    );
  }

  factory GraphDocument.fromJson(Map<String, Object?> json) {
    final nodesJson = json['nodes'] as List<Object?>? ?? const <Object?>[];
    final linksJson = json['links'] as List<Object?>? ?? const <Object?>[];

    return GraphDocument(
      schemaVersion: json['schemaVersion'] as int? ?? currentSchemaVersion,
      graph: GraphMetadata.fromJson(
        json['graph'] as Map<String, Object?>? ?? const <String, Object?>{},
      ),
      nodes: nodesJson
          .whereType<Map<String, Object?>>()
          .map(GraphNode.fromJson)
          .toList(growable: false),
      links: linksJson
          .whereType<Map<String, Object?>>()
          .map(GraphLink.fromJson)
          .toList(growable: false),
    );
  }

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final GraphMetadata graph;
  final List<GraphNode> nodes;
  final List<GraphLink> links;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'graph': graph.toJson(),
      'nodes': nodes.map((node) => node.toJson()).toList(growable: false),
      'links': links.map((link) => link.toJson()).toList(growable: false),
    };
  }
}
