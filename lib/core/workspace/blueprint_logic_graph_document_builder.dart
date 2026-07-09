import 'dart:convert';
import 'dart:io';

import '../models/graph_document.dart';
import '../models/graph_event.dart';
import '../models/graph_function.dart';
import '../models/graph_link.dart';
import '../models/graph_node.dart';
import '../models/graph_pin.dart';
import '../models/graph_variable.dart';
import '../models/graph_viewport.dart';
import 'get_the_meaning_import_service.dart';

class BlueprintLogicGraphDocumentBuilder {
  const BlueprintLogicGraphDocumentBuilder();

  Future<GraphDocument?> buildFromAsset({
    required String exportPath,
    required GetTheMeaningAssetSummary asset,
    required String graphName,
  }) async {
    final logicPath = _resolveLogicPath(exportPath, asset.logicJsonPath);
    if (logicPath.isEmpty) {
      return null;
    }

    final file = File(logicPath);
    if (!await file.exists()) {
      return null;
    }

    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return build(
      logicJson: json,
      asset: asset,
      graphName: graphName,
      logicPath: logicPath,
    );
  }

  GraphDocument? build({
    required Map<String, Object?> logicJson,
    required GetTheMeaningAssetSummary asset,
    required String graphName,
    String logicPath = '',
  }) {
    final graphs = _readObjectList(logicJson['graphs']);
    final graph = graphs
        .where((graph) => (graph['name'] as String? ?? '') == graphName)
        .firstOrNull;
    if (graph == null) {
      return null;
    }

    final rawNodes = _readObjectList(graph['nodes']);
    if (rawNodes.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    final assetInfo = _readObject(logicJson['asset']);
    final parentClass = asset.parentClass.ifEmpty(
      assetInfo['parentClass'] as String? ?? '',
    );
    final graphKind = graph['kind'] as String? ?? '';
    final nodes = rawNodes.map(_nodeFromJson).toList(growable: false);

    return GraphDocument(
      schemaVersion: GraphDocument.currentSchemaVersion,
      graph: GraphMetadata(
        id: _safeId('logic_${asset.name}_$graphName'),
        title: '${asset.name} / $graphName',
        description: [
          '由 GetTheMeaning 节点级 Logic JSON 复原。',
          if (graphKind.isNotEmpty) 'GraphKind: $graphKind',
          if (logicPath.isNotEmpty) 'Source: $logicPath',
        ].join('\n'),
        createdAt: now,
        updatedAt: now,
        viewport: _viewportFor(nodes),
        blueprintType: _normalizedBlueprintType(asset.type),
        parentClass: parentClass,
      ),
      nodes: nodes,
      links: _linksFromGraph(graph),
      variables: _variablesFromJson(logicJson),
      events: _eventsFromJson(logicJson),
      functions: _functionsFromJson(logicJson),
    );
  }

  GraphNode _nodeFromJson(Map<String, Object?> json) {
    final nodeClass = json['class'] as String? ?? 'K2Node';
    final title = _cleanTitle(
      json['title'] as String? ?? json['name'] as String? ?? '',
    );
    final summary = json['summary'] as String? ?? '';
    final position = _readObject(json['position']);
    final pins = _readObjectList(
      json['pins'],
    ).map(_pinFromJson).toList(growable: false);

    return GraphNode(
      id: json['id'] as String? ?? _safeId(title),
      nodeType: _nodeTypeFromClass(nodeClass, title),
      title: title.ifEmpty(nodeClass),
      description: [
        if (summary.isNotEmpty) summary,
        'UE Class: $nodeClass',
      ].join('\n'),
      position: GraphNodePosition(
        x: _readDouble(position['x']),
        y: _readDouble(position['y']),
      ),
      size: _sizeForPins(pins),
      pins: pins,
    );
  }

  GraphPin _pinFromJson(Map<String, Object?> json) {
    final type = _readObject(json['type']);
    final isExec = json['isExec'] as bool? ?? false;
    final direction = (json['direction'] as String? ?? '').toLowerCase();

    return GraphPin(
      id: json['id'] as String? ?? _safeId(json['name'] as String? ?? 'pin'),
      direction: direction == 'output'
          ? GraphPinDirection.output
          : GraphPinDirection.input,
      title: json['name'] as String? ?? '',
      dataType: isExec ? 'exec' : _pinDataType(type),
      allowMultipleLinks: direction == 'output',
      defaultValue: _optionalString(json['defaultValue']),
    );
  }

  List<GraphLink> _linksFromGraph(Map<String, Object?> graph) {
    final links = <GraphLink>[];
    for (final rawLink in _readObjectList(graph['links'])) {
      final fromNodeId = rawLink['fromNodeId'] as String? ?? '';
      final fromPinId = rawLink['fromPinId'] as String? ?? '';
      final toNodeId = rawLink['toNodeId'] as String? ?? '';
      final toPinId = rawLink['toPinId'] as String? ?? '';
      if ([
        fromNodeId,
        fromPinId,
        toNodeId,
        toPinId,
      ].any((value) => value.isEmpty)) {
        continue;
      }

      final isExec = rawLink['isExec'] as bool? ?? false;
      final fromPinName = rawLink['fromPinName'] as String? ?? '';
      final toPinName = rawLink['toPinName'] as String? ?? '';
      links.add(
        GraphLink(
          id: _safeId(
            'link_${links.length}_${fromNodeId}_${fromPinId}_${toNodeId}_$toPinId',
          ),
          fromNodeId: fromNodeId,
          fromPinId: fromPinId,
          toNodeId: toNodeId,
          toPinId: toPinId,
          title: isExec ? '' : '$fromPinName -> $toPinName',
          description: '$fromPinName -> $toPinName',
          linkType: isExec ? 'exec' : 'data',
        ),
      );
    }

    return links;
  }

  List<GraphVariable> _variablesFromJson(Map<String, Object?> json) {
    return _readObjectList(json['variables'])
        .map(
          (variable) => GraphVariable(
            id:
                variable['guid'] as String? ??
                _safeId(variable['name'] as String? ?? 'variable'),
            name: variable['name'] as String? ?? '',
            dataType: _pinDataType(_readObject(variable['type'])),
            defaultValue: variable['defaultValue'] as String? ?? '',
            category: variable['category'] as String? ?? '',
            description: _variableDescription(variable),
            replication: _replicationFromNetwork(
              _readObject(variable['network']),
            ),
            exportSource: 'GetTheMeaning',
            exportPath: json['asset'] is Map<String, Object?>
                ? ((_readObject(json['asset'])['path'] as String?) ?? '')
                : '',
            exportDisplayName: variable['friendlyName'] as String? ?? '',
          ),
        )
        .where((variable) => variable.name.isNotEmpty)
        .toList(growable: false);
  }

  List<GraphEvent> _eventsFromJson(Map<String, Object?> json) {
    return _readObjectList(json['events'])
        .map(
          (event) => GraphEvent(
            id:
                event['nodeId'] as String? ??
                _safeId(event['name'] as String? ?? 'event'),
            name: event['name'] as String? ?? '',
            category: event['graph'] as String? ?? '',
            description: 'Graph: ${event['graph'] as String? ?? ''}',
            eventType: _eventType(event['name'] as String? ?? ''),
            replicates: (event['replication'] as String? ?? 'Local') != 'Local',
            rpcType: event['replication'] as String? ?? 'None',
            reliability: event['reliable'] == true ? 'Reliable' : 'Unreliable',
            exportSource: 'GetTheMeaning',
            exportPath: _assetPath(json),
            exportDisplayName: event['name'] as String? ?? '',
          ),
        )
        .where((event) => event.name.isNotEmpty)
        .toList(growable: false);
  }

  List<GraphFunction> _functionsFromJson(Map<String, Object?> json) {
    return _readObjectList(json['functions'])
        .map(
          (function) => GraphFunction(
            id: _safeId(function['name'] as String? ?? 'function'),
            name: function['name'] as String? ?? '',
            description: '由 GetTheMeaning 函数信息复原。',
            inputs: _parametersFromJson(function['inputs']),
            outputs: _parametersFromJson(function['outputs']),
            exportSource: 'GetTheMeaning',
            exportPath: _assetPath(json),
            exportDisplayName: function['name'] as String? ?? '',
          ),
        )
        .where((function) => function.name.isNotEmpty)
        .toList(growable: false);
  }

  List<GraphFunctionParameter> _parametersFromJson(Object? value) {
    return _readObjectList(value)
        .map(
          (parameter) => GraphFunctionParameter(
            id:
                parameter['id'] as String? ??
                _safeId(parameter['name'] as String? ?? 'parameter'),
            name: parameter['name'] as String? ?? '',
            dataType: _pinDataType(_readObject(parameter['type'])),
            defaultValue: parameter['defaultValue'] as String? ?? '',
          ),
        )
        .where((parameter) => parameter.name.isNotEmpty)
        .toList(growable: false);
  }

  GraphViewport _viewportFor(List<GraphNode> nodes) {
    if (nodes.isEmpty) {
      return GraphViewport.initial();
    }

    final minX = nodes
        .map((node) => node.position.x)
        .reduce((a, b) => a < b ? a : b);
    final minY = nodes
        .map((node) => node.position.y)
        .reduce((a, b) => a < b ? a : b);
    return GraphViewport(
      offsetX: 120 - minX * 0.82,
      offsetY: 90 - minY * 0.82,
      zoom: 0.82,
    );
  }

  GraphNodeSize _sizeForPins(List<GraphPin> pins) {
    final rowCount = pins.length < 2 ? 2 : pins.length;
    return GraphNodeSize(width: 300, height: 112 + rowCount * 18);
  }

  String _nodeTypeFromClass(String nodeClass, String title) {
    return switch (nodeClass) {
      'K2Node_CustomEvent' => 'CustomEvent',
      'K2Node_Event' => 'Event',
      'K2Node_CallFunction' => _callFunctionType(title),
      'K2Node_VariableGet' => 'VariableGet',
      'K2Node_VariableSet' => 'VariableSet',
      'K2Node_IfThenElse' => 'Branch',
      'K2Node_DynamicCast' => 'Cast',
      'K2Node_FormatText' => 'Text',
      'K2Node_Select' => 'FlowControl',
      'K2Node_SwitchString' ||
      'K2Node_SwitchEnum' ||
      'K2Node_SwitchInteger' => 'FlowControl',
      'K2Node_GetSubsystem' => 'Object',
      _ => nodeClass.contains('Widget') ? 'Widget' : 'Function',
    };
  }

  String _callFunctionType(String title) {
    if (title.contains('可靠的复制') ||
        title.contains('复制到') ||
        title.startsWith('RPC')) {
      return 'Network';
    }
    return 'FunctionCall';
  }

  String _pinDataType(Map<String, Object?> type) {
    final category = type['category'] as String? ?? '';
    final display = type['display'] as String? ?? '';
    if (category.isNotEmpty) {
      if (category == 'byte' && display.contains('<')) {
        return 'enum';
      }
      return category;
    }
    return display.ifEmpty('custom');
  }

  String _variableDescription(Map<String, Object?> variable) {
    final network = _readObject(variable['network']);
    final flags = _readObject(variable['flags']);
    final lines = <String>[
      if ((variable['friendlyName'] as String? ?? '').isNotEmpty)
        '显示名：${variable['friendlyName']}',
      '复制：${_replicationFromNetwork(network)}',
      if (flags.isNotEmpty)
        'Flags: private=${flags['private']}, editable=${flags['editable']}, exposeOnSpawn=${flags['exposeOnSpawn']}',
    ];
    return lines.join('\n');
  }

  String _replicationFromNetwork(Map<String, Object?> network) {
    final replication = network['replication'] as String? ?? '';
    if (replication.isNotEmpty) {
      return replication;
    }
    if (network['usesRepNotify'] == true) {
      return 'RepNotify';
    }
    if (network['replicated'] == true) {
      return 'Replicated';
    }
    return 'None';
  }

  String _eventType(String name) {
    if (name.startsWith('Receive') || name == 'Construct') {
      return 'Event';
    }
    return 'CustomEvent';
  }

  String _assetPath(Map<String, Object?> json) {
    return _readObject(json['asset'])['path'] as String? ?? '';
  }

  String _cleanTitle(String value) {
    return value.replaceAll('\r\n', '\n').trim();
  }

  String? _optionalString(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return value;
  }

  String _resolveLogicPath(String exportPath, String logicJsonPath) {
    final normalized = logicJsonPath.trim();
    if (normalized.isEmpty) {
      return '';
    }

    final asFile = File(normalized);
    if (asFile.isAbsolute) {
      return asFile.path;
    }

    final exportFolderName = exportPath
        .replaceAll('\\', '/')
        .split('/')
        .where((part) => part.isNotEmpty)
        .lastOrNull;
    var relativePath = normalized.replaceAll('\\', '/');
    if (exportFolderName != null &&
        relativePath.startsWith('$exportFolderName/')) {
      relativePath = relativePath.substring(exportFolderName.length + 1);
    }
    const exportedRootPrefix = 'GetTheMeaningExports/';
    if (relativePath.startsWith(exportedRootPrefix)) {
      relativePath = relativePath.substring(exportedRootPrefix.length);
    }

    return [
      exportPath,
      ...relativePath.split('/').where((part) => part.isNotEmpty),
    ].join(Platform.pathSeparator);
  }

  String _normalizedBlueprintType(String value) {
    return switch (value.trim()) {
      'Blueprint' => 'ActorBlueprint',
      'WidgetBlueprint' => 'WidgetBlueprint',
      final other when other.isNotEmpty => other,
      _ => '',
    };
  }

  String _safeId(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_\u4e00-\u9fa5]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (normalized.isEmpty) {
      return 'item';
    }

    return normalized;
  }
}

Map<String, Object?> _readObject(Object? value) {
  return value is Map<String, Object?> ? value : const <String, Object?>{};
}

List<Map<String, Object?>> _readObjectList(Object? value) {
  return value is List<Object?>
      ? value.whereType<Map<String, Object?>>().toList(growable: false)
      : const <Map<String, Object?>>[];
}

double _readDouble(Object? value) {
  return switch (value) {
    final num number => number.toDouble(),
    _ => 0,
  };
}

extension on String {
  String ifEmpty(String fallback) {
    return isEmpty ? fallback : this;
  }
}
