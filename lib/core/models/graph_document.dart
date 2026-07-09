import 'graph_link.dart';
import 'graph_node.dart';
import 'graph_event.dart';
import 'graph_function.dart';
import 'graph_variable.dart';
import 'graph_viewport.dart';

class GraphMetadata {
  const GraphMetadata({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.viewport,
    this.blueprintType = '',
    this.parentClass = '',
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
      blueprintType: 'Unknown',
      parentClass: '',
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
      blueprintType: json['blueprintType'] as String? ?? '',
      parentClass: json['parentClass'] as String? ?? '',
    );
  }

  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final GraphViewport viewport;
  final String blueprintType;
  final String parentClass;

  GraphMetadata copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    GraphViewport? viewport,
    String? blueprintType,
    String? parentClass,
  }) {
    return GraphMetadata(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      viewport: viewport ?? this.viewport,
      blueprintType: blueprintType ?? this.blueprintType,
      parentClass: parentClass ?? this.parentClass,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'viewport': viewport.toJson(),
      if (blueprintType.isNotEmpty) 'blueprintType': blueprintType,
      if (parentClass.isNotEmpty) 'parentClass': parentClass,
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
    this.variables = const <GraphVariable>[],
    this.functions = const <GraphFunction>[],
    this.events = const <GraphEvent>[],
  });

  factory GraphDocument.empty() {
    return GraphDocument(
      schemaVersion: currentSchemaVersion,
      graph: GraphMetadata.empty(),
      nodes: const <GraphNode>[],
      links: const <GraphLink>[],
      variables: const <GraphVariable>[],
      functions: const <GraphFunction>[],
      events: const <GraphEvent>[],
    );
  }

  factory GraphDocument.fromJson(Map<String, Object?> json) {
    final nodesJson = json['nodes'] as List<Object?>? ?? const <Object?>[];
    final linksJson = json['links'] as List<Object?>? ?? const <Object?>[];
    final variablesJson =
        json['variables'] as List<Object?>? ?? const <Object?>[];
    final functionsJson =
        json['functions'] as List<Object?>? ?? const <Object?>[];
    final eventsJson = json['events'] as List<Object?>? ?? const <Object?>[];

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
      variables: variablesJson
          .whereType<Map<String, Object?>>()
          .map(GraphVariable.fromJson)
          .toList(growable: false),
      functions: functionsJson
          .whereType<Map<String, Object?>>()
          .map(GraphFunction.fromJson)
          .toList(growable: false),
      events: eventsJson
          .whereType<Map<String, Object?>>()
          .map(GraphEvent.fromJson)
          .toList(growable: false),
    );
  }

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final GraphMetadata graph;
  final List<GraphNode> nodes;
  final List<GraphLink> links;
  final List<GraphVariable> variables;
  final List<GraphFunction> functions;
  final List<GraphEvent> events;

  GraphDocument copyWith({
    int? schemaVersion,
    GraphMetadata? graph,
    List<GraphNode>? nodes,
    List<GraphLink>? links,
    List<GraphVariable>? variables,
    List<GraphFunction>? functions,
    List<GraphEvent>? events,
  }) {
    return GraphDocument(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      graph: graph ?? this.graph,
      nodes: nodes ?? this.nodes,
      links: links ?? this.links,
      variables: variables ?? this.variables,
      functions: functions ?? this.functions,
      events: events ?? this.events,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'graph': graph.toJson(),
      'nodes': nodes.map((node) => node.toJson()).toList(growable: false),
      'links': links.map((link) => link.toJson()).toList(growable: false),
      'variables': variables
          .map((variable) => variable.toJson())
          .toList(growable: false),
      'functions': functions
          .map((function) => function.toJson())
          .toList(growable: false),
      'events': events.map((event) => event.toJson()).toList(growable: false),
    };
  }
}
