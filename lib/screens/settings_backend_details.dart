import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/backend_config_service.dart';
import '../services/finance_tracker_service.dart';
import '../services/google_sheet_service.dart';
import '../widgets/app_message.dart';

class SettingsBackendDetailsScreen extends StatefulWidget {
  const SettingsBackendDetailsScreen({super.key});

  @override
  State<SettingsBackendDetailsScreen> createState() =>
      _SettingsBackendDetailsScreenState();
}

class _SettingsBackendDetailsScreenState
    extends State<SettingsBackendDetailsScreen> {
  static const Color _surface = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _surfaceLowest = Colors.white;
  static const Color _surfaceContainer = Color(0xFFECEEEC);
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF3F4945);
  static const Color _outlineVariant = Color(0xFFBFC9C4);

  final TextEditingController _webAppLinkController = TextEditingController();

  bool _isLoading = true;
  bool _isSavingLink = false;
  bool _isExportingScript = false;
  String? _currentLink;
  String? _overrideLink;

  bool get _hasCustomLink => (_overrideLink ?? '').trim().isNotEmpty;

  bool get _hasBackendLink => (_currentLink ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadBackendLink();
  }

  @override
  void dispose() {
    _webAppLinkController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: _surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
    );
  }

  Future<void> _loadBackendLink() async {
    setState(() {
      _isLoading = true;
    });

    final currentLink = await BackendConfigService.getGoogleScriptUrl();
    final overrideLink =
      await BackendConfigService.getOverrideGoogleScriptUrl();

    if (!mounted) {
      return;
    }

    setState(() {
      _currentLink = currentLink;
      _overrideLink = overrideLink;
      _webAppLinkController.text = currentLink;
      _isLoading = false;
    });
  }

  Future<void> _saveWebAppLink() async {
    final link = _webAppLinkController.text.trim();
    final uri = Uri.tryParse(link);
    if (link.isEmpty || uri == null || !uri.hasScheme || !uri.hasAuthority) {
      AppMessage.showError(context, 'Enter a valid Apps Script web app URL.');
      return;
    }

    setState(() {
      _isSavingLink = true;
    });

    try {
      await BackendConfigService.setGoogleScriptUrl(link);
      GoogleSheetService.instance.clearCache();
      await FinanceTrackerService.clearLocalCache();
      await _loadBackendLink();

      if (!mounted) {
        return;
      }

      AppMessage.showSuccess(context, 'Web app link updated successfully.');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingLink = false;
        });
      }
    }
  }

  Future<void> _resetWebAppLink() async {
    setState(() {
      _isSavingLink = true;
    });

    try {
      await BackendConfigService.clearGoogleScriptUrlOverride();
      GoogleSheetService.instance.clearCache();
      await FinanceTrackerService.clearLocalCache();
      await _loadBackendLink();

      if (!mounted) {
        return;
      }

      AppMessage.showSuccess(
        context,
        'Default backend link restored successfully.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingLink = false;
        });
      }
    }
  }

  Future<void> _downloadScriptTemplate() async {
    setState(() {
      _isExportingScript = true;
    });

    try {
      final scriptContent = await rootBundle.loadString(
        'google_apps_script/Code.gs',
      );
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/Code.gs.txt');
      await file.writeAsString(scriptContent);

      await Share.shareXFiles([XFile(file.path)], subject: 'Code.gs Template');

      if (!mounted) {
        return;
      }

      AppMessage.showInfo(
        context,
        'Code.gs TXT export is ready. It uses the script bundled in this app build. After changing Code.gs, rebuild or fully restart the app before exporting again.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppMessage.showError(context, 'Failed to export Code.gs TXT: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isExportingScript = false;
        });
      }
    }
  }

  String get _statusText {
    if (_hasCustomLink) {
      return 'Currently using a custom stock and finance backend.';
    }

    if (_hasBackendLink) {
      return 'Currently using the default configured stock and finance backend.';
    }

    return 'No backend link saved yet.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Google Sheets Backend'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _surfaceLowest,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1200342D),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stock + Finance Web App Link',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: _textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Paste one Apps Script web app link here to connect both stock manager records and finance entries to the same Google Sheet backend.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Use the same deployed Code.gs link for inventory, orders, tax, invoice branding, and finance entries. Changing this link switches both stock and finance data sources together.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _textSecondary,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  TextField(
                    controller: _webAppLinkController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: _fieldDecoration(
                      'Paste Apps Script web app URL here',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSavingLink ? null : _saveWebAppLink,
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSavingLink
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.1,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Save Link'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSavingLink || !_hasCustomLink
                              ? null
                              : _resetWebAppLink,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            foregroundColor: _primary,
                            side: const BorderSide(color: _outlineVariant),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Reset Default'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isExportingScript
                          ? null
                          : _downloadScriptTemplate,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: _primary,
                        side: const BorderSide(color: _outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isExportingScript
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.1,
                              ),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(
                        _isExportingScript
                            ? 'Preparing TXT...'
                            : 'Download Code.gs TXT',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'The TXT file comes from the Code.gs asset bundled inside this app. If you update google_apps_script/Code.gs, install a rebuilt app or do a full restart before downloading the template again.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _textSecondary,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
