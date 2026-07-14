import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:ona_net/auth/auth_service.dart';
import 'package:ona_net/onanet_provider_dash/pro_analytics.dart';
import 'package:ona_net/screens/login.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:ona_net/services/provider_inbox.dart';
import 'package:ona_net/services/subscription_service.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _openMapLocation(BuildContext context, String url) async {
  final parsed = Uri.tryParse(url);
  final uri =
      parsed != null && (parsed.scheme == 'https' || parsed.scheme == 'http')
      ? parsed
      : Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': url,
        });
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Google Maps.')),
    );
  }
}

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _dashBackground(BuildContext context) =>
    _isDark(context) ? const Color(0xFF06131E) : const Color(0xFFF4F7FB);

Color _dashSurface(BuildContext context) =>
    _isDark(context) ? const Color(0xFF0D2231) : AppTheme.white;

Color _dashText(BuildContext context) =>
    _isDark(context) ? AppTheme.offWhite : AppTheme.navy;

Color _dashMuted(BuildContext context) =>
    _isDark(context) ? const Color(0xFF8FA6B5) : const Color(0xFF64748B);

Color _dashBorder(BuildContext context) => _isDark(context)
    ? Colors.white.withValues(alpha: .075)
    : const Color(0xFFE5EAF1);

Color _dashSoftAmber(BuildContext context) => _isDark(context)
    ? AppTheme.amber.withValues(alpha: .14)
    : AppTheme.amberLight.withValues(alpha: .55);

Color _dashAccentText(BuildContext context) =>
    _isDark(context) ? AppTheme.amberLight : AppTheme.amberDark;

Color _dashShadow(BuildContext context) =>
    (_isDark(context) ? Colors.black : const Color(0xFF16324A)).withValues(
      alpha: _isDark(context) ? .2 : .065,
    );

