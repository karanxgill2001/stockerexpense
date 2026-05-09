import 'package:flutter/material.dart';

import '../services/google_sheet_service.dart';
import '../widgets/app_message.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneNoController = TextEditingController();
  final TextEditingController _masterKeyController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureMasterKey = true;
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _companyNameController.dispose();
    _fullNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneNoController.dispose();
    _masterKeyController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateAccount() async {
    final companyName = _companyNameController.text.trim();
    final fullName = _fullNameController.text.trim();
    final address = _addressController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final phoneNo = _phoneNoController.text.trim();
    final masterKey = _masterKeyController.text;
    final password = _passwordController.text;

    if (companyName.isEmpty ||
        fullName.isEmpty ||
        address.isEmpty ||
        email.isEmpty ||
        phoneNo.isEmpty ||
        masterKey.isEmpty ||
        password.isEmpty) {
      AppMessage.showError(
        context,
        'Please fill in company name, your name, address, email, phone number, master key, and password.',
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      AppMessage.showError(context, 'Please enter a valid email address.');
      return;
    }

    if (password.length < 6) {
      AppMessage.showError(context, 'Password must be at least 6 characters.');
      return;
    }

    if (masterKey.length < 4) {
      AppMessage.showError(
        context,
        'Master key must be at least 4 characters.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await GoogleSheetService.instance.createAccount(
        companyName: companyName,
        fullName: fullName,
        address: address,
        email: email,
        phoneNo: phoneNo,
        masterKey: masterKey,
        password: password,
      );

      if (!mounted) {
        return;
      }

      AppMessage.showSuccess(context, 'Account created successfully.');
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
      backgroundColor: const Color(0xFFF8FAF7),
      body: Stack(
        children: [
          const Positioned.fill(child: _CreateAccountBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stocker Expense Tracker',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: const Color(0xFF00342D),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 54),
                      const _CreateAccountHeroCard(),
                      const SizedBox(height: 44),
                      Text(
                        'Create Account',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: const Color(0xFF00342D),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.9,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Join the elite network of professional inventory managers.',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF2C3934),
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 34),
                      const _CreateAccountLabel(label: 'COMPANY NAME'),
                      const SizedBox(height: 10),
                      _CreateAccountInput(
                        controller: _companyNameController,
                        hintText: 'North Harbor Trading',
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 26),
                      const _CreateAccountLabel(label: 'FULL NAME'),
                      const SizedBox(height: 10),
                      _CreateAccountInput(
                        controller: _fullNameController,
                        hintText: 'Evelyn Thorne',
                        keyboardType: TextInputType.name,
                      ),
                      const SizedBox(height: 26),
                      const _CreateAccountLabel(label: 'ADDRESS'),
                      const SizedBox(height: 10),
                      _CreateAccountInput(
                        controller: _addressController,
                        hintText: '45 Riverside Avenue, Houston, TX',
                        keyboardType: TextInputType.streetAddress,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 26),
                      const _CreateAccountLabel(label: 'EMAIL ADDRESS'),
                      const SizedBox(height: 10),
                      _CreateAccountInput(
                        controller: _emailController,
                        hintText: 'e.thorne@stockerinventory.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 26),
                      const _CreateAccountLabel(label: 'PHONE NO'),
                      const SizedBox(height: 10),
                      _CreateAccountInput(
                        controller: _phoneNoController,
                        hintText: '+1 555 0199',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 26),
                      const _CreateAccountLabel(label: 'MASTER KEY'),
                      const SizedBox(height: 10),
                      _CreateAccountInput(
                        controller: _masterKeyController,
                        hintText: 'Used later for password reset',
                        obscureText: _obscureMasterKey,
                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureMasterKey = !_obscureMasterKey;
                            });
                          },
                          icon: Icon(
                            _obscureMasterKey
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF4B5752),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      const _CreateAccountLabel(label: 'PASSWORD'),
                      const SizedBox(height: 10),
                      _CreateAccountInput(
                        controller: _passwordController,
                        hintText: '••••••••••••',
                        obscureText: _obscurePassword,
                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF4B5752),
                          ),
                        ),
                      ),
                      const SizedBox(height: 54),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : _handleCreateAccount,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00342D),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(72),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          iconAlignment: IconAlignment.end,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.arrow_forward, size: 22),
                          label: Text(
                            _isSubmitting ? 'Saving...' : 'Create Account',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 56),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text(
                              'Already have an account?',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF2A3933),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                '/login',
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF00342D),
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Login',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: const Color(0xFF00342D),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 64),
                      Container(
                        height: 1,
                        color: const Color(0xFFBFC9C4).withValues(alpha: 0.28),
                      ),
                      const SizedBox(height: 36),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'KARAN',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: const Color(0xFF2E3733),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3.0,
                              ),
                            ),
                            const SizedBox(height: 10),
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

