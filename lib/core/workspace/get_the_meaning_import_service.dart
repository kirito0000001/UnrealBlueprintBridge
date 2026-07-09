import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class GetTheMeaningAssetSummary {
  const GetTheMeaningAssetSummary({
    required this.name,
    required this.displayName,
    required this.type,
    required this.assetPath,
    required this.packagePath,
    required this.parentClass,
    required this.readablePath,
    required this.logicJsonPath,
    required this.variables,
    required this.events,
    required this.rpcs,
    required this.functions,
    required this.calls,
  });

  factory GetTheMeaningAssetSummary.fromJson(Map<String, Object?> json) {
    return GetTheMeaningAssetSummary(
      name: json['name'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      type: json['type'] as String? ?? '',
      assetPath: json['assetPath'] as String? ?? '',
      packagePath: json['packagePath'] as String? ?? '',
      parentClass: json['parentClass'] as String? ?? '',
      readablePath: json['readablePath'] as String? ?? '',
      logicJsonPath: json['logicJsonPath'] as String? ?? '',
      variables: _readStringList(json['variables']),
      events: _readStringList(json['events']),
      rpcs: _readStringList(json['rpcs']),
      functions: _readStringList(json['functions']),
      calls: _readStringList(json['calls']),
    );
  }

  final String name;
  final String displayName;
  final String type;
  final String assetPath;
  final String packagePath;
  final String parentClass;
  final String readablePath;
  final String logicJsonPath;
  final List<String> variables;
  final List<String> events;
  final List<String> rpcs;
  final List<String> functions;
  final List<String> calls;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'displayName': displayName,
      'type': type,
      'assetPath': assetPath,
      'packagePath': packagePath,
      'parentClass': parentClass,
      'readablePath': readablePath,
      'logicJsonPath': logicJsonPath,
      'variables': variables,
      'events': events,
      'rpcs': rpcs,
      'functions': functions,
      'calls': calls,
    };
  }

  static List<String> _readStringList(Object? value) {
    final list = value as List<Object?>? ?? const <Object?>[];
    return list.whereType<String>().toList(growable: false);
  }
}

class GetTheMeaningImportSummary {
  const GetTheMeaningImportSummary({
    required this.available,
    required this.message,
    required this.exportPath,
    required this.assetCount,
    required this.blueprintCount,
    required this.widgetBlueprintCount,
    required this.graphNodeCount,
    required this.graphEdgeCount,
    required this.cppClassCount,
    required this.cppStructCount,
    required this.cppEnumCount,
    required this.cppFunctionCount,
    required this.assets,
  });

  factory GetTheMeaningImportSummary.fromJson(Map<String, Object?> json) {
    return GetTheMeaningImportSummary(
      available: json['available'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      exportPath: json['exportPath'] as String? ?? '',
      assetCount: _readParsedInt(json['assetCount']),
      blueprintCount: _readParsedInt(json['blueprintCount']),
      widgetBlueprintCount: _readParsedInt(json['widgetBlueprintCount']),
      graphNodeCount: _readParsedInt(json['graphNodeCount']),
      graphEdgeCount: _readParsedInt(json['graphEdgeCount']),
      cppClassCount: _readParsedInt(json['cppClassCount']),
      cppStructCount: _readParsedInt(json['cppStructCount']),
      cppEnumCount: _readParsedInt(json['cppEnumCount']),
      cppFunctionCount: _readParsedInt(json['cppFunctionCount']),
      assets: (json['assets'] as List<Object?>? ?? const <Object?>[])
          .whereType<Map<String, Object?>>()
          .map(GetTheMeaningAssetSummary.fromJson)
          .toList(growable: false),
    );
  }

  factory GetTheMeaningImportSummary.missing({
    required String exportPath,
    required String message,
  }) {
    return GetTheMeaningImportSummary(
      available: false,
      message: message,
      exportPath: exportPath,
      assetCount: 0,
      blueprintCount: 0,
      widgetBlueprintCount: 0,
      graphNodeCount: 0,
      graphEdgeCount: 0,
      cppClassCount: 0,
      cppStructCount: 0,
      cppEnumCount: 0,
      cppFunctionCount: 0,
      assets: const <GetTheMeaningAssetSummary>[],
    );
  }

  final bool available;
  final String message;
  final String exportPath;
  final int assetCount;
  final int blueprintCount;
  final int widgetBlueprintCount;
  final int graphNodeCount;
  final int graphEdgeCount;
  final int cppClassCount;
  final int cppStructCount;
  final int cppEnumCount;
  final int cppFunctionCount;
  final List<GetTheMeaningAssetSummary> assets;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'available': available,
      'message': message,
      'exportPath': exportPath,
      'assetCount': assetCount,
      'blueprintCount': blueprintCount,
      'widgetBlueprintCount': widgetBlueprintCount,
      'graphNodeCount': graphNodeCount,
      'graphEdgeCount': graphEdgeCount,
      'cppClassCount': cppClassCount,
      'cppStructCount': cppStructCount,
      'cppEnumCount': cppEnumCount,
      'cppFunctionCount': cppFunctionCount,
      'assets': assets.map((asset) => asset.toJson()).toList(growable: false),
    };
  }
}

