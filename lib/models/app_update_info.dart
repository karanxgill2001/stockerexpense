class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    required this.releaseNotes,
    required this.forceUpdate,
    required this.updatedAt,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      version: (json['version'] ?? '').toString().trim(),
      buildNumber: (json['buildNumber'] ?? '').toString().trim(),
      apkUrl: (json['apkUrl'] ?? '').toString().trim(),
      releaseNotes: (json['releaseNotes'] ?? '').toString().trim(),
      forceUpdate: json['forceUpdate'] == true,
      updatedAt: (json['updatedAt'] ?? '').toString().trim(),
    );
  }

  final String version;
  final String buildNumber;
  final String apkUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final String updatedAt;

  bool get isConfigured =>
      version.isNotEmpty || buildNumber.isNotEmpty || apkUrl.isNotEmpty;

  bool get hasDownloadLink => apkUrl.isNotEmpty;

  bool matchesVersion({
    required String currentVersion,
    required String currentBuildNumber,
  }) {
    final versionMatches =
        version.isEmpty || _compareDotSeparated(version, currentVersion) == 0;
    final buildMatches =
        buildNumber.isEmpty ||
        _compareDotSeparated(buildNumber, currentBuildNumber) == 0;
    return versionMatches && buildMatches;
  }

  bool isNewerThan({
    required String currentVersion,
    required String currentBuildNumber,
  }) {
    final versionComparison = _compareDotSeparated(version, currentVersion);
    if (versionComparison != 0) {
      return versionComparison > 0;
    }

    return _compareDotSeparated(buildNumber, currentBuildNumber) > 0;
  }

  String get displayVersion {
    if (version.isEmpty && buildNumber.isEmpty) {
      return 'Not set';
    }
    if (buildNumber.isEmpty) {
      return version;
    }
    if (version.isEmpty) {
      return buildNumber;
    }
    return '$version+$buildNumber';
  }

  int _compareDotSeparated(String left, String right) {
    final leftParts = _splitParts(left);
    final rightParts = _splitParts(right);
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var index = 0; index < length; index += 1) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }

    return 0;
  }

  List<int> _splitParts(String value) {
    return value
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }
}
