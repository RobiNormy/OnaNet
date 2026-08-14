import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/core/theme/app_theme.dart';
import 'package:ona_net/features/auth/data/auth_service.dart';
import 'package:ona_net/features/auth/presentation/login_screen.dart';
import 'package:ona_net/features/customer/presentation/home_screen.dart';
import 'package:ona_net/features/onboarding/data/onboarding_store.dart';
import 'package:ona_net/features/onboarding/presentation/onboarding_screen.dart';
import 'package:ona_net/features/provider_registration/presentation/registration_screen.dart';
import 'package:ona_net/features/auth/presentation/sign_up_screen.dart';

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
  bool _loading = false;
  bool _leaving = false;
  String? _message = 'We sent a secure verification link to your email.';
  late final String _email = widget.email;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _sendLink() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await AuthService().startEmailVerification(email: _email);
      if (mounted) {
        setState(
          () => _message = 'A new verification link was sent to $_email.',
        );
      }
    } on AuthServiceException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeEmail() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => SignUp(providerMode: widget.providerMode),
      ),
      (route) => false,
    );
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final verified = await AuthService().completeEmailVerification();
      if (!verified) {
        if (mounted) {
          setState(() {
            _message =
                'Open the link in your email first, then return here and continue.';
          });
        }
        return;
      }
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
                          'Open the verification link sent to $_email, then return to OnaNet and continue.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.urbanist(
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _loading ? null : _changeEmail,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Wrong email? Start again'),
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
                                : const Text('I verified my email — Continue'),
                          ),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _sendLink,
                          child: const Text('Resend verification link'),
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
