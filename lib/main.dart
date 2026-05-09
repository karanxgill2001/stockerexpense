import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'screens/settings_app_version.dart';
import 'screens/finance_hub.dart';
import 'screens/startup_whats_new.dart';
import 'services/employee_directory_service.dart';
import 'services/app_update_service.dart';
import 'services/app_mode_service.dart';
import 'services/currency_settings_service.dart';
import 'services/finance_currency_settings_service.dart';
import 'services/finance_tracker_service.dart';
import 'services/google_sheet_service.dart';
import 'services/order_sync_service.dart';
import 'services/session_service.dart';
import 'screens/login.dart';
import 'screens/create_account.dart';
import 'screens/dashboard.dart';
import 'screens/inventory_list.dart';
import 'screens/add_stock.dart';
import 'screens/orders.dart';
import 'screens/notifications.dart';
import 'screens/settings.dart';
import 'screens/sell_items.dart';
import 'widgets/design_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await AppUpdateService.instance.cleanupPendingDownloadedApkOnStartup();
  }
  await AppModeService.initialize();
  await CurrencySettingsService.initialize();
  await FinanceCurrencySettingsService.initialize();
  await OrderSyncService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      OrderSyncService.scheduleImmediateBackgroundCheck();
    }
  }

  static const Color primaryColor = Color(0xFF00342D);
  static const Color surfaceColor = Color(0xFFF8FAF7);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppMode>(
      valueListenable: AppModeService.changes,
      builder: (context, appMode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Stocker Expense Tracker',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
          scaffoldBackgroundColor: surfaceColor,
          textTheme: Typography.material2018().black,
        ),
        home: const _AppStartGate(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/create-account': (context) => const CreateAccountScreen(),
          '/home': (context) => const _SignedInStartHome(),
          '/dashboard': (context) => _screenForTab(0),
          '/inventory': (context) => _screenForTab(1),
          '/orders': (context) => _screenForTab(2),
          '/notifications': (context) => const NotificationsScreen(),
          '/add': (context) => _screenForTab(3),
          '/sell': (context) => _screenForTab(4),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }

  Widget _screenForTab(int index) {
    if (AppModeService.isExpenseTracker) {
      return FinanceHubScreen(initialTabIndex: index);
    }

    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const InventoryListScreen();
      case 2:
        return const OrdersScreen();
      case 3:
        return const AddStockScreen();
      case 4:
        return const SellItemsScreen();
      default:
        return const DashboardScreen();
    }
  }
}

class _AppStartGate extends StatefulWidget {
  const _AppStartGate();

  @override
  State<_AppStartGate> createState() => _AppStartGateState();
}

class _AppStartGateState extends State<_AppStartGate> {
  late final Future<bool> _startStateFuture;
  bool _handledStartupExperience = false;
  String _startupMessage = 'Preparing your workspace...';

  @override
  void initState() {
    super.initState();
    _startStateFuture = _resolveStartState();
  }

  void _setStartupMessage(String message) {
    if (_startupMessage == message) {
      return;
    }

    if (!mounted) {
      _startupMessage = message;
      return;
    }

    setState(() {
      _startupMessage = message;
    });
  }

  Future<bool> _resolveStartState() async {
    _setStartupMessage('Checking saved sign-in...');
    final staySignedIn = await SessionService.shouldStaySignedIn();
    if (!staySignedIn) {
      return false;
    }

    final email = await SessionService.getUserEmail();
    if (email != null && email.trim().isNotEmpty) {
      _setStartupMessage('Loading saved account access...');
      final profile = await GoogleSheetService.instance.getStoredAccountProfile(email);
      if (profile != null) {
        await AppModeService.enforceAccess(profile.accessScope);
      }
    }

    if (AppModeService.isExpenseTracker) {
      await _preloadExpenseTrackerData(email);
    } else {
      _setStartupMessage('Syncing stock and order data...');
      await GoogleSheetService.instance.preloadStartupData();
    }

    return true;
  }

