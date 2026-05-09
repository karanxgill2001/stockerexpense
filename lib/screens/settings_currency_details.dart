import 'package:flutter/material.dart';

import '../services/currency_settings_service.dart';
import '../services/finance_currency_settings_service.dart';

enum SettingsCurrencyScope { stock, finance }

class SettingsCurrencyDetailsScreen extends StatefulWidget {
  const SettingsCurrencyDetailsScreen({
    super.key,
    required this.initialCurrencyCode,
    required this.scope,
  });

  final String initialCurrencyCode;
  final SettingsCurrencyScope scope;

  @override
  State<SettingsCurrencyDetailsScreen> createState() =>
      _SettingsCurrencyDetailsScreenState();
}

class _SettingsCurrencyDetailsScreenState
    extends State<SettingsCurrencyDetailsScreen> {
  static const Color _surface = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _surfaceLowest = Colors.white;
  static const Color _surfaceContainer = Color(0xFFECEEEC);
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF3F4945);
  static const Color _outlineVariant = Color(0xFFBFC9C4);

  late String _selectedCurrencyCode;
  String _query = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCurrencyCode = CurrencySettingsService.optionForCode(
      widget.initialCurrencyCode,
    ).code;
  }

  Future<void> _saveSelection() async {
    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.scope == SettingsCurrencyScope.finance) {
        await FinanceCurrencySettingsService.setSelectedCurrencyCode(
          _selectedCurrencyCode,
        );
      } else {
        await CurrencySettingsService.setSelectedCurrencyCode(
          _selectedCurrencyCode,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(_selectedCurrencyCode);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<CurrencyOption> get _filteredOptions {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return CurrencySettingsService.options;
    }

    return CurrencySettingsService.options.where((option) {
      return option.code.toLowerCase().contains(normalizedQuery) ||
          option.name.toLowerCase().contains(normalizedQuery) ||
          option.symbol.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCurrency = CurrencySettingsService.optionForCode(
      _selectedCurrencyCode,
    );
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardVisible = keyboardInset > 0;
    final isFinance = widget.scope == SettingsCurrencyScope.finance;
    final title = isFinance ? 'Finance Currency' : 'Stock Currency';
    final heading = isFinance
      ? 'Select finance default currency'
      : 'Select stock transaction currency';
    final description = isFinance
      ? 'Choose the default currency used when adding finance entries. Entries are saved to Google Sheets in the selected currency and shown back exactly as saved.'
      : 'Choose the currency label used for inventory values, checkout totals, order history, and invoice exports. Amounts are saved exactly as entered without rate conversion.';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _saveSelection,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.1,
                        valueColor: AlwaysStoppedAnimation<Color>(_primary),
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Container(
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
                    heading,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: _textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Amounts are saved and displayed directly from Google Sheets without exchange-rate conversion.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      selectedCurrency.summary,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name, code, or symbol',
                      prefixIcon: const Icon(Icons.search_rounded),
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
                        borderSide: const BorderSide(
                          color: _primary,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              itemCount: _filteredOptions.length,
              itemBuilder: (context, index) {
                final option = _filteredOptions[index];
                final isSelected = option.code == _selectedCurrencyCode;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _isSaving
                        ? null
                        : () {
                            setState(() {
                              _selectedCurrencyCode = option.code;
                            });
                          },
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? _primary
                              : _outlineVariant.withValues(alpha: 0.55),
                          width: isSelected ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected ? _primary : _surfaceContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              option.symbol,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isSelected ? Colors.white : _primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: _textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${option.code} • ${option.symbol}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: _textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: isSelected
                                ? _primary
                                : _outlineVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: isKeyboardVisible
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveSelection,
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
                      : const Text('Save Currency'),
                ),
              ),
            ),
    );
  }
}