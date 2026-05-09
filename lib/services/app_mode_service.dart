import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_profile.dart';

enum AppMode { stockManager, expenseTracker }

extension AppModePresentation on AppMode {
  String get title {
    switch (this) {
      case AppMode.stockManager:
        return 'Stock Manager';
      case AppMode.expenseTracker:
        return 'Expense Tracker';
    }
  }

  String get summary {
    switch (this) {
      case AppMode.stockManager:
        return 'Inventory, sales, orders, and stock operations';
      case AppMode.expenseTracker:
        return 'Expenses, salary, credit, and running balance entries';
    }
  }
}

class AppModeService {
  AppModeService._();

  static const String _preferenceKey = 'app_workspace_mode';
  static final ValueNotifier<AppMode> changes = ValueNotifier<AppMode>(
    AppMode.stockManager,
  );

  static AppMode _currentMode = AppMode.stockManager;

  static AppMode get currentMode => _currentMode;

  static bool get isExpenseTracker => _currentMode == AppMode.expenseTracker;

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _currentMode = _modeFromStorage(
      preferences.getString(_preferenceKey) ?? AppMode.stockManager.name,
    );
    changes.value = _currentMode;
  }

  static Future<AppMode> getMode() async {
    if (changes.value != _currentMode) {
      _currentMode = changes.value;
    }

    return _currentMode;
  }

  static Future<void> setMode(AppMode mode) async {
    if (_currentMode == mode && changes.value == mode) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, mode.name);
    _currentMode = mode;
    changes.value = mode;
  }

  static AppMode resolvedModeForAccess(
    AccountWorkspaceAccess access,
    AppMode preferredMode,
  ) {
    switch (access) {
      case AccountWorkspaceAccess.stocker:
        return AppMode.stockManager;
      case AccountWorkspaceAccess.finance:
        return AppMode.expenseTracker;
      case AccountWorkspaceAccess.both:
        return preferredMode;
    }
  }

  static Future<AppMode> enforceAccess(AccountWorkspaceAccess access) async {
    final nextMode = resolvedModeForAccess(access, _currentMode);
    await setMode(nextMode);
    return nextMode;
  }

  static AppMode _modeFromStorage(String value) {
    return AppMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AppMode.stockManager,
    );
  }
}
