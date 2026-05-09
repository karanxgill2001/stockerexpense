import 'dart:async';

import 'package:flutter/material.dart';

enum AppMessageTone { info, success, error }

class AppMessage {
  AppMessage._();

  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void showInfo(BuildContext context, String message) {
    show(context, message, tone: AppMessageTone.info);
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message, tone: AppMessageTone.success);
  }

  static void showError(BuildContext context, String message) {
    show(context, message, tone: AppMessageTone.error);
  }

  static void show(
    BuildContext context,
    String message, {
    AppMessageTone tone = AppMessageTone.info,
    Duration duration = const Duration(milliseconds: 2600),
  }) {
    if (!context.mounted) {
      return;
    }

    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    final entry = OverlayEntry(
      builder: (overlayContext) =>
          _AppMessageOverlay(message: message, tone: tone),
    );

    _currentEntry = entry;
    overlay.insert(entry);
    _dismissTimer = Timer(duration, _removeCurrent);
  }

  static void _removeCurrent() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _AppMessageOverlay extends StatelessWidget {
  const _AppMessageOverlay({required this.message, required this.tone});

  final String message;
  final AppMessageTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = _toneScheme(tone);
    final mediaQuery = MediaQuery.of(context);
    final bottomOffset = mediaQuery.viewInsets.bottom > 0
        ? mediaQuery.viewInsets.bottom + 20
        : mediaQuery.padding.bottom + 92;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomOffset,
      child: IgnorePointer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.background, scheme.backgroundAccent],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: scheme.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 24,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: scheme.iconBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        scheme.icon,
                        color: scheme.iconColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: scheme.textColor,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
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
  }

  _AppMessageScheme _toneScheme(AppMessageTone tone) {
    switch (tone) {
      case AppMessageTone.success:
        return const _AppMessageScheme(
          background: Color(0xFF0D3B34),
          backgroundAccent: Color(0xFF145347),
          border: Color(0xFF2A6B5E),
          iconBackground: Color(0x1FFFFFFF),
          iconColor: Color(0xFFE6FFF8),
          textColor: Colors.white,
          icon: Icons.check_circle_rounded,
        );
      case AppMessageTone.error:
        return const _AppMessageScheme(
          background: Color(0xFF4D1F1F),
          backgroundAccent: Color(0xFF6A2828),
          border: Color(0xFF8A4343),
          iconBackground: Color(0x1AFFFFFF),
          iconColor: Color(0xFFFFE9E9),
          textColor: Colors.white,
          icon: Icons.error_rounded,
        );
      case AppMessageTone.info:
        return const _AppMessageScheme(
          background: Color(0xFFF8FCFB),
          backgroundAccent: Color(0xFFEAF4F1),
          border: Color(0xFFD3E3DD),
          iconBackground: Color(0xFFDAECE6),
          iconColor: Color(0xFF00342D),
          textColor: Color(0xFF10201D),
          icon: Icons.info_rounded,
        );
    }
  }
}

class _AppMessageScheme {
  const _AppMessageScheme({
    required this.background,
    required this.backgroundAccent,
    required this.border,
    required this.iconBackground,
    required this.iconColor,
    required this.textColor,
    required this.icon,
  });

  final Color background;
  final Color backgroundAccent;
  final Color border;
  final Color iconBackground;
  final Color iconColor;
  final Color textColor;
  final IconData icon;
}
