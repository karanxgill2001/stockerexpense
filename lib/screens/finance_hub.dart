import 'package:flutter/material.dart';

import '../models/employee_record.dart';
import '../models/finance_entry.dart';
import '../services/employee_directory_service.dart';
import '../services/currency_settings_service.dart';
import '../services/finance_currency_formatter.dart';
import '../services/finance_currency_settings_service.dart';
import '../services/finance_tracker_service.dart';
import '../services/google_sheet_service.dart';
import '../services/session_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_message.dart';
import '../widgets/design_loader.dart';
import '../widgets/order_date_range_picker.dart';

class FinanceHubScreen extends StatefulWidget {
  const FinanceHubScreen({super.key, required this.initialTabIndex});

  final int initialTabIndex;

  @override
  State<FinanceHubScreen> createState() => _FinanceHubScreenState();
}

class _FinanceHubScreenState extends State<FinanceHubScreen>
  with WidgetsBindingObserver {
  static const Color _surface = Color(0xFFF7F6F2);
  static const Color _expense = Color(0xFFB4573A);
  static const Color _salary = Color(0xFF2D7A59);
  static const Color _credit = Color(0xFF4E6F9D);
  static const Color _balance = Color(0xFF7B5A9B);

  FinanceTrackerSnapshot? _snapshot;
  List<EmployeeRecord> _employees = const [];
  DateTimeRange? _overviewDateRange;
  Object? _loadError;
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _isMutatingEntry = false;
  bool _canManageFinanceEntries = true;
  String _entryMutationMessage = 'Saving entry...';
  String? _lastShownSyncErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FinanceCurrencySettingsService.changes.addListener(_handleCurrencyChanged);
    FinanceTrackerService.changes.addListener(_handleTrackerChanged);
    EmployeeDirectoryService.changes.addListener(_handleEmployeesChanged);
    _loadSnapshot(showLoader: true);
    _loadEmployees();
    _syncFinanceEntryAccessFromServer();
    FinanceTrackerService.preloadStartupData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FinanceCurrencySettingsService.changes.removeListener(_handleCurrencyChanged);
    FinanceTrackerService.changes.removeListener(_handleTrackerChanged);
    EmployeeDirectoryService.changes.removeListener(_handleEmployeesChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncFinanceEntryAccessFromServer();
    }
  }

  void _handleCurrencyChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleTrackerChanged() {
    if (!mounted) {
      return;
    }

    _loadSnapshot();
  }

  void _showSyncErrorIfNeeded() {
    final message = FinanceTrackerService.lastSyncErrorMessage?.trim();
    if (!mounted) {
      return;
    }

    if (message == null || message.isEmpty) {
      _lastShownSyncErrorMessage = null;
      return;
    }

    if (_lastShownSyncErrorMessage == message) {
      return;
    }

    _lastShownSyncErrorMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      AppMessage.showError(context, message);
    });
  }

  void _handleEmployeesChanged() {
    if (!mounted) {
      return;
    }

    _loadEmployees(forceRefresh: true);
  }

  Future<void> _setFinanceEntryAccess(bool value) async {
    await SessionService.updateFinanceEntryAccess(value);
    if (!mounted) {
      return;
    }

    setState(() {
      _canManageFinanceEntries = value;
    });
  }

  Future<void> _syncFinanceEntryAccessFromServer() async {
    try {
      final email = await SessionService.getUserEmail();
      if (email == null || email.trim().isEmpty) {
        return;
      }

      final profile = await GoogleSheetService.instance.fetchAccountProfile(email);
      await _setFinanceEntryAccess(profile.canManageFinanceEntries);
    } catch (_) {
      // Keep the locally cached permission when the credentials backend is unavailable.
    }
  }

  Future<void> _refreshEntries({bool forceRefresh = false}) async {
    if (forceRefresh && mounted) {
      setState(() {
        _isRefreshing = true;
      });
    }

    try {
      await Future.wait([
        _loadSnapshot(forceRefresh: forceRefresh),
        _loadEmployees(forceRefresh: forceRefresh),
        _syncFinanceEntryAccessFromServer(),
      ]);
    } finally {
      if (forceRefresh && mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadEmployees({bool forceRefresh = false}) async {
    try {
      final employees = await EmployeeDirectoryService.loadEmployees(
        forceRefresh: forceRefresh,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _employees = employees;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _employees = const [];
      });
    }
  }

  Future<void> _loadSnapshot({
    bool forceRefresh = false,
    bool showLoader = false,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        _isInitialLoading = true;
        _loadError = null;
      });
    }

    try {
      final snapshot = await FinanceTrackerService.loadSnapshot(
        forceRefresh: forceRefresh,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = snapshot;
        _loadError = null;
        _isInitialLoading = false;
      });
      _showSyncErrorIfNeeded();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error;
        _isInitialLoading = false;
      });
      rethrow;
    }
  }

  Future<void> _openEntrySheet({FinanceEntry? existingEntry}) async {
    final isEditing = existingEntry != null;
    if (isEditing && !_canManageFinanceEntries) {
      AppMessage.showError(
        context,
        'This account is not allowed to edit finance entries.',
      );
      return;
    }

    final entry = await showModalBottomSheet<FinanceEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddFinanceEntrySheet(
        initialType: existingEntry?.type ??
            _preferredType ??
            FinanceEntryType.expense,
        lockType: _preferredType != null,
        employees: _employees,
        initialEntry: existingEntry,
      ),
    );

    if (entry == null) {
      return;
    }

    try {
      setState(() {
        _isMutatingEntry = true;
        _entryMutationMessage = isEditing ? 'Updating entry...' : 'Saving entry...';
      });
      await FinanceTrackerService.upsertEntry(entry, isEditing: isEditing);
      if (!mounted) {
        return;
      }

      AppMessage.showSuccess(
        context,
        isEditing ? '${entry.type.label} entry updated.' : '${entry.type.label} entry added.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppMessage.showError(context, error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isMutatingEntry = false;
        });
      }
    }
  }

  Future<void> _deleteEntry(FinanceEntry entry) async {
    if (!_canManageFinanceEntries) {
      AppMessage.showError(
        context,
        'This account is not allowed to delete finance entries.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete entry?'),
          content: Text(
            'Delete ${entry.title.trim().isEmpty ? entry.type.label.toLowerCase() : '"${entry.title.trim()}"'} permanently from the entry log? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB4573A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      setState(() {
        _isMutatingEntry = true;
        _entryMutationMessage = 'Deleting entry...';
      });
      await FinanceTrackerService.deleteEntry(entry.id);
      if (!mounted) {
        return;
      }

      AppMessage.showInfo(context, '${entry.title} removed.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppMessage.showError(context, error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isMutatingEntry = false;
        });
      }
    }
  }

  Future<void> _openEntryDetails(FinanceEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FinanceEntryDetailsSheet(entry: entry),
    );
  }

  Future<void> _openOverviewDateFilter() async {
    final range = await showOrderDateRangePicker(
      context,
      initialRange: _overviewDateRange,
    );

    if (!mounted || range == null) {
      return;
    }

    setState(() {
      _overviewDateRange = DateTimeRange(
        start: DateUtils.dateOnly(range.start),
        end: DateUtils.dateOnly(range.end),
      );
    });
  }

  List<FinanceEntry> _applyOverviewDateFilter(List<FinanceEntry> entries) {
    final range = _overviewDateRange;
    if (range == null) {
      return _sortEntriesForDisplay(entries);
    }

    final start = DateUtils.dateOnly(range.start);
    final end = DateUtils.dateOnly(range.end);

    final filteredEntries = entries.where((entry) {
      final occurredOn = DateUtils.dateOnly(entry.occurredOn);
      return !occurredOn.isBefore(start) && !occurredOn.isAfter(end);
    }).toList(growable: false);

    return _sortEntriesForDisplay(filteredEntries);
  }

  String _formatSelectedRange(DateTimeRange range) {
    final start = range.start;
    final end = range.end;
    if (DateUtils.isSameDay(start, end)) {
      return 'Showing ${_formatShortDate(start)}';
    }

    return 'Showing ${_formatShortDate(start)} - ${_formatShortDate(end)}';
  }

  String _formatShortDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  FinanceEntryType? get _preferredType {
    switch (widget.initialTabIndex) {
      case 1:
        return FinanceEntryType.expense;
      case 2:
        return FinanceEntryType.salary;
      case 3:
        return FinanceEntryType.credit;
      case 4:
        return FinanceEntryType.balance;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _tabConfig(widget.initialTabIndex);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: _surface,
          body: SafeArea(
            child: Builder(
              builder: (context) {
            if (_isInitialLoading && _snapshot == null) {
              return const DesignLoaderView(label: 'Loading finance workspace...');
            }

            if (_loadError != null && _snapshot == null) {
              return _FinanceErrorView(
                message: _loadError.toString(),
                onRetry: _refreshEntries,
              );
            }

            final financeSnapshot =
                _snapshot ?? const FinanceTrackerSnapshot(entries: []);
            final entries = _entriesForCurrentTab(financeSnapshot);
            final overviewEntries = _applyOverviewDateFilter(entries);
            final heroExpenseTotal = widget.initialTabIndex == 1
              ? _totalFor(entries)
              : financeSnapshot.expenseTotal;
            final heroSalaryTotal = widget.initialTabIndex == 2
              ? _totalFor(entries)
              : financeSnapshot.salaryTotal;
            final heroCreditTotal = widget.initialTabIndex == 3
              ? _totalFor(entries)
              : financeSnapshot.creditTotal;
            final heroEntryCount = widget.initialTabIndex == 0
              ? financeSnapshot.entries.length
              : entries.length;

            return RefreshIndicator(
              onRefresh: () => _refreshEntries(forceRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 124),
                children: [
                  _FinanceTopBar(config: config),
                  const SizedBox(height: 22),
                  _HeroPanel(
                    config: config,
                    currentBalance: financeSnapshot.currentBalance,
                    expenseTotal: heroExpenseTotal,
                    salaryTotal: heroSalaryTotal,
                    creditTotal: heroCreditTotal,
                    balanceAdjustments: financeSnapshot.balanceAdjustments,
                    entryCount: heroEntryCount,
                  ),
                  const SizedBox(height: 18),
                  if (widget.initialTabIndex == 0) ...[
                    _OverviewMetricGrid(snapshot: financeSnapshot),
                    const SizedBox(height: 26),
                    _SectionHeading(
                      title: 'Transaction history',
                      subtitle: 'Review finance entries across every tracker with a date filter.',
                    ),
                    const SizedBox(height: 14),
                    _OverviewFilterRow(
                      hasActiveFilter: _overviewDateRange != null,
                      label: _overviewDateRange == null
                          ? 'Filter by date range'
                          : _formatSelectedRange(_overviewDateRange!),
                      onFilterTap: _openOverviewDateFilter,
                      onClearTap: _overviewDateRange == null
                          ? null
                          : () {
                              setState(() {
                                _overviewDateRange = null;
                              });
                            },
                    ),
                    const SizedBox(height: 14),
                    if (overviewEntries.isEmpty)
                      _EmptyFinanceState(
                        title: _overviewDateRange == null
                            ? 'No entries yet'
                            : 'No transactions in this range',
                        subtitle: _overviewDateRange == null
                            ? 'Start with an expense, salary payment, credit record, or balance adjustment.'
                            : 'Try another date range to see matching finance entries.',
                      )
                    else
                      ...overviewEntries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _FinanceEntryTile(
                            entry: entry,
                            onTap: () => _openEntryDetails(entry),
                            onEdit: _canManageFinanceEntries
                                ? () => _openEntrySheet(existingEntry: entry)
                                : null,
                            onDelete: _canManageFinanceEntries
                                ? () => _deleteEntry(entry)
                                : null,
                          ),
                        ),
                      ),
                  ] else if (widget.initialTabIndex == 4) ...[
                    _BalanceInsightCard(snapshot: financeSnapshot),
                    const SizedBox(height: 26),
                    _SectionHeading(
                      title: 'Balance adjustments',
                      subtitle:
                          'Track manual openings, corrections, and cash alignment entries.',
                    ),
                    const SizedBox(height: 14),
                    if (entries.isEmpty)
                      const _EmptyFinanceState(
                        title: 'No balance adjustments',
                        subtitle:
                            'Add opening balance or correction entries to keep your running total honest.',
                      )
                    else
                      ...entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _FinanceEntryTile(
                            entry: entry,
                            onTap: () => _openEntryDetails(entry),
                            onEdit: _canManageFinanceEntries
                                ? () => _openEntrySheet(existingEntry: entry)
                                : null,
                            onDelete: _canManageFinanceEntries
                                ? () => _deleteEntry(entry)
                                : null,
                          ),
                        ),
                      ),
                  ] else ...[
                    _TypeSummaryStrip(
                      type: _preferredType!,
                      entries: entries,
                      totalAmount: _totalFor(entries),
                    ),
                    const SizedBox(height: 26),
                    _SectionHeading(
                      title: config.listTitle,
                      subtitle: config.listSubtitle,
                    ),
                    const SizedBox(height: 14),
                    if (entries.isEmpty)
                      _EmptyFinanceState(
                        title: 'No ${config.title.toLowerCase()} entries',
                        subtitle: config.emptySubtitle,
                      )
                    else
                      ...entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _FinanceEntryTile(
                            entry: entry,
                            onTap: () => _openEntryDetails(entry),
                            onEdit: _canManageFinanceEntries
                                ? () => _openEntrySheet(existingEntry: entry)
                                : null,
                            onDelete: _canManageFinanceEntries
                                ? () => _deleteEntry(entry)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            );
              },
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _isMutatingEntry ? null : _openEntrySheet,
            backgroundColor: config.accent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: Text(config.addActionLabel),
          ),
          bottomNavigationBar: AppBottomNav(currentIndex: widget.initialTabIndex),
        ),
        if (_isMutatingEntry)
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: const Color(0x66000000),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _entryMutationMessage,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF19352C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_isRefreshing)
          const Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Colors.white,
                child: DesignLoaderView(
                  label: 'Refreshing finance workspace...',
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<FinanceEntry> _entriesForCurrentTab(FinanceTrackerSnapshot snapshot) {
    final entries = snapshot.entries;
    if (widget.initialTabIndex == 0) {
      return _sortEntriesForDisplay(entries);
    }

    if (_preferredType == null) {
      return _sortEntriesForDisplay(entries);
    }

    final filteredEntries = entries
        .where((entry) => entry.type == _preferredType)
        .toList(growable: false);

    return _sortEntriesForDisplay(filteredEntries);
  }

  double _totalFor(List<FinanceEntry> entries) {
    return entries.fold<double>(0, (sum, entry) => sum + entry.amount);
  }

  List<FinanceEntry> _sortEntriesForDisplay(List<FinanceEntry> entries) {
    final sortedEntries = List<FinanceEntry>.from(entries)
      ..sort((left, right) {
        final occurredComparison = DateUtils.dateOnly(
          right.occurredOn,
        ).compareTo(DateUtils.dateOnly(left.occurredOn));
        if (occurredComparison != 0) {
          return occurredComparison;
        }

        final createdComparison = right.createdAt.compareTo(left.createdAt);
        if (createdComparison != 0) {
          return createdComparison;
        }

        final leftNumericId = int.tryParse(left.id);
        final rightNumericId = int.tryParse(right.id);
        if (leftNumericId != null && rightNumericId != null) {
          return rightNumericId.compareTo(leftNumericId);
        }

        return right.id.compareTo(left.id);
      });

    return sortedEntries;
  }

  _FinanceTabConfig _tabConfig(int index) {
    switch (index) {
      case 1:
        return const _FinanceTabConfig(
          title: 'Expenses',
          subtitle: 'Capture spending in one place with clean daily records.',
          heroLabel: 'Expense total',
          listTitle: 'Expense entries',
          listSubtitle: 'Every outgoing entry is listed newest first.',
          emptySubtitle: 'Add bills, transport, supplies, or any outgoing cost.',
          addActionLabel: 'Add Expense',
          icon: Icons.payments_outlined,
          accent: _expense,
        );
      case 2:
        return const _FinanceTabConfig(
          title: 'Salary',
          subtitle: 'Record owner payouts, staff payroll, or regular income.',
          heroLabel: 'Salary total',
          listTitle: 'Salary records',
          listSubtitle: 'Keep payroll and recurring income entries organized.',
          emptySubtitle: 'Add salary payments to track how much has been paid in.',
          addActionLabel: 'Add Salary',
          icon: Icons.work_history_outlined,
          accent: _salary,
        );
      case 3:
        return const _FinanceTabConfig(
          title: 'Credit',
          subtitle: 'Log borrowed money, due collections, or credit received.',
          heroLabel: 'Credit total',
          listTitle: 'Credit records',
          listSubtitle: 'See all credit inflows and follow-ups in one feed.',
          emptySubtitle: 'Add customer credit, borrowed amounts, or due receipts.',
          addActionLabel: 'Add Credit',
          icon: Icons.credit_card_outlined,
          accent: _credit,
        );
      case 4:
        return const _FinanceTabConfig(
          title: 'Balance',
          subtitle: 'Monitor your running balance and review manual adjustments separately.',
          heroLabel: 'Current balance',
          listTitle: 'Balance adjustments',
          listSubtitle: 'Manual openings, resets, and corrections are tracked here.',
          emptySubtitle: 'Add an opening or correction amount to record a manual adjustment.',
          addActionLabel: 'Adjust Balance',
          icon: Icons.account_balance_wallet_outlined,
          accent: _balance,
        );
      default:
        return const _FinanceTabConfig(
          title: 'Overview',
          subtitle: 'A compact finance workspace for daily cash flow control.',
          heroLabel: 'Current balance',
          listTitle: 'Recent activity',
          listSubtitle: 'Your latest finance entries across every tracker.',
          emptySubtitle: 'Add your first entry to start building a running ledger.',
          addActionLabel: 'Add Entry',
          icon: Icons.grid_view_rounded,
          accent: Color(0xFF19352C),
        );
    }
  }
}

