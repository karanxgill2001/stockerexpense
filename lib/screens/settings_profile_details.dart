import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/account_profile.dart';
import '../services/google_sheet_service.dart';
import '../services/session_service.dart';
import '../widgets/app_message.dart';

class SettingsProfileDetailsScreen extends StatefulWidget {
  const SettingsProfileDetailsScreen({super.key, required this.profile});

  final AccountProfile profile;

  @override
  State<SettingsProfileDetailsScreen> createState() =>
      _SettingsProfileDetailsScreenState();
}

class _SettingsProfileDetailsScreenState
    extends State<SettingsProfileDetailsScreen> {
  static const Color _surface = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _surfaceLowest = Colors.white;
  static const Color _surfaceContainer = Color(0xFFECEEEC);
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF3F4945);
  static const Color _outlineVariant = Color(0xFFBFC9C4);

  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneNoController = TextEditingController();
  final TextEditingController _masterKeyController = TextEditingController();

  late String _currentEmail;
  bool _isSaving = false;
  bool _obscureMasterKey = true;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _currentEmail = profile.email.trim().toLowerCase();
    _companyNameController.text = profile.companyName;
    _fullNameController.text = profile.fullName;
    _addressController.text = profile.address;
    _emailController.text = profile.email;
    _phoneNoController.text = profile.phoneNo;
    _masterKeyController.text = profile.masterKey;
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _fullNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneNoController.dispose();
    _masterKeyController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: _surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final companyName = _companyNameController.text.trim();
    final fullName = _fullNameController.text.trim();
    final address = _addressController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final phoneNo = _phoneNoController.text.trim();
    final masterKey = _masterKeyController.text.trim();

    if (companyName.isEmpty ||
        fullName.isEmpty ||
        address.isEmpty ||
        email.isEmpty ||
        phoneNo.isEmpty) {
      AppMessage.showError(
        context,
        'Please fill in company name, your name, address, email, and phone number.',
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      AppMessage.showError(context, 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedProfile = await GoogleSheetService.instance
          .updateAccountProfile(
            currentEmail: _currentEmail,
            companyName: companyName,
            fullName: fullName,
            address: address,
            email: email,
            phoneNo: phoneNo,
            masterKey: masterKey,
          );

      await SessionService.updateStoredProfile(
        email: updatedProfile.email,
        fullName: updatedProfile.fullName,
        companyName: updatedProfile.companyName,
        address: updatedProfile.address,
        phoneNo: updatedProfile.phoneNo,
        canManageFinanceEntries: updatedProfile.canManageFinanceEntries,
      );

      if (!mounted) {
        return;
      }

      _currentEmail = updatedProfile.email.trim().toLowerCase();
      AppMessage.showSuccess(context, 'Profile updated successfully.');
      Navigator.of(context).pop(updatedProfile);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppMessage.showError(context, error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _copyMasterKey() async {
    final masterKey = _masterKeyController.text.trim();
    if (masterKey.isEmpty) {
      AppMessage.showError(context, 'Create a master key first.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: masterKey));
    if (!mounted) {
      return;
    }

    AppMessage.showInfo(context, 'Master key copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCreatingMasterKey = widget.profile.masterKey.trim().isEmpty;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Profile'),
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
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: _primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Business Profile',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: _textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage company details and create the master key used for password recovery.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileField(
                        label: 'Company Name',
                        child: TextField(
                          controller: _companyNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _fieldDecoration('North Harbor Trading'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProfileField(
                        label: 'Your Name',
                        child: TextField(
                          controller: _fullNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _fieldDecoration('Ariana Cole'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ProfileField(
                  label: 'Address',
                  child: TextField(
                    controller: _addressController,
                    minLines: 2,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _fieldDecoration(
                      '45 Riverside Avenue, Houston, TX',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileField(
                        label: 'Email',
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _fieldDecoration('ops@northharbor.com'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProfileField(
                        label: 'Phone No',
                        child: TextField(
                          controller: _phoneNoController,
                          keyboardType: TextInputType.phone,
                          decoration: _fieldDecoration('+1 555 0199'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ProfileField(
                  label: isCreatingMasterKey
                      ? 'Create Master Key'
                      : 'Master Key',
                  child: TextField(
                    controller: _masterKeyController,
                    obscureText: _obscureMasterKey,
                    decoration:
                        _fieldDecoration(
                          'Create or update your master key',
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscureMasterKey = !_obscureMasterKey;
                              });
                            },
                            icon: Icon(
                              _obscureMasterKey
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: _textSecondary,
                            ),
                          ),
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This master key is saved directly in the credentials sheet and can be copied when you need it.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _copyMasterKey,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: _outlineVariant),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy Master Key'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.1,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Save Profile'),
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

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: _SettingsProfileDetailsScreenState._textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
