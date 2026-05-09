import 'package:flutter/material.dart';

import '../services/invoice_template_settings_service.dart';

class SettingsInvoiceTemplateScreen extends StatefulWidget {
  const SettingsInvoiceTemplateScreen({
    super.key,
    required this.initialTemplateId,
  });

  final int initialTemplateId;

  @override
  State<SettingsInvoiceTemplateScreen> createState() =>
      _SettingsInvoiceTemplateScreenState();
}

class _SettingsInvoiceTemplateScreenState
    extends State<SettingsInvoiceTemplateScreen> {
  static const Color _surface = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _surfaceLowest = Colors.white;
  static const Color _surfaceContainer = Color(0xFFECEEEC);
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF3F4945);
  static const Color _outlineVariant = Color(0xFFBFC9C4);

  late int _selectedTemplateId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedTemplateId = InvoiceTemplateSettingsService.optionForId(
      widget.initialTemplateId,
    ).id;
  }

  Future<void> _saveSelection() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await InvoiceTemplateSettingsService.setSelectedTemplateId(
        _selectedTemplateId,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(_selectedTemplateId);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedOption = InvoiceTemplateSettingsService.optionForId(
      _selectedTemplateId,
    );

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Invoice Template'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _surfaceLowest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1400342D),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice export style',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: _textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the template used when you download an order invoice. Exports intentionally spend 20 seconds preparing so all saved details can be collected before the file is shared.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(_iconFor(selectedOption.id), color: _primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${selectedOption.name} selected',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: _textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Live Preview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _InvoiceTemplatePreview(templateId: _selectedTemplateId),
              ],
            ),
          ),
          const SizedBox(height: 22),
          ...InvoiceTemplateSettingsService.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _isSaving
                    ? null
                    : () {
                        setState(() {
                          _selectedTemplateId = option.id;
                        });
                      },
                child: Ink(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _surfaceLowest,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _selectedTemplateId == option.id
                          ? _primary
                          : _outlineVariant.withValues(alpha: 0.45),
                      width: _selectedTemplateId == option.id ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _selectedTemplateId == option.id
                              ? _primary
                              : _surfaceContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _iconFor(option.id),
                          color: _selectedTemplateId == option.id
                              ? Colors.white
                              : _primary,
                        ),
                      ),
                      const SizedBox(width: 16),
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
                            const SizedBox(height: 6),
                            Text(
                              option.summary,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _textSecondary,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        _selectedTemplateId == option.id
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: _selectedTemplateId == option.id
                            ? _primary
                            : _outlineVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveSelection,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Saving...' : 'Save Template'),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(int templateId) {
    switch (templateId) {
      case 2:
        return Icons.dashboard_customize_outlined;
      case 3:
        return Icons.auto_awesome_outlined;
      case 4:
        return Icons.view_agenda_outlined;
      case 5:
        return Icons.layers_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }
}

class _InvoiceTemplatePreview extends StatelessWidget {
  const _InvoiceTemplatePreview({required this.templateId});

  final int templateId;

