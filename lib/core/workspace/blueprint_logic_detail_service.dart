import 'dart:convert';
import 'dart:io';

import 'get_the_meaning_import_service.dart';

class BlueprintLogicDetail {
  const BlueprintLogicDetail({
    required this.available,
    required this.message,
    required this.logicPath,
    required this.entryPoints,
    required this.controlFlows,
    required this.branchRoutes,
    required this.callParameters,
    required this.warnings,
    required this.commentBoxes,
    required this.gameModeDefaults,
    required this.callCount,
  });

  factory BlueprintLogicDetail.missing({
    required String logicPath,
    required String message,
  }) {
    return BlueprintLogicDetail(
      available: false,
      message: message,
      logicPath: logicPath,
      entryPoints: const <BlueprintEntryPoint>[],
      controlFlows: const <BlueprintControlFlow>[],
      branchRoutes: const <BlueprintBranchRoute>[],
      callParameters: const <BlueprintCallParameterTable>[],
      warnings: const <BlueprintLogicWarning>[],
      commentBoxes: const <BlueprintCommentBox>[],
      gameModeDefaults: const <String, String>{},
      callCount: 0,
    );
  }

  final bool available;
  final String message;
  final String logicPath;
  final List<BlueprintEntryPoint> entryPoints;
  final List<BlueprintControlFlow> controlFlows;
  final List<BlueprintBranchRoute> branchRoutes;
  final List<BlueprintCallParameterTable> callParameters;
  final List<BlueprintLogicWarning> warnings;
  final List<BlueprintCommentBox> commentBoxes;
  final Map<String, String> gameModeDefaults;
  final int callCount;

  int get controlFlowCount => controlFlows.length;
}

class BlueprintEntryPoint {
  const BlueprintEntryPoint({
    required this.graphName,
    required this.name,
    required this.type,
    required this.replication,
    required this.reliable,
  });

  factory BlueprintEntryPoint.fromJson(Map<String, Object?> json) {
    return BlueprintEntryPoint(
      graphName: json['graphName'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      replication: json['replication'] as String? ?? '',
      reliable: json['reliable'] as bool? ?? false,
    );
  }

  final String graphName;
  final String name;
  final String type;
  final String replication;
  final bool reliable;
}

class BlueprintControlFlow {
  const BlueprintControlFlow({
    required this.graphName,
    required this.fromNodeTitle,
    required this.toNodeTitle,
    required this.kind,
    required this.depth,
  });

  factory BlueprintControlFlow.fromJson(Map<String, Object?> json) {
    return BlueprintControlFlow(
      graphName: json['graphName'] as String? ?? '',
      fromNodeTitle: json['fromNodeTitle'] as String? ?? '',
      toNodeTitle: json['toNodeTitle'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      depth: _readInt(json['depth']),
    );
  }

  final String graphName;
  final String fromNodeTitle;
  final String toNodeTitle;
  final String kind;
  final int depth;
}

class BlueprintBranchRoute {
  const BlueprintBranchRoute({
    required this.graphName,
    required this.nodeTitle,
    required this.condition,
    required this.trueTarget,
    required this.falseTarget,
  });

  factory BlueprintBranchRoute.fromJson(Map<String, Object?> json) {
    return BlueprintBranchRoute(
      graphName: json['graphName'] as String? ?? '',
      nodeTitle: json['nodeTitle'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      trueTarget: json['trueTarget'] as String? ?? '',
      falseTarget: json['falseTarget'] as String? ?? '',
    );
  }

  final String graphName;
  final String nodeTitle;
  final String condition;
  final String trueTarget;
  final String falseTarget;
}

class BlueprintCallParameterTable {
  const BlueprintCallParameterTable({
    required this.graphName,
    required this.nodeTitle,
    required this.functionName,
    required this.ownerClass,
    required this.replication,
    required this.parameters,
  });

  factory BlueprintCallParameterTable.fromJson(Map<String, Object?> json) {
    return BlueprintCallParameterTable(
      graphName: json['graphName'] as String? ?? '',
      nodeTitle: json['nodeTitle'] as String? ?? '',
      functionName: json['functionName'] as String? ?? '',
      ownerClass: json['ownerClass'] as String? ?? '',
      replication: json['replication'] as String? ?? '',
      parameters: _readObjectList(
        json['parameters'],
      ).map(BlueprintCallParameter.fromJson).toList(growable: false),
    );
  }

  final String graphName;
  final String nodeTitle;
  final String functionName;
  final String ownerClass;
  final String replication;
  final List<BlueprintCallParameter> parameters;
}

class BlueprintCallParameter {
  const BlueprintCallParameter({
    required this.name,
    required this.value,
    required this.defaultValue,
    required this.linked,
  });

