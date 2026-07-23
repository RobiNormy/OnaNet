import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/auth/auth_service.dart';
import 'package:ona_net/auth/installation_service_request.dart';
import 'package:ona_net/services/preferred_location_store.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:ona_net/utils/location.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key, required this.account});

  final Map<String, dynamic> account;

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  late final TextEditingController _firstName = TextEditingController(
    text: widget.account['first_name']?.toString() ?? '',
  );
  late final TextEditingController _lastName = TextEditingController(
    text: widget.account['last_name']?.toString() ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstName.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await AuthService().updateMyAccount(
        firstName: _firstName.text,
        lastName: _lastName.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personal information updated.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final joined = DateTime.tryParse(
      widget.account['created_at']?.toString() ?? '',
    );
    return _ProfilePage(
      title: 'Personal information',
      children: [
        _SurfaceCard(
          child: Column(
            children: [
              TextField(
                controller: _firstName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'First name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _lastName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Last name'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SurfaceCard(
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: widget.account['email']?.toString() ?? 'Not available',
              ),
              const Divider(height: 24),
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone number',
                value:
                    widget.account['phone_number']?.toString() ??
                    'Not verified',
              ),
              const Divider(height: 24),
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Date joined',
                value: joined == null ? 'Not available' : _date(joined),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving...' : 'Save name'),
        ),
      ],
    );
  }
}

class PasswordSecurityScreen extends StatelessWidget {
  const PasswordSecurityScreen({super.key});

  Future<void> _changeEmail(BuildContext context) async {
    final controller = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.email ?? '',
    );
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change email'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Send verification'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty || !context.mounted) return;
    try {
      await AuthService().requestEmailChange(email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verification sent to $email. Your email changes after you confirm it.',
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Change password'),
        content: Column(
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                helperText: 'Use at least 8 characters.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (next.text.length < 8 || current.text.isEmpty) return;
              try {
                await AuthService().changePassword(
                  currentPassword: current.text,
                  newPassword: next.text,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            },
            child: const Text('Update password'),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    }
  }

  Future<void> _resetPassword(BuildContext context) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    try {
      await AuthService().sendPasswordReset(email: email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email.')),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProfilePage(
      title: 'Password & security',
      children: [
        _ActionCard(
          icon: Icons.alternate_email_rounded,
          title: 'Change email',
          subtitle: FirebaseAuth.instance.currentUser?.email ?? '',
          onTap: () => _changeEmail(context),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.password_rounded,
          title: 'Change password',
          subtitle: 'Confirm your current password and choose a new one',
          onTap: () => _changePassword(context),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.lock_reset_rounded,
          title: 'Forgot your password?',
          subtitle: 'Email me a secure password reset link',
          onTap: () => _resetPassword(context),
        ),
      ],
    );
  }
}

class LocationPreferencesScreen extends StatefulWidget {
  const LocationPreferencesScreen({super.key});

  @override
  State<LocationPreferencesScreen> createState() =>
      _LocationPreferencesScreenState();
}

class _LocationPreferencesScreenState extends State<LocationPreferencesScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  PreferredLocation? _current;
  List<LocationSuggestion> _suggestions = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    PreferredLocationStore.load().then((value) {
      if (mounted) setState(() => _current = value);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final query = _controller.text.trim();
      final results = await Location.searchAreas(query);
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    });
  }

  Future<void> _select(LocationSuggestion suggestion) async {
    final selected = PreferredLocation(
      name: suggestion.title,
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
    );
    await PreferredLocationStore.save(selected);
    if (!mounted) return;
    setState(() {
      _current = selected;
      _suggestions = const [];
      _controller.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selected.name} is now your default location.')),
    );
  }

  Future<void> _clear() async {
    await PreferredLocationStore.clear();
    if (mounted) setState(() => _current = null);
  }

  @override
  Widget build(BuildContext context) {
    return _ProfilePage(
      title: 'Location preferences',
      children: [
        if (_current != null) ...[
          _SurfaceCard(
            child: _InfoRow(
              icon: Icons.location_city_rounded,
              label: 'Default search location',
              value: _current!.name,
              trailing: TextButton(
                onPressed: _clear,
                child: const Text('Remove'),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _controller,
          onChanged: _search,
          decoration: InputDecoration(
            labelText: 'Search for an area',
            hintText: 'Estate, town or landmark',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        ..._suggestions.map(
          (suggestion) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ActionCard(
              icon: Icons.location_on_outlined,
              title: suggestion.title,
              subtitle: suggestion.subtitle,
              onTap: () => _select(suggestion),
            ),
          ),
        ),
        if (_current == null && _suggestions.isEmpty && !_searching)
          const _EmptyHint(
            icon: Icons.travel_explore_rounded,
            text:
                'Search and select an area. Home and Search will use it automatically instead of asking for GPS.',
          ),
      ],
    );
  }
}

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  late Future<List<Map<String, dynamic>>> _reviews = AuthService()
      .getMyReviews();

  Future<void> _refresh() async {
    final request = AuthService().getMyReviews();
    setState(() {
      _reviews = request;
    });
    await request;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My reviews')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _reviews,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _CenteredRetry(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }
          final reviews = snapshot.data ?? const [];
          if (reviews.isEmpty) {
            return const _EmptyHint(
              icon: Icons.rate_review_outlined,
              text:
                  'Your ratings and written reviews will appear here after completed installations.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: reviews.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _ReviewCard(review: reviews[index]),
            ),
          );
        },
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<InstallationRequestResult>> _requests =
      InstallationServiceRequest().myRequests();

  Future<void> _refresh() async {
    final request = InstallationServiceRequest().myRequests();
    setState(() {
      _requests = request;
    });
    await request;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: FutureBuilder<List<InstallationRequestResult>>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _CenteredRetry(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }
          final items = (snapshot.data ?? const [])
              .where(
                (request) => {
                  'accepted',
                  'declined',
                  'complete',
                  'completed',
                }.contains(request.status.toLowerCase()),
              )
              .toList();
          if (items.isEmpty) {
            return const _EmptyHint(
              icon: Icons.notifications_none_rounded,
              text:
                  'Provider decisions and installation updates will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) =>
                  _NotificationCard(request: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const _faqs = [
    (
      'How do I request an installation?',
      'Open a provider, choose a package, tap View Deal, then submit your address and preferred installation time.',
    ),
    (
      'How do I know whether a provider accepted?',
      'Check Notifications or My requests. An accepted request shows that the provider approved it and is arranging the installation.',
    ),
    (
      'Why must I verify my phone number?',
      'Providers need a verified number to contact you safely about an installation request.',
    ),
    (
      'When can I leave a review?',
      'You can rate and review a provider after the provider marks the installation as completed.',
    ),
    (
      'How do saved providers work?',
      'Tap the bookmark on any provider. Saved providers are kept separately for your signed-in account.',
    ),
  ];

  Future<void> _emailSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'onanetsupport@gmail.com',
      queryParameters: {'subject': 'OnaNet support request'},
    );
    if (!await launchUrl(uri) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open your email app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProfilePage(
      title: 'Help center',
      children: [
        _SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: _faqs
                .map(
                  (faq) => ExpansionTile(
                    title: Text(
                      faq.$1,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(faq.$2)],
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        _ActionCard(
          icon: Icons.support_agent_rounded,
          title: 'Email OnaNet support',
          subtitle: 'onanetsupport@gmail.com',
          onTap: () => _emailSupport(context),
        ),
      ],
    );
  }
}

class AboutOnaNetScreen extends StatelessWidget {
  const AboutOnaNetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ProfilePage(
      title: 'About OnaNet',
      children: [
        _SurfaceCard(
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppTheme.amber.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.wifi_rounded,
                  color: AppTheme.amber,
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'OnaNet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Discover, compare and request internet packages available in your area.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (_, snapshot) => Text(
                  snapshot.hasData
                      ? 'Version ${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                      : 'Loading version...',
                  style: const TextStyle(
                    color: AppTheme.gray,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _EmptyHint(
          icon: Icons.description_outlined,
          text: 'Terms and policies will be added here later.',
        ),
      ],
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
        children: children,
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
      ),
      child: child,
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: _SurfaceCard(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.amber.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppTheme.amber),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppTheme.gray),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.gray),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.amber, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.gray)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final provider = review['provider_name']?.toString() ?? 'Internet provider';
    final rating = int.tryParse(review['rating']?.toString() ?? '') ?? 0;
    final updated = DateTime.tryParse(
      review['updated_at']?.toString() ??
          review['created_at']?.toString() ??
          '',
    );
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.amber.withValues(alpha: .15),
                child: Text(
                  provider.isEmpty ? 'O' : provider[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.amber,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      review['package_name']?.toString() ?? 'Package',
                      style: const TextStyle(color: AppTheme.gray),
                    ),
                  ],
                ),
              ),
              if (updated != null)
                Text(
                  _date(updated),
                  style: const TextStyle(color: AppTheme.gray, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                size: 20,
                color: AppTheme.amber,
              ),
            ),
          ),
          if (review['comment']?.toString().trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(review['comment'].toString()),
          ],
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.request});

  final InstallationRequestResult request;

  @override
  Widget build(BuildContext context) {
    final status = request.status.toLowerCase();
    final declined = status == 'declined';
    final completed = status == 'complete' || status == 'completed';
    final color = declined
        ? Colors.red
        : completed
        ? AppTheme.green
        : AppTheme.amber;
    final title = declined
        ? 'Request declined'
        : completed
        ? 'Installation completed'
        : 'Request approved';
    final message = declined
        ? 'The provider declined your request.${request.declineReason?.trim().isNotEmpty == true ? ' Reason: ${request.declineReason}' : ''}'
        : completed
        ? '${request.providerName ?? 'The provider'} completed your ${request.packageName ?? 'package'} installation.'
        : 'Your request has been approved. ${request.providerName ?? 'The provider'} is on the way and will contact you about the installation.';
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              declined
                  ? Icons.cancel_outlined
                  : completed
                  ? Icons.task_alt_rounded
                  : Icons.notifications_active_outlined,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(message),
                if (request.updatedAt != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    _dateTime(request.updatedAt!.toLocal()),
                    style: const TextStyle(color: AppTheme.gray, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppTheme.amber),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CenteredRetry extends StatelessWidget {
  const _CenteredRetry({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime value) {
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
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String _dateTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '${_date(value)} · $hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}