TextStyle _dashFont({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  double? height,
}) {
  return GoogleFonts.urbanist(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

enum _ProviderDashView {
  dashboard,
  packages,
  coverage,
  installationRequests,
  customers,
  reviews,
  messages,
  analytics,
}

class _DashboardState extends State<Dashboard> {
  bool _showMobileSidebar = false;
  _ProviderDashView _activeView = _ProviderDashView.dashboard;
  late Future<Map<String, dynamic>> _providerFuture;
  late DateTimeRange _selectedDateRange;
  late String _selectedMonth;
  final _inboxService = ProviderInbox();
  final _requestsSectionKey = GlobalKey();
  List<ProviderInboxItem> _inboxItems = const [];
  bool _inboxLoading = false;
  bool _inboxLoaded = false;
  String? _inboxError;
  bool _isTestUpgradeRunning = false;

  Future<void> _activateTestUpgrade() async {
    if (_isTestUpgradeRunning) return;
    setState(() => _isTestUpgradeRunning = true);

    try {
      await SubscriptionService().upgradeToProForTesting();
      if (!mounted) return;
      _refreshProviderDashboard();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Test Pro plan activated for 30 days.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString()),
        ),
      );
    } finally {
      if (mounted) setState(() => _isTestUpgradeRunning = false);
    }
  }

  Future<void> _refreshInbox() async {
    setState(() {
      _inboxLoading = true;
      _inboxError = null;
    });
    try {
      final items = await _inboxService.listInbox();
      if (!mounted) return;
      setState(() {
        _inboxItems = items;
        _inboxLoaded = true;
        _inboxLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inboxError = e.toString();
        _inboxLoaded = true;
        _inboxLoading = false;
      });
    }
  }

  void _refreshProviderDashboard() {
    setState(() {
      _providerFuture = AuthService().getProviderDashboardData();
    });
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      await _inboxService.accept(requestId);
      await _refreshInbox();
      _refreshProviderDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _declineRequest(String requestId, String? reason) async {
    try {
      await _inboxService.decline(requestId, reason: reason);
      await _refreshInbox();
      _refreshProviderDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _completeRequest(String requestId) async {
    try {
      await _inboxService.complete(requestId);
      await _refreshInbox();
      _refreshProviderDashboard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Installation completed. Customer added to Customers.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showInstallationRequests({bool closeSidebar = false}) {
    setState(() {
      _activeView = _ProviderDashView.installationRequests;
      if (closeSidebar) _showMobileSidebar = false;
    });
    _refreshInbox();
  }

  void _showDashboard({bool closeSidebar = false}) {
    setState(() {
      _activeView = _ProviderDashView.dashboard;
      if (closeSidebar) _showMobileSidebar = false;
    });
  }

  void _showView(_ProviderDashView view, {bool closeSidebar = false}) {
    setState(() {
      _activeView = view;
      if (closeSidebar) _showMobileSidebar = false;
    });
    if (view == _ProviderDashView.installationRequests ||
        view == _ProviderDashView.customers ||
        view == _ProviderDashView.messages) {
      _refreshInbox();
    }
  }

  Future<void> _logoutProvider({bool closeSidebar = false}) async {
    if (closeSidebar && mounted) {
      setState(() => _showMobileSidebar = false);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text('Sign out of this provider account?'),
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
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService().signOut();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Signed out successfully.'),
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Login(providerMode: true)),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not sign out: $error'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _providerFuture = AuthService().getProviderDashboardData();
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 6)),
      end: now,
    );
    _selectedMonth = _monthLabel(now);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshInbox());
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final dashboardTheme = baseTheme.copyWith(
      textTheme: GoogleFonts.urbanistTextTheme(baseTheme.textTheme),
      cardTheme: CardThemeData(
        color: _dashSurface(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _dashBorder(context)),
        ),
      ),
      dividerColor: _dashBorder(context),
    );
    return Theme(
      data: dashboardTheme,
      child: Builder(
        builder: (context) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _providerFuture,
            builder: (context, snapshot) {
              final provider = snapshot.data;
              final providerName = _providerName(provider);
              final providerStatus = _providerStatus(provider);
              final metrics = _metricsFromProvider(provider);
              final revenue = _revenueFromProvider(provider);
              final packages = _packagesFromProvider(provider);
              final locations = _locationsFromProvider(provider);
              final reviews = _reviewsFromProvider(provider);
              final pendingRequestCount = _intValue(
                provider,
                'pending_installations',
              );
              final livePendingRequestCount = _inboxLoaded
                  ? _inboxItems.where((request) => request.isPending).length
                  : pendingRequestCount;

              return DefaultTextStyle(
                style: _dashFont(color: _dashText(context), fontSize: 14),
                child: Scaffold(
                  backgroundColor: _dashBackground(context),
                  body: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 1100;
                      final content = switch (_activeView) {
                        _ProviderDashView.dashboard => _DashboardContent(
                          metrics: metrics,
                          revenue: revenue,
                          revenueTotal: _moneyValue(
                            provider,
                            'monthly_revenue',
                          ),
                          dateRangeLabel: _dateRangeLabel(_selectedDateRange),
                          selectedMonth: _selectedMonth,
                          onDateRangePressed: _pickDateRange,
                          onMonthPressed: _pickMonth,
                          packages: packages,
                          locations: locations,
                          requests: _inboxItems,
                          requestsLoading: _inboxLoading,
                          requestsError: _inboxError,
                          onRefreshRequests: _refreshInbox,
                          onAcceptRequest: _acceptRequest,
                          onDeclineRequest: _declineRequest,
                          onCompleteRequest: _completeRequest,
                          onOpenFullRequests: _showInstallationRequests,
                          requestsSectionKey: _requestsSectionKey,
                          reviews: reviews,
                          pendingRequestCount: livePendingRequestCount,
                          providerName: providerName,
                          providerStatus: providerStatus,
                          providerLoadError: snapshot.hasError
                              ? snapshot.error.toString()
                              : null,
                          isLoadingProvider:
                              snapshot.connectionState ==
                              ConnectionState.waiting,
                          showMenuButton: !wide,
                          onMenuPressed: () {
                            setState(() => _showMobileSidebar = true);
                          },
                        ),
                        _ProviderDashView.installationRequests =>
                          _InstallationRequestsPage(
                            providerName: providerName,
                            providerStatus: providerStatus,
                            notificationCount: livePendingRequestCount,
                            dateRangeLabel: _dateRangeLabel(_selectedDateRange),
                            requests: _inboxItems,
                            isLoading: _inboxLoading,
                            error: _inboxError,
                            showMenuButton: !wide,
                            onMenuPressed: () {
                              setState(() => _showMobileSidebar = true);
                            },
                            onDateRangePressed: _pickDateRange,
                            onBackToDashboard: _showDashboard,
                            onRefresh: _refreshInbox,
                            onAccept: _acceptRequest,
                            onDecline: _declineRequest,
                            onComplete: _completeRequest,
                          ),
                        _ProviderDashView.analytics => ProAnalyticsPage(
                          isPro:
                              provider?['subscription_tier']
                                  ?.toString()
                                  .trim()
                                  .toLowerCase() ==
                              'pro',
                          isUpgradeRunning: _isTestUpgradeRunning,
                          onUpgradePressed: _activateTestUpgrade,
                          showMenuButton: !wide,
                          onMenuPressed: () =>
                              setState(() => _showMobileSidebar = true),
                        ),
                        _ => _ProviderSectionPage(
                          view: _activeView,
                          providerId: provider?['id']?.toString() ?? '',
                          providerName: providerName,
                          providerStatus: providerStatus,
                          requests: _inboxItems,
                          showMenuButton: !wide,
                          onMenuPressed: () =>
                              setState(() => _showMobileSidebar = true),
                          onChanged: () {
                            _refreshProviderDashboard();
                            _refreshInbox();
                          },
                        ),
                      };
                      if (!wide) {
                        return SizedBox.expand(
                          child: SafeArea(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Positioned.fill(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(16),
                                    child: content,
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: () => setState(
                                      () => _showMobileSidebar = true,
                                    ),
                                    onHorizontalDragEnd: (details) {
                                      if ((details.primaryVelocity ?? 0) > 0) {
                                        setState(
                                          () => _showMobileSidebar = true,
                                        );
                                      }
                                    },
                                    child: const SizedBox(width: 24),
                                  ),
                                ),
                                if (_showMobileSidebar)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        setState(
                                          () => _showMobileSidebar = false,
                                        );
                                      },
                                      child: Container(
                                        color: Colors.black.withValues(
                                          alpha: .35,
                                        ),
                                      ),
                                    ),
                                  ),
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                  left: _showMobileSidebar ? 0 : -280,
                                  top: 0,
                                  bottom: 0,
                                  width: 280,
                                  child: Material(
                                    color: Colors.transparent,
                                    elevation: _showMobileSidebar ? 18 : 0,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {},
                                      onHorizontalDragEnd: (details) {
                                        if ((details.primaryVelocity ?? 0) <
                                            0) {
                                          setState(
                                            () => _showMobileSidebar = false,
                                          );
                                        }
                                      },
                                      child: _SideBar(
                                        activeView: _activeView,
                                        providerName: providerName,
                                        providerStatus: providerStatus,
                                        subscriptionTier:
                                            provider?['subscription_tier']
                                                ?.toString() ??
                                            'free',
                                        packageCount: packages.length,
                                        isUpgradeRunning: _isTestUpgradeRunning,
                                        pendingRequestCount:
                                            livePendingRequestCount,
                                        onViewPressed: (view) =>
                                            _showView(view, closeSidebar: true),
                                        onUpgradePressed: _activateTestUpgrade,
                                        onLogoutPressed: () =>
                                            _logoutProvider(closeSidebar: true),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Row(
                        children: [
                          _SideBar(
                            activeView: _activeView,
                            providerName: providerName,
                            providerStatus: providerStatus,
                            subscriptionTier:
                                provider?['subscription_tier']?.toString() ??
                                'free',
                            packageCount: packages.length,
                            isUpgradeRunning: _isTestUpgradeRunning,
                            pendingRequestCount: livePendingRequestCount,
                            onViewPressed: _showView,
                            onUpgradePressed: _activateTestUpgrade,
                            onLogoutPressed: _logoutProvider,
                          ),
                          Expanded(
                            child: SafeArea(
                              left: false,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  28,
                                  20,
                                  28,
                                  20,
                                ),
                                child: content,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _providerName(Map<String, dynamic>? provider) {
    final name = provider?['provider_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;

    final userName = AuthService().currentUser?.displayName?.trim();
    if (userName != null && userName.isNotEmpty) return userName;

    return 'Provider';
  }

  String _providerStatus(Map<String, dynamic>? provider) {
    if (provider == null) return 'Loading provider';
    if (provider['is_verified'] == true) return 'Verified Provider';

    final status = provider['status']?.toString().trim();
    if (status == null || status.isEmpty) return 'Provider';
    return '${status[0].toUpperCase()}${status.substring(1)} Provider';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.amber,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDateRange = picked);
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final months = List.generate(12, (index) {
      final month = DateTime(now.year, index + 1);
      return _monthLabel(month);
    });

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _dashSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: months.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: _dashBorder(context)),
            itemBuilder: (context, index) {
              final month = months[index];
              final selected = month == _selectedMonth;
              return ListTile(
                title: Text(
                  month,
                  style: TextStyle(
                    color: _dashText(context),
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
                trailing: selected
                    ? const Icon(Icons.check_rounded, color: AppTheme.amber)
                    : null,
                onTap: () => Navigator.pop(context, month),
              );
            },
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedMonth = selected);
  }

  List<_Metric> _metricsFromProvider(Map<String, dynamic>? provider) {
    return [
      _Metric(
        title: 'Active Customers',
        value: _formatInt(_intValue(provider, 'active_customers')),
        trend: 'Live',
        helper: 'customers',
        icon: Icons.groups_rounded,
        positive: true,
      ),
      _Metric(
        title: 'Pending Installations',
        value: _formatInt(_intValue(provider, 'pending_installations')),
        trend: 'Live',
        helper: 'requests',
        icon: Icons.wifi_rounded,
        positive: true,
      ),
      _Metric(
        title: 'Monthly Revenue',
        value: 'KES ${_formatMoney(_moneyValue(provider, 'monthly_revenue'))}',
        trend: 'Live',
        helper: 'this month',
        icon: Icons.account_balance_wallet_outlined,
        positive: true,
      ),
      _Metric(
        title: 'Packages',
        value: _formatInt(_intValue(provider, 'packages_count')),
        trend: 'Live',
        helper: 'saved packages',
        icon: Icons.inventory_2_outlined,
        positive: true,
      ),
      _Metric(
        title: 'Coverage Areas',
        value: _formatInt(_intValue(provider, 'coverage_count')),
        trend: 'Live',
        helper: 'saved areas',
        icon: Icons.location_on_outlined,
        positive: true,
      ),
      _Metric(
        title: 'Pending Documents',
        value: _formatInt(_intValue(provider, 'pending_documents')),
        trend: 'Live',
        helper: 'awaiting review',
        icon: Icons.description_outlined,
        positive: true,
      ),
    ];
  }

  List<_RevenuePoint> _revenueFromProvider(Map<String, dynamic>? provider) {
    final history = provider?['revenue_history'];
    if (history is! List) return const [];
    return _mapList(history)
        .map(
          (point) => _RevenuePoint(
            point['month']?.toString() ?? '',
            _moneyFromObject(point['amount']),
          ),
        )
        .where((point) => point.month.isNotEmpty)
        .toList();
  }

  List<_PackageRow> _packagesFromProvider(Map<String, dynamic>? provider) {
    final packages = provider?['packages'];
    if (packages is! List) return const [];

    return _mapList(packages).map((package) {
      final name = _stringValue(package, 'package_name');
      final speed = _intFromObject(package['speed_mbps']);
      final label = [
        if (name != null && name.isNotEmpty) name,
        if (speed > 0) '$speed Mbps',
      ].join(' - ');
      final users = _intFromObject(
        package['users'] ??
            package['active_users'] ??
            package['customer_count'],
      );
      final revenue = _moneyFromObject(
        package['revenue'] ?? package['monthly_revenue'],
      );
      final growth = _moneyFromObject(
        package['growth'] ?? package['growth_percent'],
      );

      return _PackageRow(
        label.isEmpty ? 'Package' : label,
        _formatInt(users),
        'KES ${_formatMoney(revenue)}',
        '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(0)}%',
        growth >= 0,
        Icons.wifi_rounded,
        AppTheme.amber,
      );
    }).toList();
  }

  List<_LocationRow> _locationsFromProvider(Map<String, dynamic>? provider) {
    final areas = provider?['coverage_areas'];
    if (areas is! List) return const [];

    return areas
        .map((area) {
          if (area is Map) {
            final map = Map<String, dynamic>.from(area);
            final name =
                _stringValue(map, 'name') ??
                _stringValue(map, 'area_name') ??
                _stringValue(map, 'area') ??
                _stringValue(map, 'location') ??
                'Coverage area';
            final users = _intFromObject(
              map['users'] ?? map['active_users'] ?? map['customer_count'],
            );
            final revenue = _moneyFromObject(
              map['revenue'] ?? map['monthly_revenue'],
            );
            final progress = (_moneyFromObject(map['progress']) / 100)
                .clamp(.08, 1.0)
                .toDouble();
            return _LocationRow(
              name,
              '${_formatInt(users)} users',
              'KES ${_formatMoney(revenue)}',
              users > 0 ? progress : .08,
              latitude: _nullableDouble(map['latitude']),
              longitude: _nullableDouble(map['longitude']),
              radiusKm: _nullableDouble(map['radius_km']),
            );
          }

          final name = area.toString().trim();
          return _LocationRow(name, '0 users', 'KES ${_formatMoney(0)}', .08);
        })
        .where((area) => area.name.isNotEmpty)
        .toList();
  }

  List<_ReviewRow> _reviewsFromProvider(Map<String, dynamic>? provider) {
    final reviews = provider?['recent_reviews'];
    if (reviews is! List) return const [];
    return _mapList(reviews).map((review) {
      final name =
          _stringValue(review, 'customer_name') ??
          _stringValue(review, 'name') ??
          'Customer';
      final plan =
          _stringValue(review, 'package_name') ??
          _stringValue(review, 'plan') ??
          'OnaNet package';
      final comment =
          _stringValue(review, 'comment') ??
          _stringValue(review, 'review') ??
          'No comment provided.';
      final stars = _intFromObject(
        review['stars'] ?? review['rating'],
      ).clamp(0, 5).toInt();
      return _ReviewRow(
        _initials(name).substring(0, 1),
        name,
        plan,
        comment,
        stars,
      );
    }).toList();
  }

  List<Map<String, dynamic>> _mapList(List<dynamic> items) {
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String? _stringValue(Map<String, dynamic> data, String key) {
    final value = data[key]?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  int _intValue(Map<String, dynamic>? data, String key) {
    return _intFromObject(data?[key]);
  }

  int _intFromObject(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _moneyValue(Map<String, dynamic>? data, String key) {
    return _moneyFromObject(data?[key]);
  }

  double _moneyFromObject(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _nullableDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _formatInt(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
  }

  String _formatMoney(double value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  String _dateRangeLabel(DateTimeRange range) {
    final sameYear = range.start.year == range.end.year;
    final start = sameYear
        ? '${_shortMonth(range.start)} ${range.start.day}'
        : '${_shortMonth(range.start)} ${range.start.day}, ${range.start.year}';
    final end = '${_shortMonth(range.end)} ${range.end.day}, ${range.end.year}';
    return '$start - $end';
  }

  String _monthLabel(DateTime date) => '${_longMonth(date)} ${date.year}';

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'ON';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  String _shortMonth(DateTime date) {
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
    return months[date.month - 1];
  }

  String _longMonth(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[date.month - 1];
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.metrics,
    required this.revenue,
    required this.revenueTotal,
    required this.dateRangeLabel,
    required this.selectedMonth,
    required this.onDateRangePressed,
    required this.onMonthPressed,
    required this.packages,
    required this.locations,
    required this.requests,
    required this.requestsLoading,
    required this.requestsError,
    required this.onRefreshRequests,
    required this.onAcceptRequest,
    required this.onDeclineRequest,
    required this.onCompleteRequest,
    required this.onOpenFullRequests,
    required this.requestsSectionKey,
    required this.reviews,
    required this.pendingRequestCount,
    required this.providerName,
    required this.providerStatus,
    required this.providerLoadError,
    required this.isLoadingProvider,
    required this.showMenuButton,
    required this.onMenuPressed,
  });
  final List<_Metric> metrics;
  final List<_RevenuePoint> revenue;
  final double revenueTotal;
  final String dateRangeLabel;
  final String selectedMonth;
  final VoidCallback onDateRangePressed;
  final VoidCallback onMonthPressed;
  final List<_PackageRow> packages;
  final List<_LocationRow> locations;
  final List<ProviderInboxItem> requests;
  final bool requestsLoading;
  final String? requestsError;
  final Future<void> Function() onRefreshRequests;
  final Future<void> Function(String requestId) onAcceptRequest;
  final Future<void> Function(String requestId, String? reason)
  onDeclineRequest;
  final Future<void> Function(String requestId) onCompleteRequest;
  final VoidCallback onOpenFullRequests;
  final GlobalKey requestsSectionKey;
  final List<_ReviewRow> reviews;
  final int pendingRequestCount;
  final String providerName;
  final String providerStatus;
  final String? providerLoadError;
  final bool isLoadingProvider;
  final bool showMenuButton;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(
          providerName: providerName,
          providerStatus: providerStatus,
          notificationCount: pendingRequestCount,
          dateRangeLabel: dateRangeLabel,
          onDateRangePressed: onDateRangePressed,
          showMenuButton: showMenuButton,
          onMenuPressed: onMenuPressed,
        ),
        if (providerLoadError != null) ...[
          const SizedBox(height: 12),
          _DashboardNotice(message: providerLoadError!),
        ] else if (isLoadingProvider) ...[
          const SizedBox(height: 12),
          const _DashboardNotice(message: 'Loading provider dashboard data...'),
        ],
        const SizedBox(height: 24),
        _MetricGrid(metrics: metrics),
        const SizedBox(height: 18),
        _ResponsivePair(
          leftFlex: 9,
          rightFlex: 10,
          left: _RevenueCard(
            points: revenue,
            totalRevenue: revenueTotal,
            selectedMonth: selectedMonth,
            onMonthPressed: onMonthPressed,
          ),
          right: _PackagesCard(
            packages: packages,
            selectedMonth: selectedMonth,
            onMonthPressed: onMonthPressed,
          ),
        ),
        const SizedBox(height: 18),
        _ResponsivePair(
          leftFlex: 9,
          rightFlex: 10,
          left: _LocationsCard(locations: locations),
          right: _RequestsCard(
            key: requestsSectionKey,
            requests: requests,
            isLoading: requestsLoading,
            error: requestsError,
            onRefresh: onRefreshRequests,
            onAccept: onAcceptRequest,
            onDecline: onDeclineRequest,
            onComplete: onCompleteRequest,
            onViewAll: onOpenFullRequests,
          ),
        ),
        const SizedBox(height: 18),
        _ReviewsCard(reviews: reviews),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '© ${DateTime.now().year} OnaNet. All rights reserved.',
            style: TextStyle(color: _dashMuted(context), fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.providerName,
    required this.providerStatus,
    required this.notificationCount,
    required this.dateRangeLabel,
    required this.onDateRangePressed,
    required this.showMenuButton,
    required this.onMenuPressed,
  });

  final String providerName;
  final String providerStatus;
  final int notificationCount;
  final String dateRangeLabel;
  final VoidCallback onDateRangePressed;
  final bool showMenuButton;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF102D3E), Color(0xFF0A1E2B)]
              : const [Color(0xFFFFFFFF), Color(0xFFFFF8E8)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _dashBorder(context)),
        boxShadow: [
          BoxShadow(
            color: _dashShadow(context),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 760;
          final welcome = _WelcomeBlock(
            providerName: providerName,
            showMenuButton: showMenuButton,
            onMenuPressed: onMenuPressed,
          );

          if (mobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                welcome,
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: dateRangeLabel,
                        onPressed: onDateRangePressed,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _NotificationButton(count: notificationCount),
                  ],
                ),
                const SizedBox(height: 10),
                _ProfileChip(
                  expanded: true,
                  providerName: providerName,
                  providerStatus: providerStatus,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: welcome),
              const SizedBox(width: 20),
              _HeaderActions(
                providerName: providerName,
                providerStatus: providerStatus,
                notificationCount: notificationCount,
                dateRangeLabel: dateRangeLabel,
                onDateRangePressed: onDateRangePressed,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WelcomeBlock extends StatelessWidget {
  const _WelcomeBlock({
    required this.providerName,
    required this.showMenuButton,
    required this.onMenuPressed,
  });

  final String providerName;
  final bool showMenuButton;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showMenuButton) ...[
          _MenuButton(onPressed: onMenuPressed),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BUSINESS OVERVIEW',
                style: TextStyle(
                  color: _dashAccentText(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Good to see you, $providerName',
                softWrap: true,
                style: TextStyle(
                  color: _dashText(context),
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Here's what's happening with your business today.",
                softWrap: true,
                style: TextStyle(color: _dashMuted(context), fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.providerName,
    required this.providerStatus,
    required this.notificationCount,
    required this.dateRangeLabel,
    required this.onDateRangePressed,
  });

  final String providerName;
  final String providerStatus;
  final int notificationCount;
  final String dateRangeLabel;
  final VoidCallback onDateRangePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DateButton(
          width: 240,
          label: dateRangeLabel,
          onPressed: onDateRangePressed,
        ),
        const SizedBox(width: 12),
        _NotificationButton(count: notificationCount),
        const SizedBox(width: 12),
        _ProfileChip(
          providerName: providerName,
          providerStatus: providerStatus,
        ),
      ],
    );
  }
}

class _DashboardNotice extends StatelessWidget {
  const _DashboardNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _dashSoftAmber(context),
        border: Border.all(color: _dashBorder(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: _dashText(context),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Open sidebar',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: _dashSurface(context),
            border: Border.all(color: _dashBorder(context)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.menu_rounded, color: _dashText(context)),
        ),
      ),
    );
  }
}

class _SideBar extends StatelessWidget {
  const _SideBar({
    required this.activeView,
    required this.providerName,
    required this.providerStatus,
    required this.subscriptionTier,
    required this.packageCount,
    required this.isUpgradeRunning,
    required this.pendingRequestCount,
    required this.onViewPressed,
    required this.onUpgradePressed,
    required this.onLogoutPressed,
  });

  final _ProviderDashView activeView;
  final String providerName;
  final String providerStatus;
  final String subscriptionTier;
  final int packageCount;
  final bool isUpgradeRunning;
  final int pendingRequestCount;
  final void Function(_ProviderDashView view) onViewPressed;
  final VoidCallback onUpgradePressed;
  final VoidCallback onLogoutPressed;

  @override
  Widget build(BuildContext context) {
    final operateItems = <(String, IconData, String, _ProviderDashView)>[
      ('Dashboard', Icons.home_rounded, '0', _ProviderDashView.dashboard),
      (
        'Packages',
        Icons.router_outlined,
        packageCount.toString(),
        _ProviderDashView.packages,
      ),
      ('Coverage', Icons.map_outlined, '0', _ProviderDashView.coverage),
      (
        'Installation Requests',
        Icons.groups_2_outlined,
        pendingRequestCount.toString(),
        _ProviderDashView.installationRequests,
      ),
      (
        'Customers',
        Icons.people_outline_rounded,
        '0',
        _ProviderDashView.customers,
      ),
    ];
    final growItems = <(String, IconData, String, _ProviderDashView?)>[
      ('Reviews', Icons.star_border_rounded, '0', _ProviderDashView.reviews),
      (
        'Analytics',
        Icons.bar_chart_rounded,
        'PRO',
        _ProviderDashView.analytics,
      ),
      ('Messages', Icons.mail_outline_rounded, '0', _ProviderDashView.messages),
    ];
    return SizedBox(
      width: 280,
      height: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF071D2B), Color(0xFF04131E)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            key: const PageStorageKey<String>('provider-sidebar'),
            primary: false,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.amberLight, AppTheme.amber],
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.amber.withValues(alpha: .24),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.wifi_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Ona',
                            style: _dashFont(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: 'Net',
                            style: _dashFont(
                              color: AppTheme.amber,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: '\nProvider workspace',
                            style: _dashFont(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ProviderIdentity(
                  name: providerName,
                  status: providerStatus,
                ),
              ),
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: _NavSectionLabel('OPERATE'),
              ),
              for (final item in operateItems)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: _NavItem(
                    label: item.$1,
                    icon: item.$2,
                    badge: item.$3,
                    selected: activeView == item.$4,
                    onTap: () => onViewPressed(item.$4),
                  ),
                ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: _NavSectionLabel('GROW'),
              ),
              for (final item in growItems)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: _NavItem(
                    label: item.$1,
                    icon: item.$2,
                    badge: item.$3,
                    selected: item.$4 != null && activeView == item.$4,
                    onTap: item.$4 == null
                        ? null
                        : () => onViewPressed(item.$4!),
                  ),
                ),
              const SizedBox(height: 12),
              _PlanCard(
                tier: subscriptionTier,
                packageCount: packageCount,
                isUpgradeRunning: isUpgradeRunning,
                onUpgradePressed: onUpgradePressed,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: _NavItem(
                  label: 'Sign out',
                  icon: Icons.logout_rounded,
                  badge: '0',
                  selected: false,
                  onTap: onLogoutPressed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderIdentity extends StatelessWidget {
  const _ProviderIdentity({required this.name, required this.status});

  final String name;
  final String status;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'P' : name.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: Colors.white.withValues(alpha: .1),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavSectionLabel extends StatelessWidget {
  const _NavSectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.badge,
    required this.selected,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final String badge;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = selected
        ? Colors.white
        : enabled
        ? Colors.white.withValues(alpha: .84)
        : Colors.white.withValues(alpha: .42);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.amber.withValues(alpha: .18)
                : Colors.transparent,
            border: selected
                ? Border.all(color: AppTheme.amber.withValues(alpha: .38))
                : null,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? AppTheme.amber : foreground,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (badge != '0')
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.amber,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.tier,
    required this.packageCount,
    required this.isUpgradeRunning,
    required this.onUpgradePressed,
  });
  final String tier;
  final int packageCount;
  final bool isUpgradeRunning;
  final VoidCallback onUpgradePressed;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.amber.withValues(alpha: .09),
        border: Border.all(color: AppTheme.amber.withValues(alpha: .22)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: AppTheme.amber,
                size: 22,
              ),
              SizedBox(width: 12),
              Text(
                'SUBSCRIPTION',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_titleCase(tier)} plan',
            style: const TextStyle(
              color: AppTheme.amber,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$packageCount of 10 packages used',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (tier.toLowerCase() != 'pro') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isUpgradeRunning ? null : onUpgradePressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isUpgradeRunning)
                      const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(Icons.bolt_rounded, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isUpgradeRunning
                            ? 'UPGRADING...'
                            : 'TEST UPGRADE TO PRO',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _titleCase(String value) {
    final clean = value.trim().isEmpty ? 'free' : value.trim();
    return '${clean[0].toUpperCase()}${clean.substring(1)}';
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.onPressed, this.width});

  final String label;
  final VoidCallback onPressed;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Choose date range',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: _SoftButton(
          width: width,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                color: _dashText(context),
                size: 18,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _dashText(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _dashText(context),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    return Tooltip(
      message: 'Notifications',
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: _dashSurface(context),
          border: Border.all(color: _dashBorder(context)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: _dashText(context),
              size: 25,
            ),
            if (count > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.amber,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.providerName,
    required this.providerStatus,
    this.expanded = false,
  });

  final String providerName;
  final String providerStatus;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expanded ? double.infinity : 250,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _dashSurface(context),
        border: Border.all(color: _dashBorder(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: AppTheme.navy,
              shape: BoxShape.circle,
              border: Border.all(color: _dashSurface(context), width: 2),
              boxShadow: [
                BoxShadow(color: _dashShadow(context), blurRadius: 12),
              ],
            ),
            child: Center(
              child: Text(
                _initials(providerName),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  providerName,
                  softWrap: true,
                  style: TextStyle(
                    color: _dashText(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  providerStatus,
                  softWrap: true,
                  style: TextStyle(color: _dashMuted(context), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _dashText(context),
            size: 20,
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'ON';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});
  final List<_Metric> metrics;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth >= 1300
            ? 5
            : maxWidth >= 900
            ? 3
            : maxWidth >= 620
            ? 2
            : 1;
        final spacing = 18.0;
        final width = (maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _MetricCard(metric: metric),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;
  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconTile(icon: metric.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  metric.title.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _dashMuted(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: .65,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _dashText(context),
              fontWeight: FontWeight.w900,
              fontSize: 28,
              letterSpacing: -.7,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (metric.positive ? AppTheme.green : Colors.red)
                      .withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      metric.positive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: metric.positive ? AppTheme.green : Colors.red,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      metric.trend,
                      style: TextStyle(
                        color: metric.positive ? AppTheme.green : Colors.red,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  metric.helper,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _dashMuted(context), fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.points,
    required this.totalRevenue,
    required this.selectedMonth,
    required this.onMonthPressed,
  });
  final List<_RevenuePoint> points;
  final double totalRevenue;
  final String selectedMonth;
  final VoidCallback onMonthPressed;
  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            title: 'Revenue Overview',
            subTitle: '(KES)',
            action: _SmallSelect(label: selectedMonth, onTap: onMonthPressed),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 250,
            child: CustomPaint(
              painter: _RevenueChartPainter(
                points,
                gridColor: _dashBorder(context),
                axisColor: _dashMuted(context),
                valueColor: _dashText(context),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Divider(height: 26, color: _dashBorder(context)),
          Wrap(
            spacing: 22,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _TinyIcon(icon: Icons.account_balance_wallet_outlined),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Revenue ($selectedMonth)',
                        style: TextStyle(
                          color: _dashMuted(context),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'KES ${_formatMoney(totalRevenue)}',
                        style: TextStyle(
                          color: _dashText(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMoney(double value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }
}

class _PackagesCard extends StatelessWidget {
  const _PackagesCard({
    required this.packages,
    required this.selectedMonth,
    required this.onMonthPressed,
  });
  final List<_PackageRow> packages;
  final String selectedMonth;
  final VoidCallback onMonthPressed;
  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardHeader(
                title: 'Top Performing Packages',
                action: _SmallSelect(
                  label: selectedMonth,
                  onTap: onMonthPressed,
                ),
              ),
              const SizedBox(height: 14),
              if (!compact)
                _TableHeader(
                  columns: const [
                    'Package',
                    'Users',
                    'Revenue (KES)',
                    'Growth',
                  ],
                  flexes: const [4, 2, 3, 2],
                ),
              if (packages.isEmpty)
                const _EmptyDashboardText(message: 'No packages saved yet.')
              else
                ...packages.map(
                  (package) => _PackageItem(package: package, compact: compact),
                ),
              const SizedBox(height: 14),
              _PackageActions(compact: compact),
            ],
          );
        },
      ),
    );
  }
}

class _PackageActions extends StatelessWidget {
  const _PackageActions({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final viewButton = OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: _dashText(context),
        side: BorderSide(color: _dashBorder(context)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      ),
      onPressed: () {},
      child: const Text('View all packages', overflow: TextOverflow.ellipsis),
    );

    final addButton = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.amber,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      ),
      onPressed: () {},
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add Package', overflow: TextOverflow.ellipsis),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [viewButton, const SizedBox(height: 10), addButton],
      );
    }

    return Row(
      children: [
        viewButton,
        const Spacer(),
        Flexible(child: addButton),
      ],
    );
  }
}

class _LocationsCard extends StatelessWidget {
  const _LocationsCard({required this.locations});
  final List<_LocationRow> locations;
  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardHeader(
            title: 'Top Locations',
            subTitle: '(By Active Users)',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 620;
              final map = SizedBox(
                height: 230,
                child: _CoverageMap(locations: locations),
              );
              final list = Column(
                children: [
                  if (locations.isEmpty)
                    const _EmptyDashboardText(
                      message: 'No coverage areas saved yet.',
                    )
                  else
                    for (var i = 0; i < locations.length; i++)
                      _LocationItem(index: i + 1, location: locations[i]),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {},
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('View all coverage areas'),
                      style: TextButton.styleFrom(
                        foregroundColor: _dashAccentText(context),
                      ),
                    ),
                  ),
                ],
              );
              if (stacked) {
                return Column(
                  children: [map, const SizedBox(height: 16), list],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: map),
                  const SizedBox(width: 24),
                  Expanded(flex: 6, child: list),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CoverageMap extends StatelessWidget {
  const _CoverageMap({required this.locations});

  final List<_LocationRow> locations;

  @override
  Widget build(BuildContext context) {
    final mapped = locations
        .where(
          (location) => location.latitude != null && location.longitude != null,
        )
        .toList();
    if (mapped.isEmpty) {
      return const Center(
        child: _EmptyDashboardText(
          message: 'Add coverage coordinates to see the live map.',
        ),
      );
    }
    final center = LatLng(mapped.first.latitude!, mapped.first.longitude!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 11,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.onanet.provider.dashboard',
          ),
          CircleLayer(
            circles: mapped
                .map(
                  (location) => CircleMarker(
                    point: LatLng(location.latitude!, location.longitude!),
                    radius: math.max(1, location.radiusKm ?? 1) * 1000,
                    useRadiusInMeter: true,
                    color: AppTheme.amber.withValues(alpha: .2),
                    borderColor: AppTheme.amber,
                    borderStrokeWidth: 2,
                  ),
                )
                .toList(),
          ),
          MarkerLayer(
            markers: mapped
                .map(
                  (location) => Marker(
                    point: LatLng(location.latitude!, location.longitude!),
                    width: 120,
                    height: 28,
                    child: _MapLabel(label: location.name),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppTheme.navy,
        fontWeight: FontWeight.w800,
        fontSize: 16,
        shadows: [
          Shadow(color: Colors.white.withValues(alpha: .9), blurRadius: 6),
        ],
      ),
    );
  }
}

class _RequestsCard extends StatelessWidget {
  const _RequestsCard({
    super.key,
    required this.requests,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    required this.onAccept,
    required this.onDecline,
    required this.onComplete,
    required this.onViewAll,
  });

  final List<ProviderInboxItem> requests;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String requestId) onAccept;
  final Future<void> Function(String requestId, String? reason) onDecline;
  final Future<void> Function(String requestId) onComplete;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            title: 'Installation Requests',
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    foregroundColor: _dashAccentText(context),
                  ),
                  child: const Text('View all'),
                ),
                TextButton.icon(
                  onPressed: () => onRefresh(),
                  style: TextButton.styleFrom(
                    foregroundColor: _dashAccentText(context),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: Text(isLoading ? 'Refreshing...' : 'Refresh'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (error != null) ...[
            _DashboardNotice(message: error!),
            const SizedBox(height: 10),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 860,
              child: Column(
                children: [
                  const _TableHeader(
                    columns: [
                      'Customer',
                      'Package',
                      'Location',
                      'Requested On',
                      'Status',
                      'Actions',
                    ],
                    flexes: [3, 3, 2, 3, 3, 2],
                  ),
                  _buildInboxList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInboxList() {
    if (isLoading && requests.isEmpty) {
      return const _InboxLoadingSkeleton();
    }

    if (requests.isEmpty) {
      return _InboxEmptyState(
        message: error == null
            ? 'No installation requests yet.'
            : 'No installation requests loaded.',
        onRefresh: onRefresh,
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        return _RequestItem(
          request: requests[index],
          onAccept: onAccept,
          onDecline: onDecline,
          onComplete: onComplete,
        );
      },
    );
  }
}

enum _RequestListFilter { all, pending, accepted, completed, declined }

class _InstallationRequestsPage extends StatefulWidget {
  const _InstallationRequestsPage({
    required this.providerName,
    required this.providerStatus,
    required this.notificationCount,
    required this.dateRangeLabel,
    required this.requests,
    required this.isLoading,
    required this.error,
    required this.showMenuButton,
    required this.onMenuPressed,
    required this.onDateRangePressed,
    required this.onBackToDashboard,
    required this.onRefresh,
    required this.onAccept,
    required this.onDecline,
    required this.onComplete,
  });

  final String providerName;
  final String providerStatus;
  final int notificationCount;
  final String dateRangeLabel;
  final List<ProviderInboxItem> requests;
  final bool isLoading;
  final String? error;
  final bool showMenuButton;
  final VoidCallback onMenuPressed;
  final VoidCallback onDateRangePressed;
  final VoidCallback onBackToDashboard;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String requestId) onAccept;
  final Future<void> Function(String requestId, String? reason) onDecline;
  final Future<void> Function(String requestId) onComplete;

  @override
  State<_InstallationRequestsPage> createState() =>
      _InstallationRequestsPageState();
}

class _InstallationRequestsPageState extends State<_InstallationRequestsPage> {
  _RequestListFilter _filter = _RequestListFilter.all;

  List<ProviderInboxItem> _filteredRequests() {
    return switch (_filter) {
      _RequestListFilter.all => widget.requests,
      _RequestListFilter.pending =>
        widget.requests
            .where((request) => request.isPending)
            .toList(growable: false),
      _RequestListFilter.accepted =>
        widget.requests
            .where((request) => request.isAccepted)
            .toList(growable: false),
      _RequestListFilter.completed =>
        widget.requests
            .where((request) => request.isCompleted)
            .toList(growable: false),
      _RequestListFilter.declined =>
        widget.requests
            .where((request) => request.isDeclined)
            .toList(growable: false),
    };
  }

  String _filterLabel() {
    return switch (_filter) {
      _RequestListFilter.all => 'installation requests',
      _RequestListFilter.pending => 'pending requests',
      _RequestListFilter.accepted => 'accepted requests',
      _RequestListFilter.completed => 'completed requests',
      _RequestListFilter.declined => 'declined requests',
    };
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.requests
        .where((request) => request.isPending)
        .length;
    final accepted = widget.requests
        .where((request) => request.isAccepted)
        .length;
    final finished = widget.requests
        .where((request) => request.isCompleted)
        .length;
    final declined = widget.requests
        .where((request) => request.isDeclined)
        .length;
    final visibleRequests = _filteredRequests();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(
          providerName: widget.providerName,
          providerStatus: widget.providerStatus,
          notificationCount: widget.notificationCount,
          dateRangeLabel: widget.dateRangeLabel,
          onDateRangePressed: widget.onDateRangePressed,
          showMenuButton: widget.showMenuButton,
          onMenuPressed: widget.onMenuPressed,
        ),
        const SizedBox(height: 24),
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  final title = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Installation Requests',
                        style: TextStyle(
                          color: _dashText(context),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Full customer details and request actions',
                        style: TextStyle(
                          color: _dashMuted(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                  final actions = Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.onBackToDashboard,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Dashboard'),
                      ),
                      FilledButton.icon(
                        onPressed: () => widget.onRefresh(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          widget.isLoading ? 'Refreshing' : 'Refresh',
                        ),
                      ),
                    ],
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title, const SizedBox(height: 14), actions],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 14),
                      actions,
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _RequestSummaryChip(
                    label: 'Total',
                    value: widget.requests.length.toString(),
                    color: AppTheme.amber,
                    selected: _filter == _RequestListFilter.all,
                    onTap: () {
                      setState(() => _filter = _RequestListFilter.all);
                    },
                  ),
                  _RequestSummaryChip(
                    label: 'Pending',
                    value: pending.toString(),
                    color: Colors.orange,
                    selected: _filter == _RequestListFilter.pending,
                    onTap: () {
                      setState(() => _filter = _RequestListFilter.pending);
                    },
                  ),
                  _RequestSummaryChip(
                    label: 'Accepted',
                    value: accepted.toString(),
                    color: Colors.blue,
                    selected: _filter == _RequestListFilter.accepted,
                    onTap: () {
                      setState(() => _filter = _RequestListFilter.accepted);
                    },
                  ),
                  _RequestSummaryChip(
                    label: 'Completed',
                    value: finished.toString(),
                    color: AppTheme.green,
                    selected: _filter == _RequestListFilter.completed,
                    onTap: () {
                      setState(() => _filter = _RequestListFilter.completed);
                    },
                  ),
                  _RequestSummaryChip(
                    label: 'Declined',
                    value: declined.toString(),
                    color: Colors.red,
                    selected: _filter == _RequestListFilter.declined,
                    onTap: () {
                      setState(() => _filter = _RequestListFilter.declined);
                    },
                  ),
                ],
              ),
              if (widget.error != null) ...[
                const SizedBox(height: 14),
                _DashboardNotice(message: widget.error!),
              ],
              const SizedBox(height: 16),
              if (widget.isLoading && widget.requests.isEmpty)
                const _InboxLoadingSkeleton()
              else if (visibleRequests.isEmpty)
                _InboxEmptyState(
                  message: widget.error == null
                      ? 'No ${_filterLabel()} yet.'
                      : 'No ${_filterLabel()} loaded.',
                  onRefresh: widget.onRefresh,
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleRequests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _DetailedRequestItem(
                      request: visibleRequests[index],
                      onAccept: widget.onAccept,
                      onDecline: widget.onDecline,
                      onComplete: widget.onComplete,
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RequestSummaryChip extends StatelessWidget {
  const _RequestSummaryChip({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : color;
    final labelColor = selected ? Colors.white : _dashText(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: .28),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailedRequestItem extends StatelessWidget {
  const _DetailedRequestItem({
    required this.request,
    required this.onAccept,
    required this.onDecline,
    required this.onComplete,
  });

  final ProviderInboxItem request;
  final Future<void> Function(String requestId) onAccept;
  final Future<void> Function(String requestId, String? reason) onDecline;
  final Future<void> Function(String requestId) onComplete;

  @override
  Widget build(BuildContext context) {
    final statusColors = _inboxStatusColors(request.statusLabel);
    final customer = _requestCustomerLabel(request);
    final packageLabel = _requestPackageLabel(request);
    final preferredDate = request.preferredDate == null
        ? 'Not set'
        : _inboxDateLabel(request.preferredDate!);
    final preferredTime = request.preferredTime == null
        ? 'Not set'
        : _inboxTimeLabel(request.preferredTime!);
    final createdAt = request.createdAt == null
        ? 'Not set'
        : _inboxDateLabel(request.createdAt!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _dashBackground(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _dashBorder(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final header = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _dashSoftAmber(context),
                child: Text(
                  _inboxInitials(customer),
                  style: TextStyle(
                    color: _dashAccentText(context),
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
                      customer,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _dashText(context),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customer ID: ${request.userId.isEmpty ? 'Not set' : request.userId}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _dashMuted(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(
                label: request.statusLabel,
                background: statusColors.$1,
                foreground: statusColors.$2,
              ),
            ],
          );

          final details = Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _RequestDetailTile(
                icon: Icons.inventory_2_outlined,
                label: 'Package',
                value: packageLabel,
              ),
              _RequestDetailTile(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: request.phoneE164?.trim().isNotEmpty == true
                    ? request.phoneE164!.trim()
                    : 'Not set',
              ),
              _RequestDetailTile(
                icon: Icons.apartment_rounded,
                label: 'Estate / Building',
                value: request.estateOrBuilding.trim().isEmpty
                    ? 'Not set'
                    : request.estateOrBuilding.trim(),
              ),
              _RequestDetailTile(
                icon: Icons.home_work_outlined,
                label: 'House / Apartment',
                value: request.houseOrApartment?.trim().isNotEmpty == true
                    ? request.houseOrApartment!.trim()
                    : 'Not set',
              ),
              _RequestDetailTile(
                icon: Icons.place_outlined,
                label: 'Landmark',
                value: request.landmark?.trim().isNotEmpty == true
                    ? request.landmark!.trim()
                    : 'Not set',
              ),
              _RequestDetailTile(
                icon: Icons.my_location_rounded,
                label: 'Map Location',
                value: request.gpsLocation?.trim().isNotEmpty == true
                    ? 'Open in Google Maps'
                    : 'Not set',
                onTap: request.gpsLocation?.trim().isNotEmpty == true
                    ? () =>
                          _openMapLocation(context, request.gpsLocation!.trim())
                    : null,
              ),
              _RequestDetailTile(
                icon: Icons.event_available_outlined,
                label: 'Preferred Date',
                value: preferredDate,
              ),
              _RequestDetailTile(
                icon: Icons.schedule_rounded,
                label: 'Preferred Time',
                value: preferredTime,
              ),
              _RequestDetailTile(
                icon: Icons.inbox_outlined,
                label: 'Requested On',
                value: createdAt,
              ),
              if (request.declineReason?.trim().isNotEmpty == true)
                _RequestDetailTile(
                  icon: Icons.report_problem_outlined,
                  label: 'Decline Reason',
                  value: request.declineReason!.trim(),
                ),
              if (request.customerMessage?.trim().isNotEmpty == true)
                _RequestDetailTile(
                  icon: Icons.message_outlined,
                  label: 'Customer Message',
                  value: request.customerMessage!.trim(),
                ),
            ],
          );

          final actions = _RequestActionButtons(
            request: request,
            onAccept: onAccept,
            onDecline: onDecline,
            onComplete: onComplete,
            compact: false,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 14),
                details,
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: header),
                  const SizedBox(width: 16),
                  actions,
                ],
              ),
              const SizedBox(height: 14),
              details,
            ],
          );
        },
      ),
    );
  }
}

class _RequestDetailTile extends StatelessWidget {
  const _RequestDetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: _dashAccentText(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _dashMuted(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      value,
                      softWrap: true,
                      style: TextStyle(
                        color: onTap == null
                            ? _dashText(context)
                            : _dashAccentText(context),
                        decoration: onTap == null
                            ? TextDecoration.none
                            : TextDecoration.underline,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
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

class _InboxLoadingSkeleton extends StatelessWidget {
  const _InboxLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => _RowShell(
          child: Row(
            children: [
              for (final width in const [170.0, 150.0, 120.0, 115.0, 92.0])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: _SkeletonBar(width: width),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        height: 14,
        decoration: BoxDecoration(
          color: _dashBorder(context).withValues(alpha: .62),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _InboxEmptyState extends StatelessWidget {
  const _InboxEmptyState({required this.message, required this.onRefresh});

  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: _dashSoftAmber(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _dashBorder(context)),
            ),
            child: Icon(
              Icons.mark_email_unread_outlined,
              color: _dashAccentText(context),
              size: 34,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _dashText(context),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => onRefresh(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh Inbox'),
          ),
        ],
      ),
    );
  }
}

class _ReviewsCard extends StatelessWidget {
  const _ReviewsCard({required this.reviews});
  final List<_ReviewRow> reviews;
  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            title: 'Recent Reviews',
            trailing: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: _dashAccentText(context),
              ),
              child: const Text('View all'),
            ),
          ),
          const SizedBox(height: 14),
          if (reviews.isEmpty)
            const _EmptyDashboardText(message: 'No reviews yet.')
          else
            ...reviews.map((review) => _ReviewItem(review: review)),
        ],
      ),
    );
  }
}

class _EmptyDashboardText extends StatelessWidget {
  const _EmptyDashboardText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _dashMuted(context),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(children: [left, const SizedBox(height: 18), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: 18),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      },
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _dashSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _dashBorder(context)),
        boxShadow: [
          BoxShadow(
            color: _dashShadow(context),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, this.subTitle, this.action});
  final String title;
  final String? subTitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final subTitleSpan = subTitle == null
        ? null
        : TextSpan(
            text: ' $subTitle',
            style: _dashFont(
              color: _dashMuted(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          );
    final action = this.action;
    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              text: title,
              style: _dashFont(
                color: _dashText(context),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
              children: [?subTitleSpan],
            ),
          ),
        ),
        ?action,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: _dashText(context),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.columns, required this.flexes});
  final List<String> columns;
  final List<int> flexes;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _dashBorder(context))),
      ),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: flexes[i],
              child: Text(
                columns[i],
                style: TextStyle(
                  color: _dashMuted(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PackageItem extends StatelessWidget {
  const _PackageItem({required this.package, required this.compact});
  final _PackageRow package;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _RowShell(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CircleIcon(icon: package.icon, color: package.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          package.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _dashText(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Growth(
                        value: package.growth,
                        positive: package.positive,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${package.users} users',
                        style: TextStyle(
                          color: _dashMuted(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        package.revenue,
                        style: TextStyle(
                          color: _dashText(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _RowShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                _CircleIcon(icon: package.icon, color: package.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    package.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _dashText(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: _Cell(package.users)),
          Expanded(flex: 3, child: _Cell(package.revenue, bold: true)),
          Expanded(
            flex: 2,
            child: _Growth(value: package.growth, positive: package.positive),
          ),
        ],
      ),
    );
  }
}

class _LocationItem extends StatelessWidget {
  const _LocationItem({required this.index, required this.location});
  final int index;
  final _LocationRow location;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$index',
              style: TextStyle(
                color: _dashText(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              location.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _dashText(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.users,
                  style: TextStyle(color: _dashMuted(context), fontSize: 12),
                ),
                const SizedBox(height: 5),
                FractionallySizedBox(
                  widthFactor: location.progress,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.amber,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              location.revenue,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: _dashText(context),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestItem extends StatelessWidget {
  const _RequestItem({
    required this.request,
    required this.onAccept,
    required this.onDecline,
    required this.onComplete,
  });

  final ProviderInboxItem request;
  final Future<void> Function(String requestId) onAccept;
  final Future<void> Function(String requestId, String? reason) onDecline;
  final Future<void> Function(String requestId) onComplete;

  @override
  Widget build(BuildContext context) {
    final customer = _requestCustomerLabel(request);
    final location = [
      request.estateOrBuilding,
      if (request.houseOrApartment?.isNotEmpty == true)
        request.houseOrApartment!,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    final date = request.preferredDate ?? request.createdAt;
    final status = request.statusLabel;
    final colors = _inboxStatusColors(status);
    final packageLabel = _requestPackageLabel(request);

    return _RowShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: _dashBorder(context),
                  child: Text(
                    _inboxInitials(customer),
                    style: TextStyle(
                      color: _dashText(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _Cell(customer, bold: true, full: true)),
              ],
            ),
          ),
          Expanded(flex: 3, child: _Cell(packageLabel, full: true)),
          Expanded(
            flex: 2,
            child: _Cell(location.isEmpty ? 'Not set' : location, full: true),
          ),
          Expanded(
            flex: 3,
            child: _Cell(
              date == null ? 'Not set' : _inboxDateLabel(date),
              full: true,
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusPill(
                label: status,
                background: colors.$1,
                foreground: colors.$2,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _RequestActionButtons(
              request: request,
              onAccept: onAccept,
              onDecline: onDecline,
              onComplete: onComplete,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestActionButtons extends StatelessWidget {
  const _RequestActionButtons({
    required this.request,
    required this.onAccept,
    required this.onDecline,
    required this.onComplete,
    required this.compact,
  });

  final ProviderInboxItem request;
  final Future<void> Function(String requestId) onAccept;
  final Future<void> Function(String requestId, String? reason) onDecline;
  final Future<void> Function(String requestId) onComplete;
  final bool compact;

  Future<void> _confirmAndDecline(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Decline request?'),
          content: const Text(
            'This will mark the installation request as declined.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    final reason = await _showDeclineReasonSheet(context);
    if (reason == null || !context.mounted) return;
    await onDecline(request.id, reason);
  }

  Future<String?> _showDeclineReasonSheet(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _DeclineReasonSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAct = request.id.isNotEmpty && request.isPending;
    final canComplete = request.id.isNotEmpty && request.isAccepted;
    if (compact) {
      return Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ActionIcon(icon: Icons.remove_red_eye_outlined),
          _ActionIcon(
            icon: request.isAccepted || request.isCompleted
                ? Icons.check_circle_outline_rounded
                : Icons.cancel_outlined,
            color: request.isAccepted || request.isCompleted
                ? AppTheme.green
                : _dashText(context),
            onTap: canAct ? () => _confirmAndDecline(context) : null,
          ),
          if (canAct)
            _ActionIcon(
              icon: Icons.check_circle_outline_rounded,
              color: AppTheme.green,
              onTap: () => onAccept(request.id),
            ),
          if (canComplete)
            _ActionIcon(
              icon: Icons.task_alt_rounded,
              color: AppTheme.green,
              onTap: () => onComplete(request.id),
            ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: canAct ? () => _confirmAndDecline(context) : null,
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Decline'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.withValues(alpha: .35)),
          ),
        ),
        FilledButton.icon(
          onPressed: canAct
              ? () => onAccept(request.id)
              : canComplete
              ? () => onComplete(request.id)
              : null,
          icon: Icon(
            canComplete ? Icons.task_alt_rounded : Icons.check_rounded,
            size: 18,
          ),
          label: Text(canComplete ? 'Complete' : 'Accept'),
        ),
      ],
    );
  }
}

class _PackageEditorDialog extends StatefulWidget {
  const _PackageEditorDialog({this.package});

  final Map<String, dynamic>? package;

  @override
  State<_PackageEditorDialog> createState() => _PackageEditorDialogState();
}

class _PackageEditorDialogState extends State<_PackageEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.package?['package_name']?.toString(),
  );
  late final TextEditingController _speed = TextEditingController(
    text: widget.package?['speed_mbps']?.toString(),
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.package?['monthly_price']?.toString(),
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _speed.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final speedValue = int.tryParse(_speed.text.trim());
    final priceValue = double.tryParse(_price.text.trim());
    if (_name.text.trim().isEmpty || speedValue == null || priceValue == null) {
      setState(() => _error = 'Enter a valid name, speed, and monthly price.');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'package_name': _name.text.trim(),
      'speed_mbps': speedValue,
      'monthly_price': priceValue,
      if (widget.package == null) ...{
        'installation_fee': 0,
        'billing_cycle': 'monthly',
        'contract_type': 'no_contract',
        'router_included': false,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.package == null ? 'Add package' : 'Edit package'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Package name'),
            ),
            TextField(
              controller: _speed,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Speed (Mbps)'),
            ),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Monthly price'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _ProviderSectionPage extends StatefulWidget {
  const _ProviderSectionPage({
    required this.view,
    required this.providerId,
    required this.providerName,
    required this.providerStatus,
    required this.requests,
    required this.showMenuButton,
    required this.onMenuPressed,
    required this.onChanged,
  });

  final _ProviderDashView view;
  final String providerId;
  final String providerName;
  final String providerStatus;
  final List<ProviderInboxItem> requests;
  final bool showMenuButton;
  final VoidCallback onMenuPressed;
  final VoidCallback onChanged;

  @override
  State<_ProviderSectionPage> createState() => _ProviderSectionPageState();
}

class _ProviderSectionPageState extends State<_ProviderSectionPage> {
  final _service = AuthService();
  late Future<List<Map<String, dynamic>>> _items = _load();

  Future<List<Map<String, dynamic>>> _load() {
    return switch (widget.view) {
      _ProviderDashView.packages => _service.getProviderPackages(
        widget.providerId,
      ),
      _ProviderDashView.coverage => _service.getProviderCoverageAreas(
        widget.providerId,
      ),
      _ProviderDashView.customers => _service.getProviderCustomers(),
      _ProviderDashView.reviews => _service.getProviderReviews(),
      _ProviderDashView.messages => Future.value(
        widget.requests
            .where((r) => r.customerMessage?.trim().isNotEmpty == true)
            .map(
              (r) => {
                'id': r.id,
                'customer': r.phoneE164 ?? 'Customer',
                'message': r.customerMessage,
                'package_name': r.packageName,
                'created_at': r.createdAt?.toIso8601String(),
              },
            )
            .toList(),
      ),
      _ => Future.value(const []),
    };
  }

  void _reload() {
    setState(() => _items = _load());
    widget.onChanged();
  }

  String get _title => switch (widget.view) {
    _ProviderDashView.packages => 'Packages',
    _ProviderDashView.coverage => 'Coverage Areas',
    _ProviderDashView.customers => 'Customers',
    _ProviderDashView.reviews => 'Reviews',
    _ProviderDashView.messages => 'Messages',
    _ => 'Provider Workspace',
  };

  Future<void> _packageDialog([Map<String, dynamic>? item]) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PackageEditorDialog(package: item),
    );
    if (payload == null) return;
    try {
      if (item == null) {
        await _service.submitProviderPackage(
          providerId: widget.providerId,
          payload: payload,
        );
      } else {
        await _service.updateProviderPackage(
          widget.providerId,
          item['id'].toString(),
          payload,
        );
      }
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deletePackage(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete package?'),
        content: Text(
          'Delete ${item['package_name']}? Existing requests will prevent deletion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _service.deleteProviderPackage(
        widget.providerId,
        item['id'].toString(),
      );
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _addCoverage(List<Map<String, dynamic>> existing) async {
    final name = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add coverage area'),
        content: TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Area name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, name.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    name.dispose();
    if (value == null || value.isEmpty) return;
    final areas = [
      ...existing.map(
        (e) => {
          'area_name': e['area_name'],
          'latitude': e['latitude'],
          'longitude': e['longitude'],
          'radius_km': e['radius_km'],
        },
      ),
      {'area_name': value, 'latitude': 0.0, 'longitude': 0.0, 'radius_km': 5.0},
    ];
    try {
      await _service.submitProviderCoverageAreas(
        providerId: widget.providerId,
        payload: {'coverage_areas': areas},
      );
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(
          providerName: widget.providerName,
          providerStatus: widget.providerStatus,
          notificationCount: 0,
          dateRangeLabel: _title,
          onDateRangePressed: () {},
          showMenuButton: widget.showMenuButton,
          onMenuPressed: widget.onMenuPressed,
        ),
        const SizedBox(height: 24),
        _Surface(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _items,
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <Map<String, dynamic>>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _title,
                          style: TextStyle(
                            color: _dashText(context),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (widget.view == _ProviderDashView.packages)
                        FilledButton.icon(
                          onPressed: () => _packageDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add package'),
                        ),
                      if (widget.view == _ProviderDashView.coverage)
                        FilledButton.icon(
                          onPressed: () => _addCoverage(items),
                          icon: const Icon(Icons.add_location_alt),
                          label: const Text('Add area'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else if (snapshot.hasError)
                    Text(
                      snapshot.error.toString(),
                      style: const TextStyle(color: Colors.red),
                    )
                  else if (items.isEmpty)
                    Text(
                      'No ${_title.toLowerCase()} yet.',
                      style: TextStyle(color: _dashMuted(context)),
                    )
                  else
                    ...items.map(
                      (item) => widget.view == _ProviderDashView.customers
                          ? _ProviderCustomerCard(item: item)
                          : Card(
                              child: ListTile(
                                leading: Icon(
                                  widget.view == _ProviderDashView.reviews
                                      ? Icons.star
                                      : widget.view ==
                                            _ProviderDashView.messages
                                      ? Icons.message
                                      : Icons.circle_outlined,
                                  color: AppTheme.amber,
                                ),
                                title: Text(_itemTitle(item)),
                                subtitle: Text(_itemSubtitle(item)),
                                trailing:
                                    widget.view == _ProviderDashView.packages
                                    ? Wrap(
                                        children: [
                                          IconButton(
                                            onPressed: () =>
                                                _packageDialog(item),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () =>
                                                _deletePackage(item),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                            ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _itemTitle(Map<String, dynamic> item) => switch (widget.view) {
    _ProviderDashView.packages => item['package_name']?.toString() ?? 'Package',
    _ProviderDashView.coverage => item['area_name']?.toString() ?? 'Area',
    _ProviderDashView.customers =>
      '${item['first_name'] ?? ''} ${item['last_name'] ?? ''}'.trim(),
    _ProviderDashView.reviews =>
      '${item['rating'] ?? 0}/5 · ${item['first_name'] ?? ''} ${item['last_name'] ?? ''}',
    _ProviderDashView.messages => item['customer']?.toString() ?? 'Customer',
    _ => '',
  };

  String _itemSubtitle(Map<String, dynamic> item) => switch (widget.view) {
    _ProviderDashView.packages =>
      '${item['speed_mbps']} Mbps · KES ${item['monthly_price']}/month',
    _ProviderDashView.coverage => '${item['radius_km']} km radius',
    _ProviderDashView.customers =>
      '${item['email'] ?? item['phone_number'] ?? ''} · ${item['request_count']} request(s) · ${(item['packages'] as List?)?.join(', ') ?? ''}',
    _ProviderDashView.reviews =>
      '${item['package_name'] ?? 'Package'} · ${item['comment'] ?? 'No comment'}',
    _ProviderDashView.messages =>
      '${item['package_name'] ?? 'Package'} · ${item['message']}',
    _ => '',
  };
}

class _ProviderCustomerCard extends StatelessWidget {
  const _ProviderCustomerCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final firstName = (item['first_name'] ?? '').toString().trim();
    final lastName = (item['last_name'] ?? '').toString().trim();
    final name = '$firstName $lastName'.trim();
    final phone = (item['phone_number'] ?? '').toString().trim();
    final email = (item['email'] ?? '').toString().trim();
    final estate = (item['latest_estate_or_building'] ?? '').toString().trim();
    final house = (item['latest_house_or_apartment'] ?? '').toString().trim();
    final landmark = (item['latest_landmark'] ?? '').toString().trim();
    final gpsLocation = (item['latest_gps_location'] ?? '').toString().trim();
    final addressParts = [
      estate,
      house,
      landmark,
    ].where((part) => part.isNotEmpty).toList(growable: false);
    final address = addressParts.join(', ');
    final packages =
        (item['packages'] as List?)
            ?.where((value) => value != null)
            .map((value) => value.toString())
            .join(', ') ??
        '';
    final requestCount = item['request_count'] ?? 0;
    final initials = [
      if (firstName.isNotEmpty) firstName[0],
      if (lastName.isNotEmpty) lastName[0],
    ].join().toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.amber.withValues(alpha: 0.16),
                  child: Text(
                    initials.isEmpty ? 'C' : initials,
                    style: const TextStyle(
                      color: AppTheme.amberDark,
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
                        name.isEmpty ? 'Customer' : name,
                        style: TextStyle(
                          color: _dashText(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _dashMuted(context)),
                        ),
                    ],
                  ),
                ),
                if (item['is_phone_verified'] == true)
                  const Tooltip(
                    message: 'Verified phone',
                    child: Icon(Icons.verified_rounded, color: AppTheme.green),
                  ),
              ],
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 12),
              _CustomerContactRow(icon: Icons.phone_outlined, text: phone),
            ],
            if (address.isNotEmpty) ...[
              const SizedBox(height: 8),
              _CustomerContactRow(
                icon: Icons.location_on_outlined,
                text: address,
              ),
            ],
            if (packages.isNotEmpty) ...[
              const SizedBox(height: 8),
              _CustomerContactRow(
                icon: Icons.wifi_rounded,
                text: '$packages · $requestCount completed installation(s)',
              ),
            ],
            if (gpsLocation.isNotEmpty || address.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (gpsLocation.isNotEmpty || address.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _openMapLocation(
                        context,
                        gpsLocation.isNotEmpty ? gpsLocation : address,
                      ),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Open location'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomerContactRow extends StatelessWidget {
  const _CustomerContactRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppTheme.amber),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            color: _dashMuted(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _DeclineReasonSheet extends StatefulWidget {
  const _DeclineReasonSheet();

  @override
  State<_DeclineReasonSheet> createState() => _DeclineReasonSheetState();
}

class _DeclineReasonSheetState extends State<_DeclineReasonSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = _controller.text.trim();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reason for declining',
                      style: TextStyle(
                        color: _dashText(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                minLines: 3,
                maxLines: 5,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Example: Area is outside our current coverage',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: reason.isEmpty
                    ? null
                    : () => Navigator.pop(context, reason),
                child: const Text('Decline Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _inboxDateLabel(DateTime date) {
  return '${_inboxShortMonth(date)} ${date.day}, ${date.year}';
}

String _inboxTimeLabel(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String _requestCustomerLabel(ProviderInboxItem request) {
  final phone = request.phoneE164?.trim();
  if (phone != null && phone.isNotEmpty) return phone;
  final userId = request.userId.trim();
  if (userId.isEmpty) return 'Customer';
  return 'Customer $userId';
}

String _requestPackageLabel(ProviderInboxItem request) {
  final packageName = request.packageName?.trim();
  if (packageName != null && packageName.isNotEmpty) return packageName;
  final packageId = request.packageId.trim();
  if (packageId.isEmpty) return 'Package';
  return packageId;
}

String _inboxInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'ON';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return '${words[0][0]}${words[1][0]}'.toUpperCase();
}

(Color, Color) _inboxStatusColors(String status) {
  final normalized = status.toLowerCase();
  if (normalized.contains('accepted') || normalized.contains('complete')) {
    return (AppTheme.greenLight, AppTheme.green);
  }
  if (normalized.contains('cancel') ||
      normalized.contains('decline') ||
      normalized.contains('reject')) {
    return (Colors.red.withValues(alpha: .12), Colors.red.shade700);
  }
  return (AppTheme.amberLight.withValues(alpha: .7), AppTheme.amberDark);
}

String _inboxShortMonth(DateTime date) {
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
  return months[date.month - 1];
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.review});
  final _ReviewRow review;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _dashBorder(context))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.green,
            child: Text(
              review.initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _dashText(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _Stars(count: review.stars),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  review.plan,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _dashMuted(context), fontSize: 12),
                ),
                const SizedBox(height: 9),
                Text(
                  review.comment,
                  style: TextStyle(color: _dashMuted(context), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  const _RevenueChartPainter(
    this.points, {
    required this.gridColor,
    required this.axisColor,
    required this.valueColor,
  });
  final List<_RevenuePoint> points;
  final Color gridColor;
  final Color axisColor;
  final Color valueColor;
  @override
  void paint(Canvas canvas, Size size) {
    const left = 64.0;
    const top = 14.0;
    const right = 14.0;
    const bottom = 42.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final axisText = TextStyle(color: axisColor, fontSize: 11);
    final valueText = TextStyle(
      color: valueColor,
      fontSize: 11,
      fontWeight: FontWeight.w800,
    );
    final highestPoint = points.fold<double>(
      0,
      (highest, point) => point.amount > highest ? point.amount : highest,
    );
    final maxY = _niceChartMax(highestPoint);
    for (var i = 0; i <= 5; i++) {
      final value = maxY * i / 5;
      final y = chart.bottom - (chart.height * i / 5);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _drawText(
        canvas,
        i == 0 ? 'KES 0' : 'KES ${_compactAmount(value)}',
        Offset(0, y - 7),
        axisText,
        width: 54,
        align: TextAlign.right,
      );
    }
    final offsets = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + (chart.width * i / (points.length - 1));
      final normalizedAmount = (points[i].amount / maxY).clamp(0.0, 1.0);
      final y = chart.bottom - (chart.height * normalizedAmount);
      offsets.add(Offset(x, y));
      _drawText(
        canvas,
        points[i].month,
        Offset(x - 18, chart.bottom + 18),
        axisText,
        width: 36,
        align: TextAlign.center,
      );
      _drawText(
        canvas,
        'KES ${_compactAmount(points[i].amount)}',
        Offset(x - 34, y - 24),
        valueText,
        width: 72,
        align: TextAlign.center,
      );
    }
    if (offsets.isEmpty) return;
    final fillPath = ui.Path()
      ..moveTo(offsets.first.dx, chart.bottom)
      ..lineTo(offsets.first.dx, offsets.first.dy);
    final linePath = ui.Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final point in offsets.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath
      ..lineTo(offsets.last.dx, chart.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.amber.withValues(alpha: .28),
            AppTheme.amber.withValues(alpha: .02),
          ],
        ).createShader(chart),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppTheme.amber
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    for (final point in offsets) {
      canvas.drawCircle(point, 4, Paint()..color = AppTheme.amber);
    }
  }

  static String _compactAmount(double amount) {
    return amount >= 1000000
        ? '${(amount / 1000000).toStringAsFixed(1)}M'
        : amount >= 1000
        ? '${(amount / 1000).toStringAsFixed(0)}K'
        : amount
              .toStringAsFixed(0)
              .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  static double _niceChartMax(double highestPoint) {
    if (highestPoint <= 0) return 100000;
    final padded = highestPoint * 1.25;
    if (padded <= 100000) return 100000;
    if (padded <= 250000) return 250000;
    if (padded <= 500000) return 500000;
    if (padded <= 1000000) return 1000000;
    return ((padded / 1000000).ceil() * 1000000).toDouble();
  }

  static void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    required double width,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.valueColor != valueColor;
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({required this.child, this.width});
  final Widget child;
  final double? width;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _dashSurface(context),
        border: Border.all(color: _dashBorder(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: child),
    );
  }
}

class _SmallSelect extends StatelessWidget {
  const _SmallSelect({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Choose month',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: _SoftButton(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: _dashText(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 17,
                color: _dashText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      width: 58,
      decoration: BoxDecoration(
        color: _dashSoftAmber(context),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.amber.withValues(alpha: .16)),
      ),
      child: Icon(icon, color: AppTheme.amber, size: 27),
    );
  }
}

class _TinyIcon extends StatelessWidget {
  const _TinyIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      width: 34,
      decoration: BoxDecoration(
        color: _dashSoftAmber(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppTheme.amber, size: 20),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: 32,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 17),
    );
  }
}

class _Growth extends StatelessWidget {
  const _Growth({required this.value, required this.positive});
  final String value;
  final bool positive;
  @override
  Widget build(BuildContext context) {
    final color = positive ? AppTheme.green : Colors.red;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(
          positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          color: color,
          size: 14,
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.value, {this.bold = false, this.full = false});
  final String value;
  final bool bold;
  final bool full;
  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: full ? 3 : 1,
      overflow: TextOverflow.ellipsis,
      softWrap: full,
      style: TextStyle(
        color: _dashText(context),
        fontSize: 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, this.color, this.onTap});

  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: color ?? _dashText(context), size: 16),
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          Icons.star_rounded,
          color: index < count ? AppTheme.amber : _dashBorder(context),
          size: 16,
        ),
      ),
    );
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _dashBorder(context))),
      ),
      child: child,
    );
  }
}

class _Metric {
  const _Metric({
    required this.title,
    required this.value,
    required this.trend,
    required this.helper,
    required this.icon,
    required this.positive,
  });
  final String title;
  final String value;
  final String trend;
  final String helper;
  final IconData icon;
  final bool positive;
}

class _RevenuePoint {
  const _RevenuePoint(this.month, this.amount);
  final String month;
  final double amount;
}

class _PackageRow {
  const _PackageRow(
    this.name,
    this.users,
    this.revenue,
    this.growth,
    this.positive,
    this.icon,
    this.color,
  );
  final String name;
  final String users;
  final String revenue;
  final String growth;
  final bool positive;
  final IconData icon;
  final Color color;
}

class _LocationRow {
  const _LocationRow(
    this.name,
    this.users,
    this.revenue,
    this.progress, {
    this.latitude,
    this.longitude,
    this.radiusKm,
  });
  final String name;
  final String users;
  final String revenue;
  final double progress;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;
}

class _ReviewRow {
  const _ReviewRow(
    this.initial,
    this.name,
    this.plan,
    this.comment,
    this.stars,
  );
  final String initial;
  final String name;
  final String plan;
  final String comment;
  final int stars;
}
