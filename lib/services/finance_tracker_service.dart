import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/finance_entry.dart';
import 'google_sheet_service.dart';
import 'session_service.dart';

class FinanceTrackerSnapshot {
  const FinanceTrackerSnapshot({required this.entries});

  final List<FinanceEntry> entries;

  double get expenseTotal => _totalFor(FinanceEntryType.expense);
  double get salaryTotal => _totalFor(FinanceEntryType.salary);
  double get creditTotal => _totalFor(FinanceEntryType.credit);
  double get balanceAdjustments => _totalFor(FinanceEntryType.balance);

  double get currentBalance {
    return creditTotal + balanceAdjustments - expenseTotal - salaryTotal;
  }

  List<FinanceEntry> entriesFor(FinanceEntryType type) {
    return entries.where((entry) => entry.type == type).toList(growable: false);
  }

  double _totalFor(FinanceEntryType type) {
    return entries
        .where((entry) => entry.type == type)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
  }
}

class FinanceTrackerService {
  FinanceTrackerService._();

  static const String _entriesKey = 'finance_tracker_entries_v1';
  static final ValueNotifier<int> _changeCounter = ValueNotifier<int>(0);
  static List<FinanceEntry>? _entriesCache;
  static Future<List<FinanceEntry>>? _syncFuture;
  static bool _startupSyncPrimed = false;
  static String? _lastSyncErrorMessage;

  static ValueListenable<int> get changes => _changeCounter;
  static String? get lastSyncErrorMessage => _lastSyncErrorMessage;

  static Future<void> preloadStartupData({bool waitForRemote = false}) async {
    await _ensureLocalCacheLoaded();

    if (_startupSyncPrimed && !waitForRemote) {
      return;
    }

    final syncFuture = syncFromServer();
    if (waitForRemote) {
      await syncFuture;
      _startupSyncPrimed = true;
      return;
    }

    unawaited(syncFuture);
  }

  static Future<FinanceTrackerSnapshot> loadSnapshot({
    bool forceRefresh = false,
  }) async {
    final entries = await loadEntries(forceRefresh: forceRefresh);
    return FinanceTrackerSnapshot(entries: entries);
  }

  static Future<List<FinanceEntry>> loadEntries({bool forceRefresh = false}) async {
    await _ensureLocalCacheLoaded();

    if (forceRefresh) {
      return syncFromServer();
    }

    return List<FinanceEntry>.from(_entriesCache ?? const []);
  }

  static Future<List<FinanceEntry>> syncFromServer() async {
    final inFlightSync = _syncFuture;
    if (inFlightSync != null) {
      return inFlightSync;
    }

    final future = () async {
      try {
        final entries = await GoogleSheetService.instance.fetchFinanceEntries();
        await _saveEntries(entries);
        final sortedEntries = _sortEntries(entries);
        _entriesCache = sortedEntries;
        _lastSyncErrorMessage = null;
        _changeCounter.value++;
        return sortedEntries;
      } catch (error) {
        final localEntries = await _loadLocalEntries();
        _entriesCache = localEntries;
        _lastSyncErrorMessage = error.toString();
        _changeCounter.value++;
        return localEntries;
      } finally {
        _syncFuture = null;
      }
    }();

    _syncFuture = future;
    return future;
  }

  static Future<void> clearLocalCache() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_entriesKey);
    _entriesCache = null;
    _startupSyncPrimed = false;
    _changeCounter.value++;
  }

  static Future<void> upsertEntry(
    FinanceEntry entry, {
    bool isEditing = false,
  }) async {
    final accountEmail = await SessionService.getUserEmail();
    final accountName = await SessionService.getUserFullName();
    if (accountEmail == null || accountEmail.trim().isEmpty) {
      throw Exception('Signed-in account was not found. Please log in again.');
    }

    if (isEditing) {
      final canManageFinanceEntries =
          await SessionService.getCanManageFinanceEntries();
      if (!canManageFinanceEntries) {
        throw Exception(
          'This account is not allowed to edit finance entries.',
        );
      }
    }

    final preservedAccountEmail = entry.accountEmail.trim();
    final preservedAccountName = entry.accountName.trim();

    final normalizedEntry = entry.copyWith(
      accountEmail: preservedAccountEmail.isNotEmpty
          ? preservedAccountEmail
          : accountEmail.trim(),
      accountName: preservedAccountName.isNotEmpty
          ? preservedAccountName
          : accountName?.trim() ?? '',
    );
    await GoogleSheetService.instance.upsertFinanceEntry(entry: normalizedEntry);

    final entries = await _loadLocalEntries();
    final existingIndex = entries.indexWhere((item) => item.id == entry.id);
    if (existingIndex >= 0) {
      entries[existingIndex] = normalizedEntry;
    } else {
      entries.add(normalizedEntry);
    }

    await _saveEntries(entries);
    _entriesCache = _sortEntries(entries);
    _changeCounter.value++;
  }

  static Future<void> deleteEntry(String id) async {
    final accountEmail = await SessionService.getUserEmail();
    if (accountEmail == null || accountEmail.trim().isEmpty) {
      throw Exception('Signed-in account was not found. Please log in again.');
    }

    final canManageFinanceEntries =
        await SessionService.getCanManageFinanceEntries();
    if (!canManageFinanceEntries) {
      throw Exception('This account is not allowed to delete finance entries.');
    }

    await GoogleSheetService.instance.deleteFinanceEntry(
      accountEmail: accountEmail,
      entryId: id,
    );

    final entries = await _loadLocalEntries();
    entries.removeWhere((entry) => entry.id == id);
    await _saveEntries(entries);
    _entriesCache = _sortEntries(entries);
    _changeCounter.value++;
  }

  static Future<void> _ensureLocalCacheLoaded() async {
    if (_entriesCache != null) {
      return;
    }

    _entriesCache = await _loadLocalEntries();
  }

  static Future<List<FinanceEntry>> _loadLocalEntries() async {
    final preferences = await SharedPreferences.getInstance();
    final encodedEntries = preferences.getStringList(_entriesKey) ?? const [];
    final entries = encodedEntries
        .map((value) => _decodeEntry(value))
        .whereType<FinanceEntry>()
        .toList();

    return _sortEntries(entries);
  }

  static List<FinanceEntry> _sortEntries(List<FinanceEntry> entries) {
    final sortedEntries = List<FinanceEntry>.from(entries)
      ..sort(_compareEntriesForDisplay);

    return sortedEntries;
  }

  static int _compareEntriesForDisplay(FinanceEntry left, FinanceEntry right) {
    final leftOccurredOn = DateTime(
      left.occurredOn.year,
      left.occurredOn.month,
      left.occurredOn.day,
    );
    final rightOccurredOn = DateTime(
      right.occurredOn.year,
      right.occurredOn.month,
      right.occurredOn.day,
    );
    final occurredComparison = rightOccurredOn.compareTo(leftOccurredOn);
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
  }

  static Future<void> _saveEntries(List<FinanceEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _entriesKey,
      _sortEntries(entries).map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }

  static FinanceEntry? _decodeEntry(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return FinanceEntry.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}


