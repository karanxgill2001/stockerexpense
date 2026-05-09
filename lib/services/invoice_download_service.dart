import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/account_profile.dart';
import '../models/order_line_item.dart';
import '../models/order_record.dart';
import 'currency_formatter.dart';
import 'google_sheet_service.dart';
import 'invoice_logo_service.dart';
import 'invoice_template_settings_service.dart';
import 'session_service.dart';

class GeneratedInvoiceFile {
  const GeneratedInvoiceFile({
    required this.filePath,
    required this.fileName,
    required this.template,
  });

  final String filePath;
  final String fileName;
  final InvoiceTemplateOption template;
}

class InvoiceDownloadService {
  const InvoiceDownloadService._();

  static const int preparationSeconds = 20;
  static const Duration _minimumGenerationDuration = Duration(
    seconds: preparationSeconds,
  );

  static Future<GeneratedInvoiceFile> generateInvoice(OrderRecord order) async {
    final generationStartedAt = DateTime.now();
    final template = await InvoiceTemplateSettingsService.getSelectedTemplate();
    final sellerProfile = await _loadSellerProfile();
    final logoBytes = await InvoiceLogoService.loadLogoBytes();
    final theme = _themeFor(template.id);
    final data = _InvoiceDocumentData.fromOrder(
      order: order,
      sellerProfile: sellerProfile,
      logoBytes: logoBytes,
      theme: theme,
      template: template,
    );
    final pdf = pw.Document(title: 'Invoice ${order.orderId}');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
        build: (context) => _buildTemplateSections(data),
      ),
    );

    final invoiceDirectory = await _ensureInvoiceDirectory();
    final fileName =
        'invoice_${_sanitizeFileSegment(order.orderId)}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${invoiceDirectory.path}/$fileName');
    await file.writeAsBytes(await pdf.save(), flush: true);

    final elapsed = DateTime.now().difference(generationStartedAt);
    final remaining = _minimumGenerationDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }

    return GeneratedInvoiceFile(
      filePath: file.path,
      fileName: fileName,
      template: template,
    );
  }

  static List<pw.Widget> _buildTemplateSections(_InvoiceDocumentData data) {
    switch (data.template.id) {
      case 2:
        return _buildTemplateTwo(data);
      case 3:
        return _buildTemplateThree(data);
      case 4:
        return _buildTemplateFour(data);
      case 5:
        return _buildTemplateFive(data);
      default:
        return _buildTemplateOne(data);
    }
  }

  static List<pw.Widget> _buildTemplateOne(_InvoiceDocumentData data) {
    return [
      _templateOneHeader(data),
      pw.SizedBox(height: 18),
      _twoColumnCards(
        left: _partyCard(data, title: 'Invoice To', lines: data.customerLines),
        right: _partyCard(data, title: 'Invoice From', lines: data.sellerLines),
      ),
      pw.SizedBox(height: 18),
      _itemsTableStandard(data),
      pw.SizedBox(height: 18),
      _totalsAndNotes(data, showNotesCard: true),
      pw.SizedBox(height: 18),
      _twoColumnCards(
        left: _infoCard(data, title: 'Contact Us', lines: data.contactLines),
        right: _infoCard(data, title: 'Payment Info', lines: data.paymentLines),
      ),
      pw.SizedBox(height: 16),
      _noticeBlock(data),
      pw.SizedBox(height: 14),
      _simpleFooter(data),
    ];
  }

  static List<pw.Widget> _buildTemplateTwo(_InvoiceDocumentData data) {
    return [
      _centeredLogoHeader(data),
      pw.SizedBox(height: 18),
      _simplePartyColumns(data),
      pw.SizedBox(height: 18),
      _metaBarHeader(data),
      pw.SizedBox(height: 18),
      _itemsTableStandard(data),
      pw.SizedBox(height: 18),
      _totalsAndNotes(data, showNotesCard: false),
      pw.SizedBox(height: 18),
      _twoColumnCards(
        left: _infoCard(data, title: 'Payment Info', lines: data.paymentLines),
        right: _infoCard(data, title: 'Contact Us', lines: data.contactLines),
      ),
      pw.SizedBox(height: 16),
      _noticeBlock(data),
      pw.SizedBox(height: 14),
      _simpleFooter(data),
    ];
  }

  static List<pw.Widget> _buildTemplateThree(_InvoiceDocumentData data) {
    return [
      _templateThreeHeader(data),
      pw.SizedBox(height: 18),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _partyCard(
              data,
              title: 'Invoice To',
              lines: data.customerLines,
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: _partyCard(
              data,
              title: 'Invoice From',
              lines: data.sellerLines,
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: _infoCard(
              data,
              title: 'Contact Info',
              lines: data.contactLines,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 18),
      _itemsTableWithVat(data),
      pw.SizedBox(height: 18),
      _totalsAndNotes(data, showNotesCard: false),
      pw.SizedBox(height: 18),
      _twoColumnCards(
        left: _infoCard(data, title: 'Payment Info', lines: data.paymentLines),
        right: _infoCard(
          data,
          title: 'Terms & Conditions',
          lines: data.termsLines,
        ),
      ),
      pw.SizedBox(height: 16),
      _noticeBlock(data),
      pw.SizedBox(height: 14),
      _simpleFooter(data),
    ];
  }

  static List<pw.Widget> _buildTemplateFour(_InvoiceDocumentData data) {
    return [
      _templateFourHeader(data),
      pw.SizedBox(height: 18),
      _templateFourSummaryCard(data),
      pw.SizedBox(height: 18),
      _itemsTableCompact(data),
      pw.SizedBox(height: 18),
      _totalsAndNotes(data, showNotesCard: false, compactSummary: true),
      pw.SizedBox(height: 18),
      _twoColumnCards(
        left: _infoCard(data, title: 'Contact Info', lines: data.contactLines),
        right: _infoCard(
          data,
          title: 'Terms & Conditions',
          lines: data.termsLines,
        ),
      ),
      pw.SizedBox(height: 16),
      _noticeBlock(data),
      pw.SizedBox(height: 14),
      _simpleFooter(data),
    ];
  }

  static List<pw.Widget> _buildTemplateFive(_InvoiceDocumentData data) {
    return [
      _templateFiveHero(data),
      pw.SizedBox(height: 18),
      _templateFiveMetaRow(data),
      pw.SizedBox(height: 18),
      _twoColumnCards(
        left: _partyCard(data, title: 'Invoice To', lines: data.customerLines),
        right: _partyCard(data, title: 'Invoice From', lines: data.sellerLines),
      ),
      pw.SizedBox(height: 18),
      _itemsTableWithVat(data),
      pw.SizedBox(height: 18),
      _totalsAndNotes(data, showNotesCard: false),
      pw.SizedBox(height: 18),
      _twoColumnCards(
        left: _infoCard(data, title: 'Payment Info', lines: data.paymentLines),
        right: _infoCard(
          data,
          title: 'Terms & Conditions',
          lines: data.termsLines,
        ),
      ),
      pw.SizedBox(height: 16),
      _noticeBlock(data),
      pw.SizedBox(height: 14),
      _bandFooter(data),
    ];
  }

  static pw.Widget _templateOneHeader(_InvoiceDocumentData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: data.theme.line, width: 1),
        borderRadius: pw.BorderRadius.circular(18),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Invoice',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: data.theme.accent,
                  ),
                ),
                pw.SizedBox(height: 10),
                _logoTitle(data, large: true, lightBox: false),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          _metaColumn(data, textColor: data.theme.text),
        ],
      ),
    );
  }

  static pw.Widget _centeredLogoHeader(_InvoiceDocumentData data) {
    return pw.Align(
      alignment: pw.Alignment.centerLeft,
      child: _logoTitle(data, logoOnly: true, accentOnLight: true),
    );
  }

  static pw.Widget _templateThreeHeader(_InvoiceDocumentData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: pw.BoxDecoration(
        color: _lighten(data.theme.soft, 0.03),
        borderRadius: pw.BorderRadius.circular(20),
        border: pw.Border(
          bottom: pw.BorderSide(color: data.theme.accent, width: 2.2),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _logoTitle(data, logoOnly: true),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Invoice',
                  style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    color: data.theme.text,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Designed statement for completed order billing.',
                  style: pw.TextStyle(fontSize: 10, color: data.theme.muted),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          _metaColumn(data, textColor: data.theme.text),
        ],
      ),
    );
  }

  static pw.Widget _templateFourHeader(_InvoiceDocumentData data) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        _logoTitle(data, logoOnly: true, accentOnLight: false),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Invoice',
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  color: data.theme.text,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Invoice No: ${data.order.orderId}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: data.theme.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _templateFiveHero(_InvoiceDocumentData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: pw.BoxDecoration(
        color: data.theme.accent,
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _logoTitle(data, logoOnly: true, onDark: true),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Contact Info',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: data.theme.onAccent,
                  ),
                ),
                pw.SizedBox(height: 8),
                for (final line in data.contactLines.take(3))
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(
                      line,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: data.theme.onAccentMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _templateFiveMetaRow(_InvoiceDocumentData data) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Invoice',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: data.theme.accent,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Invoice',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: data.theme.text,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        _metaColumn(data, textColor: data.theme.text),
      ],
    );
  }

  static pw.Widget _metaBarHeader(_InvoiceDocumentData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: data.theme.accent, width: 2),
          bottom: pw.BorderSide(color: data.theme.accent, width: 2),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Invoice',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: data.theme.accent,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Invoice',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: data.theme.text,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          _metaColumn(data, textColor: data.theme.text),
        ],
      ),
    );
  }

  static pw.Widget _simplePartyColumns(_InvoiceDocumentData data) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _simplePartyColumn(data, 'Invoice To', data.customerLines),
        ),
        pw.SizedBox(width: 24),
        pw.Expanded(
          child: _simplePartyColumn(data, 'Invoice From', data.sellerLines),
        ),
      ],
    );
  }

  static pw.Widget _simplePartyColumn(
    _InvoiceDocumentData data,
    String title,
    List<String> lines,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: data.theme.accent,
          ),
        ),
        pw.SizedBox(height: 8),
        for (var index = 0; index < lines.length; index++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              lines[index],
              style: pw.TextStyle(
                fontSize: index == 0 ? 15 : 10,
                fontWeight: index == 0
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                color: index == 0 ? data.theme.text : data.theme.muted,
              ),
            ),
          ),
      ],
    );
  }

  static pw.Widget _partyCard(
    _InvoiceDocumentData data, {
    required String title,
    required List<String> lines,
  }) {
    return _baseCard(
      data,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionLabel(data, title),
          pw.SizedBox(height: 8),
          for (var index = 0; index < lines.length; index++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                lines[index],
                style: pw.TextStyle(
                  fontSize: index == 0 ? 14 : 10,
                  fontWeight: index == 0
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: index == 0 ? data.theme.text : data.theme.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _infoCard(
    _InvoiceDocumentData data, {
    required String title,
    required List<String> lines,
  }) {
    return _baseCard(
      data,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionLabel(data, title),
          pw.SizedBox(height: 8),
          for (final line in lines)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Text(
                line,
                style: pw.TextStyle(fontSize: 10, color: data.theme.muted),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _baseCard(
    _InvoiceDocumentData data, {
    required pw.Widget child,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: data.theme.soft,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(
          color: _lighten(data.theme.line, -0.02),
          width: 0.6,
        ),
      ),
      child: child,
    );
  }

  static pw.Widget _twoColumnCards({
    required pw.Widget left,
    required pw.Widget right,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: left),
        pw.SizedBox(width: 16),
        pw.Expanded(child: right),
      ],
    );
  }

  static pw.Widget _itemsTableStandard(_InvoiceDocumentData data) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: data.theme.line, width: 0.7),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.TableHelper.fromTextArray(
        headers: const ['No.', 'Description', 'Price', 'Qty', 'Total'],
        data: data.lines
            .map(
              (line) => [
                '${line.index}',
                line.name,
                _currency(line.unitPrice),
                '${line.quantity}',
                _currency(line.total),
              ],
            )
            .toList(),
        border: null,
        headerDecoration: pw.BoxDecoration(color: data.theme.tableHeader),
        headerStyle: pw.TextStyle(
          color: data.theme.tableHeaderText,
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
        cellStyle: pw.TextStyle(fontSize: 9.5, color: data.theme.text),
        oddRowDecoration: pw.BoxDecoration(color: data.theme.tableStripe),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        headerPadding: const pw.EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 9,
        ),
        columnWidths: {
          0: const pw.FixedColumnWidth(26),
          2: const pw.FixedColumnWidth(60),
          3: const pw.FixedColumnWidth(34),
          4: const pw.FixedColumnWidth(62),
        },
      ),
    );
  }

  static pw.Widget _itemsTableWithVat(_InvoiceDocumentData data) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: data.theme.line, width: 0.7),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.TableHelper.fromTextArray(
        headers: const ['No.', 'Description', 'Price', 'VAT', 'Total'],
        data: data.lines
            .map(
              (line) => [
                '${line.index}',
                line.name,
                _currency(line.unitPrice),
                _currency(line.taxAmount),
                _currency(line.total),
              ],
            )
            .toList(),
        border: null,
        headerDecoration: pw.BoxDecoration(color: data.theme.accent),
        headerStyle: pw.TextStyle(
          color: data.theme.onAccent,
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
        cellStyle: pw.TextStyle(fontSize: 9.5, color: data.theme.text),
        oddRowDecoration: pw.BoxDecoration(color: data.theme.tableStripe),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        headerPadding: const pw.EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 9,
        ),
        columnWidths: {
          0: const pw.FixedColumnWidth(26),
          2: const pw.FixedColumnWidth(58),
          3: const pw.FixedColumnWidth(54),
          4: const pw.FixedColumnWidth(64),
        },
      ),
    );
  }

  static pw.Widget _itemsTableCompact(_InvoiceDocumentData data) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: data.theme.line, width: 0.7),
        borderRadius: pw.BorderRadius.circular(18),
      ),
      child: pw.TableHelper.fromTextArray(
        headers: const ['Description', 'Price', 'VAT', 'Total'],
        data: data.lines
            .map(
              (line) => [
                line.name,
                _currency(line.unitPrice),
                _currency(line.taxAmount),
                _currency(line.total),
              ],
            )
            .toList(),
        border: null,
        headerDecoration: pw.BoxDecoration(
          color: _lighten(data.theme.soft, 0.03),
        ),
        headerStyle: pw.TextStyle(
          color: data.theme.text,
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
        cellStyle: pw.TextStyle(fontSize: 9.5, color: data.theme.text),
        oddRowDecoration: pw.BoxDecoration(color: data.theme.tableStripe),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        headerPadding: const pw.EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 9,
        ),
        columnWidths: {
          1: const pw.FixedColumnWidth(62),
          2: const pw.FixedColumnWidth(58),
          3: const pw.FixedColumnWidth(62),
        },
      ),
    );
  }

  static pw.Widget _totalsAndNotes(
    _InvoiceDocumentData data, {
    required bool showNotesCard,
    bool compactSummary = false,
  }) {
    final summary = _summaryCard(data, compact: compactSummary);
    if (!showNotesCard) {
      return pw.Align(alignment: pw.Alignment.centerRight, child: summary);
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: data.theme.line),
              borderRadius: pw.BorderRadius.circular(18),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionLabel(data, 'Order Notes'),
                pw.SizedBox(height: 8),
                pw.Text(
                  'This invoice summarizes the order, taxes, shipping, and customer information captured in Stocker.',
                  style: pw.TextStyle(fontSize: 10, color: data.theme.muted),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 16),
        summary,
      ],
    );
  }

  static pw.Widget _summaryCard(
    _InvoiceDocumentData data, {
    bool compact = false,
  }) {
    return pw.Container(
      width: compact ? 210 : 190,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: data.theme.soft,
        borderRadius: pw.BorderRadius.circular(compact ? 20 : 18),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _summaryLine(data, 'Subtotal', _currency(data.subtotal)),
          pw.SizedBox(height: 8),
          _summaryLine(data, 'Tax', _currency(data.order.taxAmount)),
          pw.SizedBox(height: 8),
          _summaryLine(data, 'Shipping', _currency(data.order.shippingCost)),
          pw.Divider(color: data.theme.line, height: 20),
          _summaryLine(
            data,
            'Total',
            _currency(data.order.totalCost),
            emphasize: true,
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryLine(
    _InvoiceDocumentData data,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    final textStyle = pw.TextStyle(
      fontSize: emphasize ? 12 : 10,
      fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: emphasize ? data.theme.text : data.theme.muted,
    );

    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: data.theme.muted),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(value, style: textStyle),
      ],
    );
  }

  static pw.Widget _templateFourSummaryCard(_InvoiceDocumentData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: data.theme.soft,
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _miniInfoBlock(data, 'Invoice To', data.customerLines),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: _miniInfoBlock(data, 'Invoice From', data.sellerLines),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: _miniInfoBlock(data, 'Payment Method', data.paymentLines),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: _miniInfoBlock(data, 'Date', [
              'Invoice Date: ${_formatDate(data.order.createdAt)}',
              'Units: ${data.order.quantity}',
            ]),
          ),
        ],
      ),
    );
  }

  static pw.Widget _miniInfoBlock(
    _InvoiceDocumentData data,
    String title,
    List<String> lines,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: data.theme.muted,
          ),
        ),
        pw.SizedBox(height: 7),
        for (var index = 0; index < lines.length && index < 4; index++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              lines[index],
              style: pw.TextStyle(
                fontSize: index == 0 ? 11 : 9.4,
                fontWeight: index == 0
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                color: index == 0 ? data.theme.text : data.theme.muted,
              ),
            ),
          ),
      ],
    );
  }

  static pw.Widget _noticeBlock(_InvoiceDocumentData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _lighten(data.theme.soft, 0.02),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Text(
        'This is a system-generated invoice.',
        style: pw.TextStyle(
          fontSize: 9.5,
          color: data.theme.muted,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _simpleFooter(_InvoiceDocumentData data) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            'Stocker Invoice Export',
            style: pw.TextStyle(fontSize: 9, color: data.theme.muted),
          ),
        ),
        pw.Text(
          _formatDate(data.order.createdAt),
          style: pw.TextStyle(fontSize: 9, color: data.theme.muted),
        ),
      ],
    );
  }

  static pw.Widget _bandFooter(_InvoiceDocumentData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: pw.BoxDecoration(
        color: data.theme.accent,
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'Stocker Invoice Export',
              style: pw.TextStyle(fontSize: 9, color: data.theme.onAccent),
            ),
          ),
          pw.Text(
            data.order.orderId,
            style: pw.TextStyle(
              fontSize: 9,
              color: data.theme.onAccentMuted,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaColumn(
    _InvoiceDocumentData data, {
    required PdfColor textColor,
  }) {
    final labelStyle = pw.TextStyle(fontSize: 9, color: textColor);
    final valueStyle = pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      color: textColor,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _metaLine('Invoice No', data.order.orderId, labelStyle, valueStyle),
        pw.SizedBox(height: 6),
        _metaLine(
          'Invoice Date',
          _formatDate(data.order.createdAt),
          labelStyle,
          valueStyle,
        ),
        pw.SizedBox(height: 6),
        _metaLine('Quantity', '${data.order.quantity}', labelStyle, valueStyle),
      ],
    );
  }

  static pw.Widget _metaLine(
    String label,
    String value,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
  ) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.SizedBox(width: 62, child: pw.Text(label, style: labelStyle)),
        pw.SizedBox(width: 8),
        pw.Text(value, style: valueStyle),
      ],
    );
  }

  static pw.Widget _logoTitle(
    _InvoiceDocumentData data, {
    bool large = false,
    bool logoOnly = false,
    bool accentOnLight = false,
    bool lightBox = true,
    bool onDark = false,
  }) {
    final textColor = onDark
        ? data.theme.onAccent
        : (accentOnLight ? data.theme.accent : data.theme.text);
    final subtitleColor = onDark ? data.theme.onAccentMuted : data.theme.muted;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        _logoMark(
          data,
          width: large ? 84 : 62,
          height: large ? 54 : 42,
          lightBox: lightBox,
        ),
        if (!logoOnly) ...[
          pw.SizedBox(width: 12),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Invoice',
                style: pw.TextStyle(
                  fontSize: large ? 28 : 22,
                  fontWeight: pw.FontWeight.bold,
                  color: textColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                data.sellerProfile.companyName.trim().isEmpty
                    ? 'Sales billing statement'
                    : data.sellerProfile.companyName.trim(),
                style: pw.TextStyle(fontSize: 9.5, color: subtitleColor),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static pw.Widget _logoMark(
    _InvoiceDocumentData data, {
    required double width,
    required double height,
    required bool lightBox,
  }) {
    final logo = data.logoImage;
    return pw.Container(
      width: width,
      height: height,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: lightBox ? PdfColors.white : data.theme.soft,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: logo != null
          ? pw.Image(logo, fit: pw.BoxFit.contain)
          : pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _markBar(data.theme.accent, 10, height - 12),
                pw.SizedBox(width: 6),
                _markBar(data.theme.accent, 10, height * 0.64),
                pw.SizedBox(width: 6),
                _markBar(data.theme.accent, 10, height * 0.46),
              ],
            ),
    );
  }

  static pw.Widget _markBar(PdfColor color, double width, double height) {
    return pw.Container(
      width: width,
      height: height,
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(999),
      ),
    );
  }

  static pw.Widget _sectionLabel(_InvoiceDocumentData data, String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: data.theme.accent,
      ),
    );
  }

  static PdfColor _lighten(PdfColor color, double amount) {
    final value = color.toInt();
    final alpha = (value >> 24) & 0xFF;
    final red = (value >> 16) & 0xFF;
    final green = (value >> 8) & 0xFF;
    final blue = value & 0xFF;

    int shift(int channel) {
      final target = amount >= 0 ? 255 : 0;
      final next = channel + ((target - channel) * amount.abs());
      return next.clamp(0, 255).round();
    }

    return PdfColor.fromInt(
      (alpha << 24) | (shift(red) << 16) | (shift(green) << 8) | shift(blue),
    );
  }

  static Future<AccountProfile> _loadSellerProfile() async {
    final email = await SessionService.getUserEmail();
    if (email == null || email.trim().isEmpty) {
      return _fallbackSellerProfile();
    }

    final storedProfile = await GoogleSheetService.instance
        .getStoredAccountProfile(email);
    if (storedProfile != null) {
      return storedProfile;
    }

    try {
      return await GoogleSheetService.instance.fetchAccountProfile(email);
    } catch (_) {
      return _fallbackSellerProfile();
    }
  }

  static AccountProfile _fallbackSellerProfile() {
    return const AccountProfile(
      companyName: 'Stocker Business',
      fullName: 'Sales Team',
      address: '',
      email: '',
      phoneNo: '',
      masterKey: '',
      accessScope: AccountWorkspaceAccess.both,
      canManageFinanceEntries: true,
    );
  }

  static Future<Directory> _ensureInvoiceDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/invoices');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static String _bestCustomerTitle(OrderRecord order) {
    final customerName = order.customerName.trim();
    if (customerName.isNotEmpty) {
      return customerName;
    }

    final companyName = order.companyName.trim();
    if (companyName.isNotEmpty) {
      return companyName;
    }

    return 'Customer';
  }

  static String _bestSellerTitle(AccountProfile profile) {
    final fullName = profile.fullName.trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }

    final companyName = profile.companyName.trim();
    if (companyName.isNotEmpty) {
      return companyName;
    }

    return 'Sales Team';
  }

  static double _subtotal(OrderRecord order) {
    final subtotal = order.items.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );
    if (subtotal > 0) {
      return subtotal;
    }

    final derivedSubtotal =
        order.totalCost - order.taxAmount - order.shippingCost;
    return derivedSubtotal < 0 ? 0 : derivedSubtotal;
  }

  static _InvoiceTheme _themeFor(int templateId) {
    switch (templateId) {
      case 2:
        return const _InvoiceTheme(
          accent: PdfColor.fromInt(0xFF0D6EFD),
          soft: PdfColor.fromInt(0xFFEAF2FF),
          text: PdfColor.fromInt(0xFF243447),
          muted: PdfColor.fromInt(0xFF5D6B7B),
          line: PdfColor.fromInt(0xFFD8E3F2),
          tableStripe: PdfColor.fromInt(0xFFF8FBFF),
          tableHeader: PdfColor.fromInt(0xFFD8E8FF),
          tableHeaderText: PdfColor.fromInt(0xFF28589A),
          onAccent: PdfColors.black,
          onAccentMuted: PdfColor.fromInt(0xFF405264),
        );
      case 3:
        return const _InvoiceTheme(
          accent: PdfColor.fromInt(0xFF0059C7),
          soft: PdfColor.fromInt(0xFFE9F0FF),
          text: PdfColor.fromInt(0xFF1A2850),
          muted: PdfColor.fromInt(0xFF5B6E95),
          line: PdfColor.fromInt(0xFFD6E0F7),
          tableStripe: PdfColor.fromInt(0xFFF7FAFF),
          tableHeader: PdfColor.fromInt(0xFF0059C7),
          tableHeaderText: PdfColors.white,
          onAccent: PdfColors.white,
          onAccentMuted: PdfColor.fromInt(0xFFD9E6FF),
        );
      case 4:
        return const _InvoiceTheme(
          accent: PdfColor.fromInt(0xFF202632),
          soft: PdfColor.fromInt(0xFFF2F4F8),
          text: PdfColor.fromInt(0xFF202632),
          muted: PdfColor.fromInt(0xFF6B7280),
          line: PdfColor.fromInt(0xFFE3E8EF),
          tableStripe: PdfColor.fromInt(0xFFFBFCFE),
          tableHeader: PdfColor.fromInt(0xFFF7F8FB),
          tableHeaderText: PdfColor.fromInt(0xFF2D3341),
          onAccent: PdfColors.white,
          onAccentMuted: PdfColor.fromInt(0xFFDBE1EA),
        );
      case 5:
        return const _InvoiceTheme(
          accent: PdfColor.fromInt(0xFF163B6C),
          soft: PdfColor.fromInt(0xFFEEF4FF),
          text: PdfColor.fromInt(0xFF1E3351),
          muted: PdfColor.fromInt(0xFF61748D),
          line: PdfColor.fromInt(0xFFD7E1EF),
          tableStripe: PdfColor.fromInt(0xFFF7FAFE),
          tableHeader: PdfColor.fromInt(0xFFF0F5FC),
          tableHeaderText: PdfColor.fromInt(0xFF244567),
          onAccent: PdfColors.white,
          onAccentMuted: PdfColor.fromInt(0xFFD7E6FF),
        );
      default:
        return const _InvoiceTheme(
          accent: PdfColor.fromInt(0xFF00342D),
          soft: PdfColor.fromInt(0xFFE7F1EE),
          text: PdfColor.fromInt(0xFF1A1F1D),
          muted: PdfColor.fromInt(0xFF5A6662),
          line: PdfColor.fromInt(0xFFD9E4DF),
          tableStripe: PdfColor.fromInt(0xFFF8FBFA),
          tableHeader: PdfColor.fromInt(0xFF00342D),
          tableHeaderText: PdfColors.white,
          onAccent: PdfColors.white,
          onAccentMuted: PdfColor.fromInt(0xFFD5E4E0),
        );
    }
  }

  static String _sanitizeFileSegment(String value) {
    final trimmed = value.trim();
    final sanitized = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    if (sanitized.isEmpty) {
      return 'invoice';
    }
    return sanitized;
  }

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Recent order';
    }

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

  static String _currency(double value) =>
      CurrencyFormatter.formatAmount(value, useCode: true);
}