  Future<void> _preloadExpenseTrackerData(String? email) async {
    _setStartupMessage('Loading saved finance data...');
    await FinanceTrackerService.loadEntries();

    _setStartupMessage('Syncing finance entries from Google Sheets...');
    await FinanceTrackerService.preloadStartupData(waitForRemote: true);

    _setStartupMessage('Loading employee directory...');
    await EmployeeDirectoryService.preloadStartupData();

    if (email == null || email.trim().isEmpty) {
      return;
    }

    _setStartupMessage('Refreshing account access...');
    try {
      final profile = await GoogleSheetService.instance.fetchAccountProfile(email);
      await SessionService.updateStoredProfile(
        email: profile.email,
        fullName: profile.fullName,
        companyName: profile.companyName,
        address: profile.address,
        phoneNo: profile.phoneNo,
        canManageFinanceEntries: profile.canManageFinanceEntries,
      );
      await AppModeService.enforceAccess(profile.accessScope);
    } catch (_) {
      // Keep the saved local profile if the credentials backend is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _startStateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return DesignLoaderScreen(
            eyebrow: AppModeService.isExpenseTracker
                ? 'Expense tracker startup'
                : 'Workspace startup',
            title: AppModeService.isExpenseTracker
                ? 'Loading expense tracker'
                : 'Loading workspace',
            label: _startupMessage,
            note: AppModeService.isExpenseTracker
                ? 'Fetching saved local data first, then syncing the latest finance data from Google Sheets.'
                : 'Preparing your saved workspace data before opening the app.',
          );
        }

        final staySignedIn = snapshot.data == true;
        if (!_handledStartupExperience) {
          _handledStartupExperience = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleStartupExperience(staySignedIn: staySignedIn);
          });
        }

        if (staySignedIn) {
          return const _SignedInStartHome();
        }

        return const LoginScreen();
      },
    );
  }

  Future<void> _handleStartupExperience({required bool staySignedIn}) async {
    if (kIsWeb) {
      return;
    }

    try {
      final releaseNotes = await AppUpdateService.instance
          .getStartupReleaseNotesIfNeeded();
      if (mounted && releaseNotes != null) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => StartupWhatsNewScreen(
              versionLabel: releaseNotes.versionLabel,
              releaseNotes: releaseNotes.releaseNotes,
            ),
          ),
        );
        await AppUpdateService.instance.markStartupReleaseNotesSeen(
          releaseNotes.versionKey,
        );
      }
    } catch (_) {
      // Ignore release note fetch failures so the app still opens.
    }

    if (!mounted || !staySignedIn) {
      return;
    }

    await _showStartupUpdatePrompt();
  }

  Future<void> _showStartupUpdatePrompt() async {
    if (kIsWeb) {
      return;
    }

    try {
      final status = await AppUpdateService.instance.checkForUpdate();
      if (!mounted || !status.isAvailable) {
        return;
      }

      final remoteInfo = status.remoteInfo;
      final shouldOpen = await showDialog<bool>(
        context: context,
        barrierDismissible: !((remoteInfo?.forceUpdate ?? false)),
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Update available'),
            content: Text(
              remoteInfo == null
                  ? 'A new Stocker Expense Tracker update is available.'
                  : 'Version ${remoteInfo.displayVersion} is ready to install. Open App Version to download and install the APK.',
            ),
            actions: [
              if (!(remoteInfo?.forceUpdate ?? false))
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Later'),
                ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Update'),
              ),
            ],
          );
        },
      );

      if (!mounted || shouldOpen != true) {
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => const SettingsAppVersionScreen(autoCheck: true),
        ),
      );
    } catch (_) {
      // Ignore startup update errors so the app still opens normally.
    }
  }
}

class _SignedInStartHome extends StatelessWidget {
  const _SignedInStartHome();

  @override
  Widget build(BuildContext context) {
    if (AppModeService.isExpenseTracker) {
      return const FinanceHubScreen(initialTabIndex: 0);
    }

    return const DashboardScreen();
  }
}