class _FinanceTabConfig {
  const _FinanceTabConfig({
    required this.title,
    required this.subtitle,
    required this.heroLabel,
    required this.listTitle,
    required this.listSubtitle,
    required this.emptySubtitle,
    required this.addActionLabel,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String heroLabel;
  final String listTitle;
  final String listSubtitle;
  final String emptySubtitle;
  final String addActionLabel;
  final IconData icon;
  final Color accent;
}

class _FinanceTopBar extends StatelessWidget {
  const _FinanceTopBar({required this.config});

  final _FinanceTabConfig config;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF19352C),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(config.icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expense Workspace',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF19352C),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                config.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5E655F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.config,
    required this.currentBalance,
    required this.expenseTotal,
    required this.salaryTotal,
    required this.creditTotal,
    required this.balanceAdjustments,
    required this.entryCount,
  });

  final _FinanceTabConfig config;
  final double currentBalance;
  final double expenseTotal;
  final double salaryTotal;
  final double creditTotal;
  final double balanceAdjustments;
  final int entryCount;

  @override
  Widget build(BuildContext context) {
    final heroValue = switch (config.title) {
      'Expenses' => expenseTotal,
      'Salary' => salaryTotal,
      'Credit' => creditTotal,
      'Balance' => currentBalance,
      _ => currentBalance,
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [config.accent, const Color(0xFF19352C)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              config.heroLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            FinanceCurrencyFormatter.formatAmount(heroValue, includeCode: true),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            config.subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'Entries',
                  value: '$entryCount',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStat(
                  label: 'Net flow',
                  value: FinanceCurrencyFormatter.formatAmount(
                    creditTotal - expenseTotal - salaryTotal,
                    includeCode: true,
                  ),
                ),
              ),
            ],
          ),
          if (balanceAdjustments != 0) ...[
            const SizedBox(height: 10),
            _HeroStat(
              label: 'Manual adjustments',
              value: FinanceCurrencyFormatter.formatAmount(
                balanceAdjustments,
                includeCode: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.76),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewMetricGrid extends StatelessWidget {
  const _OverviewMetricGrid({required this.snapshot});

  final FinanceTrackerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Expenses',
                value: FinanceCurrencyFormatter.formatAmount(snapshot.expenseTotal),
                accent: const Color(0xFFB4573A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Salary',
                value: FinanceCurrencyFormatter.formatAmount(snapshot.salaryTotal),
                accent: const Color(0xFF2D7A59),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Credit',
                value: FinanceCurrencyFormatter.formatAmount(snapshot.creditTotal),
                accent: const Color(0xFF4E6F9D),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Balance',
                value: FinanceCurrencyFormatter.formatAmount(snapshot.currentBalance),
                accent: const Color(0xFF19352C),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD6D1C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5E655F),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF1D211F),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFF1D211F),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF5E655F),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _OverviewFilterRow extends StatelessWidget {
  const _OverviewFilterRow({
    required this.hasActiveFilter,
    required this.label,
    required this.onFilterTap,
    required this.onClearTap,
  });

  final bool hasActiveFilter;
  final String label;
  final VoidCallback onFilterTap;
  final VoidCallback? onClearTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: onFilterTap,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF19352C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.calendar_month_rounded),
          label: const Text('Filter'),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD6D1C7)),
          ),
          child: Row(
            children: [
              Icon(
                hasActiveFilter
                    ? Icons.event_available_rounded
                    : Icons.event_note_rounded,
                color: const Color(0xFF5E655F),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF1D211F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (hasActiveFilter && onClearTap != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onClearTap,
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF5E655F),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TypeSummaryStrip extends StatelessWidget {
  const _TypeSummaryStrip({
    required this.type,
    required this.entries,
    required this.totalAmount,
  });

  final FinanceEntryType type;
  final List<FinanceEntry> entries;
  final double totalAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD6D1C7)),
      ),
      child: Column(
        children: [
          _StripSummaryRow(
            label: 'Entries',
            value: '${entries.length}',
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE3DDD1)),
          const SizedBox(height: 12),
          _StripSummaryRow(
            label: 'Total',
            value: FinanceCurrencyFormatter.formatAmount(totalAmount),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE3DDD1)),
          const SizedBox(height: 12),
          _StripSummaryRow(
            label: 'Type',
            value: type.label,
          ),
        ],
      ),
    );
  }
}