class GetTheMeaningImportService {
  const GetTheMeaningImportService();

  Future<GetTheMeaningImportSummary> inspectDirectory(String exportPath) async {
    final directory = Directory(exportPath);
    if (!await directory.exists()) {
      return GetTheMeaningImportSummary.missing(
        exportPath: exportPath,
        message: '未找到 GetTheMeaning 导出目录，请使用 GetTheMeaning 插件导出项目数据。',
      );
    }

    final exportIndexFile = File(_join(exportPath, 'ExportIndex.json'));
    if (!await exportIndexFile.exists()) {
      return GetTheMeaningImportSummary.missing(
        exportPath: exportPath,
        message: '没有找到 ExportIndex.json',
      );
    }

    final exportIndex = await _readJson(exportIndexFile);
    final graphIndex = await _readOptionalJsonText(
      _join(exportPath, 'ExportGraph.json'),
    );
    final cppIndex = await _readOptionalJsonText(
      _join(exportPath, 'CppSourceIndex.json'),
    );

    final parsed = await compute(_parseImportSummary, <String, Object?>{
      'exportPath': exportPath,
      'exportIndexText': exportIndex,
      'graphIndexText': graphIndex,
      'cppIndexText': cppIndex,
    });

    return GetTheMeaningImportSummary(
      available: true,
      message: '已识别 GetTheMeaning 导出',
      exportPath: exportPath,
      assetCount: _readInt(parsed['assetCount']),
      blueprintCount: _readInt(parsed['blueprintCount']),
      widgetBlueprintCount: _readInt(parsed['widgetBlueprintCount']),
      graphNodeCount: _readInt(parsed['graphNodeCount']),
      graphEdgeCount: _readInt(parsed['graphEdgeCount']),
      cppClassCount: _readInt(parsed['cppClassCount']),
      cppStructCount: _readInt(parsed['cppStructCount']),
      cppEnumCount: _readInt(parsed['cppEnumCount']),
      cppFunctionCount: _readInt(parsed['cppFunctionCount']),
      assets: (parsed['assets'] as List<Object?>? ?? const <Object?>[])
          .whereType<Map<String, Object?>>()
          .map(GetTheMeaningAssetSummary.fromJson)
          .toList(growable: false),
    );
  }

  Future<String> _readJson(File file) {
    return file.readAsString();
  }

  Future<String?> _readOptionalJsonText(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }

    return _readJson(file);
  }

  int _readInt(Object? value, {int fallback = 0}) {
    return switch (value) {
      final int number => number,
      final num number => number.toInt(),
      _ => fallback,
    };
  }

  String _join(String folder, String fileName) {
    final separator = Platform.pathSeparator;
    if (folder.endsWith(separator)) {
      return '$folder$fileName';
    }

    return '$folder$separator$fileName';
  }
}

Map<String, Object?> _parseImportSummary(Map<String, Object?> message) {
  final exportIndexText = message['exportIndexText'] as String;
  final graphIndexText = message['graphIndexText'] as String?;
  final cppIndexText = message['cppIndexText'] as String?;

  final exportIndex = jsonDecode(exportIndexText) as Map<String, Object?>;
  final graphIndex = graphIndexText == null
      ? const <String, Object?>{}
      : jsonDecode(graphIndexText) as Map<String, Object?>;
  final cppIndex = cppIndexText == null
      ? const <String, Object?>{}
      : jsonDecode(cppIndexText) as Map<String, Object?>;

  final assets = exportIndex['assets'] as List<Object?>? ?? const <Object?>[];
  final assetSummaries = assets
      .whereType<Map<String, Object?>>()
      .map(GetTheMeaningAssetSummary.fromJson)
      .toList(growable: false);
  var blueprintCount = 0;
  var widgetBlueprintCount = 0;
  for (final asset in assetSummaries) {
    final type = asset.type;
    if (type == 'Blueprint') {
      blueprintCount++;
    } else if (type == 'WidgetBlueprint') {
      widgetBlueprintCount++;
    }
  }

  return <String, Object?>{
    'assetCount': _readParsedInt(
      exportIndex['assetCount'],
      fallback: assets.length,
    ),
    'blueprintCount': blueprintCount,
    'widgetBlueprintCount': widgetBlueprintCount,
    'graphNodeCount': _readParsedInt(graphIndex['nodeCount']),
    'graphEdgeCount': _readParsedInt(graphIndex['edgeCount']),
    'cppClassCount': _readParsedInt(cppIndex['classCount']),
    'cppStructCount': _readParsedInt(cppIndex['structCount']),
    'cppEnumCount': _readParsedInt(cppIndex['enumCount']),
    'cppFunctionCount': _readParsedInt(cppIndex['functionCount']),
    'assets': assetSummaries
        .map((asset) => asset.toJson())
        .toList(growable: false),
  };
}

int _readParsedInt(Object? value, {int fallback = 0}) {
  return switch (value) {
    final int number => number,
    final num number => number.toInt(),
    _ => fallback,
  };
}
