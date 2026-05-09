import 'package:flutter/material.dart';

import '../models/account_profile.dart';
import '../services/app_update_service.dart';
import '../services/app_mode_service.dart';
import '../services/backend_config_service.dart';
import '../services/currency_settings_service.dart';
import '../services/finance_currency_settings_service.dart';
import '../services/google_sheet_service.dart';
import '../services/invoice_logo_service.dart';
import '../services/invoice_template_settings_service.dart';
import '../services/session_service.dart';
import '../services/tax_settings_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_message.dart';
import 'settings_backend_details.dart';
import 'settings_app_version.dart';
import 'settings_currency_details.dart';
import 'settings_invoice_logo.dart';
import 'settings_invoice_template.dart';
import 'settings_legal_details.dart';
import 'settings_employee_details.dart';
import 'settings_profile_details.dart';
import 'settings_security_details.dart';
import 'settings_tax_details.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _surface = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _primaryContainer = Color(0xFF004D43);
  static const Color _surfaceLowest = Colors.white;
  static const Color _surfaceContainer = Color(0xFFECEEEC);
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF3F4945);
  static const Color _outlineVariant = Color(0xFFBFC9C4);
  static const Color _accent = Color(0xFFCFE6F2);

  bool _isLoadingProfile = false;
  bool _isLoadingTax = false;
  bool _isLoadingCurrency = false;
  bool _isLoadingFinanceCurrency = false;
  bool _isLoadingInvoiceTemplate = false;
  bool _isLoadingInvoiceLogo = false;
  bool _isUpdatingAppMode = false;
  String? _currentLink;
  String? _overrideLink;
  String? _profileError;
  AccountProfile? _profile;
  AppMode _appMode = AppMode.stockManager;
  double _taxPercentage = 0;
  String _currencyCode = CurrencySettingsService.defaultCurrencyCode;
  String _financeCurrencyCode = CurrencySettingsService.defaultCurrencyCode;
  int _invoiceTemplateId = InvoiceTemplateSettingsService.defaultTemplateId;
  bool _hasInvoiceLogo = false;
  String _appVersionSummary = 'Loading current version...';

  @override
  void initState() {
    super.initState();
    _loadAppMode();
    _loadBackendLink();
    _loadProfile();
    _loadTaxSetting();
    _loadCurrencySetting();
    _loadFinanceCurrencySetting();
    _loadInvoiceTemplateSetting();
    _loadInvoiceLogoSetting();
    _loadAppVersion();
  }

  bool get _hasCustomLink => (_overrideLink ?? '').trim().isNotEmpty;

  bool get _hasBackendLink => (_currentLink ?? '').trim().isNotEmpty;

    AccountWorkspaceAccess get _workspaceAccess =>
      _profile?.accessScope ?? AccountWorkspaceAccess.both;

    bool get _canToggleWorkspace =>
      !_isLoadingProfile && _profile != null && _profile!.canToggleWorkspace;

  Future<void> _loadAppMode() async {
    final appMode = await AppModeService.getMode();
    if (!mounted) {
      return;
    }

    setState(() {
      _appMode = appMode;
    });
  }

  Future<void> _loadBackendLink() async {
    final currentLink = await BackendConfigService.getGoogleScriptUrl();
    final overrideLink =
        await BackendConfigService.getOverrideGoogleScriptUrl();
    if (!mounted) {
      return;
    }

    setState(() {
      _currentLink = currentLink;
      _overrideLink = overrideLink;
    });
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _profileError = null;
    });

    try {
      final email = await SessionService.getUserEmail();
      if (email == null || email.trim().isEmpty) {
        throw Exception(
          'Signed-in account was not found. Please log in again.',
        );
      }

      final localProfile = await GoogleSheetService.instance
          .getStoredAccountProfile(email);
      if (mounted && localProfile != null) {
        setState(() {
          _profile = localProfile;
        });
        await _applyProfileAccess(localProfile);
      }

      final profile = await GoogleSheetService.instance.fetchAccountProfile(
        email,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
      });
      await _applyProfileAccess(profile);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _profileError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _loadTaxSetting() async {
    setState(() {
      _isLoadingTax = true;
    });

    final localTaxPercentage =
        await TaxSettingsService.getStoredTaxPercentage();
    if (mounted) {
      setState(() {
        _taxPercentage = localTaxPercentage;
        _isLoadingTax = false;
      });
    }

    final syncedTaxPercentage =
        await TaxSettingsService.syncTaxPercentageFromServer();
    if (!mounted) {
      return;
    }

    setState(() {
      _taxPercentage = syncedTaxPercentage;
    });
  }

  Future<void> _loadCurrencySetting() async {
    setState(() {
      _isLoadingCurrency = true;
    });

    final selectedCurrency = await CurrencySettingsService.getSelectedCurrency();
    if (!mounted) {
      return;
    }

    setState(() {
      _currencyCode = selectedCurrency.code;
      _isLoadingCurrency = false;
    });
  }

  Future<void> _loadFinanceCurrencySetting() async {
    setState(() {
      _isLoadingFinanceCurrency = true;
    });

    final selectedCurrency =
        await FinanceCurrencySettingsService.getSelectedCurrency();
    if (!mounted) {
      return;
    }

    setState(() {
      _financeCurrencyCode = selectedCurrency.code;
      _isLoadingFinanceCurrency = false;
    });
  }

  Future<void> _loadInvoiceTemplateSetting() async {
    setState(() {
      _isLoadingInvoiceTemplate = true;
    });

    final selectedTemplateId =
        await InvoiceTemplateSettingsService.getSelectedTemplateId();

    if (!mounted) {
      return;
    }

    setState(() {
      _invoiceTemplateId = selectedTemplateId;
      _isLoadingInvoiceTemplate = false;
    });
  }

  Future<void> _loadInvoiceLogoSetting() async {
    setState(() {
      _isLoadingInvoiceLogo = true;
    });

    final hasLogo = await InvoiceLogoService.hasLogo(refreshFromServer: true);
    if (!mounted) {
      return;
    }

    setState(() {
      _hasInvoiceLogo = hasLogo;
      _isLoadingInvoiceLogo = false;
    });
  }

  Future<void> _openProfile() async {
    final profile = _profile;
    if (profile == null) {
      AppMessage.showInfo(
        context,
        _isLoadingProfile
            ? 'Profile is still loading.'
            : (_profileError ?? 'Profile is not available right now.'),
      );
      return;
    }

    final updatedProfile = await Navigator.of(context).push<AccountProfile>(
      MaterialPageRoute(
        builder: (context) => SettingsProfileDetailsScreen(profile: profile),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updatedProfile != null) {
      setState(() {
        _profile = updatedProfile;
        _profileError = null;
      });
    } else {
      await _loadProfile();
    }
  }

  Future<void> _openSecurity() async {
    final email = (_profile?.email ?? '').trim();
    if (email.isEmpty) {
      AppMessage.showError(
        context,
        'Load the profile first before opening security.',
      );
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SettingsSecurityDetailsScreen(email: email),
      ),
    );
  }

  Future<void> _openTaxSettings() async {
    final updatedPercentage = await Navigator.of(context).push<double>(
      MaterialPageRoute(
        builder: (context) =>
            SettingsTaxDetailsScreen(initialPercentage: _taxPercentage),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updatedPercentage != null) {
      setState(() {
        _taxPercentage = updatedPercentage;
      });
    } else {
      await _loadTaxSetting();
    }
  }

  Future<void> _openCurrencySettings() async {
    final updatedCurrencyCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => SettingsCurrencyDetailsScreen(
          initialCurrencyCode: _currencyCode,
          scope: SettingsCurrencyScope.stock,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updatedCurrencyCode != null) {
      setState(() {
        _currencyCode = CurrencySettingsService.optionForCode(
          updatedCurrencyCode,
        ).code;
      });
      AppMessage.showSuccess(context, 'Currency updated.');
    } else {
      await _loadCurrencySetting();
    }
  }

  Future<void> _openFinanceCurrencySettings() async {
    final updatedCurrencyCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => SettingsCurrencyDetailsScreen(
          initialCurrencyCode: _financeCurrencyCode,
          scope: SettingsCurrencyScope.finance,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updatedCurrencyCode != null) {
      setState(() {
        _financeCurrencyCode = CurrencySettingsService.optionForCode(
          updatedCurrencyCode,
        ).code;
      });
      AppMessage.showSuccess(context, 'Finance currency updated.');
    } else {
      await _loadFinanceCurrencySetting();
    }
  }

  Future<void> _openBackendSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => const SettingsBackendDetailsScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadBackendLink();
  }

  Future<void> _openEmployeeSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => const SettingsEmployeeDetailsScreen(),
      ),
    );
  }

  Future<void> _openInvoiceTemplateSettings() async {
    final updatedTemplateId = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (context) => SettingsInvoiceTemplateScreen(
          initialTemplateId: _invoiceTemplateId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updatedTemplateId != null) {
      setState(() {
        _invoiceTemplateId = updatedTemplateId;
      });
      AppMessage.showSuccess(context, 'Invoice template updated.');
    } else {
      await _loadInvoiceTemplateSetting();
    }
  }

  Future<void> _openInvoiceLogoSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => const SettingsInvoiceLogoScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadInvoiceLogoSetting();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await AppUpdateService.instance.getPackageInfo();
      if (!mounted) {
        return;
      }

      setState(() {
        _appVersionSummary =
        'Stocker Expense Tracker ${packageInfo.version}+${packageInfo.buildNumber}';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _appVersionSummary = 'Stocker Expense Tracker';
      });
    }
  }

  Future<void> _openAppVersion() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (context) => const SettingsAppVersionScreen()),
    );
  }

  Future<void> _openPrivacy() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => SettingsLegalDetailsScreen.privacy(),
      ),
    );
  }

  Future<void> _openTerms() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => SettingsLegalDetailsScreen.terms(),
      ),
    );
  }

  Future<void> _toggleAppMode(bool enableExpenseTracker) async {
    if (!_canToggleWorkspace) {
      return;
    }

    final nextMode = enableExpenseTracker
        ? AppMode.expenseTracker
        : AppMode.stockManager;
    if (nextMode == _appMode) {
      return;
    }

    setState(() {
      _isUpdatingAppMode = true;
    });

    await AppModeService.setMode(nextMode);
    if (!mounted) {
      return;
    }

    setState(() {
      _appMode = nextMode;
      _isUpdatingAppMode = false;
    });

    AppMessage.showSuccess(
      context,
      nextMode == AppMode.expenseTracker
          ? 'Expense tracker workspace enabled.'
          : 'Stock manager workspace enabled.',
    );
  }

  Future<void> _applyProfileAccess(AccountProfile profile) async {
    await SessionService.updateFinanceEntryAccess(
      profile.canManageFinanceEntries,
    );
    final enforcedMode = await AppModeService.enforceAccess(profile.accessScope);
    if (!mounted) {
      return;
    }

    setState(() {
      _appMode = enforcedMode;
    });
  }

  Future<void> _signOut(BuildContext context) async {
    await SessionService.clearSession();
    if (!context.mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  String get _profileSummary {
    if (_isLoadingProfile) {
      return 'Loading saved business account...';
    }
    if (_profileError != null) {
      return 'Tap to retry loading your credentials sheet profile';
    }
    final profile = _profile;
    if (profile == null) {
      return 'Open your saved business profile';
    }

    final companyName = profile.companyName.trim();
    final fullName = profile.fullName.trim();
    if (companyName.isEmpty && fullName.isEmpty) {
      return 'Open your saved business profile';
    }
    if (companyName.isEmpty) {
      return fullName;
    }
    if (fullName.isEmpty) {
      return companyName;
    }
    return '$companyName • $fullName';
  }

  String get _securitySummary {
    final profile = _profile;
    if (_isLoadingProfile) {
      return 'Loading master key status...';
    }
    if (profile == null) {
      return 'Reset password using your master key';
    }
    return profile.masterKey.trim().isEmpty
        ? 'Create a master key in Profile first'
        : 'Reset password using the saved master key';
  }

  String get _taxSummary {
    if (_isLoadingTax) {
      return 'Loading current tax rate...';
    }

    if (_taxPercentage == _taxPercentage.roundToDouble()) {
      return '${_taxPercentage.toStringAsFixed(0)}% applied to checkout subtotal';
    }

    return '${_taxPercentage.toStringAsFixed(2)}% applied to checkout subtotal';
  }

  String get _currencySummary {
    if (_isLoadingCurrency) {
      return 'Loading selected stock currency...';
    }

    return CurrencySettingsService.optionForCode(_currencyCode).summary;
  }

  String get _financeCurrencySummary {
    if (_isLoadingFinanceCurrency) {
      return 'Loading selected finance currency...';
    }

    return CurrencySettingsService.optionForCode(_financeCurrencyCode).summary;
  }

  String get _backendSummary {
    if (_currentLink == null) {
      return 'Loading backend configuration...';
    }

    if (_hasCustomLink) {
      return 'Custom stock and finance backend connected';
    }

    if (_hasBackendLink) {
      return 'Stock and finance backend connected';
    }

    return 'Tap to connect one Google Sheets backend for stock and finance';
  }

  String get _invoiceTemplateSummary {
    if (_isLoadingInvoiceTemplate) {
      return 'Loading invoice export template...';
    }

    final option = InvoiceTemplateSettingsService.optionForId(
      _invoiceTemplateId,
    );
    return '${option.name} • ${option.summary}';
  }

  String get _invoiceLogoSummary {
    if (_isLoadingInvoiceLogo) {
      return 'Checking invoice branding logo...';
    }

    return _hasInvoiceLogo
        ? 'PNG logo uploaded for invoice exports'
        : 'Upload a PNG company logo for invoices';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 120),
          children: [
            const _SettingsTopBar(),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
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
                    'Settings',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Account and security open separately, while backend setup stays editable right here on this screen.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SectionTitle(title: 'Workspace'),
            const SizedBox(height: 14),
            _SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: _surfaceContainer,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              _appMode == AppMode.expenseTracker
                                  ? Icons.wallet_rounded
                                  : Icons.inventory_2_outlined,
                              color: _primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Expense Tracker Mode',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: _textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _canToggleWorkspace
                                      ? (_appMode == AppMode.expenseTracker
                                          ? 'Enabled'
                                          : 'Disabled')
                                      : _workspaceAccess.title,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_canToggleWorkspace)
                            Switch.adaptive(
                              value: _appMode == AppMode.expenseTracker,
                              onChanged: _isUpdatingAppMode ? null : _toggleAppMode,
                              activeTrackColor: _primary.withValues(alpha: 0.45),
                              thumbColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return _primary;
                                }

                                return null;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _canToggleWorkspace
                            ? (_appMode == AppMode.expenseTracker
                                ? 'Bottom tabs now open Overview, Expenses, Salary, Credit, and Balance with finance tracking.'
                                : 'Keep the stock workflow for dashboard, inventory, orders, add stock, and checkout.')
                            : (_workspaceAccess == AccountWorkspaceAccess.finance
                                ? 'This account is restricted to the finance workspace from the credentials sheet.'
                                : 'This account is restricted to the stock workspace from the credentials sheet.'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _appMode.summary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _textSecondary,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionTitle(title: 'Account'),
            const SizedBox(height: 14),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile',
                  subtitle: _profileSummary,
                  onTap: _openProfile,
                ),
                const _SettingsDivider(),
                _SettingsRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'Security',
                  subtitle: _securitySummary,
                  onTap: _openSecurity,
                ),
              ],
            ),
            if (_profileError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6E7E6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFF9A3E31),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _profileError!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF9A3E31),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadProfile,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            const _SectionTitle(title: 'Business'),
            const SizedBox(height: 14),
            _SettingsCard(
              children: [
                if (_appMode == AppMode.expenseTracker)
                  _SettingsRow(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Finance Currency',
                    subtitle: _financeCurrencySummary,
                    onTap: _openFinanceCurrencySettings,
                  )
                else
                  _SettingsRow(
                    icon: Icons.currency_exchange_rounded,
                    title: 'Stock Currency',
                    subtitle: _currencySummary,
                    onTap: _openCurrencySettings,
                  ),
                const _SettingsDivider(),
                if (_appMode == AppMode.expenseTracker) ...[
                  _SettingsRow(
                    icon: Icons.groups_outlined,
                    title: 'Employees',
                    subtitle: 'Add employees for salary entries',
                    onTap: _openEmployeeSettings,
                  ),
                  const _SettingsDivider(),
                ],
                _SettingsRow(
                  icon: Icons.percent_rounded,
                  title: 'Tax Settings',
                  subtitle: _taxSummary,
                  onTap: _openTaxSettings,
                ),
                const _SettingsDivider(),
                _SettingsRow(
                  icon: Icons.receipt_long_rounded,
                  title: 'Invoice Template',
                  subtitle: _invoiceTemplateSummary,
                  onTap: _openInvoiceTemplateSettings,
                ),
                const _SettingsDivider(),
                _SettingsRow(
                  icon: Icons.image_outlined,
                  title: 'Invoice Logo',
                  subtitle: _invoiceLogoSummary,
                  onTap: _openInvoiceLogoSettings,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionTitle(title: 'Legal'),
            const SizedBox(height: 14),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy',
                  subtitle:
                      'Read how account, stock, and order data is handled',
                  onTap: _openPrivacy,
                ),
                const _SettingsDivider(),
                _SettingsRow(
                  icon: Icons.description_outlined,
                  title: 'Terms & Conditions',
                  subtitle: 'Read the usage terms for Stocker operations',
                  onTap: _openTerms,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionTitle(title: 'System'),
            const SizedBox(height: 14),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.cloud_done_outlined,
                  title: 'Google Sheets Backend',
                  subtitle: _backendSummary,
                  onTap: _openBackendSettings,
                ),
                const _SettingsDivider(),
                _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  title: 'App Version',
                  subtitle: _appVersionSummary,
                  onTap: _openAppVersion,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionTitle(title: 'Quick Actions'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: _appMode == AppMode.expenseTracker
                        ? Icons.payments_outlined
                        : Icons.inventory_2_outlined,
                    title: _appMode == AppMode.expenseTracker
                        ? 'Expenses'
                        : 'Inventory',
                    subtitle: _appMode == AppMode.expenseTracker
                        ? 'Open tracker'
                        : 'Review stock',
                    backgroundColor: _surfaceLowest,
                    onTap: () =>
                        Navigator.pushReplacementNamed(context, '/inventory'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    subtitle: 'Back to login',
                    backgroundColor: _accent,
                    onTap: () => _signOut(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 5),
    );
  }
}

class _SettingsTopBar extends StatelessWidget {
  const _SettingsTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _SettingsScreenState._primary,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.person, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Settings',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: _SettingsScreenState._primary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        IconButton(
          onPressed: () {},
          splashRadius: 22,
          icon: const Icon(
            Icons.settings_suggest_outlined,
            color: Color(0xFF5CA899),
            size: 26,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: _SettingsScreenState._textPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _SettingsScreenState._surfaceLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1200342D),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _SettingsScreenState._surfaceContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: _SettingsScreenState._primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _SettingsScreenState._textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _SettingsScreenState._textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.chevron_right_rounded,
            color: _SettingsScreenState._textSecondary,
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: content,
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        color: _SettingsScreenState._outlineVariant.withValues(alpha: 0.38),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: _SettingsScreenState._primary,
                  size: 22,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _SettingsScreenState._textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _SettingsScreenState._textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
