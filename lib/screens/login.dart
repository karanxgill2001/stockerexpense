import 'package:flutter/material.dart';

import '../services/app_mode_service.dart';
import '../services/finance_tracker_service.dart';
import '../services/google_sheet_service.dart';
import '../services/session_service.dart';
import '../widgets/app_message.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool keepSignedIn = false;
  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isSigningIn = false;

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final email = _loginIdController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email and password.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSigningIn = true;
    });

    try {
      final previousEmail = await SessionService.getUserEmail();
      final account = await GoogleSheetService.instance.authenticateAccount(
        email: email,
        password: password,
      );

      if ((previousEmail ?? '').trim().toLowerCase() != email) {
        GoogleSheetService.instance.clearCache();
        await FinanceTrackerService.clearLocalCache();
      }

      await SessionService.saveLogin(
        keepSignedIn: keepSignedIn,
        email: email,
        fullName: account.fullName,
        companyName: account.companyName,
        address: account.address,
        phoneNo: account.phoneNo,
        canManageFinanceEntries: account.canManageFinanceEntries,
      );
      await AppModeService.enforceAccess(account.accessScope);

      if (!mounted) {
        return;
      }

      Navigator.pushReplacementNamed(context, '/home');
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final resetCompleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            _ForgotPasswordScreen(initialEmail: _loginIdController.text.trim()),
      ),
    );

    if (resetCompleted != true || !mounted) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _passwordController.clear();
    });

    AppMessage.showSuccess(
      context,
      'Password reset successfully. Sign in with the new password.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAF7),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFFF8FAF7), const Color(0xFFF0F4F1)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: const Color(0xFF004D43).withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _ArchitecturalPainter())),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF0D2445,
                              ).withValues(alpha: 0.20),
                              blurRadius: 30,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/images/stocker_expense_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Stocker Expense Tracker',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          color: const Color(0xFF00342D),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track stock, sales, and inventory in one place.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF3F4945),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 36),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF00342D,
                              ).withValues(alpha: 0.08),
                              blurRadius: 36,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome Back',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: const Color(0xFF191C1B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Please enter your credentials to access your inventory dashboard.',
                              style: theme.textTheme.titleMedium?.copyWith(
                                height: 1.45,
                                color: const Color(0xFF3F4945),
                              ),
                            ),
                            const SizedBox(height: 28),
                            _FieldLabel(label: 'EMAIL ADDRESS'),
                            const SizedBox(height: 10),
                            _LedgerInput(
                              controller: _loginIdController,
                              icon: Icons.person,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                const Expanded(
                                  child: _FieldLabel(label: 'PASSWORD'),
                                ),
                                TextButton(
                                  onPressed: _handleForgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Text(
                                    'Forgot Password?',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: const Color(0xFF00342D),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _LedgerInput(
                              controller: _passwordController,
                              icon: Icons.lock,
                              obscureText: true,
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                _errorMessage!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFFBA1A1A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 26),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(
                                    () => keepSignedIn = !keepSignedIn,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 42,
                                    height: 24,
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: keepSignedIn
                                          ? const Color(0xFF00342D)
                                          : const Color(0xFFE1E3E0),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Align(
                                      alignment: keepSignedIn
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  'Keep me signed in',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF3F4945),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isSigningIn ? null : _handleSignIn,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF00342D),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(64),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isSigningIn
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        'Sign In',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Use the email and password saved from Create Account.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF526772),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 30),
                            Divider(
                              height: 1,
                              color: const Color(
                                0xFFBFC9C4,
                              ).withValues(alpha: 0.28),
                            ),
                            const SizedBox(height: 28),
                            Center(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  Text(
                                    'New to Stocker Expense Tracker?',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: const Color(0xFF3F4945),
                                        ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pushReplacementNamed(
                                          context,
                                          '/create-account',
                                        ),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Create Account',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: const Color(0xFF00342D),
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      LayoutBuilder(
                        builder: (context, constraints) => Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: const Color(0xFFB6BDB8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'KARAN',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: const Color(0xFF9AA39E),
                                    letterSpacing: constraints.maxWidth < 340
                                        ? 2.5
                                        : 4,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: const Color(0xFFB6BDB8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Signature by KARAN',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF7B8480),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: const Color(0xFF3F4945),
        fontWeight: FontWeight.w700,
        letterSpacing: 2.8,
      ),
    );
  }
}

class _LedgerInput extends StatelessWidget {
  const _LedgerInput({
    this.controller,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController? controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: const Color(0xFF616A65),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFE7E9E6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 24,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Icon(icon, color: const Color(0xFFA2AAA5), size: 30),
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 24,
          minHeight: 24,
        ),
      ),
    );
  }
}

