import 'package:flutter/material.dart';

import '../services/google_sheet_service.dart';
import '../widgets/app_message.dart';

class SettingsSecurityDetailsScreen extends StatefulWidget {
  const SettingsSecurityDetailsScreen({super.key, required this.email});

  final String email;

  @override
  State<SettingsSecurityDetailsScreen> createState() =>
      _SettingsSecurityDetailsScreenState();
}

class _SettingsSecurityDetailsScreenState
    extends State<SettingsSecurityDetailsScreen> {
  static const Color _surface = Color(0xFFF8FAF7);
  static const Color _primary = Color(0xFF00342D);
  static const Color _surfaceLowest = Colors.white;
  static const Color _surfaceContainer = Color(0xFFECEEEC);
  static const Color _textPrimary = Color(0xFF191C1B);
  static const Color _textSecondary = Color(0xFF3F4945);

  final TextEditingController _masterKeyController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSubmitting = false;
  bool _obscureMasterKey = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _masterKeyController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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

  Future<void> _resetPassword() async {
    final email = widget.email.trim().toLowerCase();
    final masterKey = _masterKeyController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty) {
      AppMessage.showError(context, 'Account email is missing.');
      return;
    }

    if (masterKey.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      AppMessage.showError(
        context,
        'Enter master key, new password, and confirm password.',
      );
      return;
    }

    if (newPassword.length < 6) {
      AppMessage.showError(
        context,
        'New password must be at least 6 characters.',
      );
      return;
    }

    if (newPassword != confirmPassword) {
      AppMessage.showError(
        context,
        'New password and confirm password do not match.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await GoogleSheetService.instance.resetAccountPassword(
        email: email,
        masterKey: masterKey,
        newPassword: newPassword,
      );

      if (!mounted) {
        return;
      }

      AppMessage.showSuccess(context, 'Password reset successfully.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppMessage.showError(context, error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
        title: const Text('Security'),
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
                  'Reset Password',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: _textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use the master key saved in your credentials sheet to replace the current account password.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                _SecurityField(
                  label: 'Master Key',
                  child: TextField(
                    controller: _masterKeyController,
                    obscureText: _obscureMasterKey,
                    decoration: _fieldDecoration('Enter master key').copyWith(
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SecurityField(
                        label: 'New Password',
                        child: TextField(
                          controller: _newPasswordController,
                          obscureText: _obscureNewPassword,
                          decoration: _fieldDecoration('Minimum 6 characters')
                              .copyWith(
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscureNewPassword =
                                          !_obscureNewPassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscureNewPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: _textSecondary,
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SecurityField(
                        label: 'Confirm Password',
                        child: TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: _fieldDecoration('Repeat new password')
                              .copyWith(
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: _textSecondary,
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _resetPassword,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: _isSubmitting
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
                        : const Icon(Icons.lock_reset_rounded),
                    label: const Text('Reset Password'),
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

class _SecurityField extends StatelessWidget {
  const _SecurityField({required this.label, required this.child});

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
            color: _SettingsSecurityDetailsScreenState._textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
