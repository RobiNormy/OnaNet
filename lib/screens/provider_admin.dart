import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/provider/registration.dart';
import 'package:ona_net/screens/sign_up.dart';
import 'package:ona_net/themes/app_theme.dart';

class ProviderAdminScreen extends StatelessWidget {
  const ProviderAdminScreen({super.key});

  static String id = "main";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final headerTextColor = colorScheme.onPrimary;
    final logoAccentColor = isDark ? AppTheme.navy : colorScheme.secondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const valleyDepth = 34.0;
            final isCompactHeight = constraints.maxHeight < 700;
            final headerHeight = isCompactHeight ? 336.0 : 356.0;

            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: headerHeight,
                    child: _HeroHeader(
                      headerTextColor: headerTextColor,
                      logoAccentColor: logoAccentColor,
                      compact: isCompactHeight,
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -valleyDepth),
                    child: _JoinOptionsPanel(
                      valleyDepth: valleyDepth,
                      onUserTap: () {
                        _pushZoomRoute(
                          context,
                          const SignUp(),
                          duration: const Duration(milliseconds: 260),
                          beginScale: 0.97,
                        );
                      },
                      onProviderTap: () {
                        _pushZoomRoute(
                          context,
                          const ProviderReg(),
                          duration: const Duration(milliseconds: 260),
                          beginScale: 0.97,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

void _pushZoomRoute(
  BuildContext context,
  Widget screen, {
  Duration duration = const Duration(milliseconds: 360),
  double beginScale = 0.9,
}) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: duration,
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: beginScale,
              end: 1,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    ),
  );
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.headerTextColor,
    required this.logoAccentColor,
    required this.compact,
  });

  final Color headerTextColor;
  final Color logoAccentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, compact ? 14 : 18, 20, 34),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          Positioned(right: -42, top: -46, child: _HeaderRing(size: 150)),
          Positioned(right: 12, top: 34, child: _HeaderRing(size: 72)),
          Positioned(
            right: 4,
            top: compact ? 92 : 104,
            child: _SignalBadge(
              accentColor: logoAccentColor,
              size: compact ? 56 : 64,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PulsingHeaderLogo(
                textColor: headerTextColor,
                accentColor: logoAccentColor,
              ),
              SizedBox(height: compact ? 22 : 28),
              Text(
                "Find the best internet in your\narea — instantly",
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: headerTextColor,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                  letterSpacing: 0,
                  fontSize: compact ? 25 : null,
                ),
              ),
              SizedBox(height: compact ? 10 : 12),
              SizedBox(
                width: 270,
                child: Text(
                  "Compare providers, packages, and book installation in minutes",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: headerTextColor.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
              SizedBox(height: compact ? 14 : 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _HeroChip(label: 'Coverage first'),
                  _HeroChip(label: 'Fast booking'),
                  _HeroChip(label: 'Local providers'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalBadge extends StatelessWidget {
  const _SignalBadge({required this.accentColor, required this.size});

  final Color accentColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.white.withValues(alpha: 0.12)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.router_rounded, color: accentColor, size: size * 0.38),
          Positioned(
            right: size * 0.2,
            top: size * 0.18,
            child: Icon(
              Icons.wifi_rounded,
              color: AppTheme.white.withValues(alpha: 0.72),
              size: size * 0.23,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(
          color: AppTheme.white.withValues(alpha: 0.88),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _JoinOptionsPanel extends StatelessWidget {
  const _JoinOptionsPanel({
    required this.valleyDepth,
    required this.onUserTap,
    required this.onProviderTap,
  });

  final double valleyDepth;
  final VoidCallback onUserTap;
  final VoidCallback onProviderTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panelColor = isDark ? AppTheme.navyMid : AppTheme.white;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedTextColor = isDark ? AppTheme.gray : AppTheme.darkGray;
    final dividerColor = isDark
        ? AppTheme.white.withValues(alpha: 0.08)
        : AppTheme.lightGray;

    return PhysicalShape(
      clipper: _ValleyPanelClipper(valleyDepth: valleyDepth),
      color: panelColor,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, valleyDepth + 16, 20, 18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose your path',
                            style: GoogleFonts.plusJakartaSans(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'One network marketplace for homes and providers.',
                            style: GoogleFonts.urbanist(
                              color: mutedTextColor.withValues(alpha: 0.76),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _MiniMetric(
                      textColor: textColor,
                      mutedColor: mutedTextColor,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _JoinOptionCard(
                  title: 'Join us as user',
                  subtitle:
                      'Compare 50+ providers, check coverage, and book installation near you',
                  icon: Icons.home_work_rounded,
                  accentColor: const Color(0xFF00BCD4),
                  tag: 'For homes',
                  highlights: const ['Compare prices', 'Check coverage'],
                  onTap: onUserTap,
                ),
                const SizedBox(height: 12),
                _JoinOptionCard(
                  title: 'Join us as provider',
                  subtitle:
                      'List packages, manage coverage zones, and reach new customers',
                  icon: Icons.cell_tower_rounded,
                  accentColor: const Color(0xFF3F51B5),
                  tag: 'For ISPs',
                  highlights: const ['Grow demand', 'Map zones'],
                  onTap: onProviderTap,
                ),
                const SizedBox(height: 14),
                _LandingTrustBar(
                  textColor: mutedTextColor,
                  dividerColor: dividerColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.textColor, required this.mutedColor});

  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF00BCD4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00BCD4).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '50+',
            style: GoogleFonts.plusJakartaSans(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'providers',
            style: GoogleFonts.urbanist(
              color: mutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValleyPanelClipper extends CustomClipper<Path> {
  const _ValleyPanelClipper({required this.valleyDepth});

  final double valleyDepth;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..cubicTo(
        size.width * 0.24,
        valleyDepth,
        size.width * 0.76,
        valleyDepth,
        size.width,
        0,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_ValleyPanelClipper oldClipper) {
    return oldClipper.valleyDepth != valleyDepth;
  }
}

class _PulsingHeaderLogo extends StatefulWidget {
  const _PulsingHeaderLogo({
    required this.textColor,
    required this.accentColor,
  });

  final Color textColor;
  final Color accentColor;

  @override
  State<_PulsingHeaderLogo> createState() => _PulsingHeaderLogoState();
}

class _PulsingHeaderLogoState extends State<_PulsingHeaderLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.9,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _opacity = Tween<double>(
      begin: 0.08,
      end: 0.18,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scale.value,
                child: Opacity(opacity: _opacity.value, child: child),
              );
            },
            child: Container(
              width: 112,
              height: 38,
              decoration: BoxDecoration(
                color: widget.accentColor,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_rounded, color: widget.accentColor, size: 13),
                const SizedBox(width: 6),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "Ona",
                        style: GoogleFonts.plusJakartaSans(
                          color: widget.textColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      TextSpan(
                        text: 'Net',
                        style: GoogleFonts.plusJakartaSans(
                          color: widget.accentColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ],
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

class _LandingTrustBar extends StatelessWidget {
  const _LandingTrustBar({required this.textColor, required this.dividerColor});

  final Color textColor;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(color: dividerColor, height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: textColor),
            const SizedBox(width: 8),
            Text(
              'Verified paths. Clear choices. Secure signup.',
              style: GoogleFonts.urbanist(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _JoinOptionCard extends StatefulWidget {
  const _JoinOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.tag,
    required this.highlights,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String tag;
  final List<String> highlights;
  final VoidCallback onTap;

  @override
  State<_JoinOptionCard> createState() => _JoinOptionCardState();
}

class _JoinOptionCardState extends State<_JoinOptionCard> {
  bool _isForward = false;

  Future<void> _handleTap() async {
    if (_isForward) return;

    setState(() => _isForward = true);
    await Future<void>.delayed(const Duration(milliseconds: 190));
    if (!mounted) return;
    widget.onTap();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (mounted) {
      setState(() => _isForward = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? AppTheme.navy.withValues(alpha: 0.55)
        : AppTheme.offWhite;
    final borderColor = isDark
        ? AppTheme.white.withValues(alpha: 0.08)
        : AppTheme.lightGray;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedTextColor = isDark ? AppTheme.gray : AppTheme.darkGray;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _isForward ? 1.045 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isForward
                  ? widget.accentColor.withValues(alpha: 0.5)
                  : borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              if (_isForward)
                BoxShadow(
                  color: widget.accentColor.withValues(
                    alpha: isDark ? 0.22 : 0.18,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _CardIcon(
                            icon: widget.icon,
                            accentColor: widget.accentColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.tag,
                                  style: GoogleFonts.urbanist(
                                    color: widget.accentColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSlide(
                            offset: _isForward
                                ? const Offset(0.18, 0)
                                : Offset.zero,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: widget.accentColor,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.subtitle,
                        style: GoogleFonts.urbanist(
                          color: mutedTextColor.withValues(alpha: 0.82),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.highlights
                            .map(
                              (highlight) => _HighlightPill(
                                label: highlight,
                                color: widget.accentColor,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardIcon extends StatelessWidget {
  const _CardIcon({required this.icon, required this.accentColor});

  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: accentColor, size: 25),
    );
  }
}

class _HighlightPill extends StatelessWidget {
  const _HighlightPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeaderRing extends StatelessWidget {
  const _HeaderRing({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.white.withValues(alpha: 0.08)),
      ),
    );
  }
}
