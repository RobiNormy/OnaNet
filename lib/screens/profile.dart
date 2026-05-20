import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/screens/login.dart';
import 'package:ona_net/screens/sign_up.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:ona_net/themes/theme_provider.dart';
import 'package:provider/provider.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedTextColor = textColor.withValues(alpha: 0.62);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.urbanist(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ProfileHeaderCard(),
              const SizedBox(height: 12),
              _AuthLinks(textColor: textColor, mutedTextColor: mutedTextColor),
              const SizedBox(height: 22),
              _SettingsSection(
                title: 'Account & Security',
                children: [
                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal information',
                    subtitle: 'Name, email and phone number',
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                    isDark: isDark,
                  ),
                  _SectionDivider(color: mutedTextColor),
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Password & security',
                    subtitle: 'Sign-in and account protection',
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                    isDark: isDark,
                  ),
                  _SectionDivider(color: mutedTextColor),
                  _SettingsTile(
                    icon: Icons.location_on_outlined,
                    title: 'Location preferences',
                    subtitle: 'Default area and coverage checks',
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingsSection(
                title: 'Activity',
                children: [
                  _SettingsTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'My requests',
                    subtitle: 'Installation and package requests',
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                    isDark: isDark,
                  ),
                  _SectionDivider(color: mutedTextColor),
                  _SettingsTile(
                    icon: Icons.bookmark_border_rounded,
                    title: 'Saved providers',
                    subtitle: 'Providers you want to compare later',
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                    isDark: isDark,
                  ),
                  _SectionDivider(color: mutedTextColor),
                  _SettingsTile(
                    icon: Icons.star_border_rounded,
                    title: 'My reviews',
                    subtitle: 'Ratings and feedback you have shared',
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingsSection(
                title: 'Preferences',
                children: [
                  _ThemeSwitchTile(
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                    isDark: isDark,
                  ),
                  _SectionDivider(color: mutedTextColor),
                  _SettingsTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'Provider updates and request alerts',
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingsSection(
                title: 'Support',
                children: [
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help center',
                    subtitle: 'Questions, support and contact options',
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                    isDark: isDark,
                  ),
                  _SectionDivider(color: mutedTextColor),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About Ona Net',
                    subtitle: 'App version and terms',
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingsSection(
                title: 'Session',
                children: [
                  _SettingsTile(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    subtitle: 'Sign out of this account',
                    textColor: AppTheme.amberDark,
                    mutedTextColor: mutedTextColor,
                    isDark: isDark,
                    accentColor: AppTheme.amber,
                    showChevron: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthLinks extends StatelessWidget {
  const _AuthLinks({required this.textColor, required this.mutedTextColor});

  final Color textColor;
  final Color mutedTextColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        Text(
          'Continue with your account:',
          style: GoogleFonts.urbanist(
            color: mutedTextColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        _ProfileTextLink(
          label: 'Log in',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Login()),
            );
          },
        ),
        Text(
          'or',
          style: GoogleFonts.urbanist(
            color: mutedTextColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        _ProfileTextLink(
          label: 'Sign up',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignUp()),
            );
          },
        ),
      ],
    );
  }
}

class _ProfileTextLink extends StatelessWidget {
  const _ProfileTextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Text(
          label,
          style: GoogleFonts.urbanist(
            color: AppTheme.amber,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.underline,
            decorationColor: AppTheme.amber,
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedTextColor = textColor.withValues(alpha: 0.62);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppTheme.navyLight.withValues(alpha: 0.65)
              : AppTheme.lightGray,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: AppTheme.navy.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: isDark ? 0.18 : 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.amber.withValues(alpha: 0.28),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppTheme.amber,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'John Doe',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.urbanist(
                    color: textColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'johndoe@example.com',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.urbanist(
                    color: mutedTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '+254 720 204 930',
                  style: GoogleFonts.urbanist(
                    color: mutedTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.navyLight : AppTheme.offWhite,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.edit_outlined,
              color: isDark ? AppTheme.amberLight : AppTheme.amberDark,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppTheme.gray : AppTheme.darkGray;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 9),
          child: Text(
            title,
            style: GoogleFonts.urbanist(
              color: titleColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.navyMid : AppTheme.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? AppTheme.navyLight.withValues(alpha: 0.65)
                  : AppTheme.lightGray,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.textColor,
    required this.mutedTextColor,
    required this.isDark,
    this.accentColor = AppTheme.amber,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color textColor;
  final Color mutedTextColor;
  final bool isDark;
  final Color accentColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          _IconBadge(icon: icon, color: accentColor, isDark: isDark),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.urbanist(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.urbanist(
                    color: mutedTextColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 10),
            Icon(Icons.chevron_right_rounded, color: mutedTextColor, size: 22),
          ],
        ],
      ),
    );
  }
}

class _ThemeSwitchTile extends StatelessWidget {
  const _ThemeSwitchTile({
    required this.textColor,
    required this.mutedTextColor,
    required this.isDark,
  });

  final Color textColor;
  final Color mutedTextColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          _IconBadge(
            icon: Icons.dark_mode_outlined,
            color: AppTheme.amber,
            isDark: isDark,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dark mode',
                  style: GoogleFonts.urbanist(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Switch the app theme',
                  style: GoogleFonts.urbanist(
                    color: mutedTextColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: themeProvider.isDark,
            activeThumbColor: AppTheme.amber,
            activeTrackColor: AppTheme.amber.withValues(alpha: 0.32),
            inactiveThumbColor: AppTheme.gray,
            inactiveTrackColor: AppTheme.lightGray,
            onChanged: (value) {
              themeProvider.setTheme(value ? ThemeMode.dark : ThemeMode.light);
            },
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 65,
      endIndent: 14,
      color: color.withValues(alpha: 0.13),
    );
  }
}
