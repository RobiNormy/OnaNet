import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:ona_net/auth/auth_service.dart';
import 'package:ona_net/onanet_provider_dash/blueprint_components.dart';
import 'package:ona_net/onanet_provider_dash/pro_analytics.dart';
import 'package:ona_net/onanet_provider_dash/provider_documents.dart';
import 'package:ona_net/onanet_provider_dash/provider_team_accounts.dart';
import 'package:ona_net/screens/login.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:ona_net/services/provider_inbox.dart';
import 'package:ona_net/services/subscription_service.dart';
import 'package:ona_net/utils/location.dart';
import 'package:ona_net/utils/provider_filters.dart';
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
    _isDark(context) ? const Color(0xFF06131E) : AppTheme.offWhite;

Color _dashSurface(BuildContext context) =>
    _isDark(context) ? const Color(0xFF0D2231) : AppTheme.white;

Color _dashText(BuildContext context) =>
    _isDark(context) ? AppTheme.offWhite : AppTheme.navy;

Color _dashMuted(BuildContext context) =>
    _isDark(context) ? const Color(0xFF8FA6B5) : const Color(0xFF64748B);

Color _dashBorder(BuildContext context) => _isDark(context)
    ? Colors.white.withValues(alpha: .075)
    : const Color(0xFFE6E0EF);

Color _dashSoftAmber(BuildContext context) => _isDark(context)
    ? AppTheme.amber.withValues(alpha: .14)
    : AppTheme.amberLight.withValues(alpha: .55);

Color _dashAccentText(BuildContext context) =>
    _isDark(context) ? AppTheme.amberLight : AppTheme.amberDark;

Color _dashShadow(BuildContext context) =>
    (_isDark(context) ? Colors.black : const Color(0xFF16324A)).withValues(
      alpha: _isDark(context) ? .2 : .065,
    );

bool _accountCanView(Map<String, dynamic> access, String section) {
  if (access['is_owner'] != false) return true;
  final permissions = access['permissions'];
  if (permissions is! Map) return false;
  final sectionAccess = permissions[section];
  return sectionAccess is Map && sectionAccess['view'] == true;
}

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
  upgradePlan,
  teamAccounts,
  packages,
  coverage,
  documents,
  installationRequests,
  customers,
  reviews,
  messages,
  analytics,
}

enum _DashboardProfileAction { dashboard, packages, coverage, signOut }

class _DashboardState extends State<Dashboard> {
  _ProviderDashView _activeView = _ProviderDashView.dashboard;
  late Future<Map<String, dynamic>> _providerFuture;
  Future<Map<String, dynamic>>? _subscriptionFuture;
  late DateTimeRange _selectedDateRange;
  late String _selectedMonth;
  final _inboxService = ProviderInbox();
  final _requestsSectionKey = GlobalKey();
  List<ProviderInboxItem> _inboxItems = const [];
  bool _inboxLoading = false;
  bool _inboxLoaded = false;
  String? _inboxError;
  bool _isTestUpgradeRunning = false;
  bool _isTestGrowthRunning = false;
  Map<String, dynamic> _accountAccess = {
    'is_owner': true,
    'role': 'Owner',
    'permissions': <String, dynamic>{},
  };

  Future<Map<String, dynamic>> get _currentSubscription =>
      _subscriptionFuture ??= SubscriptionService().getCurrentSubscription();

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

  Future<void> _activateTestGrowth() async {
    if (_isTestGrowthRunning) return;
    setState(() {
      _isTestGrowthRunning = true;
    });

    try {
      await SubscriptionService().upgradeToGrowthForTesting();
      if (!mounted) return;
      _refreshProviderDashboard();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Test Growth plan activated for 30 days.'),
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
      if (mounted) {
        setState(() {
          _isTestGrowthRunning = false;
        });
      }
    }
  }