class _InvoiceDocumentData {
  const _InvoiceDocumentData({
    required this.order,
    required this.sellerProfile,
    required this.theme,
    required this.template,
    required this.logoImage,
    required this.lines,
    required this.customerLines,
    required this.sellerLines,
    required this.contactLines,
    required this.paymentLines,
    required this.termsLines,
    required this.subtotal,
  });

  factory _InvoiceDocumentData.fromOrder({
    required OrderRecord order,
    required AccountProfile sellerProfile,
    required Uint8List? logoBytes,
    required _InvoiceTheme theme,
    required InvoiceTemplateOption template,
  }) {
    final subtotal = InvoiceDownloadService._subtotal(order);
    final bestCustomerTitle = InvoiceDownloadService._bestCustomerTitle(order);
    final bestSellerTitle = InvoiceDownloadService._bestSellerTitle(
      sellerProfile,
    );
    final contactLines = [
      if (sellerProfile.address.trim().isNotEmpty) sellerProfile.address.trim(),
      if (sellerProfile.phoneNo.trim().isNotEmpty) sellerProfile.phoneNo.trim(),
      if (sellerProfile.email.trim().isNotEmpty) sellerProfile.email.trim(),
    ];
    final paymentLines = [
      if (sellerProfile.companyName.trim().isNotEmpty)
        'Business: ${sellerProfile.companyName.trim()}',
      if (sellerProfile.phoneNo.trim().isNotEmpty)
        'Phone: ${sellerProfile.phoneNo.trim()}',
      if (sellerProfile.email.trim().isNotEmpty)
        'Email: ${sellerProfile.email.trim()}',
    ];

    return _InvoiceDocumentData(
      order: order,
      sellerProfile: sellerProfile,
      theme: theme,
      template: template,
      logoImage: logoBytes == null ? null : pw.MemoryImage(logoBytes),
      lines: _InvoiceLineData.fromOrder(order, subtotal),
      customerLines: [
        bestCustomerTitle,
        if (order.companyName.trim().isNotEmpty &&
            order.companyName.trim() != bestCustomerTitle)
          order.companyName.trim(),
        if (order.email.trim().isNotEmpty) order.email.trim(),
        if (order.phoneNo.trim().isNotEmpty) order.phoneNo.trim(),
        if (order.shippingAddress.trim().isNotEmpty)
          order.shippingAddress.trim(),
      ],
      sellerLines: [
        bestSellerTitle,
        if (sellerProfile.companyName.trim().isNotEmpty &&
            sellerProfile.companyName.trim() != bestSellerTitle)
          sellerProfile.companyName.trim(),
        if (sellerProfile.email.trim().isNotEmpty) sellerProfile.email.trim(),
        if (sellerProfile.phoneNo.trim().isNotEmpty)
          sellerProfile.phoneNo.trim(),
        if (sellerProfile.address.trim().isNotEmpty)
          sellerProfile.address.trim(),
      ],
      contactLines: contactLines.isEmpty
          ? ['Seller contact details not provided']
          : contactLines,
      paymentLines: paymentLines.isEmpty
          ? ['Business payment details not provided']
          : paymentLines,
      termsLines: const [
        'Generated from completed order records in Stocker.',
        'Use this copy for billing, delivery confirmation, and bookkeeping.',
      ],
      subtotal: subtotal,
    );
  }