  @override
  Widget build(BuildContext context) {
    final palette = _TemplatePreviewPalette.forId(templateId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.canvas,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.line),
      ),
      child: switch (templateId) {
        2 => _buildTemplateTwoPreview(context, palette),
        3 => _buildTemplateThreePreview(context, palette),
        4 => _buildTemplateFourPreview(context, palette),
        5 => _buildTemplateFivePreview(context, palette),
        _ => _buildTemplateOnePreview(context, palette),
      },
    );
  }

  Widget _buildTemplateOnePreview(
    BuildContext context,
    _TemplatePreviewPalette palette,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreviewBar(width: 30, color: palette.accent),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _PreviewLogo(palette: palette, wide: true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PreviewBar(width: 72, color: palette.text),
                              const SizedBox(height: 6),
                              _PreviewBar(width: 56, color: palette.textMuted),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const _PreviewMetaColumn(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _PreviewInfoCard(palette: palette, title: 'Invoice To'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PreviewInfoCard(palette: palette, title: 'Invoice From'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PreviewTable(palette: palette, darkHeader: true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.line),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 110,
              height: 58,
              decoration: BoxDecoration(
                color: palette.summary,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTemplateTwoPreview(
    BuildContext context,
    _TemplatePreviewPalette palette,
  ) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _PreviewLogo(palette: palette, outlined: true),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _PreviewPlainColumn(palette: palette)),
            const SizedBox(width: 20),
            Expanded(child: _PreviewPlainColumn(palette: palette)),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(
              top: BorderSide(color: palette.accent, width: 2),
              bottom: BorderSide(color: palette.accent, width: 2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreviewBar(width: 28, color: palette.accent),
                    const SizedBox(height: 8),
                    _PreviewBar(width: 84, color: palette.text),
                  ],
                ),
              ),
              const _PreviewMetaColumn(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PreviewTable(palette: palette, darkHeader: false),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PreviewInfoCard(palette: palette, title: 'Payment'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PreviewInfoCard(palette: palette, title: 'Contact'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTemplateThreePreview(
    BuildContext context,
    _TemplatePreviewPalette palette,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.softCard,
            borderRadius: BorderRadius.circular(18),
            border: Border(bottom: BorderSide(color: palette.accent, width: 2)),
          ),
          child: Row(
            children: [
              _PreviewLogo(palette: palette, outlined: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreviewBar(width: 84, color: palette.text),
                    const SizedBox(height: 6),
                    _PreviewBar(width: 68, color: palette.textMuted),
                  ],
                ),
              ),
              const _PreviewMetaColumn(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PreviewInfoCard(palette: palette, title: 'Invoice To'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PreviewInfoCard(palette: palette, title: 'Invoice From'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PreviewInfoCard(palette: palette, title: 'Contact'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PreviewTable(palette: palette, darkHeader: true, vatColumn: true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PreviewInfoCard(palette: palette, title: 'Payment'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PreviewInfoCard(palette: palette, title: 'Terms'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTemplateFourPreview(
    BuildContext context,
    _TemplatePreviewPalette palette,
  ) {
    return Column(
      children: [
        Row(
          children: [
            _PreviewLogo(palette: palette),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PreviewBar(width: 82, color: palette.text),
                const SizedBox(height: 6),
                _PreviewBar(width: 56, color: palette.textMuted),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.softCard,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: const [
              Expanded(child: _PreviewMiniColumn()),
              SizedBox(width: 10),
              Expanded(child: _PreviewMiniColumn()),
              SizedBox(width: 10),
              Expanded(child: _PreviewMiniColumn()),
              SizedBox(width: 10),
              Expanded(child: _PreviewMiniColumn()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PreviewTable(palette: palette, darkHeader: false, compact: true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PreviewInfoCard(palette: palette, title: 'Contact'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PreviewInfoCard(palette: palette, title: 'Terms'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTemplateFivePreview(
    BuildContext context,
    _TemplatePreviewPalette palette,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.header,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _PreviewLogo(palette: palette, onDark: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreviewBar(width: 54, color: palette.onHeader),
                    const SizedBox(height: 6),
                    _PreviewBar(
                      width: 78,
                      color: palette.onHeader.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewBar(width: 24, color: palette.accent),
                  const SizedBox(height: 8),
                  _PreviewBar(width: 84, color: palette.text),
                ],
              ),
            ),
            const _PreviewMetaColumn(),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PreviewInfoCard(palette: palette, title: 'Invoice To'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PreviewInfoCard(palette: palette, title: 'Invoice From'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PreviewTable(palette: palette, darkHeader: false, vatColumn: true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PreviewInfoCard(palette: palette, title: 'Payment'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PreviewInfoCard(palette: palette, title: 'Terms'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 18,
          decoration: BoxDecoration(
            color: palette.header,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({
    required this.palette,
    required this.darkHeader,
    this.vatColumn = false,
    this.compact = false,
  });

  final _TemplatePreviewPalette palette;
  final bool darkHeader;
  final bool vatColumn;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final headerColor = darkHeader ? palette.tableHeader : palette.surface;
    final borderColor = darkHeader ? Colors.transparent : palette.line;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                _PreviewBar(
                  width: compact ? 58 : 20,
                  color: darkHeader ? palette.onTableHeader : palette.textMuted,
                ),
                const SizedBox(width: 10),
                _PreviewBar(
                  width: compact ? 44 : 66,
                  color: darkHeader ? palette.onTableHeader : palette.text,
                ),
                if (vatColumn) ...[
                  const Spacer(),
                  _PreviewBar(
                    width: 32,
                    color: darkHeader
                        ? palette.onTableHeader
                        : palette.textMuted,
                  ),
                ],
                const Spacer(),
                _PreviewBar(
                  width: 46,
                  color: darkHeader ? palette.onTableHeader : palette.textMuted,
                ),
              ],
            ),
          ),
          for (var index = 0; index < 3; index++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: index.isEven ? palette.surface : palette.rowAlt,
                border: Border(top: BorderSide(color: palette.line)),
              ),
              child: Row(
                children: [
                  _PreviewBar(
                    width: compact ? 62 : 14,
                    color: palette.textMuted,
                  ),
                  const SizedBox(width: 10),
                  _PreviewBar(width: compact ? 40 : 72, color: palette.text),
                  if (vatColumn) ...[
                    const Spacer(),
                    _PreviewBar(width: 28, color: palette.textMuted),
                  ],
                  const Spacer(),
                  _PreviewBar(width: 48, color: palette.textMuted),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewPlainColumn extends StatelessWidget {
  const _PreviewPlainColumn({required this.palette});

  final _TemplatePreviewPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PreviewBar(width: 42, color: palette.accent),
        const SizedBox(height: 8),
        _PreviewBar(width: 74, color: palette.text),
        const SizedBox(height: 6),
        _PreviewBar(width: 58, color: palette.textMuted),
        const SizedBox(height: 6),
        _PreviewBar(width: 66, color: palette.textMuted),
      ],
    );
  }
}

class _PreviewLogo extends StatelessWidget {
  const _PreviewLogo({
    required this.palette,
    this.outlined = false,
    this.wide = false,
    this.onDark = false,
  });

  final _TemplatePreviewPalette palette;
  final bool outlined;
  final bool wide;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? palette.onHeader : palette.accent;
    return Container(
      width: wide ? 62 : 52,
      height: wide ? 40 : 34,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: outlined ? palette.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: outlined ? Border.all(color: palette.line) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _PreviewBar(width: 8, color: color)),
          const SizedBox(width: 4),
          Expanded(
            child: _PreviewBar(width: 8, color: color.withValues(alpha: 0.82)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _PreviewBar(width: 8, color: color.withValues(alpha: 0.68)),
          ),
        ],
      ),
    );
  }
}

class _PreviewMetaColumn extends StatelessWidget {
  const _PreviewMetaColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _PreviewBar(width: 56, color: Color(0xFF7A8699)),
        SizedBox(height: 6),
        _PreviewBar(width: 52, color: Color(0xFF7A8699)),
        SizedBox(height: 6),
        _PreviewBar(width: 40, color: Color(0xFF7A8699)),
      ],
    );
  }
}

class _PreviewMiniColumn extends StatelessWidget {
  const _PreviewMiniColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _PreviewBar(width: 34, color: Color(0xFF7A8699)),
        SizedBox(height: 7),
        _PreviewBar(width: 42, color: Color(0xFF313846)),
        SizedBox(height: 6),
        _PreviewBar(width: 30, color: Color(0xFF7A8699)),
      ],
    );
  }
}

class _PreviewInfoCard extends StatelessWidget {
  const _PreviewInfoCard({required this.palette, required this.title});

  final _TemplatePreviewPalette palette;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.softCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: palette.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _PreviewBar(width: 64, color: palette.text),
          const SizedBox(height: 6),
          _PreviewBar(width: 48, color: palette.textMuted),
          const SizedBox(height: 6),
          _PreviewBar(width: 74, color: palette.textMuted),
        ],
      ),
    );
  }
}

class _PreviewBar extends StatelessWidget {
  const _PreviewBar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _TemplatePreviewPalette {
  const _TemplatePreviewPalette({
    required this.canvas,
    required this.surface,
    required this.softCard,
    required this.header,
    required this.headerAccent,
    required this.summary,
    required this.tableHeader,
    required this.onTableHeader,
    required this.onHeader,
    required this.accent,
    required this.text,
    required this.textMuted,
    required this.line,
    required this.rowAlt,
  });

  final Color canvas;
  final Color surface;
  final Color softCard;
  final Color header;
  final Color headerAccent;
  final Color summary;
  final Color tableHeader;
  final Color onTableHeader;
  final Color onHeader;
  final Color accent;
  final Color text;
  final Color textMuted;
  final Color line;
  final Color rowAlt;

  factory _TemplatePreviewPalette.forId(int templateId) {
    switch (templateId) {
      case 2:
        return const _TemplatePreviewPalette(
          canvas: Color(0xFFF8FAFF),
          surface: Colors.white,
          softCard: Color(0xFFF1F6FF),
          header: Color(0xFFFFFFFF),
          headerAccent: Color(0xFFDCEAFF),
          summary: Color(0xFFEAF2FF),
          tableHeader: Color(0xFFD8E8FF),
          onTableHeader: Color(0xFF28589A),
          onHeader: Color(0xFF1B2A3B),
          accent: Color(0xFF0D6EFD),
          text: Color(0xFF1F2E3E),
          textMuted: Color(0xFF718096),
          line: Color(0xFFD7E4F6),
          rowAlt: Color(0xFFFBFDFF),
        );
      case 3:
        return const _TemplatePreviewPalette(
          canvas: Color(0xFFF6F9FF),
          surface: Colors.white,
          softCard: Color(0xFFF0F5FF),
          header: Color(0xFF0059C7),
          headerAccent: Color(0xFF4A8FFF),
          summary: Color(0xFFEAF1FF),
          tableHeader: Color(0xFF0059C7),
          onTableHeader: Colors.white,
          onHeader: Colors.white,
          accent: Color(0xFF0059C7),
          text: Color(0xFF21365F),
          textMuted: Color(0xFF6077A1),
          line: Color(0xFFD6E0F5),
          rowAlt: Color(0xFFF8FAFF),
        );
      case 4:
        return const _TemplatePreviewPalette(
          canvas: Color(0xFFF7F8FB),
          surface: Colors.white,
          softCard: Color(0xFFF1F3F9),
          header: Color(0xFFF1F3F9),
          headerAccent: Color(0xFFCDD3E0),
          summary: Color(0xFFF1F3F9),
          tableHeader: Color(0xFFF7F8FB),
          onTableHeader: Color(0xFF2D3341),
          onHeader: Color(0xFF202632),
          accent: Color(0xFF202632),
          text: Color(0xFF2D3341),
          textMuted: Color(0xFF7A8293),
          line: Color(0xFFE1E6EE),
          rowAlt: Color(0xFFFCFCFE),
        );
      case 5:
        return const _TemplatePreviewPalette(
          canvas: Color(0xFFF5F8FD),
          surface: Colors.white,
          softCard: Color(0xFFEFF4FF),
          header: Color(0xFF163B6C),
          headerAccent: Color(0xFF3B6DB0),
          summary: Color(0xFFEAF1FC),
          tableHeader: Color(0xFFF0F5FC),
          onTableHeader: Color(0xFF244567),
          onHeader: Colors.white,
          accent: Color(0xFF163B6C),
          text: Color(0xFF1E3351),
          textMuted: Color(0xFF6A7D96),
          line: Color(0xFFD8E1EE),
          rowAlt: Color(0xFFF9FBFE),
        );
      default:
        return const _TemplatePreviewPalette(
          canvas: Color(0xFFF8FBFA),
          surface: Colors.white,
          softCard: Color(0xFFE8F1EE),
          header: Color(0xFF00342D),
          headerAccent: Color(0xFF1A5A50),
          summary: Color(0xFFE4F0EC),
          tableHeader: Color(0xFF00342D),
          onTableHeader: Colors.white,
          onHeader: Colors.white,
          accent: Color(0xFF00342D),
          text: Color(0xFF20302D),
          textMuted: Color(0xFF6E7D79),
          line: Color(0xFFD7E3DE),
          rowAlt: Color(0xFFF9FBFB),
        );
    }
  }
}