class _StripSummaryRow extends StatelessWidget {
  const _StripSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5E655F),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF1D211F),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceInsightCard extends StatelessWidget {
  const _BalanceInsightCard({required this.snapshot});

  final FinanceTrackerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final inflow = snapshot.creditTotal;
    final outflow = snapshot.expenseTotal + snapshot.salaryTotal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD6D1C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance formula',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF1D211F),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current balance = credit + manual adjustments - expenses - salary',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5E655F),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Inflow',
                  value: FinanceCurrencyFormatter.formatAmount(inflow),
                  accent: const Color(0xFF2D7A59),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Outflow',
                  value: FinanceCurrencyFormatter.formatAmount(outflow),
                  accent: const Color(0xFFB4573A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceEntryTile extends StatelessWidget {
  const _FinanceEntryTile({
    required this.entry,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final FinanceEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(entry.type);
    final isExpense = entry.type == FinanceEntryType.expense;
    final formattedAmount = isExpense
        ? '-${FinanceCurrencyFormatter.formatStoredEntryAmount(entry)}'
        : FinanceCurrencyFormatter.formatStoredEntryAmount(entry);
    final hasActions = onEdit != null || onDelete != null;
    final metadataText = _metadataText(entry);
    final title = _displayTitle(entry);
    final showTitle = title.trim().isNotEmpty &&
        title.trim().toLowerCase() != '${entry.type.label} entry'.toLowerCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: palette.background,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      palette.icon,
                      color: palette.foreground,
                      size: 34,
                    ),
                  ),
                  if (hasActions) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onEdit != null)
                          _EntryActionButton(
                            icon: Icons.edit_outlined,
                            onPressed: onEdit!,
                          ),
                        if (onDelete != null) ...[
                          if (onEdit != null) const SizedBox(width: 6),
                          _EntryActionButton(
                            icon: Icons.delete_outline_rounded,
                            onPressed: onDelete!,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedAmount,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: isExpense
                            ? const Color(0xFFB4573A)
                            : palette.foreground,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      metadataText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF5E655F),
                        fontWeight: FontWeight.w700,
                        height: 1.28,
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.touch_app_outlined,
                            size: 15,
                            color: Color(0xFF8A8F88),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Tap to view full details',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF8A8F88),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (showTitle) ...[
                      const SizedBox(height: 6),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF1D211F),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _metadataText(FinanceEntry entry) {
    final labels = <String>[entry.type.label, _formatDate(entry.occurredOn), entry.currencyCode];
    if (entry.type == FinanceEntryType.salary && entry.employeeName.trim().isNotEmpty) {
      labels.insert(1, _employeeNameSummary(entry.employeeName));
    }

    return labels.where((label) => label.trim().isNotEmpty).join(' • ');
  }

  String _displayTitle(FinanceEntry entry) {
    final title = entry.title.trim();
    if (title.isNotEmpty) {
      return title;
    }

    if (entry.type == FinanceEntryType.salary &&
        entry.employeeName.trim().isNotEmpty) {
      return _employeeNameSummary(entry.employeeName);
    }

    return '${entry.type.label} entry';
  }

  static String _employeeNameSummary(String rawEmployeeNames) {
    return rawEmployeeNames
        .split(RegExp(r'\r?\n|,'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(', ');
  }

  static _FinancePalette _paletteFor(FinanceEntryType type) {
    switch (type) {
      case FinanceEntryType.expense:
        return const _FinancePalette(
          icon: Icons.arrow_upward_rounded,
          background: Color(0xFFF7E7E1),
          foreground: Color(0xFFB4573A),
        );
      case FinanceEntryType.salary:
        return const _FinancePalette(
          icon: Icons.wallet_rounded,
          background: Color(0xFFE4F1EA),
          foreground: Color(0xFF2D7A59),
        );
      case FinanceEntryType.credit:
        return const _FinancePalette(
          icon: Icons.credit_card_rounded,
          background: Color(0xFFE4EBF5),
          foreground: Color(0xFF4E6F9D),
        );
      case FinanceEntryType.balance:
        return const _FinancePalette(
          icon: Icons.balance_rounded,
          background: Color(0xFFEEE7F5),
          foreground: Color(0xFF7B5A9B),
        );
    }
  }

  static String _formatDate(DateTime value) {
    final monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${monthNames[value.month - 1]} ${value.day}, ${value.year}';
  }
}

class _FinanceEntryDetailsSheet extends StatelessWidget {
  const _FinanceEntryDetailsSheet({required this.entry});

  final FinanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = _FinanceEntryTile._paletteFor(entry.type);
    final isExpense = entry.type == FinanceEntryType.expense;
    final amountText = isExpense
        ? '-${FinanceCurrencyFormatter.formatStoredEntryAmount(entry)}'
        : FinanceCurrencyFormatter.formatStoredEntryAmount(entry);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final topSpacing = mediaQuery.padding.top + 28;
    final availableHeight =
        mediaQuery.size.height - topSpacing - bottomInset - 12;
    final preferredMaxHeight = mediaQuery.size.height * 0.80;
    final maxSheetHeight = availableHeight < preferredMaxHeight
        ? availableHeight
        : preferredMaxHeight;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        topSpacing,
        12,
        bottomInset + 12,
      ),
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxSheetHeight.clamp(260.0, double.infinity),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F6F2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1CBC2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: palette.background,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          palette.icon,
                          color: palette.foreground,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _entryTitle(entry),
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: const Color(0xFF19352C),
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.type.label,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF5E655F),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFD6D1C7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF5E655F),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          amountText,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: isExpense
                                ? const Color(0xFFB4573A)
                                : palette.foreground,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _EntryDetailRow(
                    label: 'Created by',
                    value: _creatorLabel(entry),
                  ),
                  _EntryDetailRow(
                    label: 'Account email',
                    value: _fallbackValue(entry.accountEmail),
                  ),
                  _EntryDetailRow(
                    label: 'Entry date',
                    value: _FinanceEntryTile._formatDate(entry.occurredOn),
                  ),
                  _EntryDetailRow(
                    label: 'Saved on',
                    value: _formatDateTime(entry.createdAt),
                  ),
                  _EntryDetailRow(
                    label: 'Currency',
                    value: _fallbackValue(entry.currencyCode),
                  ),
                  if (entry.employeeName.trim().isNotEmpty)
                    _EntryDetailRow(
                      label: entry.employeeName.contains('\n') ? 'Employees' : 'Employee',
                      value: entry.employeeName.trim(),
                    ),
                  if (entry.employeeBreakdown.trim().isNotEmpty)
                    _EntryDetailRow(
                      label: 'Salary breakdown',
                      value: entry.employeeBreakdown.trim(),
                    ),
                  _EntryDetailRow(
                    label: 'Entry ID',
                    value: _fallbackValue(entry.id),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Note',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF19352C),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD6D1C7)),
                    ),
                    child: Text(
                      entry.note.trim().isEmpty
                          ? 'No note added for this entry.'
                          : entry.note.trim(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF4E5650),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF19352C),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _entryTitle(FinanceEntry entry) {
    final title = entry.title.trim();
    if (title.isNotEmpty) {
      return title;
    }

    if (entry.type == FinanceEntryType.salary &&
        entry.employeeName.trim().isNotEmpty) {
      return _FinanceEntryTile._employeeNameSummary(entry.employeeName);
    }

    return '${entry.type.label} entry';
  }

  static String _creatorLabel(FinanceEntry entry) {
    final accountName = entry.accountName.trim();
    if (accountName.isNotEmpty) {
      return accountName;
    }

    final accountEmail = entry.accountEmail.trim();
    if (accountEmail.isNotEmpty) {
      return accountEmail;
    }

    return 'Unknown account';
  }

  static String _fallbackValue(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? 'Not available' : normalized;
  }

  static String _formatDateTime(DateTime value) {
    final date = _FinanceEntryTile._formatDate(value);
    final hour = value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$date, $hour:$minute $period';
  }
}

