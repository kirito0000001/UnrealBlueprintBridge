import 'dart:io';

Directory defaultWorkspaceAppDataDirectory() {
  final appData = Platform.environment['APPDATA'];
  if (appData != null && appData.isNotEmpty) {
    return Directory('$appData\\UnrealBlueprintBridge');
  }

  final home = Platform.environment['HOME'] ?? Directory.current.path;
  return Directory('$home/.unreal_blueprint_bridge');
}
