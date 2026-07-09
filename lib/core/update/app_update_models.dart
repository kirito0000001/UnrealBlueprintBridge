class AppUpdateManifest {
  const AppUpdateManifest({
    required this.schemaVersion,
    required this.productKey,
    required this.displayName,
    required this.version,
    required this.channel,
    required this.releaseNotes,
    required this.releaseNotesUrl,
    required this.assets,
  });

  factory AppUpdateManifest.fromJson(Map<String, Object?> json) {
    final assetsJson = json['assets'] as List<Object?>? ?? const <Object?>[];
    return AppUpdateManifest(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      productKey: json['productKey'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      version: json['version'] as String? ?? '',
      channel: json['channel'] as String? ?? 'stable',
      releaseNotes: json['releaseNotes'] as String? ?? '',
      releaseNotesUrl: json['releaseNotesUrl'] as String? ?? '',
      assets: assetsJson
          .whereType<Map<String, Object?>>()
          .map(AppUpdateAsset.fromJson)
          .toList(growable: false),
    );
  }

  final int schemaVersion;
  final String productKey;
  final String displayName;
  final String version;
  final String channel;
  final String releaseNotes;
  final String releaseNotesUrl;
  final List<AppUpdateAsset> assets;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'productKey': productKey,
      'displayName': displayName,
      'version': version,
      'channel': channel,
      'releaseNotes': releaseNotes,
      'releaseNotesUrl': releaseNotesUrl,
      'assets': assets.map((asset) => asset.toJson()).toList(growable: false),
    };
  }
}

class AppUpdateAsset {
  const AppUpdateAsset({
    required this.runtime,
    required this.fileName,
    required this.sha256,
    required this.sizeBytes,
    required this.downloadUrl,
  });

  factory AppUpdateAsset.fromJson(Map<String, Object?> json) {
    return AppUpdateAsset(
      runtime: json['runtime'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      sha256: json['sha256'] as String? ?? '',
      sizeBytes: _readInt(json['sizeBytes']),
      downloadUrl: json['downloadUrl'] as String? ?? '',
    );
  }

  final String runtime;
  final String fileName;
  final String sha256;
  final int sizeBytes;
  final String downloadUrl;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'runtime': runtime,
      'fileName': fileName,
      'sha256': sha256,
      'sizeBytes': sizeBytes,
      'downloadUrl': downloadUrl,
    };
  }
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    required this.message,
    this.manifest,
    this.asset,
  });

  final bool hasUpdate;
  final String currentVersion;
  final String message;
  final AppUpdateManifest? manifest;
  final AppUpdateAsset? asset;
}

class AppUpdateDownloadResult {
  const AppUpdateDownloadResult({
    required this.packagePath,
    required this.manifest,
    required this.asset,
  });

  final String packagePath;
  final AppUpdateManifest manifest;
  final AppUpdateAsset asset;
}

int _readInt(Object? value) {
  return switch (value) {
    final int number => number,
    final num number => number.toInt(),
    _ => 0,
  };
}
