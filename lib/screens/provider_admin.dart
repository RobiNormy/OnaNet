import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/provider/registration.dart';
import 'package:ona_net/screens/sign_up.dart';
import 'package:ona_net/themes/app_theme.dart';

class ProviderAdminScreen extends StatefulWidget {
  const ProviderAdminScreen({super.key});

  static String id = "main";

  @override
  State<ProviderAdminScreen> createState() => _ProviderAdminScreenState();
}

class _ProviderAdminScreenState extends State<ProviderAdminScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openCustomer() {
    _pushCleanRoute(context, const SignUp());
  }

  void _openProvider() {
    _pushCleanRoute(context, const ProviderReg());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedColor = isDark ? AppTheme.gray : AppTheme.darkGray;
    final background = isDark ? AppTheme.navy : const Color(0xFFF7F9FC);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SignalFieldPainter(
                      progress: Curves.easeOutCubic.transform(
                        _controller.value,
                      ),
                      isDark: isDark,
                    ),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _StaggeredFade(
                            controller: _controller,
                            start: 0,
                            child: _BrandMark(textColor: textColor),
                          ),
                          const SizedBox(height: 34),
                          _StaggeredFade(
                            controller: _controller,
                            start: 0.1,
                            child: Text(
                              'Choose how you want to use OnaNet',
                              style: GoogleFonts.plusJakartaSans(
                                color: textColor,
                                fontSize: 30,
                                height: 1.08,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _StaggeredFade(
                            controller: _controller,
                            start: 0.18,
                            child: Text(
                              'Find internet for your home, or manage customers as a provider.',
                              style: GoogleFonts.urbanist(
                                color: mutedColor.withValues(alpha: 0.82),
                                fontSize: 15,
                                height: 1.45,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          _StaggeredFade(
                            controller: _controller,
                            start: 0.28,
                            child: _ChoiceTile(
                              title: 'Customer',
                              subtitle:
                                  'Compare packages and request installation',
                              icon: Icons.home_rounded,
                              accent: AppTheme.amber,
                              primary: true,
                              onTap: _openCustomer,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _StaggeredFade(
                            controller: _controller,
                            start: 0.38,
                            child: _ChoiceTile(
                              title: 'Provider',
                              subtitle: 'Create or open your provider account',
                              icon: Icons.cell_tower_rounded,
                              accent: const Color(0xFF16A3B8),
                              onTap: _openProvider,
                            ),
                          ),
                          const SizedBox(height: 26),
                          _StaggeredFade(
                            controller: _controller,
                            start: 0.48,
                            child: _QuietFooter(color: mutedColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

void _pushCleanRoute(BuildContext context, Widget screen) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.textColor});

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.amber,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.wifi_rounded, color: AppTheme.navy, size: 22),
        ),
        const SizedBox(width: 11),
        Text(
          'OnaNet',
          style: GoogleFonts.plusJakartaSans(
            color: textColor,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatefulWidget {
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.primary = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool primary;

  @override
  State<_ChoiceTile> createState() => _ChoiceTileState();
}

class _ChoiceTileState extends State<_ChoiceTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fill = widget.primary
        ? widget.accent
        : isDark
        ? AppTheme.navyMid
        : AppTheme.white;
    final textColor = widget.primary
        ? AppTheme.navy
        : isDark
        ? AppTheme.offWhite
        : AppTheme.navy;
    final subtitleColor = widget.primary
        ? AppTheme.navy.withValues(alpha: 0.72)
        : isDark
        ? AppTheme.gray
        : AppTheme.darkGray.withValues(alpha: 0.76);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.primary
                  ? widget.accent
                  : isDark
                  ? AppTheme.navyLight
                  : AppTheme.lightGray,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
                blurRadius: widget.primary ? 22 : 14,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.primary
                      ? AppTheme.navy.withValues(alpha: 0.1)
                      : widget.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.primary ? AppTheme.navy : widget.accent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.plusJakartaSans(
                        color: textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.urbanist(
                        color: subtitleColor,
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_rounded,
                color: widget.primary ? AppTheme.navy : widget.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuietFooter extends StatelessWidget {
  const _QuietFooter({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 15, color: color),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            'Secure account setup',
            textAlign: TextAlign.center,
            style: GoogleFonts.urbanist(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _StaggeredFade extends StatelessWidget {
  const _StaggeredFade({
    required this.controller,
    required this.start,
    required this.child,
  });

  final AnimationController controller;
  final double start;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final end = math.min(start + 0.42, 1.0);
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _SignalFieldPainter extends CustomPainter {
  const _SignalFieldPainter({required this.progress, required this.isDark});

  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = isDark ? AppTheme.white : AppTheme.navy;
    final amberPaint = Paint()
      ..color = AppTheme.amber.withValues(alpha: 0.10 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final quietPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.045 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width * 0.78, size.height * 0.18);
    for (var i = 0; i < 4; i++) {
      final radius = (64.0 + (i * 54)) * progress;
      canvas.drawCircle(center, radius, i == 0 ? amberPaint : quietPaint);
    }

    final lowerCenter = Offset(size.width * 0.08, size.height * 0.92);
    for (var i = 0; i < 3; i++) {
      final radius = (80.0 + (i * 62)) * progress;
      canvas.drawCircle(lowerCenter, radius, quietPaint);
    }
  }

  @override
  bool shouldRepaint(_SignalFieldPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