class _ArchitecturalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final diagonal = Paint()..color = const Color(0xFFE1E8E3);
    final path = Path()
      ..moveTo(size.width * 0.78, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.76, size.height * 0.32)
      ..lineTo(size.width * 0.58, size.height * 0.32)
      ..close();
    canvas.drawPath(path, diagonal);

    final bottomPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.78)
      ..lineTo(size.width * 0.16, size.height * 0.58)
      ..lineTo(size.width * 0.16, size.height)
      ..close();
    canvas.drawPath(bottomPath, diagonal);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ForgotPasswordScreen extends StatefulWidget {
  const _ForgotPasswordScreen({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<_ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _masterKeyController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSubmitting = false;
  bool _obscureMasterKey = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _masterKeyController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim().toLowerCase();
    final masterKey = _masterKeyController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty ||
        masterKey.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        _errorMessage =
            'Enter email, master key, new password, and confirm password.';
      });
      return;
    }

    if (newPassword.length < 6) {
      setState(() {
        _errorMessage = 'New password must be at least 6 characters.';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = 'New password and confirm password do not match.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
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

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  InputDecoration _decoration({
    required String hintText,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: const Color(0xFFE7E9E6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF00342D), width: 1.2),
      ),
      suffixIcon: suffixIcon == null
          ? null
          : IconButton(
              onPressed: onSuffixTap,
              icon: Icon(suffixIcon, color: const Color(0xFF5D655F)),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAF7),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFFF8FAF7), const Color(0xFFF0F4F1)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: const Color(0xFF004D43).withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _ArchitecturalPainter())),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(false),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: const Color(0xFF00342D),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Forgot Password',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF00342D),
                                letterSpacing: -0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF00342D,
                              ).withValues(alpha: 0.08),
                              blurRadius: 36,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reset Password',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: const Color(0xFF191C1B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Reset your password using the account email and master key saved in Google Sheets.',
                              style: theme.textTheme.titleMedium?.copyWith(
                                height: 1.45,
                                color: const Color(0xFF3F4945),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const _FieldLabel(label: 'EMAIL ADDRESS'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _decoration(
                                hintText: 'Enter your account email',
                              ),
                            ),
                            const SizedBox(height: 16),
                            const _FieldLabel(label: 'MASTER KEY'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _masterKeyController,
                              obscureText: _obscureMasterKey,
                              decoration: _decoration(
                                hintText: 'Enter master key',
                                suffixIcon: _obscureMasterKey
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                onSuffixTap: () {
                                  setState(() {
                                    _obscureMasterKey = !_obscureMasterKey;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            const _FieldLabel(label: 'NEW PASSWORD'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _newPasswordController,
                              obscureText: _obscureNewPassword,
                              decoration: _decoration(
                                hintText: 'Minimum 6 characters',
                                suffixIcon: _obscureNewPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                onSuffixTap: () {
                                  setState(() {
                                    _obscureNewPassword = !_obscureNewPassword;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            const _FieldLabel(label: 'CONFIRM PASSWORD'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: _decoration(
                                hintText: 'Repeat new password',
                                suffixIcon: _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                onSuffixTap: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                _errorMessage!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFFBA1A1A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isSubmitting ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF00342D),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text('Reset Password'),
                              ),
                            ),
                          ],
                        ),
                      ),
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
