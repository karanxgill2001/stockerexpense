import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/app_update_service.dart';
import '../widgets/app_message.dart';

class SettingsAppVersionScreen extends StatefulWidget {
  const SettingsAppVersionScreen({super.key, this.autoCheck = false});

  final bool autoCheck;

  @override
  State<SettingsAppVersionScreen> createState() =>
      _SettingsAppVersionScreenState();
}

class _SettingsAppVersionScreenState extends State<SettingsAppVersionScreen> {
  static const Color _surface = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _primaryContainer = Color(0xFF004D43);
  static const Color _surfaceLowest = Colors.white;
  static const Color _surfaceContainer = Color(0xFFECEEEC);
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF3F4945);
  static const Color _outlineVariant = Color(0xFFBFC9C4);
  static const Color _accent = Color(0xFFDDEFEA);

  bool _isLoading = true;
  bool _isChecking = false;
  bool _isDownloading = false;
  bool _isInstalling = false;
  double _downloadProgress = 0;
  String? _errorMessage;
  AppUpdateStatus? _status;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final status = await AppUpdateService.instance.checkForUpdate();
      if (!mounted) {
        return;
      }

      setState(() {
        _status = status;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    if (widget.autoCheck) {
      await _checkForUpdates();
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      final status = await AppUpdateService.instance.checkForUpdate();
      if (!mounted) {
        return;
      }

      setState(() {
        _status = status;
      });

      if (status.isAvailable) {
        AppMessage.showInfo(context, 'A new app update is ready to download.');
      } else if (status.isHandledOnDevice && !status.hasDownloadedFile) {
        AppMessage.showInfo(
          context,
          'This update link was already used on this device. Upload a new APK link in Google Sheets to trigger the next update.',
        );
      } else {
        AppMessage.showSuccess(
          context,
          'You are already on the latest version.',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
      AppMessage.showError(context, 'Failed to check for updates.');
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _downloadUpdate() async {
    final remoteInfo = _status?.remoteInfo;
    if (remoteInfo == null) {
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _errorMessage = null;
    });

    try {
      final file = await AppUpdateService.instance.downloadUpdate(
        remoteInfo,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }

          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _status = AppUpdateStatus(
          packageInfo: _status!.packageInfo,
          remoteInfo: remoteInfo,
          isAvailable: false,
          isHandledOnDevice: true,
          downloadedFilePath: file.path,
        );
      });
      AppMessage.showSuccess(
        context,
        'APK downloaded. You can install it now.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
      AppMessage.showError(context, 'APK download failed.');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _requestInstallPermission() async {
    final status = await AppUpdateService.instance.ensureInstallPermission();
    if (!mounted) {
      return;
    }

    if (status == PermissionStatus.granted) {
      AppMessage.showSuccess(context, 'Install permission is ready.');
      return;
    }

    AppMessage.showInfo(
      context,
      'Enable Allow from this source, then return here and tap Install Update.',
    );
  }

  Future<void> _installUpdate() async {
    final status = _status;
    if (status == null || !status.hasDownloadedFile) {
      return;
    }

    setState(() {
      _isInstalling = true;
      _errorMessage = null;
    });

    try {
      final permissionStatus = await AppUpdateService.instance
          .ensureInstallPermission();
      if (permissionStatus != PermissionStatus.granted) {
        throw const AppUpdateException(
          'Install permission is required before APK installation can start.',
        );
      }

      await AppUpdateService.instance.installDownloadedApk(
        filePath: status.downloadedFilePath!,
        appId: status.packageInfo.packageName,
      );

      if (!mounted) {
        return;
      }

      AppMessage.showInfo(
        context,
        'Android installer opened. Finish the installation from the system installer screen. The downloaded APK file will be deleted automatically the next time the app starts.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
      AppMessage.showError(context, 'Could not start APK installation.');
    } finally {
      if (mounted) {
        setState(() {
          _isInstalling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status;
    final packageInfo = status?.packageInfo;
    final remoteInfo = status?.remoteInfo;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('App Version'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primary, _primaryContainer],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1C00342D),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stocker Expense Tracker',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Check the latest APK from Google Sheets, download it in-app, then install it from this screen.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _InfoCard(
            child: Column(
              children: [
                _InfoRow(
                  title: 'Current app version',
                  value: packageInfo == null
                      ? 'Loading...'
                      : '${packageInfo.version}+${packageInfo.buildNumber}',
                ),
                const _CardDivider(),
                _InfoRow(
                  title: 'Latest uploaded version',
                  value: remoteInfo?.displayVersion ?? 'Not uploaded yet',
                ),
                const _CardDivider(),
                _InfoRow(
                  title: 'Update status',
                  value: _buildStatusLabel(status),
                ),
              ],
            ),
          ),
          if ((remoteInfo?.releaseNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Release Notes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    remoteInfo!.releaseNotes,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_isDownloading) ...[
            const SizedBox(height: 16),
            _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Downloading APK',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _downloadProgress > 0 && _downloadProgress <= 1
                        ? _downloadProgress
                        : null,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: _surfaceContainer,
                    color: _primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${(_downloadProgress * 100).clamp(0, 100).toStringAsFixed(0)}% complete',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if ((_errorMessage ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF6E7E6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFF9A3E31),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF9A3E31),
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isLoading || _isChecking ? null : _checkForUpdates,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: _isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.system_update_alt_rounded),
            label: Text(_isChecking ? 'Checking...' : 'Check for Updates'),
          ),
          const SizedBox(height: 12),
          if (status?.isAvailable == true && remoteInfo != null)
            OutlinedButton.icon(
              onPressed: _isDownloading ? null : _downloadUpdate,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                minimumSize: const Size.fromHeight(54),
                side: const BorderSide(color: _outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download Update'),
            ),
          if ((status?.hasDownloadedFile ?? false) &&
              status?.downloadedFilePath != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isInstalling ? null : _requestInstallPermission,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                backgroundColor: _accent,
                minimumSize: const Size.fromHeight(54),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Allow Install Permission'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isInstalling ? null : _installUpdate,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF115A4B),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: _isInstalling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.install_mobile_rounded),
              label: Text(
                _isInstalling ? 'Starting Installer...' : 'Install Update',
              ),
            ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 10),
              Text(
                'If Android asks for unknown app installs, allow this app as a trusted source, then tap Install Update again.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _buildStatusLabel(AppUpdateStatus? status) {
    if (_isLoading) {
      return 'Loading...';
    }
    if (status == null) {
      return 'Not available';
    }
    if (status.isAvailable) {
      return 'Update available';
    }
    if (status.hasDownloadedFile) {
      return 'Downloaded and ready to install';
    }
    if (status.isHandledOnDevice) {
      return 'Latest uploaded APK link already used on this device';
    }
    return 'Up to date';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _SettingsAppVersionScreenState._surfaceLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1200342D),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _SettingsAppVersionScreenState._textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _SettingsAppVersionScreenState._textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(
        height: 1,
        color: _SettingsAppVersionScreenState._outlineVariant.withValues(
          alpha: 0.42,
        ),
      ),
    );
  }
}
