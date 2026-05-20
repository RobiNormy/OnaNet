import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/themes/app_theme.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
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
                constraints: BoxConstraints(maxWidth: 432),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  padding: EdgeInsets.symmetric(
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
                      key:_formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _OnaNetLogo(textColor: textColor),
                          SizedBox(height: 10,),
                          Text(
                            "Welcome Back",
                            style: GoogleFonts.urbanist(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            "Sign in to continue",
                            style: GoogleFonts.urbanist(
                              fontSize: 15,
                              color: mutedTextColor,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const LoginAuth(
                            label: "Email Address",
                            myIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            obscureText: false,
                          ),
                          const SizedBox(height: 16),
                          const LoginAuth(
                            label: "Password",
                            myIcon: Icons.lock_outline_rounded,
                            obscureText: true,
                            suffixIcon: Icon(Icons.visibility_off_outlined),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.amber,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              "Login",
                              style: GoogleFonts.urbanist(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.navy,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: GoogleFonts.urbanist(
                                color: mutedTextColor,
                                fontSize: 15,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Text(
                                "Sign Up",
                                style: GoogleFonts.urbanist(
                                  color: AppTheme.amber,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        ],
                      )
                  ),
                ),
              ),
            ),
          )
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

class LoginAuth extends StatelessWidget {
  const LoginAuth({
    super.key,
    required this.label,
    required this.myIcon,
    this.keyboardType = TextInputType.text,
    required this.obscureText,
    this.suffixIcon,

  });

  final String label;
  final IconData myIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffixIcon;

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
        prefixIcon: Icon(myIcon, color: mutedTextColor, size: 22),
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
