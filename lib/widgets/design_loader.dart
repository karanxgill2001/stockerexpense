import 'dart:math' as math;

import 'package:flutter/material.dart';

class DesignLoader extends StatefulWidget {
  const DesignLoader({super.key, this.size = 44.8, this.color, this.label});

  final double size;
  final Color? color;
  final String? label;

  @override
  State<DesignLoader> createState() => _DesignLoaderState();
}

class _DesignLoaderState extends State<DesignLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loaderColor = widget.color ?? Theme.of(context).colorScheme.primary;
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = Curves.easeInOutCubicEmphasized.transform(
          _controller.value,
        );
        final insetFactor = progress < (2 / 3)
            ? (progress < (1 / 3) ? progress / (1 / 3) : 1)
            : (1 - ((progress - (2 / 3)) / (1 / 3))).clamp(0.0, 1.0);
        final rotationTurns = progress < (1 / 3)
            ? 0.0
            : (progress < (2 / 3)
                  ? ((progress - (1 / 3)) / (1 / 3)) * 0.25
                  : 0.25);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _LoaderDot(
                    diameter: widget.size * 0.25,
                    color: loaderColor,
                    offset: Offset.zero,
                  ),
                  Transform.rotate(
                    angle: rotationTurns * 2 * math.pi,
                    child: Padding(
                      padding: EdgeInsets.all(widget.size * 0.25 * insetFactor),
                      child: Stack(
                        children: [
                          _cornerDot(
                            alignment: Alignment.topLeft,
                            color: loaderColor,
                          ),
                          _cornerDot(
                            alignment: Alignment.topRight,
                            color: loaderColor,
                          ),
                          _cornerDot(
                            alignment: Alignment.bottomLeft,
                            color: loaderColor,
                          ),
                          _cornerDot(
                            alignment: Alignment.bottomRight,
                            color: loaderColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.label != null) ...[
              const SizedBox(height: 18),
              Text(
                widget.label!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _cornerDot({required Alignment alignment, required Color color}) {
    return Align(
      alignment: alignment,
      child: _LoaderDot(
        diameter: widget.size * 0.225,
        color: color,
        offset: const Offset(0, 0),
      ),
    );
  }
}

class _LoaderDot extends StatelessWidget {
  const _LoaderDot({
    required this.diameter,
    required this.color,
    required this.offset,
  });

  final double diameter;
  final Color color;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class DesignLoaderView extends StatelessWidget {
  const DesignLoaderView({super.key, this.label = 'Loading...', this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DesignLoader(label: label, color: color),
      ),
    );
  }
}

class DesignLoaderScreen extends StatelessWidget {
  const DesignLoaderScreen({
    super.key,
    this.eyebrow = 'Preparing workspace',
    this.title = 'Loading your data',
    this.label = 'Loading...',
    this.note,
  });

  final String eyebrow;
  final String title;
  final String label;
  final String? note;

  static const Color _surface = Color(0xFFF7F6F2);
  static const Color _primary = Color(0xFF19352C);
  static const Color _primaryContainer = Color(0xFF2D5A4D);
  static const Color _card = Color(0xFFFFFCF7);
  static const Color _accent = Color(0xFFE6DED0);
  static const Color _textPrimary = Color(0xFF18201D);
  static const Color _textSecondary = Color(0xFF5E655F);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF9F5EE), Color(0xFFEEF3EF)],
              ),
            ),
          ),
          const Positioned(
            top: -80,
            right: -40,
            child: _LoaderBackdropOrb(
              size: 220,
              color: Color(0x1F19352C),
            ),
          ),
          const Positioned(
            bottom: -110,
            left: -50,
            child: _LoaderBackdropOrb(
              size: 260,
              color: Color(0x22C8B59A),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x17000000),
                        blurRadius: 28,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          eyebrow,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: _primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_primary, _primaryContainer],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x2219352C),
                              blurRadius: 24,
                              offset: Offset(0, 16),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: DesignLoader(
                            size: 52,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: _textPrimary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: _textSecondary,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      if (note != null && note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          note!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoaderBackdropOrb extends StatelessWidget {
  const _LoaderBackdropOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