  Future<void> _refreshInbox() async {
    if (!mounted) return;
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

  Future<void> _loadAccountAccess() async {
    try {
      final access = await AuthService().getProviderAccountAccess();
      if (!mounted) return;
      setState(() {
        _accountAccess = access;
        if (!_canOpenView(_activeView, access)) {
          _activeView = _firstAllowedView(access);
        }
      });
    } catch (_) {
      // Keep owner accounts usable while an older backend is being migrated.
    }
  }

  bool _canOpenView(_ProviderDashView view, [Map<String, dynamic>? access]) {
    final currentAccess = access ?? _accountAccess;
    if (view == _ProviderDashView.upgradePlan ||
        view == _ProviderDashView.teamAccounts) {
      return currentAccess['is_owner'] != false;
    }
    final section = switch (view) {
      _ProviderDashView.dashboard => 'dashboard',
      _ProviderDashView.packages => 'packages',
      _ProviderDashView.coverage => 'coverage',
      _ProviderDashView.documents => 'documents',
      _ProviderDashView.installationRequests => 'installation_requests',
      _ProviderDashView.customers => 'customers',
      _ProviderDashView.reviews => 'reviews',
      _ProviderDashView.messages => 'messages',
      _ProviderDashView.analytics => 'analytics',
      _ => 'dashboard',
    };
    return _accountCanView(currentAccess, section);
  }

  _ProviderDashView _firstAllowedView(Map<String, dynamic> access) {
    const candidates = [
      _ProviderDashView.dashboard,
      _ProviderDashView.packages,
      _ProviderDashView.coverage,
      _ProviderDashView.documents,
      _ProviderDashView.installationRequests,
      _ProviderDashView.customers,
      _ProviderDashView.reviews,
      _ProviderDashView.messages,
      _ProviderDashView.analytics,
    ];
    return candidates.firstWhere(
      (view) => _canOpenView(view, access),
      orElse: () => _ProviderDashView.dashboard,
    );
  }

  void _refreshProviderDashboard() {
    if (!mounted) return;
    setState(() {
      _providerFuture = AuthService().getProviderDashboardData();
      _subscriptionFuture = SubscriptionService().getCurrentSubscription();
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
    if (!_canOpenView(_ProviderDashView.installationRequests)) return;
    setState(() {
      _activeView = _ProviderDashView.installationRequests;
    });
    _refreshInbox();
  }

  void _showDashboard({bool closeSidebar = false}) {
    setState(() {
      _activeView = _canOpenView(_ProviderDashView.dashboard)
          ? _ProviderDashView.dashboard
          : _firstAllowedView(_accountAccess);
    });
  }

  void _showView(_ProviderDashView view, {bool closeSidebar = false}) {
    if (!_canOpenView(view)) return;
    setState(() {
      _activeView = view;
    });
    if (view == _ProviderDashView.installationRequests ||
        view == _ProviderDashView.customers ||
        view == _ProviderDashView.messages) {
      _refreshInbox();
    }
  }

  Future<void> _openMoreMenu() async {
    Map<String, dynamic> provider;
    try {
      provider = await _providerFuture;
    } catch (_) {
      provider = const <String, dynamic>{};
    }
    if (!mounted) return;
    final selected = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DashboardMoreSheet(
        activeView: _activeView,
        subscriptionTier: provider['subscription_tier']?.toString() ?? 'free',
        accountAccess: _accountAccess,
      ),
    );
    if (selected is _ProviderDashView && mounted) {
      _showView(selected, closeSidebar: true);
    } else if (selected == 'sign_out' && mounted) {
      await _logoutProvider(closeSidebar: true);
    } else if (selected == 'switch_account' && mounted) {
      await _switchProviderAccount();
    }
  }

  Future<void> _switchProviderAccount() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Login(providerMode: true)),
      (route) => false,
    );
  }

  Future<void> _logoutProvider({bool closeSidebar = false}) async {
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
        MaterialPageRoute(builder: (_) => const Login()),
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
    _subscriptionFuture = SubscriptionService().getCurrentSubscription();
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 6)),
      end: now,
    );
    _selectedMonth = _monthLabel(now);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshInbox());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccountAccess());
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
          borderRadius: BorderRadius.circular(15),
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
              final rangedInboxItems = _inboxItems
                  .where(_requestInSelectedRange)
                  .toList(growable: false);
              final pendingRequestCount = _intValue(
                provider,
                'pending_installations',
              );
              final livePendingRequestCount = _inboxLoaded
                  ? rangedInboxItems
                        .where((request) => request.isPending)
                        .length
                  : pendingRequestCount;
              final selectedRevenueTotal = _selectedMonthRevenue(
                revenue,
                fallback: _moneyValue(provider, 'monthly_revenue'),
              );

              return DefaultTextStyle(
                style: _dashFont(color: _dashText(context), fontSize: 14),
                child: Scaffold(
                  backgroundColor: _dashBackground(context),
                  body: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 1100;
                      final content = switch (_activeView) {
                        _ProviderDashView.dashboard => _DashboardContent(
                          subscription: _currentSubscription,
                          fallbackTier:
                              provider?['subscription_tier']?.toString() ??
                              'free',
                          metrics: metrics,
                          revenue: revenue,
                          revenueTotal: selectedRevenueTotal,
                          dateRangeLabel: _dateRangeLabel(_selectedDateRange),
                          selectedMonth: _selectedMonth,
                          onDateRangePressed: _pickDateRange,
                          onMonthPressed: _pickMonth,
                          packages: packages,
                          locations: locations,
                          requests: rangedInboxItems,
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
                          onMenuPressed: _openMoreMenu,
                        ),
                        _ProviderDashView.upgradePlan => _SubscriptionPlansPage(
                          currentTier:
                              provider?['subscription_tier']?.toString() ??
                              'free',
                          isGrowthTestRunning: _isTestGrowthRunning,
                          onActivateGrowthTest: _activateTestGrowth,
                          isProTestRunning: _isTestUpgradeRunning,
                          onActivateProTest: _activateTestUpgrade,
                          onBackPressed: _showDashboard,
                          showMenuButton: !wide,
                          onMenuPressed: _openMoreMenu,
                        ),
                        _ProviderDashView.teamAccounts =>
                          ProviderTeamAccountsPage(
                            providerName: providerName,
                            onBackPressed: _showDashboard,
                            showMenuButton: !wide,
                            onMenuPressed: _openMoreMenu,
                          ),
                        _ProviderDashView.installationRequests =>
                          _InstallationRequestsPage(
                            providerName: providerName,
                            providerStatus: providerStatus,
                            notificationCount: livePendingRequestCount,
                            dateRangeLabel: _dateRangeLabel(_selectedDateRange),
                            requests: rangedInboxItems,
                            isLoading: _inboxLoading,
                            error: _inboxError,
                            showMenuButton: !wide,
                            onMenuPressed: _openMoreMenu,
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
                          onBackPressed: _showDashboard,
                          showMenuButton: !wide,
                          onMenuPressed: _openMoreMenu,
                        ),
                        _ProviderDashView.documents => ProviderDocumentsPage(
                          providerId: provider?['id']?.toString() ?? '',
                          providerName: providerName,
                          isVerified: provider?['is_verified'] == true,
                          onBackPressed: _showDashboard,
                          showMenuButton: !wide,
                          onMenuPressed: _openMoreMenu,
                          onChanged: _refreshProviderDashboard,
                        ),
                        _ => _ProviderSectionPage(
                          view: _activeView,
                          providerId: provider?['id']?.toString() ?? '',
                          subscriptionTier:
                              provider?['subscription_tier']?.toString() ??
                              'free',
                          providerName: providerName,
                          providerStatus: providerStatus,
                          requests: _inboxItems,
                          showMenuButton: !wide,
                          onMenuPressed: _openMoreMenu,
                          onViewChanged: _showView,
                          onChanged: () {
                            _refreshProviderDashboard();
                            _refreshInbox();
                          },
                        ),
                      };
                      if (!wide) {
                        return SizedBox.expand(
                          child: SafeArea(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                              child: content,
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
                            accountAccess: _accountAccess,
                            packageCount: packages.length,
                            pendingRequestCount: livePendingRequestCount,
                            onViewPressed: _showView,
                            onSwitchAccountPressed: _switchProviderAccount,
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

  bool _requestInSelectedRange(ProviderInboxItem request) {
    final createdAt = request.createdAt;
    if (createdAt == null) return true;
    final start = DateTime(
      _selectedDateRange.start.year,
      _selectedDateRange.start.month,
      _selectedDateRange.start.day,
    );
    final endExclusive = DateTime(
      _selectedDateRange.end.year,
      _selectedDateRange.end.month,
      _selectedDateRange.end.day + 1,
    );
    final localCreatedAt = createdAt.toLocal();
    return !localCreatedAt.isBefore(start) &&
        localCreatedAt.isBefore(endExclusive);
  }

  double _selectedMonthRevenue(
    List<_RevenuePoint> revenue, {
    required double fallback,
  }) {
    final selectedShortMonth = _selectedMonth.substring(0, 3);
    for (final point in revenue) {
      if (point.month.toLowerCase() == selectedShortMonth.toLowerCase()) {
        return point.amount;
      }
    }
    return fallback;
  }

  String _providerStatus(Map<String, dynamic>? provider) {
    if (provider == null) return 'Loading provider';
    if (provider['is_verified'] == true) return 'Verified Provider';

    final status = provider['status']?.toString().trim();
    if (status == null || status.isEmpty) return 'Provider';
    return '${humanizeBackendValue(status)} Provider';
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
    required this.subscription,
    required this.fallbackTier,
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
  final Future<Map<String, dynamic>> subscription;
  final String fallbackTier;
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
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(
          pageTitle: 'Dashboard',
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
        const SizedBox(height: 14),
        _CurrentBillingCard(
          subscription: subscription,
          fallbackTier: fallbackTier,
        ),
        if (mobile) ...[
          const SizedBox(height: 14),
          _LocationsCard(locations: locations),
        ],
        SizedBox(height: mobile ? 14 : 24),
        _MetricGrid(metrics: metrics),
        SizedBox(height: mobile ? 14 : 18),
        if (mobile) ...[
          _RevenueCard(
            points: revenue,
            totalRevenue: revenueTotal,
            selectedMonth: selectedMonth,
            onMonthPressed: onMonthPressed,
          ),
          const SizedBox(height: 14),
          _RequestsCard(
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
          const SizedBox(height: 14),
          _PackagesCard(packages: packages),
        ] else ...[
          _ResponsivePair(
            leftFlex: 9,
            rightFlex: 10,
            left: _RevenueCard(
              points: revenue,
              totalRevenue: revenueTotal,
              selectedMonth: selectedMonth,
              onMonthPressed: onMonthPressed,
            ),
            right: _PackagesCard(packages: packages),
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
        ],
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

class _CurrentBillingCard extends StatelessWidget {
  const _CurrentBillingCard({
    required this.subscription,
    required this.fallbackTier,
  });

  final Future<Map<String, dynamic>> subscription;
  final String fallbackTier;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: subscription,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        final tier = _normalizedTier(data['tier'] ?? fallbackTier);
        final isFree = tier == 'free';
        final isGrowth = tier == 'growth';
        final active = data['is_active'] != false;
        final limits = data['limits'] is Map
            ? Map<String, dynamic>.from(data['limits'] as Map)
            : const <String, dynamic>{};
        final expiresAt = DateTime.tryParse(
          data['expires_at']?.toString() ?? '',
        )?.toLocal();
        final coverageLimit = limits.containsKey('max_coverage_areas')
            ? limits['max_coverage_areas']
            : isFree
            ? 3
            : isGrowth
            ? 5
            : null;
        final planColor = isFree
            ? AppTheme.darkGray
            : isGrowth
            ? AppTheme.amberDark
            : AppTheme.navy;

        return OnaBlueprintCard(
          title: 'Current billing',
          action: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: (active ? AppTheme.green : Colors.red).withValues(
                alpha: .10,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SizedBox.square(
                    dimension: 11,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                else
                  Icon(
                    active ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: active ? AppTheme.green : Colors.red,
                    size: 13,
                  ),
                const SizedBox(width: 5),
                Text(
                  active ? 'Active' : 'Expired',
                  style: TextStyle(
                    color: active ? AppTheme.green : Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: planColor.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: planColor.withValues(alpha: .16)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: planColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isFree
                            ? Icons.wifi_rounded
                            : isGrowth
                            ? Icons.trending_up_rounded
                            : Icons.workspace_premium_rounded,
                        color: AppTheme.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_titleCase(tier)} plan',
                            softWrap: true,
                            style: GoogleFonts.plusJakartaSans(
                              color: _dashText(context),
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isFree
                                ? 'No subscription charge or renewal date.'
                                : expiresAt == null
                                ? 'Paid plan access is active.'
                                : 'Plan access is active until ${_billingDate(expiresAt)}.',
                            softWrap: true,
                            style: TextStyle(
                              color: _dashMuted(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth < 520
                      ? (constraints.maxWidth - 10) / 2
                      : (constraints.maxWidth - 20) / 3;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _BillingDetail(
                        width: itemWidth,
                        label: 'Billing',
                        value: isFree ? 'Free' : 'Paid plan',
                        icon: Icons.receipt_long_outlined,
                      ),
                      _BillingDetail(
                        width: itemWidth,
                        label: isFree ? 'Renewal' : 'Access until',
                        value: isFree
                            ? 'No renewal'
                            : expiresAt == null
                            ? 'No expiry set'
                            : _billingDate(expiresAt),
                        icon: Icons.calendar_month_outlined,
                      ),
                      _BillingDetail(
                        width: itemWidth,
                        label: 'Coverage areas',
                        value: coverageLimit == null
                            ? 'Unlimited'
                            : 'Up to $coverageLimit',
                        icon: Icons.map_outlined,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    tier == 'pro'
                        ? Icons.insights_rounded
                        : Icons.lock_outline_rounded,
                    color: tier == 'pro' ? AppTheme.green : _dashMuted(context),
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      tier == 'pro'
                          ? 'Advanced analytics are included with your plan.'
                          : 'Advanced analytics require the Pro plan.',
                      softWrap: true,
                      style: TextStyle(
                        color: _dashMuted(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (snapshot.hasError) ...[
                const SizedBox(height: 8),
                Text(
                  'Live billing details could not be refreshed. Showing your saved plan.',
                  softWrap: true,
                  style: TextStyle(color: _dashMuted(context), fontSize: 10),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _normalizedTier(Object? value) {
    final tier = value?.toString().trim().toLowerCase();
    return switch (tier) {
      'growth' => 'growth',
      'pro' => 'pro',
      _ => 'free',
    };
  }

  static String _titleCase(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';

  static String _billingDate(DateTime value) {
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
}

class _SubscriptionPlansPage extends StatelessWidget {
  const _SubscriptionPlansPage({
    required this.currentTier,
    required this.isGrowthTestRunning,
    required this.onActivateGrowthTest,
    required this.isProTestRunning,
    required this.onActivateProTest,
    required this.onBackPressed,
    required this.showMenuButton,
    required this.onMenuPressed,
  });

  final String currentTier;
  final bool isGrowthTestRunning;
  final Future<void> Function() onActivateGrowthTest;
  final bool isProTestRunning;
  final Future<void> Function() onActivateProTest;
  final VoidCallback onBackPressed;
  final bool showMenuButton;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showMenuButton)
          OnaBlueprintHeader(
            title: 'Upgrade your plan',
            onBack: onBackPressed,
            onMenu: onMenuPressed,
          )
        else
          Row(
            children: [
              IconButton(
                onPressed: onBackPressed,
                tooltip: 'Back to dashboard',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upgrade your plan',
                  softWrap: true,
                  style: GoogleFonts.plusJakartaSans(
                    color: _dashText(context),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose the OnaNet plan that fits your provider business.',
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                    color: _dashMuted(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _SubscriptionPlanSelector(
                  currentTier: currentTier,
                  isGrowthTestRunning: isGrowthTestRunning,
                  onActivateGrowthTest: onActivateGrowthTest,
                  isProTestRunning: isProTestRunning,
                  onActivateProTest: onActivateProTest,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SubscriptionPlanSelector extends StatefulWidget {
  const _SubscriptionPlanSelector({
    required this.currentTier,
    required this.isGrowthTestRunning,
    required this.onActivateGrowthTest,
    required this.isProTestRunning,
    required this.onActivateProTest,
  });

  final String currentTier;
  final bool isGrowthTestRunning;
  final Future<void> Function() onActivateGrowthTest;
  final bool isProTestRunning;
  final Future<void> Function() onActivateProTest;

  @override
  State<_SubscriptionPlanSelector> createState() =>
      _SubscriptionPlanSelectorState();
}

class _SubscriptionPlanSelectorState extends State<_SubscriptionPlanSelector> {
  static const _tiers = ['free', 'growth', 'pro'];
  late String _selectedTier = widget.currentTier;

  @override
  void didUpdateWidget(covariant _SubscriptionPlanSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTier != widget.currentTier) {
      _selectedTier = widget.currentTier;
    }
  }

  List<String> get _perks => switch (_selectedTier) {
    'growth' => const [
      'Up to 10 internet packages',
      'Up to 5 coverage areas',
      '3 provider profile photos',
      'External customer alerts',
      'Up to 3 staff accounts',
      'Your own performance statistics',
    ],
    'pro' => const [
      'Expanded package capacity',
      'Unlimited coverage areas',
      '6 provider profile photos',
      'Pinned placement in search',
      'Advanced analytics and demand intelligence',
      'Priority inbox and external alerts',
      'Custom cover and expanded staff access',
    ],
    _ => const [
      'Up to 10 internet packages',
      'Up to 3 coverage areas',
      'In-app customer alerts',
      'Your own performance statistics',
      '1 staff account',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final current = _selectedTier == widget.currentTier;
    final growthLoading =
        _selectedTier == 'growth' && widget.isGrowthTestRunning;
    final proLoading = _selectedTier == 'pro' && widget.isProTestRunning;
    final loading = growthLoading || proLoading;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.navyMid, AppTheme.navy],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.navyLight),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: .18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: _tiers.map((tier) {
              final selected = tier == _selectedTier;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => setState(() => _selectedTier = tier),
                    borderRadius: BorderRadius.circular(999),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.amber.withValues(alpha: .12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? AppTheme.amber.withValues(alpha: .55)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        _titleCase(tier),
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: TextStyle(
                          color: selected
                              ? AppTheme.white
                              : AppTheme.offWhite.withValues(alpha: .72),
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Column(
              key: ValueKey(_selectedTier),
              children: [
                if (_selectedTier == 'free') ...[
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'KES ',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.amberLight,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '0',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.amberLight,
                            fontSize: 58,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'PER MONTH',
                    style: TextStyle(
                      color: AppTheme.offWhite,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                ] else ...[
                  Text(
                    'PAID',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.amberLight,
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const Text(
                    'PRICE SHOWN AT CHECKOUT',
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: TextStyle(
                      color: AppTheme.offWhite,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .7,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                for (final perk in _perks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 13,
                          height: 13,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.amberLight.withValues(alpha: .8),
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: AppTheme.amberLight,
                            size: 9,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            perk,
                            softWrap: true,
                            style: const TextStyle(
                              color: AppTheme.offWhite,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: current || _selectedTier == 'free' || loading
                  ? null
                  : _selectedTier == 'growth'
                  ? widget.onActivateGrowthTest
                  : widget.onActivateProTest,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.amber,
                foregroundColor: AppTheme.navy,
                disabledBackgroundColor: AppTheme.white.withValues(alpha: .14),
                disabledForegroundColor: AppTheme.offWhite.withValues(
                  alpha: .72,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.offWhite,
                      ),
                    )
                  : Icon(
                      current
                          ? Icons.check_circle_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
              label: Text(
                loading
                    ? 'Activating ${_titleCase(_selectedTier)}...'
                    : current
                    ? 'Current plan'
                    : _selectedTier == 'free'
                    ? 'Free plan'
                    : 'Test ${_titleCase(_selectedTier)} for 30 days',
                softWrap: true,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedTier == 'free'
                ? 'Free has no subscription charge. You can upgrade whenever you are ready.'
                : 'Test access lasts 30 days. Paid pricing will be shown at checkout when billing is enabled.',
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              color: AppTheme.offWhite.withValues(alpha: .68),
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  static String _titleCase(String tier) =>
      '${tier[0].toUpperCase()}${tier.substring(1)}';
}

class _BillingDetail extends StatelessWidget {
  const _BillingDetail({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _dashBackground(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.amber, size: 17),
          const SizedBox(height: 7),
          Text(
            label,
            softWrap: true,
            style: TextStyle(color: _dashMuted(context), fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            softWrap: true,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.pageTitle,
    required this.providerName,
    required this.providerStatus,
    required this.notificationCount,
    required this.dateRangeLabel,
    required this.onDateRangePressed,
    required this.showMenuButton,
    required this.onMenuPressed,
  });

  final String pageTitle;
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
    final compactPage = MediaQuery.sizeOf(context).width < 1100;
    return Container(
      padding: compactPage
          ? const EdgeInsets.symmetric(vertical: 4)
          : const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: compactPage
            ? Colors.transparent
            : dark
            ? const Color(0xFF102D3E)
            : AppTheme.amberLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: compactPage ? Colors.transparent : _dashBorder(context),
        ),
        boxShadow: compactPage
            ? const []
            : [
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
            if (pageTitle == 'Dashboard') {
              return OnaDashboardBrandHeader(
                onMenu: onMenuPressed,
                notificationCount: notificationCount,
                onNotifications: () => context
                    .findAncestorStateOfType<_DashboardState>()
                    ?._showInstallationRequests(),
              );
            }
            return OnaBlueprintHeader(
              title: pageTitle,
              onBack: () => context
                  .findAncestorStateOfType<_DashboardState>()
                  ?._showDashboard(),
              onMenu: onMenuPressed,
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

class _DashboardMoreSheet extends StatelessWidget {
  const _DashboardMoreSheet({
    required this.activeView,
    required this.subscriptionTier,
    required this.accountAccess,
  });

  final _ProviderDashView activeView;
  final String subscriptionTier;
  final Map<String, dynamic> accountAccess;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF111827) : AppTheme.offWhite;
    final surface = isDark ? const Color(0xFF1F2937) : Colors.white;
    final isOwner = accountAccess['is_owner'] != false;
    final canUpgrade =
        isOwner && subscriptionTier.trim().toLowerCase() != 'pro';
    final items = [
      if (_accountCanView(accountAccess, 'dashboard'))
        (_ProviderDashView.dashboard, 'Dashboard', Icons.grid_view_rounded),
      if (_accountCanView(accountAccess, 'packages'))
        (_ProviderDashView.packages, 'Packages', Icons.wifi_rounded),
      if (_accountCanView(accountAccess, 'coverage'))
        (_ProviderDashView.coverage, 'Coverage Areas', Icons.map_outlined),
      if (_accountCanView(accountAccess, 'documents'))
        (
          _ProviderDashView.documents,
          'Documents and Verification',
          Icons.verified_user_outlined,
        ),
      if (_accountCanView(accountAccess, 'installation_requests'))
        (
          _ProviderDashView.installationRequests,
          'Installation Requests',
          Icons.add_task_rounded,
        ),
      if (_accountCanView(accountAccess, 'customers'))
        (
          _ProviderDashView.customers,
          'Customers',
          Icons.people_outline_rounded,
        ),
      if (_accountCanView(accountAccess, 'reviews'))
        (_ProviderDashView.reviews, 'Reviews', Icons.star_border_rounded),
      if (_accountCanView(accountAccess, 'messages'))
        (_ProviderDashView.messages, 'Messages', Icons.mail_outline_rounded),
      if (_accountCanView(accountAccess, 'analytics'))
        (
          _ProviderDashView.analytics,
          'Pro Analytics',
          Icons.auto_graph_rounded,
        ),
      if (isOwner)
        (
          _ProviderDashView.teamAccounts,
          'Team accounts',
          Icons.manage_accounts_outlined,
        ),
    ];
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF98A2B3).withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'OnaNet workspace',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: _dashText(context),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.55,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final selected = activeView == item.$1;
                    return InkWell(
                      onTap: () => Navigator.pop(context, item.$1),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.amber.withValues(alpha: .13)
                              : surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? AppTheme.amber
                                : _dashBorder(context),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.$3,
                              color: selected
                                  ? AppTheme.amber
                                  : _dashMuted(context),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              item.$2,
                              softWrap: true,
                              style: GoogleFonts.urbanist(
                                color: _dashText(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'switch_account'),
              icon: const Icon(Icons.switch_account_rounded),
              label: const Text('Switch provider account'),
            ),
            if (canUpgrade) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.pop(context, _ProviderDashView.upgradePlan),
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Upgrade your plan'),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'sign_out'),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
          ],
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
    required this.accountAccess,
    required this.packageCount,
    required this.pendingRequestCount,
    required this.onViewPressed,
    required this.onSwitchAccountPressed,
    required this.onLogoutPressed,
  });

  final _ProviderDashView activeView;
  final String providerName;
  final String providerStatus;
  final String subscriptionTier;
  final Map<String, dynamic> accountAccess;
  final int packageCount;
  final int pendingRequestCount;
  final void Function(_ProviderDashView view) onViewPressed;
  final VoidCallback onSwitchAccountPressed;
  final VoidCallback onLogoutPressed;

  @override
  Widget build(BuildContext context) {
    final isOwner = accountAccess['is_owner'] != false;
    final canUpgrade =
        isOwner && subscriptionTier.trim().toLowerCase() != 'pro';
    final operateItems = <(String, IconData, String, _ProviderDashView)>[
      if (_accountCanView(accountAccess, 'dashboard'))
        ('Dashboard', Icons.home_rounded, '0', _ProviderDashView.dashboard),
      if (_accountCanView(accountAccess, 'packages'))
        (
          'Packages',
          Icons.router_outlined,
          packageCount.toString(),
          _ProviderDashView.packages,
        ),
      if (_accountCanView(accountAccess, 'coverage'))
        ('Coverage', Icons.map_outlined, '0', _ProviderDashView.coverage),
      if (_accountCanView(accountAccess, 'documents'))
        (
          'Documents',
          Icons.verified_user_outlined,
          '0',
          _ProviderDashView.documents,
        ),
      if (_accountCanView(accountAccess, 'installation_requests'))
        (
          'Installation Requests',
          Icons.groups_2_outlined,
          pendingRequestCount.toString(),
          _ProviderDashView.installationRequests,
        ),
      if (_accountCanView(accountAccess, 'customers'))
        (
          'Customers',
          Icons.people_outline_rounded,
          '0',
          _ProviderDashView.customers,
        ),
    ];
    final growItems = <(String, IconData, String, _ProviderDashView?)>[
      if (_accountCanView(accountAccess, 'reviews'))
        ('Reviews', Icons.star_border_rounded, '0', _ProviderDashView.reviews),
      if (_accountCanView(accountAccess, 'analytics'))
        (
          'Analytics',
          Icons.bar_chart_rounded,
          'PRO',
          _ProviderDashView.analytics,
        ),
      if (_accountCanView(accountAccess, 'messages'))
        (
          'Messages',
          Icons.mail_outline_rounded,
          '0',
          _ProviderDashView.messages,
        ),
    ];
    return SizedBox(
      width: 280,
      height: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppTheme.offWhite),
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
                              color: AppTheme.navy,
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
                              color: Color(0xFF667085),
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
              if (isOwner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: _NavItem(
                    label: 'Team accounts',
                    icon: Icons.manage_accounts_outlined,
                    badge: '0',
                    selected: activeView == _ProviderDashView.teamAccounts,
                    onTap: () => onViewPressed(_ProviderDashView.teamAccounts),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: _NavItem(
                  label: 'Switch account',
                  icon: Icons.switch_account_rounded,
                  badge: '0',
                  selected: false,
                  onTap: onSwitchAccountPressed,
                ),
              ),
              if (canUpgrade)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: _NavItem(
                    label: 'Upgrade your plan',
                    icon: Icons.workspace_premium_outlined,
                    badge: '0',
                    selected: activeView == _ProviderDashView.upgradePlan,
                    onTap: () => onViewPressed(_ProviderDashView.upgradePlan),
                  ),
                ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0D7F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: AppTheme.amber.withValues(alpha: .12),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppTheme.amberDark,
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
                  style: const TextStyle(
                    color: AppTheme.navy,
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
                        style: const TextStyle(
                          color: Color(0xFF667085),
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
          color: Color(0xFF7A708B),
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
        ? AppTheme.amberDark
        : enabled
        ? AppTheme.navy.withValues(alpha: .82)
        : AppTheme.navy.withValues(alpha: .40);
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
    final dashboard = context.findAncestorStateOfType<_DashboardState>();
    return Tooltip(
      message: 'Open installation requests',
      child: InkWell(
        onTap: dashboard?._showInstallationRequests,
        borderRadius: BorderRadius.circular(8),
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
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.providerName,
    required this.providerStatus,
  });

  final String providerName;
  final String providerStatus;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.findAncestorStateOfType<_DashboardState>();
    return PopupMenuButton<_DashboardProfileAction>(
      tooltip: 'Provider menu',
      position: PopupMenuPosition.under,
      onSelected: (action) {
        switch (action) {
          case _DashboardProfileAction.dashboard:
            dashboard?._showDashboard();
          case _DashboardProfileAction.packages:
            dashboard?._showView(_ProviderDashView.packages);
          case _DashboardProfileAction.coverage:
            dashboard?._showView(_ProviderDashView.coverage);
          case _DashboardProfileAction.signOut:
            dashboard?._logoutProvider();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _DashboardProfileAction.dashboard,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.dashboard_outlined),
            title: Text('Dashboard'),
          ),
        ),
        PopupMenuItem(
          value: _DashboardProfileAction.packages,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.router_outlined),
            title: Text('Packages'),
          ),
        ),
        PopupMenuItem(
          value: _DashboardProfileAction.coverage,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.map_outlined),
            title: Text('Coverage'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _DashboardProfileAction.signOut,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded),
            title: Text('Sign out'),
          ),
        ),
      ],
      child: Container(
        width: 250,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _dashSurface(context),
          border: Border.all(color: _dashBorder(context)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
        if (maxWidth < 620) {
          final width = (maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: metrics
                .map(
                  (metric) => SizedBox(
                    width: width,
                    child: _MetricCard(metric: metric),
                  ),
                )
                .toList(),
          );
        }
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
    return OnaBlueprintCard(
      child: OnaKpiTile(
        label: metric.title,
        value: metric.value,
        icon: metric.icon,
        helper: '${metric.trend} · ${metric.helper}',
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
          const SizedBox(height: 8),
          OnaGroupedBarChart(
            values: points.map((point) => point.amount).toList(),
            labels: points.map((point) => point.month).toList(),
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

enum _PackageSort { revenue, customers, growth }

class _PackagesCard extends StatefulWidget {
  const _PackagesCard({required this.packages});
  final List<_PackageRow> packages;

  @override
  State<_PackagesCard> createState() => _PackagesCardState();
}

class _PackagesCardState extends State<_PackagesCard> {
  _PackageSort _sort = _PackageSort.revenue;

  String get _sortLabel => switch (_sort) {
    _PackageSort.revenue => 'Revenue',
    _PackageSort.customers => 'Customers',
    _PackageSort.growth => 'Growth',
  };

  double _number(String value) {
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0;
  }

  List<_PackageRow> get _sortedPackages {
    final sorted = [...widget.packages];
    sorted.sort((a, b) {
      final aValue = switch (_sort) {
        _PackageSort.revenue => _number(a.revenue),
        _PackageSort.customers => _number(a.users),
        _PackageSort.growth => _number(a.growth),
      };
      final bValue = switch (_sort) {
        _PackageSort.revenue => _number(b.revenue),
        _PackageSort.customers => _number(b.users),
        _PackageSort.growth => _number(b.growth),
      };
      return bValue.compareTo(aValue);
    });
    return sorted;
  }

  Future<void> _pickSort() async {
    final selected = await showModalBottomSheet<_PackageSort>(
      context: context,
      backgroundColor: _dashSurface(context),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _PackageSort.values
              .map(
                (sort) => ListTile(
                  leading: Icon(
                    switch (sort) {
                      _PackageSort.revenue =>
                        Icons.account_balance_wallet_outlined,
                      _PackageSort.customers => Icons.groups_outlined,
                      _PackageSort.growth => Icons.trending_up_rounded,
                    },
                    color: sort == _sort ? AppTheme.amber : _dashMuted(context),
                  ),
                  title: Text(switch (sort) {
                    _PackageSort.revenue => 'Sort by revenue',
                    _PackageSort.customers => 'Sort by customers',
                    _PackageSort.growth => 'Sort by growth',
                  }),
                  trailing: sort == _sort
                      ? const Icon(Icons.check_rounded, color: AppTheme.amber)
                      : null,
                  onTap: () => Navigator.pop(context, sort),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _sort = selected);
  }

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
                action: _SmallSelect(label: _sortLabel, onTap: _pickSort),
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
              if (widget.packages.isEmpty)
                const _EmptyDashboardText(message: 'No packages saved yet.')
              else
                ..._sortedPackages.map(
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
    final dashboard = context.findAncestorStateOfType<_DashboardState>();
    final viewButton = OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: _dashText(context),
        side: BorderSide(color: _dashBorder(context)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      ),
      onPressed: () => dashboard?._showView(_ProviderDashView.packages),
      child: const Text('View all packages', softWrap: true),
    );

    final addButton = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.amber,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      ),
      onPressed: () => dashboard?._showView(_ProviderDashView.packages),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add Package', softWrap: true),
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
    final dashboard = context.findAncestorStateOfType<_DashboardState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnaBlueprintCard(
          title: 'Traffic by Top Coverage Areas',
          action: IconButton(
            onPressed: () => dashboard?._showView(_ProviderDashView.coverage),
            tooltip: 'Open coverage areas',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.search_rounded, size: 18),
          ),
          child: Column(
            children: [
              const OnaSegmentedTabs(
                labels: ['All', 'Users', 'Revenue', 'Radius'],
                selected: 0,
                onSelected: _ignoreLocationTab,
              ),
              const SizedBox(height: 10),
              if (locations.isEmpty)
                const _EmptyDashboardText(
                  message: 'No coverage areas saved yet.',
                )
              else
                for (var index = 0; index < locations.length; index++)
                  OnaRankedBar(
                    label: locations[index].name,
                    valueLabel:
                        '${locations[index].users} users · ${locations[index].revenue}',
                    fraction: locations[index].progress,
                    icon: Icons.location_on_outlined,
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OnaBlueprintCard(
          title: 'Coverage Areas (${locations.length})',
          action: IconButton(
            onPressed: () => dashboard?._showView(_ProviderDashView.coverage),
            tooltip: 'More coverage options',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.more_vert_rounded, size: 18),
          ),
          child: SizedBox(
            height: 250,
            child: _CoverageMap(locations: locations),
          ),
        ),
      ],
    );
  }

  static void _ignoreLocationTab(int _) {}
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
          pageTitle: 'Installation Requests',
          providerName: widget.providerName,
          providerStatus: widget.providerStatus,
          notificationCount: widget.notificationCount,
          dateRangeLabel: widget.dateRangeLabel,
          onDateRangePressed: widget.onDateRangePressed,
          showMenuButton: widget.showMenuButton,
          onMenuPressed: widget.onMenuPressed,
        ),
        const SizedBox(height: 14),
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
                        'Request overview',
                        style: TextStyle(
                          color: _dashText(context),
                          fontSize: 17,
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

    return OnaBlueprintCard(
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
                      style: TextStyle(
                        color: _dashText(context),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customer ID: ${request.userId.isEmpty ? 'Not set' : request.userId}',
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
    final dashboard = context.findAncestorStateOfType<_DashboardState>();
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            title: 'Recent Reviews',
            trailing: TextButton(
              onPressed: () => dashboard?._showView(_ProviderDashView.reviews),
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
    return OnaBlueprintCard(child: child);
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
  const _PackageEditorDialog();

  @override
  State<_PackageEditorDialog> createState() => _PackageEditorDialogState();
}

class _PackageEditorDialogState extends State<_PackageEditorDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _speed = TextEditingController();
  final TextEditingController _price = TextEditingController();
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
      'installation_fee': 0,
      'billing_cycle': 'monthly',
      'contract_type': 'no_contract',
      'router_included': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add package'),
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

class _PackageCardGrid extends StatelessWidget {
  const _PackageCardGrid({
    required this.items,
    required this.onSave,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> items;
  final Future<void> Function(
    Map<String, dynamic> item,
    Map<String, dynamic> payload,
  )
  onSave;
  final Future<void> Function(Map<String, dynamic> item) onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 920
            ? 3
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        final cardWidth =
            (constraints.maxWidth - ((columns - 1) * 16)) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: items
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  child: _PackageFlipCard(
                    key: ValueKey(item['id']),
                    item: item,
                    onSave: (payload) => onSave(item, payload),
                    onDelete: () => onDelete(item),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _PackageFlipCard extends StatefulWidget {
  const _PackageFlipCard({
    super.key,
    required this.item,
    required this.onSave,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final Future<void> Function(Map<String, dynamic> payload) onSave;
  final Future<void> Function() onDelete;

  @override
  State<_PackageFlipCard> createState() => _PackageFlipCardState();
}

class _PackageFlipCardState extends State<_PackageFlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _turn = CurvedAnimation(
    parent: _flip,
    curve: Curves.easeInOutCubic,
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.item['package_name']?.toString() ?? '',
  );
  late final TextEditingController _speed = TextEditingController(
    text: widget.item['speed_mbps']?.toString() ?? '',
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.item['monthly_price']?.toString() ?? '',
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _flip.dispose();
    _name.dispose();
    _speed.dispose();
    _price.dispose();
    super.dispose();
  }

  void _showEditor() {
    if (!_flip.isAnimating) _flip.forward();
  }

  void _closeEditor() {
    if (_flip.isAnimating) return;
    _name.text = widget.item['package_name']?.toString() ?? '';
    _speed.text = widget.item['speed_mbps']?.toString() ?? '';
    _price.text = widget.item['monthly_price']?.toString() ?? '';
    setState(() => _error = null);
    _flip.reverse();
  }

  Future<void> _save() async {
    final speed = int.tryParse(_speed.text.trim());
    final price = double.tryParse(_price.text.trim().replaceAll(',', ''));
    if (_name.text.trim().isEmpty ||
        speed == null ||
        speed <= 0 ||
        price == null ||
        price < 0) {
      setState(() {
        _error = 'Enter a valid name, speed, and monthly price.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave({
        'package_name': _name.text.trim(),
        'speed_mbps': speed,
        'monthly_price': price,
      });
      if (mounted) await _flip.reverse();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _money(Object? value) {
    final amount = num.tryParse(value?.toString() ?? '') ?? 0;
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _turn,
      builder: (context, _) {
        final angle = _turn.value * math.pi;
        final showingFront = angle < math.pi / 2;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateY(angle);

        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: showingFront
              ? _front(context)
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: _back(context),
                ),
        );
      },
    );
  }

  Widget _shell({
    required BuildContext context,
    required Widget child,
    required List<Color> colors,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 310,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.last,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: .11)
              : Colors.black.withValues(alpha: .07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .28 : .12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _front(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = dark ? Colors.white : const Color(0xFF17202A);
    final muted = textColor.withValues(alpha: .64);
    final routerIncluded = widget.item['router_included'] == true;
    final installation = _money(widget.item['installation_fee']);

    return Semantics(
      button: true,
      label: 'Edit ${widget.item['package_name']} package',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showEditor,
          child: _shell(
            context: context,
            colors: dark
                ? const [Color(0xFF211A33), Color(0xFF151121)]
                : const [AppTheme.amberLight, AppTheme.white],
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.amber.withValues(alpha: .16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.wifi_rounded,
                              color: AppTheme.amber,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Delete package',
                            onPressed: widget.onDelete,
                            color: muted,
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.item['package_name']?.toString() ?? 'Package',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${widget.item['speed_mbps'] ?? 0} Mbps',
                        style: const TextStyle(
                          color: AppTheme.amber,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        'KES ${_money(widget.item['monthly_price'])}',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' / month',
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Icon(
                            routerIncluded
                                ? Icons.router_rounded
                                : Icons.router_outlined,
                            size: 19,
                            color: muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            routerIncluded ? 'Router included' : 'No router',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Divider(color: textColor.withValues(alpha: .09)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              installation == '0'
                                  ? 'Free installation'
                                  : 'KES $installation installation',
                              style: TextStyle(
                                color: muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(Icons.touch_app_rounded, size: 15, color: muted),
                          const SizedBox(width: 5),
                          Text(
                            'Tap to edit',
                            style: TextStyle(
                              color: muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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

  Widget _back(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = dark ? Colors.white : const Color(0xFF17202A);
    final fill = dark
        ? Colors.black.withValues(alpha: .18)
        : Colors.white.withValues(alpha: .78);
    InputDecoration fieldDecoration(String label, {String? suffix}) {
      return InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: fill,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
    }

    return _shell(
      context: context,
      colors: dark
          ? const [Color(0xFF251C38), Color(0xFF171220)]
          : const [AppTheme.amberLight, AppTheme.offWhite],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.edit_rounded, color: AppTheme.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Edit package',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cancel editing',
                  visualDensity: VisualDensity.compact,
                  onPressed: _saving ? null : _closeEditor,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 7),
            TextField(
              controller: _name,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              decoration: fieldDecoration('Package name'),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _speed,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: fieldDecoration('Speed', suffix: 'Mbps'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: TextField(
                    controller: _price,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: fieldDecoration('Price', suffix: 'KES'),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.amber,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Saving...' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCoverageEditor extends StatefulWidget {
  const _DashboardCoverageEditor();

  @override
  State<_DashboardCoverageEditor> createState() =>
      _DashboardCoverageEditorState();
}

class _DashboardCoverageEditorState extends State<_DashboardCoverageEditor> {
  static const _defaultCenter = LatLng(-1.286389, 36.817223);

  final _mapController = MapController();
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  Timer? _searchDebounce;
  LatLng _center = _defaultCenter;
  double _radiusKm = 3;
  bool _hasSelection = false;
  bool _searching = false;
  bool _locating = false;
  List<LocationSuggestion> _suggestions = const [];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _search(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      final results = await Location.searchAreas(query);
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    });
  }

  void _selectSuggestion(LocationSuggestion suggestion) {
    final point = LatLng(suggestion.latitude, suggestion.longitude);
    _searchController.text = suggestion.displayName;
    _nameController.text = suggestion.title;
    setState(() {
      _center = point;
      _hasSelection = true;
      _suggestions = const [];
    });
    _mapController.move(point, _zoomForRadius(_radiusKm));
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final location = await Location.getCurrentLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not access your current location.'),
        ),
      );
      return;
    }
    final point = LatLng(location.latitude, location.longitude);
    final areaName = location.area?.trim();
    _nameController.text = areaName == null || areaName.isEmpty
        ? 'My service area'
        : areaName;
    _searchController.text = _nameController.text;
    setState(() {
      _center = point;
      _hasSelection = true;
      _suggestions = const [];
    });
    _mapController.move(point, _zoomForRadius(_radiusKm));
  }

  void _selectMapPoint(LatLng point) {
    if (_nameController.text.trim().isEmpty) {
      _nameController.text = _searchController.text.trim().isEmpty
          ? 'Selected service area'
          : _searchController.text.trim();
    }
    setState(() {
      _center = point;
      _hasSelection = true;
      _suggestions = const [];
    });
  }

  double _zoomForRadius(double radius) {
    if (radius <= 2) return 14;
    if (radius <= 5) return 13;
    if (radius <= 12) return 12;
    if (radius <= 25) return 11;
    return 10;
  }

  void _save() {
    final name = _nameController.text.trim();
    if (!_hasSelection || name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a map location and enter an area name.'),
        ),
      );
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'area_name': name,
      'latitude': _center.latitude,
      'longitude': _center.longitude,
      'radius_km': _radiusKm,
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panel = dark ? const Color(0xFF0D2231) : Colors.white;
    final border = _dashBorder(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 820),
        child: Material(
          color: panel,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: dark
                        ? const [Color(0xFF17364A), Color(0xFF0D2231)]
                        : const [AppTheme.amberLight, AppTheme.white],
                  ),
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.add_location_alt_rounded,
                        color: AppTheme.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Coverage Area',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Search, position the map and define your service radius',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: _search,
                        decoration: InputDecoration(
                          labelText: 'Search town, estate or landmark',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searching
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Use current location',
                                  onPressed: _locating
                                      ? null
                                      : _useCurrentLocation,
                                  icon: _locating
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.my_location_rounded),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      if (_suggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: border),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: _suggestions
                                .map(
                                  (suggestion) => ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.location_on_outlined,
                                      color: AppTheme.amber,
                                    ),
                                    title: Text(suggestion.title),
                                    subtitle: suggestion.subtitle.isEmpty
                                        ? null
                                        : Text(suggestion.subtitle),
                                    onTap: () => _selectSuggestion(suggestion),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 330,
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _center,
                              initialZoom: 11,
                              onTap: (_, point) => _selectMapPoint(point),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'com.onanet.provider.dashboard',
                              ),
                              if (_hasSelection)
                                CircleLayer(
                                  circles: [
                                    CircleMarker(
                                      point: _center,
                                      radius: _radiusKm * 1000,
                                      useRadiusInMeter: true,
                                      color: AppTheme.amber.withValues(
                                        alpha: .18,
                                      ),
                                      borderColor: AppTheme.amber,
                                      borderStrokeWidth: 2,
                                    ),
                                  ],
                                ),
                              if (_hasSelection)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _center,
                                      width: 48,
                                      height: 48,
                                      child: const Icon(
                                        Icons.location_pin,
                                        color: AppTheme.amber,
                                        size: 46,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Public coverage area name',
                          prefixIcon: const Icon(Icons.label_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                        decoration: BoxDecoration(
                          color: AppTheme.amber.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.amber.withValues(alpha: .2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.radar_rounded,
                                  color: AppTheme.amber,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Coverage radius',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_radiusKm.toStringAsFixed(0)} km',
                                  style: const TextStyle(
                                    color: AppTheme.amber,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _radiusKm,
                              min: 1,
                              max: 50,
                              divisions: 49,
                              activeColor: AppTheme.amber,
                              label: '${_radiusKm.toStringAsFixed(0)} km',
                              onChanged: (value) {
                                setState(() => _radiusKm = value);
                                if (_hasSelection) {
                                  _mapController.move(
                                    _center,
                                    _zoomForRadius(value),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: panel,
                  border: Border(top: BorderSide(color: border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Add coverage'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCoverageAreas extends StatelessWidget {
  const _DashboardCoverageAreas({required this.items, required this.onDelete});

  final List<Map<String, dynamic>> items;
  final Future<void> Function(Map<String, dynamic> item) onDelete;

  double? _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final valid = items.where((item) {
      return _number(item['latitude']) != null &&
          _number(item['longitude']) != null;
    }).toList();
    final points = valid
        .map(
          (item) =>
              LatLng(_number(item['latitude'])!, _number(item['longitude'])!),
        )
        .toList();
    final center = points.isEmpty
        ? const LatLng(-1.286389, 36.817223)
        : LatLng(
            points.map((point) => point.latitude).reduce((a, b) => a + b) /
                points.length,
            points.map((point) => point.longitude).reduce((a, b) => a + b) /
                points.length,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 320,
            child: FlutterMap(
              key: ValueKey(
                items.map((item) => item['id']?.toString()).join('|'),
              ),
              options: MapOptions(
                initialCenter: center,
                initialZoom: points.length <= 1 ? 12 : 9,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.onanet.provider.dashboard',
                ),
                CircleLayer(
                  circles: valid.map((item) {
                    return CircleMarker(
                      point: LatLng(
                        _number(item['latitude'])!,
                        _number(item['longitude'])!,
                      ),
                      radius: (_number(item['radius_km']) ?? 3) * 1000,
                      useRadiusInMeter: true,
                      color: AppTheme.amber.withValues(alpha: .14),
                      borderColor: AppTheme.amber,
                      borderStrokeWidth: 1.5,
                    );
                  }).toList(),
                ),
                MarkerLayer(
                  markers: valid.asMap().entries.map((entry) {
                    final item = entry.value;
                    return Marker(
                      point: LatLng(
                        _number(item['latitude'])!,
                        _number(item['longitude'])!,
                      ),
                      width: 38,
                      height: 38,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.navy,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 850
                ? 3
                : constraints.maxWidth >= 540
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items.asMap().entries.map((entry) {
                final item = entry.value;
                final latitude = _number(item['latitude']);
                final longitude = _number(item['longitude']);
                final radius = _number(item['radius_km']) ?? 3;
                final areaName =
                    item['area_name']?.toString().trim().isNotEmpty == true
                    ? item['area_name'].toString().trim()
                    : 'Coverage area';
                return SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _dashSurface(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _dashBorder(context)),
                      boxShadow: [
                        BoxShadow(
                          color: _dashShadow(context),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 19,
                              backgroundColor: AppTheme.amber.withValues(
                                alpha: .12,
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: AppTheme.amber,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                areaName,
                                softWrap: true,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove coverage area',
                              onPressed: () => onDelete(item),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.amber.withValues(alpha: .09),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.radar_rounded,
                                    size: 16,
                                    color: AppTheme.amber,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${radius.toStringAsFixed(radius % 1 == 0 ? 0 : 1)} km radius',
                                    style: const TextStyle(
                                      color: AppTheme.amberDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.green.withValues(alpha: .09),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 15,
                                    color: AppTheme.green,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Active',
                                    style: TextStyle(
                                      color: AppTheme.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: _dashBackground(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.near_me_outlined,
                                size: 17,
                                color: _dashMuted(context),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your service coverage is centered around $areaName.',
                                  softWrap: true,
                                  style: TextStyle(
                                    color: _dashMuted(context),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (latitude != null && longitude != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _openMapLocation(
                                context,
                                'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
                              ),
                              icon: const Icon(Icons.map_outlined, size: 17),
                              label: const Text('Open on map'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ProviderSectionPage extends StatefulWidget {
  const _ProviderSectionPage({
    required this.view,
    required this.providerId,
    required this.subscriptionTier,
    required this.providerName,
    required this.providerStatus,
    required this.requests,
    required this.showMenuButton,
    required this.onMenuPressed,
    required this.onViewChanged,
    required this.onChanged,
  });

  final _ProviderDashView view;
  final String providerId;
  final String subscriptionTier;
  final String providerName;
  final String providerStatus;
  final List<ProviderInboxItem> requests;
  final bool showMenuButton;
  final VoidCallback onMenuPressed;
  final ValueChanged<_ProviderDashView> onViewChanged;
  final VoidCallback onChanged;

  @override
  State<_ProviderSectionPage> createState() => _ProviderSectionPageState();
}

class _ProviderSectionPageState extends State<_ProviderSectionPage> {
  final _service = AuthService();
  late Future<List<Map<String, dynamic>>> _items = _load();
  bool _isAddingPackage = false;
  bool _isRefreshing = false;

  int? get _coverageAreaLimit =>
      switch (widget.subscriptionTier.trim().toLowerCase()) {
        'pro' => null,
        'growth' => 5,
        _ => 3,
      };

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
    if (!mounted) return;
    setState(() => _items = _load());
    widget.onChanged();
  }

  Future<void> _refreshItems({bool showConfirmation = false}) async {
    if (_isRefreshing || !mounted) return;
    final nextItems = _load();
    setState(() {
      _isRefreshing = true;
      _items = nextItems;
    });
    try {
      await nextItems;
      if (!mounted) return;
      widget.onChanged();
      if (showConfirmation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Packages refreshed.'),
          ),
        );
      }
    } catch (_) {
      // The FutureBuilder below presents the request error with a retry action.
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  String get _title => switch (widget.view) {
    _ProviderDashView.packages => 'Packages',
    _ProviderDashView.coverage => 'Coverage Areas',
    _ProviderDashView.customers => 'Customers',
    _ProviderDashView.reviews => 'Reviews',
    _ProviderDashView.messages => 'Messages',
    _ => 'Provider Workspace',
  };

  Future<void> _pickSection() async {
    const sections = [
      (_ProviderDashView.packages, 'Packages', Icons.router_outlined),
      (_ProviderDashView.coverage, 'Coverage Areas', Icons.map_outlined),
      (_ProviderDashView.customers, 'Customers', Icons.people_outline_rounded),
      (_ProviderDashView.reviews, 'Reviews', Icons.star_border_rounded),
      (_ProviderDashView.messages, 'Messages', Icons.mail_outline_rounded),
    ];
    final selected = await showModalBottomSheet<_ProviderDashView>(
      context: context,
      backgroundColor: _dashSurface(context),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: sections
              .map(
                (section) => ListTile(
                  leading: Icon(
                    section.$3,
                    color: section.$1 == widget.view
                        ? AppTheme.amber
                        : _dashMuted(context),
                  ),
                  title: Text(
                    section.$2,
                    style: TextStyle(
                      fontWeight: section.$1 == widget.view
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
                  ),
                  trailing: section.$1 == widget.view
                      ? const Icon(Icons.check_rounded, color: AppTheme.amber)
                      : null,
                  onTap: () => Navigator.pop(context, section.$1),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null && mounted) widget.onViewChanged(selected);
  }

  Future<void> _addPackage() async {
    if (_isAddingPackage) return;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _PackageEditorDialog(),
    );
    if (payload == null || !mounted) return;
    setState(() => _isAddingPackage = true);
    try {
      await _service.submitProviderPackage(
        providerId: widget.providerId,
        payload: payload,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      await _refreshItems();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Package added.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isAddingPackage = false);
    }
  }

  Future<void> _savePackageEdits(
    Map<String, dynamic> item,
    Map<String, dynamic> payload,
  ) async {
    await _service.updateProviderPackage(
      widget.providerId,
      item['id'].toString(),
      payload,
    );
    if (!mounted) return;
    _reload();
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
    if (yes != true || !mounted) return;
    try {
      await _service.deleteProviderPackage(
        widget.providerId,
        item['id'].toString(),
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      await _refreshItems();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Package deleted.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _addCoverage(List<Map<String, dynamic>> existing) async {
    final area = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DashboardCoverageEditor(),
    );
    if (area == null || !mounted) return;

    final areas = [
      ...existing.map(
        (e) => {
          'area_name': e['area_name'],
          'latitude': e['latitude'],
          'longitude': e['longitude'],
          'radius_km': e['radius_km'],
        },
      ),
      area,
    ];
    try {
      await _service.submitProviderCoverageAreas(
        providerId: widget.providerId,
        payload: {'coverage_areas': areas},
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      _reload();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('${area['area_name']} coverage added.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deleteCoverage(
    List<Map<String, dynamic>> existing,
    Map<String, dynamic> item,
  ) async {
    final areaName = item['area_name']?.toString() ?? 'this area';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove coverage area?'),
        content: Text('Remove $areaName from your provider coverage?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final remaining = existing
        .where((area) => area['id']?.toString() != item['id']?.toString())
        .map(
          (area) => {
            'area_name': area['area_name'],
            'latitude': area['latitude'],
            'longitude': area['longitude'],
            'radius_km': area['radius_km'],
          },
        )
        .toList();
    if (remaining.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('A provider must keep at least one coverage area.'),
        ),
      );
      return;
    }

    try {
      await _service.submitProviderCoverageAreas(
        providerId: widget.providerId,
        payload: {'coverage_areas': remaining},
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      _reload();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('$areaName removed.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(
          pageTitle: _title,
          providerName: widget.providerName,
          providerStatus: widget.providerStatus,
          notificationCount: 0,
          dateRangeLabel: _title,
          onDateRangePressed: _pickSection,
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      Text(
                        '${items.length} ${_title.toLowerCase()}',
                        softWrap: true,
                        style: TextStyle(
                          color: _dashMuted(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.view == _ProviderDashView.packages) ...[
                        IconButton.filledTonal(
                          tooltip: 'Refresh packages',
                          onPressed: _isRefreshing
                              ? null
                              : () {
                                  _refreshItems(showConfirmation: true);
                                },
                          icon: _isRefreshing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: _isAddingPackage
                              ? null
                              : () {
                                  _addPackage();
                                },
                          icon: _isAddingPackage
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add),
                          label: Text(
                            _isAddingPackage ? 'Adding...' : 'Add package',
                          ),
                        ),
                      ],
                      if (widget.view == _ProviderDashView.coverage)
                        FilledButton.icon(
                          onPressed:
                              _coverageAreaLimit != null &&
                                  items.length >= _coverageAreaLimit!
                              ? null
                              : () => _addCoverage(items),
                          icon: const Icon(Icons.add_location_alt),
                          label: Text(
                            _coverageAreaLimit == null
                                ? 'Add area'
                                : '${items.length}/$_coverageAreaLimit areas',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else if (snapshot.hasError)
                    Column(
                      children: [
                        Text(
                          snapshot.error.toString(),
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            _refreshItems();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                    )
                  else if (items.isEmpty)
                    Text(
                      'No ${_title.toLowerCase()} yet.',
                      style: TextStyle(color: _dashMuted(context)),
                    )
                  else if (widget.view == _ProviderDashView.packages)
                    _PackageCardGrid(
                      items: items,
                      onSave: _savePackageEdits,
                      onDelete: _deletePackage,
                    )
                  else if (widget.view == _ProviderDashView.coverage)
                    _DashboardCoverageAreas(
                      items: items,
                      onDelete: (item) => _deleteCoverage(items, item),
                    )
                  else
                    ...items.map(
                      (item) => widget.view == _ProviderDashView.customers
                          ? _ProviderCustomerCard(item: item)
                          : Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: _dashSurface(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: _dashBorder(context)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
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
                                    widget.view == _ProviderDashView.coverage
                                    ? IconButton(
                                        tooltip: 'Remove coverage area',
                                        onPressed: () {
                                          _deleteCoverage(items, item);
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                        ),
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
      margin: const EdgeInsets.only(bottom: 12),
      color: _dashSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _dashBorder(context)),
      ),
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
