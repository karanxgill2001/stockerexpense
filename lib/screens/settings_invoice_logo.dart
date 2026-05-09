import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/invoice_logo_service.dart';
import '../widgets/app_message.dart';

class SettingsInvoiceLogoScreen extends StatefulWidget {
  const SettingsInvoiceLogoScreen({super.key});

  @override
  State<SettingsInvoiceLogoScreen> createState() =>
      _SettingsInvoiceLogoScreenState();
}

class _SettingsInvoiceLogoScreenState extends State<SettingsInvoiceLogoScreen> {
  static const Color _surface = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _surfaceLowest = Colors.white;
  static const Color _surfaceContainer = Color(0xFFECEEEC);
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF3F4945);
  static const Color _outlineVariant = Color(0xFFBFC9C4);

  bool _isLoading = true;
  bool _isSaving = false;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    final path = await InvoiceLogoService.getLogoPath(refreshFromServer: true);
    if (!mounted) {
      return;
    }

    setState(() {
      _logoPath = path;
      _isLoading = false;
    });
  }

  Future<void> _pickLogo() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final selectedPath = result.files.single.path;
      if (selectedPath == null || selectedPath.trim().isEmpty) {
        throw Exception('Selected PNG file path was not available.');
      }

      final savedPath = await InvoiceLogoService.savePngLogo(File(selectedPath));
      if (!mounted) {
        return;
      }

      setState(() {
        _logoPath = savedPath;
      });
      AppMessage.showSuccess(context, 'Invoice logo updated successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppMessage.showError(context, 'Failed to save PNG logo: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _removeLogo() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await InvoiceLogoService.clearLogo();
      if (!mounted) {
        return;
      }

      setState(() {
        _logoPath = null;
      });
      AppMessage.showSuccess(context, 'Invoice logo removed.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppMessage.showError(context, 'Failed to remove invoice logo: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLogo = (_logoPath ?? '').trim().isNotEmpty;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Invoice Logo'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _surfaceLowest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1400342D),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload company logo',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: _textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a PNG logo to save into your stock manager Google Sheet. Any device connected to the same stock sheet can fetch and use that logo for invoice exports.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _surfaceContainer,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 180,
                              decoration: BoxDecoration(
                                color: _surfaceLowest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _outlineVariant.withValues(alpha: 0.45),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: hasLogo
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        File(_logoPath!),
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.image_outlined,
                                          color: _textSecondary,
                                          size: 40,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'No PNG logo uploaded',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                color: _textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              hasLogo
                                  ? 'Current file: ${_logoPath!.split(Platform.pathSeparator).last}'
                                  : 'Only PNG files are allowed. The logo is saved in the stock Google Sheet, not the credentials sheet.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isLoading || _isSaving ? null : _pickLogo,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: Text(_isSaving ? 'Saving PNG To Sheet...' : 'Upload PNG Logo'),
          ),
          if (hasLogo) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _removeLogo,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remove Logo'),
            ),
          ],
        ],
      ),
    );
  }
}