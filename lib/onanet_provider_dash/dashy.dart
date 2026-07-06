import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:ona_net/auth/auth_service.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:ona_net/services/provider_inbox.dart';

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _dashBackground(BuildContext context) =>
    Theme.of(context).scaffoldBackgroundColor;

Color _dashSurface(BuildContext context) =>
    _isDark(context) ? AppTheme.navyMid : AppTheme.white;

Color _dashText(BuildContext context) =>
    _isDark(context) ? AppTheme.offWhite : AppTheme.navy;

Color _dashMuted(BuildContext context) =>
    _isDark(context) ? AppTheme.gray : AppTheme.darkGray;

Color _dashBorder(BuildContext context) =>
    _isDark(context) ? AppTheme.navyLight : AppTheme.lightGray;

Color _dashSoftAmber(BuildContext context) => _isDark(context)
    ? AppTheme.amber.withValues(alpha: .14)
    : AppTheme.amberLight.withValues(alpha: .55);

Color _dashAccentText(BuildContext context) =>
    _isDark(context) ? AppTheme.amberLight : AppTheme.amberDark;

Color _dashShadow(BuildContext context) =>
    (_isDark(context) ? Colors.black : AppTheme.navy).withValues(alpha: .08);

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

class _DashboardState extends State<Dashboard> {
  bool _showMobileSidebar = false;
  late final Future<Map<String, dynamic>> _providerFuture;
  late DateTimeRange _selectedDateRange;
  late String _selectedMonth;
  final _inboxService = ProviderInbox();
  final _requestsSectionKey = GlobalKey();
  List<ProviderInboxItem> _inboxItems = const [];
  bool _inboxLoading = false;
  String? _inboxError;

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
        _inboxLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inboxError = e.toString();
        _inboxLoading = false;
      });
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      await _inboxService.accept(requestId);
      await _refreshInbox();
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
    if (closeSidebar) {
      setState(() => _showMobileSidebar = false);
    }
    _refreshInbox();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sectionContext = _requestsSectionKey.currentContext;
      if (sectionContext == null) return;
      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
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

              return DefaultTextStyle(
                style: _dashFont(color: _dashText(context), fontSize: 14),
                child: Scaffold(
                  backgroundColor: _dashBackground(context),
                  body: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 1100;
                      final dashboard = _DashboardContent(
                        metrics: metrics,
                        revenue: revenue,
                        revenueTotal: _moneyValue(provider, 'monthly_revenue'),
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
                        requestsSectionKey: _requestsSectionKey,
                        reviews: reviews,
                        pendingRequestCount: pendingRequestCount,
                        providerName: providerName,
                        providerStatus: providerStatus,
                        providerLoadError: snapshot.hasError
                            ? snapshot.error.toString()
                            : null,
                        isLoadingProvider:
                            snapshot.connectionState == ConnectionState.waiting,
                        showMenuButton: !wide,
                        onMenuPressed: () {
                          setState(() => _showMobileSidebar = true);
                        },
                      );
                      if (!wide) {
                        return SafeArea(
                          child: Stack(
                            children: [
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: dashboard,
                              ),
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: () =>
                                      setState(() => _showMobileSidebar = true),
                                  onHorizontalDragEnd: (details) {
                                    if ((details.primaryVelocity ?? 0) > 0) {
                                      setState(() => _showMobileSidebar = true);
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
                                      if ((details.primaryVelocity ?? 0) < 0) {
                                        setState(
                                          () => _showMobileSidebar = false,
                                        );
                                      }
                                    },
                                    child: _SideBar(
                                      pendingRequestCount: pendingRequestCount,
                                      onInstallationRequestsPressed: () =>
                                          _showInstallationRequests(
                                            closeSidebar: true,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Row(
                        children: [
                          _SideBar(
                            pendingRequestCount: pendingRequestCount,
                            onInstallationRequestsPressed:
                                _showInstallationRequests,
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
                                child: dashboard,
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
    final monthlyRevenue = _moneyValue(provider, 'monthly_revenue');
    return [
      const _RevenuePoint('Jan', 0),
      const _RevenuePoint('Feb', 0),
      const _RevenuePoint('Mar', 0),
      const _RevenuePoint('Apr', 0),
      const _RevenuePoint('May', 0),
      _RevenuePoint('Now', monthlyRevenue),
    ];
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
    return LayoutBuilder(
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
              const SizedBox(height: 14),
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
                'Welcome back, $providerName!',
                softWrap: true,
                style: TextStyle(
                  color: _dashText(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
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
    required this.pendingRequestCount,
    required this.onInstallationRequestsPressed,
  });

  final int pendingRequestCount;
  final VoidCallback onInstallationRequestsPressed;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Dashboard', Icons.home_rounded, '0', true),
      ('Packages', Icons.inventory_2_outlined, '0', false),
      ('Coverage Areas', Icons.location_on_outlined, '0', false),
      (
        'Installation Requests',
        Icons.groups_2_outlined,
        pendingRequestCount.toString(),
        false,
      ),
      ('Customers', Icons.people_outline_rounded, '0', false),
      ('Reviews & Ratings', Icons.star_border_rounded, '0', false),
      ('Analytics', Icons.bar_chart_rounded, '0', false),
      ('Reports', Icons.article_outlined, '0', false),
      ('Messages', Icons.mail_outline_rounded, '0', false),
      ('Settings', Icons.settings_outlined, '0', false),
      ('Profile', Icons.person_outline_rounded, '0', false),
    ];
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF061A27), Color(0xFF092F42), Color(0xFF061622)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_rounded,
                    color: AppTheme.amber,
                    size: 44,
                  ),
                  const SizedBox(width: 10),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Ona',
                          style: _dashFont(
                            color: Colors.white,
                            fontSize: 33,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: 'Net',
                          style: _dashFont(
                            color: AppTheme.amber,
                            fontSize: 33,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: '\nProvider Dashboard',
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
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _NavItem(
                    label: item.$1,
                    icon: item.$2,
                    badge: item.$3,
                    selected: item.$4,
                    onTap: item.$1 == 'Installation Requests'
                        ? onInstallationRequestsPressed
                        : null,
                  );
                },
              ),
            ),
            const _PlanCard(),
            const Divider(color: Colors.white12, height: 34),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _NavItem(
                label: 'Logout',
                icon: Icons.logout_rounded,
                badge: '0',
                selected: false,
              ),
            ),
          ],
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
    final foreground = selected ? AppTheme.navy : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? AppTheme.amber : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: 23),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (badge != '0')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.navy : AppTheme.amber,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge,
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
  const _PlanCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: AppTheme.amber,
                size: 22,
              ),
              SizedBox(width: 12),
              Text(
                'Current Plan',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Verified Provider',
            style: TextStyle(
              color: AppTheme.amber,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 26),
          Text(
            'Provider Since',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          SizedBox(height: 7),
          Text(
            'March 12, 2025',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
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
      height: 140,
      child: Row(
        children: [
          _IconTile(icon: metric.icon),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _dashText(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _dashText(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 25,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(
                      metric.positive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: metric.positive ? AppTheme.green : Colors.red,
                      size: 14,
                    ),
                    Text(
                      ' ${metric.trend}',
                      style: TextStyle(
                        color: metric.positive ? AppTheme.green : Colors.red,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        ' ${metric.helper}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _dashMuted(context),
                          fontSize: 12,
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
              final map = const SizedBox(height: 230, child: _CoverageMap());
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
  const _CoverageMap();
  static const _center = LatLng(-1.2576, 36.8173);
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: _center,
          initialZoom: 11.1,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.onanet.provider.dashboard',
          ),
          CircleLayer(
            circles: [
              _hotspot(const LatLng(-1.2676, 36.8065), 62),
              _hotspot(const LatLng(-1.2921, 36.7896), 44),
              _hotspot(const LatLng(-1.2060, 36.7798), 38),
              _hotspot(const LatLng(-1.1453, 36.9633), 30),
            ],
          ),
          MarkerLayer(
            markers: const [
              Marker(
                point: LatLng(-1.2921, 36.7896),
                width: 92,
                height: 24,
                child: _MapLabel(label: 'Nairobi'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static CircleMarker _hotspot(LatLng point, double radius) {
    return CircleMarker(
      point: point,
      radius: radius,
      useRadiusInMeter: false,
      color: AppTheme.amber.withValues(alpha: .28),
      borderStrokeWidth: 0,
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
  });

  final List<ProviderInboxItem> requests;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String requestId) onAccept;
  final Future<void> Function(String requestId, String? reason) onDecline;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            title: 'Installation Requests',
            trailing: TextButton(
              onPressed: () => onRefresh(),
              style: TextButton.styleFrom(
                foregroundColor: _dashAccentText(context),
              ),
              child: Text(isLoading ? 'Refreshing...' : 'Refresh'),
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
        );
      },
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
  const _Surface({required this.child, this.height});
  final Widget child;
  final double? height;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _dashSurface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _dashBorder(context)),
        boxShadow: [
          BoxShadow(
            color: _dashShadow(context),
            blurRadius: 22,
            offset: const Offset(0, 10),
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
  });

  final ProviderInboxItem request;
  final Future<void> Function(String requestId) onAccept;
  final Future<void> Function(String requestId, String? reason) onDecline;

  @override
  Widget build(BuildContext context) {
    final customer = request.phoneE164?.isNotEmpty == true
        ? request.phoneE164!
        : 'Customer ${request.userId}';
    final location = [
      request.estateOrBuilding,
      if (request.houseOrApartment?.isNotEmpty == true)
        request.houseOrApartment!,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    final date = request.preferredDate ?? request.createdAt;
    final status = request.statusLabel;
    final colors = _inboxStatusColors(status);
    final canAct = request.id.isNotEmpty && request.isPending;
    final packageLabel = request.packageName?.trim().isNotEmpty == true
        ? request.packageName!.trim()
        : request.packageId.isEmpty
        ? 'Package'
        : request.packageId;

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
            child: Wrap(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

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
    final controller = TextEditingController();
    try {
      return await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final reason = controller.text.trim();
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
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: controller,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 500,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: const InputDecoration(
                            hintText:
                                'Example: Area is outside our current coverage',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: reason.isEmpty
                              ? null
                              : () => Navigator.pop(sheetContext, reason),
                          child: const Text('Decline Request'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }
}

String _inboxDateLabel(DateTime date) {
  return '${_inboxShortMonth(date)} ${date.day}, ${date.year}';
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
      final x = chart.left + (chart.width * i / (points.length - 1));
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppTheme.amber, size: 30),
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
  const _LocationRow(this.name, this.users, this.revenue, this.progress);
  final String name;
  final String users;
  final String revenue;
  final double progress;
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
