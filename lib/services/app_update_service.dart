import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:install_plugin/install_plugin.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_update_info.dart';
import 'google_sheet_service.dart';

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const String _handledLinkKey = 'app_update_handled_link';
  static const String _downloadedLinkKey = 'app_update_downloaded_link';
  static const String _downloadedFilePathKey =
      'app_update_downloaded_file_path';
  static const String _seenReleaseNotesVersionKey =
      'app_update_seen_release_notes_version';

  final http.Client _client = http.Client();

  Future<PackageInfo> getPackageInfo() {
    return PackageInfo.fromPlatform();
  }

  Future<StartupReleaseNotes?> getStartupReleaseNotesIfNeeded() async {
    final packageInfo = await getPackageInfo();
    final currentVersionKey = _buildVersionKey(
      packageInfo.version,
      packageInfo.buildNumber,
    );
    final preferences = await SharedPreferences.getInstance();
    final seenVersionKey =
        preferences.getString(_seenReleaseNotesVersionKey)?.trim() ?? '';

    if (seenVersionKey == currentVersionKey) {
      return null;
    }

    final remoteInfo = await GoogleSheetService.instance.fetchAppUpdateInfo();
    if (remoteInfo == null || remoteInfo.releaseNotes.trim().isEmpty) {
      return null;
    }

    if (!remoteInfo.matchesVersion(
      currentVersion: packageInfo.version,
      currentBuildNumber: packageInfo.buildNumber,
    )) {
      return null;
    }

    return StartupReleaseNotes(
      versionLabel: remoteInfo.displayVersion,
      versionKey: currentVersionKey,
      releaseNotes: remoteInfo.releaseNotes,
    );
  }

  Future<void> markStartupReleaseNotesSeen(String versionKey) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_seenReleaseNotesVersionKey, versionKey.trim());
  }

  Future<AppUpdateStatus> checkForUpdate({
    bool ignoreHandledLink = false,
  }) async {
    final packageInfo = await getPackageInfo();
    final remoteInfo = await GoogleSheetService.instance.fetchAppUpdateInfo();
    final handledLink = await _getHandledLink();
    final downloadedFile = await getDownloadedFileForLink(
      remoteInfo?.apkUrl ?? '',
    );

    if (remoteInfo == null || !remoteInfo.isConfigured) {
      return AppUpdateStatus(
        packageInfo: packageInfo,
        remoteInfo: remoteInfo,
        isAvailable: false,
        isHandledOnDevice: false,
        downloadedFilePath: downloadedFile?.path,
      );
    }

    final isNewer = remoteInfo.isNewerThan(
      currentVersion: packageInfo.version,
      currentBuildNumber: packageInfo.buildNumber,
    );
    final isHandled =
        remoteInfo.apkUrl.isNotEmpty && remoteInfo.apkUrl == handledLink;

    if (!isNewer) {
      await clearStoredDownload();
    }

    return AppUpdateStatus(
      packageInfo: packageInfo,
      remoteInfo: remoteInfo,
      isAvailable: isNewer && (ignoreHandledLink || !isHandled),
      isHandledOnDevice: isHandled,
      downloadedFilePath: downloadedFile?.path,
    );
  }

  Future<File> downloadUpdate(
    AppUpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    if (!info.hasDownloadLink) {
      throw const AppUpdateException('APK download link is missing.');
    }

    final uri = Uri.tryParse(info.apkUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const AppUpdateException('APK download link is not valid.');
    }

    final directory = await getApplicationDocumentsDirectory();
    final fileName = _buildFileName(info, uri);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    final request = http.Request('GET', uri);
    final response = await _client.send(request);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppUpdateException(
        'Download failed with status ${response.statusCode}.',
      );
    }

    final totalBytes = response.contentLength;
    var receivedBytes = 0;
    final sink = file.openWrite();

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes != null && totalBytes > 0) {
          onProgress?.call(receivedBytes / totalBytes);
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    await _setHandledLink(info.apkUrl);
    await _setDownloadedFile(info.apkUrl, file.path);
    onProgress?.call(1);
    return file;
  }

  Future<PermissionStatus> ensureInstallPermission() async {
    if (!Platform.isAndroid) {
      return PermissionStatus.granted;
    }

    var status = await Permission.requestInstallPackages.status;
    if (status == PermissionStatus.granted) {
      return status;
    }

    status = await Permission.requestInstallPackages.request();
    return status;
  }

  Future<void> cleanupPendingDownloadedApkOnStartup() async {
    final preferences = await SharedPreferences.getInstance();
    final storedPath =
        preferences.getString(_downloadedFilePathKey)?.trim() ?? '';
    if (storedPath.isEmpty) {
      return;
    }

    final file = File(storedPath);
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore cleanup failures on startup and clear stale metadata anyway.
    }

    await clearStoredDownload();
  }

  Future<void> installDownloadedApk({
    required String filePath,
    required String appId,
  }) async {
    if (!Platform.isAndroid) {
      throw const AppUpdateException(
        'APK installation is only available on Android.',
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw const AppUpdateException('Downloaded APK file was not found.');
    }

    final result = await InstallPlugin.installApk(filePath, appId: appId);
    if (result is Map && result['isSuccess'] == false) {
      throw AppUpdateException(
        (result['errorMessage'] ?? 'APK install failed.').toString(),
      );
    }
  }

  Future<File?> getDownloadedFileForLink(String link) async {
    if (link.trim().isEmpty) {
      return null;
    }

    final preferences = await SharedPreferences.getInstance();
    final storedLink = preferences.getString(_downloadedLinkKey)?.trim() ?? '';
    final storedPath =
        preferences.getString(_downloadedFilePathKey)?.trim() ?? '';

    if (storedLink != link.trim() || storedPath.isEmpty) {
      return null;
    }

    final file = File(storedPath);
    if (!await file.exists()) {
      await clearStoredDownload();
      return null;
    }

    return file;
  }

  Future<void> clearStoredDownload() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_downloadedLinkKey);
    await preferences.remove(_downloadedFilePathKey);
  }

  Future<String?> _getHandledLink() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_handledLinkKey)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  Future<void> _setHandledLink(String link) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_handledLinkKey, link.trim());
  }

  Future<void> _setDownloadedFile(String link, String filePath) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_downloadedLinkKey, link.trim());
    await preferences.setString(_downloadedFilePathKey, filePath.trim());
  }

  String _buildVersionKey(String version, String buildNumber) {
    final normalizedVersion = version.trim();
    final normalizedBuild = buildNumber.trim();
    if (normalizedBuild.isEmpty) {
      return normalizedVersion;
    }
    if (normalizedVersion.isEmpty) {
      return normalizedBuild;
    }
    return '$normalizedVersion+$normalizedBuild';
  }

  String _buildFileName(AppUpdateInfo info, Uri uri) {
    final rawName = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final sanitizedName = rawName.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    if (sanitizedName.toLowerCase().endsWith('.apk')) {
      return sanitizedName;
    }

    final versionPart = info.version.isEmpty ? 'update' : info.version;
    return 'stocker_$versionPart.apk';
  }
}

class AppUpdateStatus {
  const AppUpdateStatus({
    required this.packageInfo,
    required this.remoteInfo,
    required this.isAvailable,
    required this.isHandledOnDevice,
    required this.downloadedFilePath,
  });

  final PackageInfo packageInfo;
  final AppUpdateInfo? remoteInfo;
  final bool isAvailable;
  final bool isHandledOnDevice;
  final String? downloadedFilePath;

  bool get hasDownloadedFile => (downloadedFilePath ?? '').trim().isNotEmpty;
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StartupReleaseNotes {
  const StartupReleaseNotes({
    required this.versionLabel,
    required this.versionKey,
    required this.releaseNotes,
  });

  final String versionLabel;
  final String versionKey;
  final String releaseNotes;
}