class _CreateAccountBackground extends StatelessWidget {
  const _CreateAccountBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFF8FAF7),
                  const Color(0xFFF7FAF7),
                  const Color(0xFFF3F8F5),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -30,
          left: 0,
          right: 0,
          child: Container(
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEEE7).withValues(alpha: 0.72),
            ),
          ),
        ),
        Positioned(
          top: 108,
          right: -70,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0C6F60).withValues(alpha: 0.08),
            ),
          ),
        ),
        Positioned(
          bottom: -110,
          right: -60,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0C6F60).withValues(alpha: 0.08),
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateAccountHeroCard extends StatelessWidget {
  const _CreateAccountHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF004D43), Color(0xFF00342D)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HeroFacetPainter())),
          Padding(
            padding: const EdgeInsets.fromLTRB(42, 0, 42, 38),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Secure your\nassets today.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.14,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFacetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paints = [
      Paint()..color = const Color(0xFF0A5C50).withValues(alpha: 0.42),
      Paint()..color = const Color(0xFF0F6B5F).withValues(alpha: 0.34),
      Paint()..color = const Color(0xFF073A33).withValues(alpha: 0.46),
      Paint()..color = const Color(0xFF12584F).withValues(alpha: 0.28),
    ];

    final paths = [
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width * 0.28, 0)
        ..lineTo(size.width * 0.22, size.height * 0.32)
        ..lineTo(size.width * 0.04, size.height * 0.2)
        ..close(),
      Path()
        ..moveTo(size.width * 0.18, 0)
        ..lineTo(size.width * 0.54, 0)
        ..lineTo(size.width * 0.46, size.height * 0.26)
        ..lineTo(size.width * 0.3, size.height * 0.18)
        ..close(),
      Path()
        ..moveTo(size.width * 0.52, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width * 0.84, size.height * 0.3)
        ..lineTo(size.width * 0.66, size.height * 0.18)
        ..close(),
      Path()
        ..moveTo(0, size.height * 0.2)
        ..lineTo(size.width * 0.26, size.height * 0.34)
        ..lineTo(size.width * 0.12, size.height * 0.7)
        ..lineTo(0, size.height * 0.58)
        ..close(),
      Path()
        ..moveTo(size.width * 0.22, size.height * 0.34)
        ..lineTo(size.width * 0.48, size.height * 0.22)
        ..lineTo(size.width * 0.56, size.height * 0.58)
        ..lineTo(size.width * 0.3, size.height * 0.72)
        ..close(),
      Path()
        ..moveTo(size.width * 0.48, size.height * 0.22)
        ..lineTo(size.width * 0.82, size.height * 0.28)
        ..lineTo(size.width * 0.72, size.height * 0.58)
        ..lineTo(size.width * 0.56, size.height * 0.58)
        ..close(),
      Path()
        ..moveTo(size.width * 0.82, size.height * 0.28)
        ..lineTo(size.width, size.height * 0.16)
        ..lineTo(size.width, size.height * 0.62)
        ..lineTo(size.width * 0.74, size.height * 0.6)
        ..close(),
      Path()
        ..moveTo(0, size.height * 0.58)
        ..lineTo(size.width * 0.12, size.height * 0.7)
        ..lineTo(size.width * 0.08, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Path()
        ..moveTo(size.width * 0.12, size.height * 0.7)
        ..lineTo(size.width * 0.3, size.height * 0.72)
        ..lineTo(size.width * 0.24, size.height)
        ..lineTo(size.width * 0.08, size.height)
        ..close(),
      Path()
        ..moveTo(size.width * 0.3, size.height * 0.72)
        ..lineTo(size.width * 0.56, size.height * 0.58)
        ..lineTo(size.width * 0.6, size.height)
        ..lineTo(size.width * 0.24, size.height)
        ..close(),
      Path()
        ..moveTo(size.width * 0.56, size.height * 0.58)
        ..lineTo(size.width * 0.74, size.height * 0.6)
        ..lineTo(size.width * 0.9, size.height)
        ..lineTo(size.width * 0.6, size.height)
        ..close(),
      Path()
        ..moveTo(size.width * 0.74, size.height * 0.6)
        ..lineTo(size.width, size.height * 0.62)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width * 0.9, size.height)
        ..close(),
    ];

    for (var index = 0; index < paths.length; index += 1) {
      canvas.drawPath(paths[index], paints[index % paints.length]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CreateAccountLabel extends StatelessWidget {
  const _CreateAccountLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: const Color(0xFF252F2B),
        fontWeight: FontWeight.w800,
        letterSpacing: 2.8,
      ),
    );
  }
}

class _CreateAccountInput extends StatelessWidget {
  const _CreateAccountInput({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.suffix,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: const Color(0xFF56625D),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: const Color(0xFF74807B),
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFE7E9E6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 24,
        ),
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
          borderSide: const BorderSide(color: Color(0xFF046B5E), width: 2),
        ),
        suffixIcon: suffix,
      ),
    );
  }
}
