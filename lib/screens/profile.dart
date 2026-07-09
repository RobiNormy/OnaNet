import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/auth/auth_service.dart';
import 'package:ona_net/auth/installation_service_request.dart';
import 'package:ona_net/onanet_provider_dash/dashy.dart';
import 'package:ona_net/screens/login.dart';
import 'package:ona_net/screens/sign_up.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:ona_net/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:ona_net/provider/registration.dart';
import 'package:ona_net/screens/provider_admin.dart';

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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerRequestsScreen(),
                        ),
                      );
                    },
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerRequestsScreen(),
                        ),
                      );
                    },
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
              StreamBuilder<User?>(
                initialData: FirebaseAuth.instance.currentUser,
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  final signedIn = snapshot.data != null;
                  return _SettingsSection(
                    title: 'Session',
                    children: [
                      _SettingsTile(
                        icon: Icons.logout_rounded,
                        title: 'Logout',
                        subtitle: signedIn
                            ? 'Sign out of this account'
                            : 'No account is signed in',
                        textColor: signedIn
                            ? AppTheme.amberDark
                            : mutedTextColor,
                        mutedTextColor: mutedTextColor,
                        isDark: isDark,
                        accentColor: signedIn ? AppTheme.amber : mutedTextColor,
                        showChevron: false,
                        onTap: signedIn ? () => _signOut(context) : null,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text('Are you sure you want to log out?'),
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
        );
      },
    );

    if (shouldSignOut != true || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService().signOut();
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Signed out successfully'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not sign out: $error'),
        ),
      );
    }
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
          'Manage your Ona Net account:',
          style: GoogleFonts.urbanist(
            color: mutedTextColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        _ProfileTextLink(
          label: 'Customer sign in',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Login()),
            );
          },
        ),
        _ProfileTextLink(
          label: 'Partner portal',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProviderReg()),
            );
          },
        ),
        _ProfileTextLink(
          label: "Dashboard",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Dashboard()),
            );
          },
        ),
        _ProfileTextLink(
          label: "Intro screen",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProviderAdminScreen()),
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
          label: 'Create account',
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

class CustomerRequestsScreen extends StatefulWidget {
  const CustomerRequestsScreen({super.key});

  @override
  State<CustomerRequestsScreen> createState() => _CustomerRequestsScreenState();
}

