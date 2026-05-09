import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/tax_settings_service.dart';
import '../widgets/app_message.dart';

class SettingsTaxDetailsScreen extends StatefulWidget {
  const SettingsTaxDetailsScreen({super.key, required this.initialPercentage});

  final double initialPercentage;

  @override
  State<SettingsTaxDetailsScreen> createState() =>
      _SettingsTaxDetailsScreenState();
}

class _SettingsTaxDetailsScreenState extends State<SettingsTaxDetailsScreen> {
  static const Color _surface = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _surfaceLowest = Colors.white;
  static const Color _surfaceContainer = Color(0xFFECEEEC);
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF3F4945);

  late final TextEditingController _taxPercentageController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _taxPercentageController = TextEditingController(
      text: _formatPercentage(widget.initialPercentage),
    );
  }

  @override
  void dispose() {
    _taxPercentageController.dispose();
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
      suffixText: '%',
    );
  }

  Future<void> _saveTaxPercentage() async {
    final rawValue = _taxPercentageController.text.trim();
    final percentage = double.tryParse(rawValue);

    if (rawValue.isEmpty || percentage == null) {
      AppMessage.showError(context, 'Enter a valid tax percentage.');
      return;
    }

    if (percentage < 0 || percentage > 100) {
      AppMessage.showError(
        context,
        'Tax percentage must be between 0 and 100.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await TaxSettingsService.setTaxPercentage(percentage);

      if (!mounted) {
        return;
      }

      AppMessage.showSuccess(context, 'Tax setting updated successfully.');
      Navigator.of(context).pop(percentage);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatPercentage(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
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
        title: const Text('Tax Settings'),
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
                  'Checkout Tax Rate',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: _textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This percentage is applied to the item subtotal during checkout and added to the total amount.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tax Percentage',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _taxPercentageController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: _fieldDecoration('Enter tax percentage'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Example: enter 18 to charge 18% tax on the subtotal.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _saveTaxPercentage,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
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
                      : const Text('Save Tax Setting'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
