import 'package:shared_preferences/shared_preferences.dart';

class InvoiceTemplateOption {
  const InvoiceTemplateOption({
    required this.id,
    required this.name,
    required this.summary,
  });

  final int id;
  final String name;
  final String summary;
}

class InvoiceTemplateSettingsService {
  const InvoiceTemplateSettingsService._();

  static const int defaultTemplateId = 1;
  static const String _selectedTemplateKey = 'selected_invoice_template_id';

  static const List<InvoiceTemplateOption> options = [
    InvoiceTemplateOption(
      id: 1,
      name: 'Template 1',
      summary: 'Balanced layout with a clean header and compact totals.',
    ),
    InvoiceTemplateOption(
      id: 2,
      name: 'Template 2',
      summary: 'Bordered statement look with a clear metadata bar.',
    ),
    InvoiceTemplateOption(
      id: 3,
      name: 'Template 3',
      summary: 'Bold blue style with stronger section emphasis.',
    ),
    InvoiceTemplateOption(
      id: 4,
      name: 'Template 4',
      summary: 'Soft card presentation with rounded blocks and muted tones.',
    ),
    InvoiceTemplateOption(
      id: 5,
      name: 'Template 5',
      summary: 'Dark hero style with stronger contrast and footer banding.',
    ),
  ];

  static InvoiceTemplateOption optionForId(int? id) {
    return options.firstWhere(
      (option) => option.id == id,
      orElse: () => options.first,
    );
  }

  static Future<int> getSelectedTemplateId() async {
    final preferences = await SharedPreferences.getInstance();
    final storedId = preferences.getInt(_selectedTemplateKey);
    return optionForId(storedId).id;
  }

  static Future<InvoiceTemplateOption> getSelectedTemplate() async {
    return optionForId(await getSelectedTemplateId());
  }

  static Future<void> setSelectedTemplateId(int id) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_selectedTemplateKey, optionForId(id).id);
  }
}