class _CustomerRequestsScreenState extends State<CustomerRequestsScreen> {
  final _service = InstallationServiceRequest();
  late Future<List<InstallationRequestResult>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _requestsFuture = _service.myRequests();
  }

  void _reload() {
    setState(() => _requestsFuture = _service.myRequests());
  }

  Future<void> _cancelRequest(InstallationRequestResult request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel request?'),
          content: const Text(
            'You can only cancel installation requests within 10 minutes of submitting them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep request'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel request'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service.cancel(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Request cancelled.'),
        ),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString()),
        ),
      );
      _reload();
    }
  }

  Future<void> _reviewRequest(InstallationRequestResult request) async {
    final review = await showModalBottomSheet<_ReviewDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ReviewRequestSheet(request: request);
      },
    );
    if (review == null || !mounted) return;

    try {
      await _service.submitReview(
        installationRequestId: request.id,
        rating: review.rating,
        comment: review.comment,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Review saved. Thanks for keeping OnaNet honest.'),
        ),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedTextColor = textColor.withValues(alpha: .65);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My requests',
          style: GoogleFonts.urbanist(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<InstallationRequestResult>>(
          future: _requestsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, _) => const _CustomerRequestSkeleton(),
              );
            }

            if (snapshot.hasError) {
              return _CustomerRequestsMessage(
                icon: Icons.error_outline_rounded,
                title: 'Could not load requests',
                message: snapshot.error.toString(),
                actionLabel: 'Try again',
                onAction: _reload,
              );
            }

            final requests = snapshot.data ?? const [];
            if (requests.isEmpty) {
              return _CustomerRequestsMessage(
                icon: Icons.receipt_long_outlined,
                title: 'No requests yet',
                message: 'Installation requests you submit will show up here.',
                actionLabel: 'Refresh',
                onAction: _reload,
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                itemCount: requests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _CustomerRequestCard(
                    request: requests[index],
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                    isDark: isDark,
                    onCancel: _cancelRequest,
                    onReview: _reviewRequest,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CustomerRequestCard extends StatelessWidget {
  const _CustomerRequestCard({
    required this.request,
    required this.textColor,
    required this.mutedTextColor,
    required this.isDark,
    required this.onCancel,
    required this.onReview,
  });

  final InstallationRequestResult request;
  final Color textColor;
  final Color mutedTextColor;
  final bool isDark;
  final Future<void> Function(InstallationRequestResult request) onCancel;
  final Future<void> Function(InstallationRequestResult request) onReview;

  bool get _isCompleted {
    return request.status == 'complete' || request.status == 'completed';
  }

  bool get _canCancel {
    final createdAt = request.createdAt;
    if (createdAt == null || request.status != 'pending') return false;
    final elapsed = DateTime.now().difference(createdAt.toLocal());
    return !elapsed.isNegative && elapsed < const Duration(minutes: 10);
  }

  String get _cancelWindowLabel {
    final createdAt = request.createdAt;
    if (createdAt == null) return 'Cancellation window unavailable';
    final remaining =
        const Duration(minutes: 10) -
        DateTime.now().difference(createdAt.toLocal());
    if (remaining.isNegative || request.status != 'pending') {
      return 'Cancellation window closed';
    }
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    return 'Cancel available for ${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final statusColors = _customerRequestStatusColors(request.status);
    final packageName = request.packageName?.trim().isNotEmpty == true
        ? request.packageName!.trim()
        : 'Package ${_shortId(request.packageId)}';
    final locationParts = [
      request.estateOrBuilding,
      if (request.houseOrApartment?.trim().isNotEmpty == true)
        request.houseOrApartment!.trim(),
      if (request.landmark?.trim().isNotEmpty == true) request.landmark!.trim(),
    ].where((part) => part.trim().isNotEmpty).join(', ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyLight : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppTheme.navyLight.withValues(alpha: .7)
              : AppTheme.lightGray,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .16 : .06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(
                icon: Icons.wifi_rounded,
                color: AppTheme.amber,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      packageName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _customerRequestDateLine(request),
                      style: GoogleFonts.urbanist(
                        color: mutedTextColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _CustomerStatusPill(
                label: _statusLabel(request.status),
                background: statusColors.$1,
                foreground: statusColors.$2,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CustomerRequestDetail(
            icon: Icons.place_outlined,
            label: 'Location',
            value: locationParts.isEmpty ? 'Not set' : locationParts,
            mutedTextColor: mutedTextColor,
            textColor: textColor,
          ),
          const SizedBox(height: 8),
          _CustomerRequestDetail(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: request.phoneE164?.trim().isNotEmpty == true
                ? request.phoneE164!.trim()
                : 'Not set',
            mutedTextColor: mutedTextColor,
            textColor: textColor,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _isCompleted
                      ? 'Installation fulfilled. Share your experience.'
                      : _cancelWindowLabel,
                  style: GoogleFonts.urbanist(
                    color: _isCompleted || _canCancel
                        ? AppTheme.amberDark
                        : mutedTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_isCompleted)
                FilledButton.icon(
                  onPressed: () => onReview(request),
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text('Review'),
                )
              else
                OutlinedButton.icon(
                  onPressed: _canCancel ? () => onCancel(request) : null,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerRequestDetail extends StatelessWidget {
  const _CustomerRequestDetail({
    required this.icon,
    required this.label,
    required this.value,
    required this.mutedTextColor,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color mutedTextColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.amber),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: '$label: ',
              style: GoogleFonts.urbanist(
                color: mutedTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.urbanist(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewDraft {
  const _ReviewDraft({required this.rating, required this.comment});

  final int rating;
  final String comment;
}

class _ReviewRequestSheet extends StatefulWidget {
  const _ReviewRequestSheet({required this.request});

  final InstallationRequestResult request;

  @override
  State<_ReviewRequestSheet> createState() => _ReviewRequestSheetState();
}

class _ReviewRequestSheetState extends State<_ReviewRequestSheet> {
  final _commentController = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(
      context,
      _ReviewDraft(rating: _rating, comment: _commentController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedColor = textColor.withValues(alpha: .64);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final packageName = widget.request.packageName?.trim().isNotEmpty == true
        ? widget.request.packageName!.trim()
        : 'Package ${_shortId(widget.request.packageId)}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, bottomInset + 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.navyMid : AppTheme.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: mutedColor.withValues(alpha: .4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Rate the service',
                style: GoogleFonts.urbanist(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                packageName,
                style: GoogleFonts.urbanist(
                  color: mutedColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  return IconButton(
                    tooltip: '$star stars',
                    onPressed: () => setState(() => _rating = star),
                    icon: Icon(
                      star <= _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppTheme.amber,
                      size: 34,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: GoogleFonts.urbanist(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'How was installation, support, and connection?',
                  hintStyle: GoogleFonts.urbanist(color: mutedColor),
                  filled: true,
                  fillColor: isDark ? AppTheme.navy : AppTheme.offWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerStatusPill extends StatelessWidget {
  const _CustomerStatusPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CustomerRequestSkeleton extends StatelessWidget {
  const _CustomerRequestSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline.withValues(alpha: .16);
    return Container(
      height: 132,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _CustomerRequestsMessage extends StatelessWidget {
  const _CustomerRequestsMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.offWhite
        : AppTheme.navy;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.amber, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(
                color: textColor.withValues(alpha: .65),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

String _customerRequestDateLine(InstallationRequestResult request) {
  final preferredDate = request.preferredDate;
  final preferredTime = request.preferredTime;
  final date = preferredDate == null
      ? 'Preferred date not set'
      : '${_monthName(preferredDate.month)} ${preferredDate.day}, ${preferredDate.year}';
  final time = preferredTime == null
      ? ''
      : ' at ${preferredTime.hour.toString().padLeft(2, '0')}:${preferredTime.minute.toString().padLeft(2, '0')}';
  return '$date$time';
}

(Color, Color) _customerRequestStatusColors(String status) {
  return switch (status) {
    'accepted' => (Colors.blue.withValues(alpha: .12), Colors.blue.shade700),
    'complete' ||
    'completed' => (Colors.green.withValues(alpha: .12), Colors.green.shade700),
    'declined' => (Colors.red.withValues(alpha: .12), Colors.red.shade700),
    'cancelled' => (Colors.grey.withValues(alpha: .18), Colors.grey.shade700),
    _ => (AppTheme.amberLight.withValues(alpha: .65), AppTheme.amberDark),
  };
}

String _statusLabel(String status) {
  return switch (status) {
    'pending' => 'Pending',
    'accepted' => 'Accepted',
    'complete' || 'completed' => 'Completed',
    'declined' => 'Declined',
    'cancelled' => 'Cancelled',
    _ =>
      status.isEmpty
          ? 'Unknown'
          : '${status[0].toUpperCase()}${status.substring(1)}',
  };
}

String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      initialData: FirebaseAuth.instance.currentUser,
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        return _ProfileHeaderContent(user: snapshot.data);
      },
    );
  }
}

class _ProfileHeaderContent extends StatelessWidget {
  const _ProfileHeaderContent({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedTextColor = textColor.withValues(alpha: 0.62);
    final name = _profileName(user);
    final email = _profileEmail(user);
    final phoneNumber = user?.phoneNumber?.trim();
    final photoUrl = user?.photoURL;

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
            child: ClipOval(
              child: photoUrl != null && photoUrl.trim().isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person_rounded,
                        color: AppTheme.amber,
                        size: 34,
                      ),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      color: AppTheme.amber,
                      size: 34,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
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
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.urbanist(
                    color: mutedTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (phoneNumber != null && phoneNumber.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    phoneNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.urbanist(
                      color: mutedTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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

  static String _profileName(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'Guest user';
  }

  static String _profileEmail(User? user) {
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }

    return 'Sign in to view your account';
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
