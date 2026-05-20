import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/screens/login.dart';
import 'package:ona_net/themes/app_theme.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark ? AppTheme.navyLight : AppTheme.white;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedTextColor = textColor.withValues(alpha: 0.65);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 36,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.08,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _OnaNetLogo(textColor: textColor),
                      const SizedBox(height: 10),
                      Text(
                        'Create Account',
                        style: GoogleFonts.urbanist(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Find better internet near you',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.urbanist(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: mutedTextColor,
                        ),
                      ),
                      SizedBox(height: 15),
                      AuthTextField(
                        label: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                      SizedBox(height: 15),
                      AuthTextField(
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      SizedBox(height: 15),
                      AuthTextField(
                        label: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        suffixIcon: Icon(Icons.visibility_outlined),
                      ),
                      SizedBox(height: 15),
                      AuthTextField(
                        label: 'Confirm Password',
                        icon: Icons.lock_reset_outlined,
                        obscureText: true,
                        suffixIcon: Icon(Icons.visibility_outlined),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              // TODO: handle sign up
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.amber,
                            foregroundColor: AppTheme.navy,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Sign Up',
                            style: GoogleFonts.urbanist(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.5),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'or',
                              style: GoogleFonts.urbanist(
                                color: mutedTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          onPressed: () {
                            // TODO: Google sign in
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.8),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Continue with Google',
                            style: GoogleFonts.urbanist(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: GoogleFonts.urbanist(
                              color: mutedTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const Login()),
                              );
                            },
                            child: Text(
                              'Sign in',
                              style: GoogleFonts.urbanist(
                                color: AppTheme.amber,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
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

class _OnaNetLogo extends StatelessWidget {
  final Color textColor;

  const _OnaNetLogo({required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            RichText(
              text: TextSpan(
                text: "O",
                style: GoogleFonts.urbanist(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  height: 1,
                  color: textColor,
                ),
              ),
            ),
            Positioned(
              top: -15,
              height: -1,
              child: Icon(Icons.wifi_rounded, color: Colors.amber),
            ),
          ],
        ),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "na",
                style: GoogleFonts.urbanist(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  height: 1,
                  color: textColor,
                ),
              ),
              TextSpan(
                text: "Net",
                style: GoogleFonts.urbanist(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  height: 1,
                  color: AppTheme.amber,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AuthTextField extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffixIcon;

  const AuthTextField({
    super.key,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedTextColor = textColor.withValues(alpha: 0.65);
    final fillColor = isDark ? AppTheme.navyMid : AppTheme.white;
    final borderColor = isDark
        ? AppTheme.offWhite.withValues(alpha: 0.18)
        : AppTheme.lightGray;

    return TextFormField(
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.urbanist(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.urbanist(
          color: mutedTextColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.urbanist(
          color: AppTheme.amber,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),

        prefixIcon: Icon(icon, color: mutedTextColor, size: 22),

        suffixIcon: suffixIcon == null
            ? null
            : IconTheme(
                data: IconThemeData(color: mutedTextColor, size: 22),
                child: suffixIcon!,
              ),

        filled: true,
        fillColor: fillColor,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor, width: 1.2),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.amber, width: 1.5),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.2),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}
