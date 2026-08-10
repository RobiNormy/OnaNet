import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/core/theme/app_theme.dart';
import 'package:ona_net/features/auth/data/auth_service.dart';
import 'package:ona_net/features/auth/presentation/login_screen.dart';
import 'package:ona_net/features/customer/presentation/home_screen.dart';
import 'package:ona_net/features/onboarding/data/onboarding_store.dart';
import 'package:ona_net/features/onboarding/presentation/onboarding_screen.dart';
import 'package:ona_net/features/provider_registration/presentation/registration_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.providerMode = false,
  });

  final String email;
  final bool providerMode;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _leaving = false;
  String? _message;
  late String _email = widget.email;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
  }

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final authService = AuthService();
      final refreshedEmail = await authService.refreshAccountEmail();
      if (refreshedEmail != null && refreshedEmail.trim().isNotEmpty) {
        _email = refreshedEmail.trim();
      }
      await authService.startEmailVerification();
      if (mounted) {
        setState(() => _message = 'A verification code was sent to $_email.');
      }
    } on AuthServiceException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeEmail() async {
    _emailController.text = _email;
    final newEmail = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change email'),
        content: TextField(
          controller: _emailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Correct email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _emailController.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (newEmail == null || !mounted) return;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(newEmail)) {
      setState(() => _message = 'Enter a valid email address.');
      return;
    }
    if (newEmail.toLowerCase() == _email.toLowerCase()) return;

    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await AuthService().requestEmailChange(newEmail);
      if (mounted) {
        setState(() {
          _message =
              'A confirmation link was sent to $newEmail. Open it, then come back and tap Resend code.';
        });
      }
    } on AuthServiceException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _message = 'Enter the verification code from your email.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await AuthService().verifyEmailVerification(code);
      if (!mounted) return;
      final onboardingCompleted = await OnboardingStore.isCompleted();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => onboardingCompleted
              ? (widget.providerMode
                    ? const ProviderReg()
                    : const AuthenticatedLanding())
              : const OnboardingScreen(),
        ),
        (route) => false,
      );
    } on AuthServiceException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _backToLogin() async {
    if (_leaving) return;
    _leaving = true;
    try {
      await AuthService().signOut();
    } finally {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => Login(providerMode: widget.providerMode),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _backToLogin();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.mark_email_read_rounded,
                          size: 52,
                          color: AppTheme.amber,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Verify your email',
                          style: GoogleFonts.urbanist(
                            color: textColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Enter the code sent to $_email. You need to verify your email before continuing.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.urbanist(
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _loading ? null : _changeEmail,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Wrong email? Change it'),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _codeController,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          maxLength: 8,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.urbanist(
                            fontSize: 24,
                            letterSpacing: 8,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Verification code',
                            counterText: '',
                          ),
                          onSubmitted: (_) => _verify(),
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.urbanist(
                              color: textColor.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _verify,
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Verify email'),
                          ),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _sendCode,
                          child: const Text('Resend code'),
                        ),
                        TextButton.icon(
                          onPressed: _loading || _leaving ? null : _backToLogin,
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Back to login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
