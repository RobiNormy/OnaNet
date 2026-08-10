import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/core/theme/app_theme.dart';
import 'package:ona_net/features/customer/presentation/home_screen.dart';
import 'package:ona_net/features/onboarding/data/onboarding_store.dart';
import 'package:ona_net/features/provider_registration/presentation/registration_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _images = [
    'lib/images/onboarding-screen-01.png',
    'lib/images/onboarding-screen-02.png',
    'lib/images/onboarding-screen-03.png',
    'lib/images/onboarding-screen-04.png',
  ];

  final _pageController = PageController();
  int _page = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await OnboardingStore.markCompleted();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  void _next() {
    if (_page == _images.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _images.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) => AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    final currentPage = _pageController.hasClients
                        ? (_pageController.page ?? _page.toDouble())
                        : _page.toDouble();
                    final distance = (currentPage - index).abs().clamp(
                      0.0,
                      1.0,
                    );
                    final scale = 1 - (distance * 0.055);
                    final opacity = 1 - (distance * 0.35);
                    return Transform.scale(
                      scale: scale,
                      child: Opacity(opacity: opacity, child: child),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppTheme.amber.withValues(alpha: 0.22),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.navy.withValues(alpha: 0.1),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(_images[index], fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _finishing ? null : _finish,
                    child: const Text('Skip'),
                  ),
                  const Spacer(),
                  Row(
                    children: List.generate(
                      _images.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: index == _page ? 22 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: index == _page
                              ? AppTheme.amber
                              : AppTheme.lightGray,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _finishing ? null : _next,
                    child: Text(
                      _page == _images.length - 1 ? 'Get started' : 'Next',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _open(BuildContext context, Widget destination) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedColor = isDark ? AppTheme.gray : AppTheme.darkGray;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0, end: 1),
                builder: (context, value, child) => Transform.translate(
                  offset: Offset(0, 22 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _OnaNetLogo(textColor: textColor),
                    const SizedBox(height: 18),
                    Text(
                      'How will you use OnaNet?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose where you want to begin. You can still access the other side later.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(
                        fontSize: 15,
                        height: 1.5,
                        color: mutedColor,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _RoleCard(
                      icon: Icons.travel_explore_rounded,
                      title: 'I’m looking for internet',
                      subtitle:
                          'Compare providers and packages available near you.',
                      buttonLabel: 'Continue as a client',
                      onPressed: () => _open(context, const MainWrapper()),
                    ),
                    const SizedBox(height: 16),
                    _RoleCard(
                      icon: Icons.business_rounded,
                      title: 'Join as a provider',
                      subtitle:
                          'List your coverage, packages and manage client requests.',
                      buttonLabel: 'Set up provider profile',
                      outlined: true,
                      onPressed: () => _open(context, const ProviderReg()),
                    ),
                  ],
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
  const _OnaNetLogo({required this.textColor});

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final logoStyle = GoogleFonts.urbanist(
      fontSize: 34,
      fontWeight: FontWeight.w900,
      letterSpacing: -1,
      height: 1,
    );
    return Column(
      children: [
        const Icon(Icons.wifi_rounded, color: AppTheme.amber, size: 46),
        const SizedBox(height: 5),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Ona',
                style: logoStyle.copyWith(color: textColor),
              ),
              TextSpan(
                text: 'Net',
                style: logoStyle.copyWith(color: AppTheme.amber),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    this.outlined = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: AppTheme.lightGray),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.amber, size: 38),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.urbanist(
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.urbanist(height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: outlined
                ? OutlinedButton(onPressed: onPressed, child: Text(buttonLabel))
                : FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ),
        ],
      ),
    );
  }
}
