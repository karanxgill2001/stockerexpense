import 'package:flutter/material.dart';

import '../services/app_mode_service.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({required this.currentIndex, super.key});

  static const Color _primary = Color(0xFF00342D);
  static const Color _surface = Color(0xFFEAF7F2);
  static const Color _muted = Color(0xFF7EAFA5);

  final int currentIndex;

  void _onTap(
    BuildContext context,
    int index,
    List<({IconData icon, String label, String route})> items,
  ) {
    if (index == currentIndex) {
      return;
    }

    Navigator.pushReplacementNamed(context, items[index].route);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppMode>(
      valueListenable: AppModeService.changes,
      builder: (context, appMode, _) {
        final items = _itemsFor(appMode);

        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
            decoration: const BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1400342D),
                  blurRadius: 24,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = index == currentIndex;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: isSelected ? _primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _onTap(context, index, items),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 12,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.icon,
                                  size: 24,
                                  color: isSelected ? Colors.white : _muted,
                                ),
                                const SizedBox(height: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.labelSmall
                                        ?.copyWith(
                                          color: isSelected
                                              ? Colors.white
                                              : _muted,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  List<({IconData icon, String label, String route})> _itemsFor(AppMode mode) {
    if (mode == AppMode.expenseTracker) {
      return const [
        (icon: Icons.grid_view_rounded, label: 'Overview', route: '/dashboard'),
        (icon: Icons.payments_outlined, label: 'Expenses', route: '/inventory'),
        (icon: Icons.work_history_outlined, label: 'Salary', route: '/orders'),
        (icon: Icons.credit_card_outlined, label: 'Credit', route: '/add'),
        (
          icon: Icons.account_balance_wallet_outlined,
          label: 'Balance',
          route: '/sell',
        ),
        (icon: Icons.settings_rounded, label: 'Settings', route: '/settings'),
      ];
    }

    return const [
      (icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/dashboard'),
      (icon: Icons.inventory_2_rounded, label: 'Inventory', route: '/inventory'),
      (icon: Icons.receipt_long_rounded, label: 'Orders', route: '/orders'),
      (icon: Icons.add_a_photo_rounded, label: 'Add Stock', route: '/add'),
      (icon: Icons.shopping_cart_rounded, label: 'Checkout', route: '/sell'),
      (icon: Icons.settings_rounded, label: 'Settings', route: '/settings'),
    ];
  }
}
