import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/core/theme/app_theme.dart';
import 'package:ona_net/features/auth/data/auth_service.dart';
import 'package:ona_net/features/customer/presentation/home_screen.dart';
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
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await AuthService().startEmailVerification();
      if (mounted) {
        setState(() => _message = 'A verification code was sent to your email.');
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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => widget.providerMode
              ? const ProviderReg()
              : const AuthenticatedLanding(),
        ),
        (route) => false,
      );
    } on AuthServiceException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    return Scaffold(
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
                      const Icon(Icons.mark_email_read_rounded,
                          size: 52, color: AppTheme.amber),
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
                        'Enter the code sent to ${widget.email}. You need to verify your email before continuing.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.urbanist(color: textColor.withValues(alpha: 0.7)),
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
                          style: GoogleFonts.urbanist(color: textColor.withValues(alpha: 0.75)),
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
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Verify email'),
                        ),
                      ),
                      TextButton(
                        onPressed: _loading ? null : _sendCode,
                        child: const Text('Resend code'),
                      ),
                    ],
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