class _EntryDetailRow extends StatelessWidget {
  const _EntryDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD6D1C7)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5E655F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF1D211F),
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancePalette {
  const _FinancePalette({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
}

class _EntryActionButton extends StatelessWidget {
  const _EntryActionButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onPressed,
      radius: 20,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, color: const Color(0xFF8A8F88), size: 28),
      ),
    );
  }
}

class _EmptyFinanceState extends StatelessWidget {
  const _EmptyFinanceState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD6D1C7)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFE4EEE9),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.note_alt_outlined,
              color: Color(0xFF19352C),
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF1D211F),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5E655F),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceErrorView extends StatelessWidget {
  const _FinanceErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Color(0xFFB4573A),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFinanceEntrySheet extends StatefulWidget {
  const _AddFinanceEntrySheet({
    required this.initialType,
    required this.lockType,
    required this.employees,
    this.initialEntry,
  });

  final FinanceEntryType initialType;
  final bool lockType;
  final List<EmployeeRecord> employees;
  final FinanceEntry? initialEntry;

  @override
  State<_AddFinanceEntrySheet> createState() => _AddFinanceEntrySheetState();
}

class _AddFinanceEntrySheetState extends State<_AddFinanceEntrySheet> {
  static const Color _primary = Color(0xFF19352C);
  static const Color _surface = Color(0xFFF7F6F2);
  static const Color _surfaceContainer = Color(0xFFF0ECE4);
  static const String _selectExpenseTitle = 'Select title';
  static const String _customExpenseTitle = 'Custom';
  static const List<String> _expenseTitleOptions = [
    'Electronic appliances',
    'Fuel',
    'Kitchen / Washroom goods',
    'Food',
    'Utility equipments',
    'Electric equipment',
    _customExpenseTitle,
  ];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final Map<String, TextEditingController> _salaryAmountControllers = {};

  late FinanceEntryType _selectedType;
  late String _selectedCurrencyCode;
  late String _selectedExpenseTitle;
  List<String> _selectedEmployeeIds = const [];
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initialEntry = widget.initialEntry;
    _selectedType = initialEntry?.type ?? widget.initialType;
    _selectedCurrencyCode = initialEntry?.currencyCode ??
        FinanceCurrencySettingsService.currentCurrency.code;
    _selectedExpenseTitle = initialEntry == null
        ? _selectExpenseTitle
        : _resolveExpenseTitleSelection(initialEntry.title);
    if (initialEntry != null) {
      _titleController.text = initialEntry.title;
      _noteController.text = initialEntry.note;
      _selectedDate = initialEntry.occurredOn;

      if (initialEntry.employeeName.trim().isNotEmpty) {
        _selectedEmployeeIds = _resolveInitialEmployeeIds(
          initialEntry.employeeName,
        );
      }

      _seedSalaryAmountControllers(initialEntry);
      if (_selectedType != FinanceEntryType.salary) {
        _amountController.text = initialEntry.displayAmount.toString();
      }
    } else {
      _syncSalaryAmountControllers();
    }
  }

  @override
  void dispose() {
    for (final controller in _salaryAmountControllers.values) {
      controller.dispose();
    }
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
    });
  }

  List<EmployeeRecord> get _selectedEmployees {
    if (_selectedEmployeeIds.isEmpty) {
      return const [];
    }

    final employeeIds = _selectedEmployeeIds.toSet();
    return widget.employees.where((employee) {
      return employeeIds.contains(employee.id);
    }).toList(growable: false);
  }

  String get _selectedEmployeeLabel {
    final employees = _selectedEmployees;
    if (employees.isEmpty) {
      return 'Select employees';
    }

    if (employees.length == 1) {
      return employees.first.name;
    }

    return '${employees.length} employees selected';
  }

  String get _selectedEmployeeNamesForStorage {
    return _selectedEmployees.map((employee) => employee.name.trim()).join('\n');
  }

  List<String> _resolveInitialEmployeeIds(String rawEmployeeNames) {
    final normalizedNames = rawEmployeeNames
        .split(RegExp(r'\r?\n|,'))
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();

    if (normalizedNames.isEmpty) {
      return const [];
    }

    return widget.employees.where((employee) {
      return normalizedNames.contains(employee.name.trim().toLowerCase());
    }).map((employee) => employee.id).toList(growable: false);
  }

  Map<String, String> _parseSalaryBreakdown(String rawBreakdown) {
    final amountsByName = <String, String>{};
    final rows = rawBreakdown
        .split(RegExp(r'\r?\n'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);

    for (final row in rows) {
      final delimiterIndex = row.lastIndexOf(':');
      if (delimiterIndex <= 0 || delimiterIndex >= row.length - 1) {
        continue;
      }

      final name = row.substring(0, delimiterIndex).trim().toLowerCase();
      final amount = row.substring(delimiterIndex + 1).trim();
      if (name.isEmpty || amount.isEmpty) {
        continue;
      }

      amountsByName[name] = amount;
    }

    return amountsByName;
  }

  String _formatEditableAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.round().toString();
    }

    return amount.toString();
  }

  void _seedSalaryAmountControllers(FinanceEntry initialEntry) {
    final parsedBreakdown = _parseSalaryBreakdown(initialEntry.employeeBreakdown);
    _syncSalaryAmountControllers(
      initialAmountsByName: parsedBreakdown,
      fallbackSingleAmount: parsedBreakdown.isEmpty
          ? initialEntry.displayAmount
          : null,
    );
  }

  void _syncSalaryAmountControllers({
    Map<String, String>? initialAmountsByName,
    double? fallbackSingleAmount,
  }) {
    final selectedIds = _selectedEmployeeIds.toSet();
    final removableIds = _salaryAmountControllers.keys.where((employeeId) {
      return !selectedIds.contains(employeeId);
    }).toList(growable: false);

    for (final employeeId in removableIds) {
      _salaryAmountControllers.remove(employeeId)?.dispose();
    }

    for (final employee in _selectedEmployees) {
      final existingController = _salaryAmountControllers[employee.id];
      if (existingController != null) {
        continue;
      }

      final normalizedName = employee.name.trim().toLowerCase();
      final seededAmount = initialAmountsByName?[normalizedName] ??
          ((fallbackSingleAmount != null && _selectedEmployeeIds.length == 1)
              ? _formatEditableAmount(fallbackSingleAmount)
              : '');
      _salaryAmountControllers[employee.id] = TextEditingController(
        text: seededAmount,
      );
    }
  }

  double _salaryAmountForEmployee(String employeeId) {
    return double.tryParse(
          _salaryAmountControllers[employeeId]?.text.trim() ?? '',
        ) ??
        0;
  }

  double get _salaryTotalAmount {
    return _selectedEmployees.fold<double>(0, (sum, employee) {
      return sum + _salaryAmountForEmployee(employee.id);
    });
  }

  String get _salaryBreakdownForStorage {
    return _selectedEmployees.map((employee) {
      final amount = _salaryAmountForEmployee(employee.id);
      return '${employee.name.trim()}: ${_formatEditableAmount(amount)}';
    }).join('\n');
  }

  Future<void> _pickType() async {
    final selectedType = await showModalBottomSheet<FinanceEntryType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FinanceTypePickerSheet(initialType: _selectedType),
    );

    if (!mounted || selectedType == null || selectedType == _selectedType) {
      return;
    }

    setState(() {
      _selectedType = selectedType;
      if (_selectedType == FinanceEntryType.expense) {
        _syncExpenseTitleController();
      }
      if (_selectedType == FinanceEntryType.salary) {
        _syncSalaryAmountControllers();
      }
    });
  }

  Future<void> _pickExpenseTitle() async {
    final selectedTitle = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExpenseTitlePickerSheet(
        selectedTitle: _selectedExpenseTitle,
        options: _expenseTitleOptions,
      ),
    );

    if (!mounted ||
        selectedTitle == null ||
        selectedTitle == _selectedExpenseTitle) {
      return;
    }

    setState(() {
      _selectedExpenseTitle = selectedTitle;
      _syncExpenseTitleController();
    });
  }

  String _resolveExpenseTitleSelection(String title) {
    final normalizedTitle = title.trim().toLowerCase();
    if (normalizedTitle.isEmpty) {
      return _selectExpenseTitle;
    }

    for (final option in _expenseTitleOptions) {
      if (option == _customExpenseTitle) {
        continue;
      }

      if (option.toLowerCase() == normalizedTitle) {
        return option;
      }
    }

    return _customExpenseTitle;
  }

  void _syncExpenseTitleController() {
    if (_selectedExpenseTitle == _customExpenseTitle ||
        _selectedExpenseTitle == _selectExpenseTitle) {
      return;
    }

    _titleController.text = _selectedExpenseTitle;
  }

  String get _resolvedTitle {
    if (_selectedType == FinanceEntryType.expense &&
        _selectedExpenseTitle != _customExpenseTitle) {
      if (_selectedExpenseTitle == _selectExpenseTitle) {
        return '';
      }

      return _selectedExpenseTitle;
    }

    return _titleController.text.trim();
  }

  Future<void> _pickEmployees() async {
    if (widget.employees.isEmpty) {
      AppMessage.showInfo(
        context,
        'Add employees from Settings before selecting salary entries.',
      );
      return;
    }

    final selectedEmployeeIds = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EmployeeMultiPickerSheet(
        employees: widget.employees,
        initialEmployeeIds: _selectedEmployeeIds,
      ),
    );

    if (!mounted || selectedEmployeeIds == null) {
      return;
    }

    setState(() {
      _selectedEmployeeIds = selectedEmployeeIds;
      _syncSalaryAmountControllers();
    });
  }

  void _save() {
    final title = _resolvedTitle;
    final rawAmount = _amountController.text.trim();
    final isSalary = _selectedType == FinanceEntryType.salary;
    final amount = isSalary
        ? _salaryTotalAmount
        : (double.tryParse(rawAmount) ?? 0);

    if (title.isEmpty) {
      AppMessage.showError(context, 'Enter a title for this entry.');
      return;
    }

    if (!isSalary && (rawAmount.isEmpty || amount == 0)) {
      AppMessage.showError(context, 'Enter a valid amount.');
      return;
    }

    if (_selectedType != FinanceEntryType.balance && amount < 0) {
      AppMessage.showError(context, 'Amount must be positive for this entry type.');
      return;
    }

    if (_selectedType == FinanceEntryType.balance && amount == 0) {
      AppMessage.showError(context, 'Balance adjustment cannot be zero.');
      return;
    }

    if (_selectedType == FinanceEntryType.salary && _selectedEmployees.isEmpty) {
      AppMessage.showError(context, 'Select one or more employees for this salary entry.');
      return;
    }

    if (isSalary) {
      for (final employee in _selectedEmployees) {
        final employeeAmount = _salaryAmountForEmployee(employee.id);
        if (employeeAmount <= 0) {
          AppMessage.showError(
            context,
            'Enter a valid amount for ${employee.name}.',
          );
          return;
        }
      }
    }

    setState(() {
      _isSaving = true;
    });

    Navigator.of(context).pop(
      FinanceEntry(
        id: widget.initialEntry?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        type: _selectedType,
        title: title,
        amount: amount,
        displayAmount: amount,
        currencyCode: _selectedCurrencyCode,
        occurredOn: _selectedDate,
        createdAt: widget.initialEntry?.createdAt ?? DateTime.now(),
        employeeName: _selectedEmployeeNamesForStorage,
        employeeBreakdown: isSalary ? _salaryBreakdownForStorage : '',
        accountName: widget.initialEntry?.accountName ?? '',
        accountEmail: widget.initialEntry?.accountEmail ?? '',
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final topInset = mediaQuery.padding.top + switch (_selectedType) {
      FinanceEntryType.expense => 10.0,
      FinanceEntryType.salary => 5.0,
      _ => 10.0,
    };
    final availableHeight = mediaQuery.size.height - topInset - 12;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, topInset, 12, 12),
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: availableHeight.clamp(320.0, double.infinity),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(30),
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: keyboardInset + 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1CBC2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.initialEntry == null ? 'New entry' : 'Edit entry',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: _primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.initialEntry == null
                        ? 'Track spending, salary, credit, and balance changes in one clean ledger.'
                        : 'Update the saved finance entry details and keep the ledger accurate.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5E655F),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (widget.lockType)
                    _ReadOnlyTypePill(type: _selectedType)
                  else
                    InkWell(
                      onTap: _pickType,
                      borderRadius: BorderRadius.circular(18),
                      child: InputDecorator(
                        decoration: _decoration('Select entry type', label: 'Entry type'),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedType.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF1D211F),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.expand_more_rounded,
                              color: Color(0xFF6A706B),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (_selectedType == FinanceEntryType.salary) ...[
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Employees',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF5E655F),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _pickEmployees,
                        borderRadius: BorderRadius.circular(22),
                        child: Ink(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _surfaceContainer,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _selectedEmployees.isEmpty
                                    ? Text(
                                        widget.employees.isEmpty
                                            ? 'Add employees from Settings'
                                            : 'Select employees',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: const Color(0xFF6A706B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedEmployeeLabel,
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: const Color(0xFF1D211F),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: _selectedEmployees.map((employee) {
                                              return _ExpenseTitleSelectorCard(
                                                title: employee.name,
                                                isSelected: true,
                                              );
                                            }).toList(growable: false),
                                          ),
                                        ],
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFEA),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.group_add_rounded,
                                  color: _primary,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedEmployees.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Salary amounts',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF5E655F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._selectedEmployees.map((employee) {
                      final controller = _salaryAmountControllers[employee.id]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          decoration: BoxDecoration(
                            color: _surfaceContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF1D211F),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: controller,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onChanged: (_) {
                                  setState(() {});
                                },
                                decoration: _decoration(
                                  FinanceCurrencyFormatter.currencyHint(
                                    currencyCode: _selectedCurrencyCode,
                                  ),
                                  label: 'Amount for ${employee.name}',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7EFEA),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFD4C9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total salary amount',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF4A5C54),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            FinanceCurrencyFormatter.formatDisplayAmount(
                              _salaryTotalAmount,
                              currencyCode: _selectedCurrencyCode,
                            ),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: _primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 14),
                if (_selectedType == FinanceEntryType.expense) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Title',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF5E655F),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _isSaving ? null : _pickExpenseTitle,
                        borderRadius: BorderRadius.circular(22),
                        child: Ink(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _surfaceContainer,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _ExpenseTitleSelectorCard(
                                      title: _selectedExpenseTitle,
                                      isSelected: true,
                                    ),
                                    if (_selectedExpenseTitle == _customExpenseTitle &&
                                        _titleController.text.trim().isNotEmpty)
                                      _ExpenseTitleSelectorCard(
                                        title: _titleController.text.trim(),
                                        isSelected: false,
                                        isCustomValue: true,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFEA),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.expand_more_rounded,
                                  color: _primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedExpenseTitle == _customExpenseTitle) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decoration(
                        'Type any other title',
                        label: 'Custom title',
                      ),
                    ),
                  ],
                ] else
                  TextField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoration(
                      _selectedType == FinanceEntryType.salary
                          ? 'Monthly salary'
                          : _selectedType == FinanceEntryType.credit
                              ? 'Borrowed amount'
                              : 'Opening balance',
                      label: 'Title',
                    ),
                  ),
                const SizedBox(height: 14),
                if (_selectedType != FinanceEntryType.salary) ...[
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: _decoration(
                      FinanceCurrencyFormatter.currencyHint(
                        currencyCode: _selectedCurrencyCode,
                      ),
                      label: _selectedType == FinanceEntryType.balance
                          ? 'Amount (use - for deduction)'
                          : 'Amount',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: _primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _FinanceEntryTile._formatDate(_selectedDate),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF1D211F),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: _primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration('Optional note', label: 'Note'),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      widget.initialEntry == null ? 'Save Entry' : 'Update Entry',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  InputDecoration _decoration(String hintText, {String? label}) {
    return InputDecoration(
      labelText: label,
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
}

class _CurrencyPickerSheet extends StatefulWidget {
  const _CurrencyPickerSheet({required this.initialCurrencyCode});

  final String initialCurrencyCode;

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _FinanceTypePickerSheet extends StatelessWidget {
  const _FinanceTypePickerSheet({required this.initialType});

  final FinanceEntryType initialType;

  @override
  Widget build(BuildContext context) {
    return _FinanceChoiceSheet<FinanceEntryType>(
      title: 'Pick entry type',
      description: 'Choose the finance entry category you want to save.',
      items: FinanceEntryType.values,
      isSelected: (type) => type == initialType,
      onSelected: (type) => Navigator.of(context).pop(type),
      titleFor: (type) => type.label,
      subtitleFor: (type) {
        switch (type) {
          case FinanceEntryType.expense:
            return 'Track outgoing money';
          case FinanceEntryType.salary:
            return 'Record employee or owner salary';
          case FinanceEntryType.credit:
            return 'Store credit received or due collection';
          case FinanceEntryType.balance:
            return 'Adjust manual opening or correction';
        }
      },
    );
  }
}

class _ExpenseTitlePickerSheet extends StatelessWidget {
  const _ExpenseTitlePickerSheet({
    required this.selectedTitle,
    required this.options,
  });

  final String selectedTitle;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return _FinanceChoiceSheet<String>(
      title: 'Pick expense title',
      description: 'Choose a small category card for this expense entry.',
      items: options,
      isSelected: (option) => option == selectedTitle,
      onSelected: (option) => Navigator.of(context).pop(option),
      titleFor: (option) => option,
      subtitleFor: (option) {
        switch (option) {
          case 'Electronic appliances':
            return 'Devices, gadgets, and machine items';
          case 'Fuel':
            return 'Petrol, diesel, gas, and travel fuel';
          case 'Kitchen / Washroom goods':
            return 'Cleaning and daily-use room supplies';
          case 'Food':
            return 'Meals, snacks, and refreshment costs';
          case 'Utility equipments':
            return 'Tools and support items for daily operations';
          case 'Electric equipment':
            return 'Wires, bulbs, switches, and power items';
          case 'Custom':
            return 'Type any other title manually';
          default:
            return 'Use this title for the expense entry';
        }
      },
    );
  }
}

class _EmployeeMultiPickerSheet extends StatefulWidget {
  const _EmployeeMultiPickerSheet({
    required this.employees,
    required this.initialEmployeeIds,
  });

  final List<EmployeeRecord> employees;
  final List<String> initialEmployeeIds;

  @override
  State<_EmployeeMultiPickerSheet> createState() => _EmployeeMultiPickerSheetState();
}

class _EmployeeMultiPickerSheetState extends State<_EmployeeMultiPickerSheet> {
  static const Color _surface = Color(0xFFF7F6F2);
  static const Color _surfaceContainer = Color(0xFFF0ECE4);
  static const Color _primary = Color(0xFF19352C);

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  late final Set<String> _selectedEmployeeIds;

  @override
  void initState() {
    super.initState();
    _selectedEmployeeIds = widget.initialEmployeeIds.toSet();
  }

  List<EmployeeRecord> get _filteredEmployees {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return widget.employees;
    }

    return widget.employees.where((employee) {
      return employee.name.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final filteredEmployees = _filteredEmployees;
    final selectedEmployees = widget.employees.where((employee) {
      return _selectedEmployeeIds.contains(employee.id);
    }).toList(growable: false);

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 12),
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1CBC2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Pick employees',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select one or more employees for a single monthly salary log.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5E655F),
                ),
              ),
              if (selectedEmployees.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedEmployees.map((employee) {
                    return _ExpenseTitleSelectorCard(
                      title: employee.name,
                      isSelected: true,
                    );
                  }).toList(growable: false),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search employee',
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
                    borderSide: const BorderSide(color: _primary, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: filteredEmployees.isEmpty
                    ? Center(
                        child: Text(
                          'No employee found.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5E655F),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredEmployees.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final employee = filteredEmployees[index];
                          final isSelected = _selectedEmployeeIds.contains(employee.id);

                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedEmployeeIds.remove(employee.id);
                                } else {
                                  _selectedEmployeeIds.add(employee.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFE7EFEA)
                                    : _surfaceContainer,
                                borderRadius: BorderRadius.circular(18),
                                border: isSelected
                                    ? Border.all(color: _primary, width: 1.2)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          employee.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                color: const Color(0xFF1D211F),
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        if (isSelected)
                                          Text(
                                            'Included in this salary log',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: const Color(0xFF5E655F),
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.chevron_right_rounded,
                                    color: isSelected
                                        ? _primary
                                        : const Color(0xFF6A706B),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selectedEmployees.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                            selectedEmployees
                                .map((employee) => employee.id)
                                .toList(growable: false),
                          ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    selectedEmployees.isEmpty
                        ? 'Select employee'
                        : 'Add ${selectedEmployees.length} employee${selectedEmployees.length == 1 ? '' : 's'}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceChoiceSheet<T> extends StatelessWidget {
  const _FinanceChoiceSheet({
    required this.title,
    required this.description,
    required this.items,
    required this.isSelected,
    required this.onSelected,
    required this.titleFor,
    required this.subtitleFor,
  });

  final String title;
  final String description;
  final List<T> items;
  final bool Function(T item) isSelected;
  final void Function(T item) onSelected;
  final String Function(T item) titleFor;
  final String Function(T item) subtitleFor;

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFFF7F6F2);
    const surfaceContainer = Color(0xFFF0ECE4);
    const primary = Color(0xFF19352C);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomInset + 12),
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1CBC2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5E655F),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];

                    return InkWell(
                      onTap: () => onSelected(item),
                      borderRadius: BorderRadius.circular(18),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected(item)
                              ? const Color(0xFFE7EFEA)
                              : surfaceContainer,
                          borderRadius: BorderRadius.circular(18),
                          border: isSelected(item)
                              ? Border.all(color: primary, width: 1.2)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titleFor(item),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: const Color(0xFF1D211F),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitleFor(item),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: const Color(0xFF5E655F),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              isSelected(item)
                                  ? Icons.check_circle_rounded
                                  : Icons.chevron_right_rounded,
                              color: isSelected(item)
                                  ? primary
                                  : const Color(0xFF6A706B),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseTitleSelectorCard extends StatelessWidget {
  const _ExpenseTitleSelectorCard({
    required this.title,
    required this.isSelected,
    this.isCustomValue = false,
  });

  final String title;
  final bool isSelected;
  final bool isCustomValue;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected
        ? const Color(0xFFE7EFEA)
        : const Color(0xFFF6F1E8);
    final borderColor = isSelected
        ? const Color(0xFF19352C)
        : const Color(0xFFD7CEC1);
    final textColor = isSelected
        ? const Color(0xFF19352C)
        : const Color(0xFF5E655F);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCustomValue ? Icons.edit_rounded : Icons.sell_outlined,
            size: 16,
            color: textColor,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  static const Color _surface = Color(0xFFF7F6F2);
  static const Color _surfaceContainer = Color(0xFFF0ECE4);
  static const Color _primary = Color(0xFF19352C);

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<CurrencyOption> get _filteredOptions {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return CurrencySettingsService.options;
    }

    return CurrencySettingsService.options.where((option) {
      return option.code.toLowerCase().contains(normalizedQuery) ||
          option.name.toLowerCase().contains(normalizedQuery) ||
          option.symbol.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final filteredOptions = _filteredOptions;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 12),
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1CBC2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Pick currency',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search by currency name, code, or symbol.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5E655F),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search currency',
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
                    borderSide: const BorderSide(color: _primary, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: filteredOptions.isEmpty
                    ? Center(
                        child: Text(
                          'No currency found.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5E655F),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredOptions.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final option = filteredOptions[index];
                          final isSelected =
                              option.code == widget.initialCurrencyCode;

                          return InkWell(
                            onTap: () => Navigator.of(context).pop(option.code),
                            borderRadius: BorderRadius.circular(18),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFE7EFEA)
                                    : _surfaceContainer,
                                borderRadius: BorderRadius.circular(18),
                                border: isSelected
                                    ? Border.all(color: _primary, width: 1.2)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: const Color(0xFF1D211F),
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          option.symbol.isEmpty
                                              ? option.code
                                              : '${option.code}  ${option.symbol}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: const Color(0xFF5E655F),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.chevron_right_rounded,
                                    color: isSelected
                                        ? _primary
                                        : const Color(0xFF6A706B),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyTypePill extends StatelessWidget {
  const _ReadOnlyTypePill({required this.type});

  final FinanceEntryType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECE4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        type.label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: const Color(0xFF1D211F),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
