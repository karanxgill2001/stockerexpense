import 'package:flutter/material.dart';

class SettingsLegalDetailsScreen extends StatelessWidget {
  const SettingsLegalDetailsScreen({
    super.key,
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String intro;
  final List<LegalSectionContent> sections;

  static const Color _surface = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _surfaceLowest = Colors.white;
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF3F4945);

  static SettingsLegalDetailsScreen privacy() {
    return SettingsLegalDetailsScreen(
      title: 'Privacy',
      intro:
          'This page explains how Stocker handles account data, stock records, and order information inside the app and connected Google Sheets.',
      sections: const [
        LegalSectionContent(
          heading: 'Information We Store',
          body:
              'Stocker stores the details you enter for account access, inventory items, orders, tax settings, notification history, and session preferences. Customer stock and order data are saved to the Google Sheets backend that you configure in Settings.',
        ),
        LegalSectionContent(
          heading: 'How Data Is Used',
          body:
              'Your data is used only to run inventory management features such as sign in, create account, stock updates, checkout, order history, notifications, and profile management. The app does not include an in-app advertising or analytics layer.',
        ),
        LegalSectionContent(
          heading: 'Local Device Storage',
          body:
              'Some values are stored locally on the device to improve usability, including sign-in state, backend link overrides, saved tax percentage, low-stock alert history, and bell notification entries. Removing app data from the device will clear those local values.',
        ),
        LegalSectionContent(
          heading: 'Your Responsibility',
          body:
              'You are responsible for protecting access to the connected Google account, Google Sheets, Apps Script web apps, and any device running Stocker. Share backend links and credentials only with trusted people.',
        ),
      ],
    );
  }

  static SettingsLegalDetailsScreen terms() {
    return SettingsLegalDetailsScreen(
      title: 'Terms & Conditions',
      intro:
          'These terms describe the basic rules for using Stocker to manage business inventory and order workflows.',
      sections: const [
        LegalSectionContent(
          heading: 'Acceptable Use',
          body:
              'Use Stocker only for lawful inventory and order management. You should not use the app to store misleading, harmful, or unauthorized business records.',
        ),
        LegalSectionContent(
          heading: 'Accuracy of Records',
          body:
              'You are responsible for verifying that product details, stock quantities, customer fields, tax settings, shipping values, and order information entered into the app are correct before saving.',
        ),
        LegalSectionContent(
          heading: 'Backend Control',
          body:
              'The app depends on Google Apps Script and Google Sheets backends. If those services are changed, deleted, misconfigured, or shared improperly, parts of the app may stop working. Keep your deployed scripts and spreadsheets maintained and accessible.',
        ),
        LegalSectionContent(
          heading: 'Operational Responsibility',
          body:
              'Stocker helps record and organize transactions, but final business decisions, tax compliance, invoicing, customer communication, and regulatory obligations remain your responsibility.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _surfaceLowest,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1200342D),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: _textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  intro,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                ...sections.map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.heading,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: _textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          section.body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
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
}

class LegalSectionContent {
  const LegalSectionContent({required this.heading, required this.body});

  final String heading;
  final String body;
}