  factory BlueprintCallParameter.fromJson(Map<String, Object?> json) {
    return BlueprintCallParameter(
      name: json['name'] as String? ?? '',
      value: json['value'] as String? ?? '',
      defaultValue: json['defaultValue'] as String? ?? '',
      linked: json['linked'] as bool? ?? false,
    );
  }

  final String name;
  final String value;
  final String defaultValue;
  final bool linked;
}

class BlueprintLogicWarning {
  const BlueprintLogicWarning({
    required this.severity,
    required this.category,
    required this.graphName,
    required this.nodeTitle,
    required this.message,
    required this.details,
  });

  factory BlueprintLogicWarning.fromJson(Map<String, Object?> json) {
    return BlueprintLogicWarning(
      severity: json['severity'] as String? ?? '',
      category: json['category'] as String? ?? '',
      graphName: json['graphName'] as String? ?? '',
      nodeTitle: json['nodeTitle'] as String? ?? '',
      message: json['message'] as String? ?? '',
      details: json['details'] as String? ?? '',
    );
  }

  final String severity;
  final String category;
  final String graphName;
  final String nodeTitle;
  final String message;
  final String details;
}

class BlueprintCommentBox {
  const BlueprintCommentBox({required this.graphName, required this.text});

  factory BlueprintCommentBox.fromJson(Map<String, Object?> json) {
    return BlueprintCommentBox(
      graphName: json['graphName'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }

  final String graphName;
  final String text;
}

class BlueprintLogicDetailService {
  const BlueprintLogicDetailService();

  Future<BlueprintLogicDetail> load({
    required String exportPath,
    required GetTheMeaningAssetSummary asset,
  }) async {
    final logicPath = _resolveLogicPath(exportPath, asset.logicJsonPath);
    if (logicPath.isEmpty) {
      return BlueprintLogicDetail.missing(
        logicPath: '',
        message: '该资产没有 Logic JSON 路径',
      );
    }

    final logicFile = File(logicPath);
    if (!await logicFile.exists()) {
      return BlueprintLogicDetail.missing(
        logicPath: logicPath,
        message: '没有找到 Logic JSON',
      );
    }

    final json =
        jsonDecode(await logicFile.readAsString()) as Map<String, Object?>;
    final logicSummary = _readObject(json['logicSummary']);
    final riskSummary = _readObject(json['riskSummary']);

    return BlueprintLogicDetail(
      available: true,
      message: '已读取 Logic JSON',
      logicPath: logicPath,
      entryPoints: _readObjectList(
        logicSummary['entryPoints'],
      ).map(BlueprintEntryPoint.fromJson).toList(growable: false),
      controlFlows: _readObjectList(
        logicSummary['controlFlows'],
      ).map(BlueprintControlFlow.fromJson).toList(growable: false),
      branchRoutes: _readObjectList(
        riskSummary['branchRoutes'],
      ).map(BlueprintBranchRoute.fromJson).toList(growable: false),
      callParameters: _readObjectList(
        riskSummary['callParameterTable'],
      ).map(BlueprintCallParameterTable.fromJson).toList(growable: false),
      warnings: _readObjectList(
        riskSummary['warnings'],
      ).map(BlueprintLogicWarning.fromJson).toList(growable: false),
      commentBoxes: _readObjectList(
        json['commentBoxes'],
      ).map(BlueprintCommentBox.fromJson).toList(growable: false),
      gameModeDefaults: _readGameModeDefaults(
        _readObject(json['gameModeClassDefaults']),
      ),
      callCount: _readList(logicSummary['callGraph']).length,
    );
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

    return _join(exportPath, relativePath);
  }

  String _join(String folder, String relativePath) {
    final separator = Platform.pathSeparator;
    final parts = relativePath
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return <String>[folder, ...parts].join(separator);
  }
}

Map<String, String> _readGameModeDefaults(Map<String, Object?> json) {
  if (json['isGameMode'] != true) {
    return const <String, String>{};
  }

  final defaults = <String, String>{};
  for (final key in const <String>[
    'GameStateClass',
    'PlayerStateClass',
    'PlayerControllerClass',
    'DefaultPawnClass',
    'HUDClass',
  ]) {
    final value = _readObject(json[key]);
    final display = value['display'] as String? ?? '';
    if (display.isNotEmpty) {
      defaults[key] = display;
    }
  }

  return defaults;
}

Map<String, Object?> _readObject(Object? value) {
  return value is Map<String, Object?> ? value : const <String, Object?>{};
}

List<Object?> _readList(Object? value) {
  return value is List<Object?> ? value : const <Object?>[];
}

List<Map<String, Object?>> _readObjectList(Object? value) {
  return _readList(
    value,
  ).whereType<Map<String, Object?>>().toList(growable: false);
}

int _readInt(Object? value) {
  return switch (value) {
    final int number => number,
    final num number => number.toInt(),
    _ => 0,
  };
}