  final OrderRecord order;
  final AccountProfile sellerProfile;
  final _InvoiceTheme theme;
  final InvoiceTemplateOption template;
  final pw.MemoryImage? logoImage;
  final List<_InvoiceLineData> lines;
  final List<String> customerLines;
  final List<String> sellerLines;
  final List<String> contactLines;
  final List<String> paymentLines;
  final List<String> termsLines;
  final double subtotal;
}

class _InvoiceLineData {
  const _InvoiceLineData({
    required this.index,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.taxAmount,
  });

  static List<_InvoiceLineData> fromOrder(OrderRecord order, double subtotal) {
    final items = order.items.isEmpty
        ? [
            OrderLineItem(
              itemName: order.itemName,
              sku: order.sku,
              quantity: order.quantity == 0 ? 1 : order.quantity,
              unitPrice: order.unitPrice,
            ),
          ]
        : order.items;

    return items.asMap().entries.map((entry) {
      final lineTotal = entry.value.totalPrice;
      final taxShare = subtotal == 0
          ? 0.0
          : (order.taxAmount * (lineTotal / subtotal)).toDouble();
      return _InvoiceLineData(
        index: entry.key + 1,
        name: entry.value.itemName,
        quantity: entry.value.quantity,
        unitPrice: entry.value.unitPrice,
        total: entry.value.totalPrice,
        taxAmount: taxShare,
      );
    }).toList();
  }

  final int index;
  final String name;
  final int quantity;
  final double unitPrice;
  final double total;
  final double taxAmount;
}

class _InvoiceTheme {
  const _InvoiceTheme({
    required this.accent,
    required this.soft,
    required this.text,
    required this.muted,
    required this.line,
    required this.tableStripe,
    required this.tableHeader,
    required this.tableHeaderText,
    required this.onAccent,
    required this.onAccentMuted,
  });

  final PdfColor accent;
  final PdfColor soft;
  final PdfColor text;
  final PdfColor muted;
  final PdfColor line;
  final PdfColor tableStripe;
  final PdfColor tableHeader;
  final PdfColor tableHeaderText;
  final PdfColor onAccent;
  final PdfColor onAccentMuted;
}
