import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/auth/phone_verification.dart';
import 'package:ona_net/auth/auth_service.dart';
import 'package:ona_net/screens/login.dart';
import 'package:ona_net/screens/my_requests.dart';
import 'package:ona_net/screens/customer_profile_pages.dart';
import 'package:ona_net/screens/saved.dart';
import 'package:ona_net/auth/installation_service_request.dart';
import 'package:ona_net/screens/sign_up.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:ona_net/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:ona_net/provider/registration.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _phoneVerificationService = PhoneVerificationService();
  late Future<OtpStatusResult?> _phoneStatus = _loadPhoneStatus();
  late Future<Map<String, dynamic>> _account = _loadAccount();
  late Future<List<InstallationRequestResult>> _requestUpdates =
      _loadRequestUpdates();
  bool _isSigningOut = false;

  Future<OtpStatusResult?> _loadPhoneStatus() async {
    if (FirebaseAuth.instance.currentUser == null) return null;
    try {
      return await _phoneVerificationService.status();
    } catch (_) {
      // A failed status lookup must never expose a saved phone number.
      return null;
    }
  }

  Future<void> _refreshProfile() async {
    final phone = _loadPhoneStatus();
    final account = _loadAccount();
    final requests = _loadRequestUpdates();
    setState(() {
      _phoneStatus = phone;
      _account = account;
      _requestUpdates = requests;
    });
    await Future.wait([phone, account, requests]);
  }

  Future<Map<String, dynamic>> _loadAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const {};
    try {
      return await AuthService().getMyAccount();
    } catch (_) {
      return {
        'email': user.email,
        'first_name': user.displayName?.split(' ').first,
        'last_name': user.displayName?.split(' ').skip(1).join(' '),
        'created_at': user.metadata.creationTime?.toIso8601String(),
      };
    }
  }

  Future<List<InstallationRequestResult>> _loadRequestUpdates() async {
    if (FirebaseAuth.instance.currentUser == null) return const [];
    try {
      return await InstallationServiceRequest().myRequests();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> _requireAccount() async {
    if (FirebaseAuth.instance.currentUser != null) return true;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const Login()));
    if (FirebaseAuth.instance.currentUser == null) return false;
    await _refreshProfile();
    return true;
  }

  Future<void> _openPersonalInformation() async {
    if (!await _requireAccount() || !mounted) return;
    final account = await _account;
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalInformationScreen(account: account),
      ),
    );
    if (changed == true) await _refreshProfile();
  }

  Future<void> _openPage(Widget page) async {
    if (!await _requireAccount() || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _openMyRequests() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const Login()));
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MyRequestsScreen()));
  }

  Future<void> _logout() async {
    if (_isSigningOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to view your requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSigningOut = true);
    try {
      await AuthService().signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Login()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not log out: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
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
        child: RefreshIndicator(
          onRefresh: _refreshProfile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<OtpStatusResult?>(
                  future: _phoneStatus,
                  builder: (context, snapshot) => _ProfileHeaderCard(
                    displayName: _displayName(user),
                    email: user?.email,
                    verifiedPhone: snapshot.data?.isVerified == true
                        ? snapshot.data?.phoneNumber
                        : null,
                    isCheckingPhone:
                        snapshot.connectionState == ConnectionState.waiting,
                    onEdit: _openPersonalInformation,
                  ),
                ),
                if (user == null) ...[
                  const SizedBox(height: 12),
                  _AuthLinks(
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                  ),
                ],
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
                      onTap: _openPersonalInformation,
                    ),
                    _SectionDivider(color: mutedTextColor),
                    _SettingsTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Password & security',
                      subtitle: 'Sign-in and account protection',
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                      isDark: isDark,
                      onTap: () => _openPage(const PasswordSecurityScreen()),
                    ),
                    _SectionDivider(color: mutedTextColor),
                    _SettingsTile(
                      icon: Icons.location_on_outlined,
                      title: 'Location preferences',
                      subtitle: 'Default area and coverage checks',
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                      isDark: isDark,
                      onTap: () => _openPage(const LocationPreferencesScreen()),
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
                      onTap: _openMyRequests,
                    ),
                    _SectionDivider(color: mutedTextColor),
                    _SettingsTile(
                      icon: Icons.bookmark_border_rounded,
                      title: 'Saved providers',
                      subtitle: 'Providers you want to compare later',
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                      isDark: isDark,
                      onTap: () => _openPage(const SavedScreen()),
                    ),
                    _SectionDivider(color: mutedTextColor),
                    _SettingsTile(
                      icon: Icons.star_border_rounded,
                      title: 'My reviews',
                      subtitle: 'Ratings and feedback you have shared',
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                      isDark: isDark,
                      onTap: () => _openPage(const MyReviewsScreen()),
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
                    FutureBuilder<List<InstallationRequestResult>>(
                      future: _requestUpdates,
                      builder: (context, snapshot) {
                        final count = (snapshot.data ?? const [])
                            .where(
                              (request) => {
                                'accepted',
                                'declined',
                                'complete',
                                'completed',
                              }.contains(request.status.toLowerCase()),
                            )
                            .length;
                        return _SettingsTile(
                          icon: Icons.notifications_none_rounded,
                          title: 'Notifications',
                          subtitle: 'Provider updates and request alerts',
                          textColor: textColor,
                          mutedTextColor: mutedTextColor,
                          isDark: isDark,
                          badgeCount: count,
                          onTap: () => _openPage(const NotificationsScreen()),
                        );
                      },
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
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HelpCenterScreen(),
                        ),
                      ),
                    ),
                    _SectionDivider(color: mutedTextColor),
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About Ona Net',
                      subtitle: 'App version and terms',
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AboutOnaNetScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: 'Session',
                  children: [
                    _SettingsTile(
                      icon: _isSigningOut
                          ? Icons.hourglass_top_rounded
                          : Icons.logout_rounded,
                      title: _isSigningOut ? 'Logging out...' : 'Logout',
                      subtitle: 'Sign out of this account',
                      textColor: AppTheme.amberDark,
                      mutedTextColor: mutedTextColor,
                      isDark: isDark,
                      accentColor: AppTheme.amber,
                      showChevron: false,
                      onTap: _isSigningOut ? null : _logout,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _displayName(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'OnaNet user';
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
        _ProfileTextLink(
          label: 'Provider',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProviderReg()),
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
  const _ProfileHeaderCard({
    required this.displayName,
    required this.email,
    required this.verifiedPhone,
    required this.isCheckingPhone,
    required this.onEdit,
  });

  final String displayName;
  final String? email;
  final String? verifiedPhone;
  final bool isCheckingPhone;
  final VoidCallback onEdit;

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
                  displayName,
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
                  email?.trim().isNotEmpty == true
                      ? email!
                      : 'No email available',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.urbanist(
                    color: mutedTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      verifiedPhone != null
                          ? Icons.verified_rounded
                          : Icons.phone_locked_outlined,
                      size: 15,
                      color: verifiedPhone != null
                          ? AppTheme.green
                          : mutedTextColor,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        isCheckingPhone
                            ? 'Checking phone verification...'
                            : verifiedPhone != null
                            ? _formatPhone(verifiedPhone!)
                            : 'Phone appears after OTP verification',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.urbanist(
                          color: verifiedPhone != null
                              ? AppTheme.green
                              : mutedTextColor,
                          fontSize: 13,
                          fontWeight: verifiedPhone != null
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(10),
            child: Container(
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
          ),
        ],
      ),
    );
  }

  String _formatPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'^\+254\d{9}$').hasMatch(clean)) {
      return '${clean.substring(0, 4)} ${clean.substring(4, 7)} '
          '${clean.substring(7, 10)} ${clean.substring(10)}';
    }
    return clean;
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
    this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color textColor;
  final Color mutedTextColor;
  final bool isDark;
  final Color accentColor;
  final bool showChevron;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
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
              if (badgeCount > 0) ...[
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.amber,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: mutedTextColor,
                size: 22,
              ),
            ],
          ],
        ),
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
