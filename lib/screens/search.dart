import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/auth/auth_service.dart';
import 'package:ona_net/screens/provider_detail.dart';
import 'package:ona_net/themes/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _providers = [];
  bool _isLoading = true;
  String? _error;
  String _query = '';

  static const _quickGoals = [
    _SearchGoal(
      title: 'Fast home fiber',
      subtitle: 'Find high-speed providers with home installation.',
      icon: Icons.bolt_rounded,
      keywords: ['fast', 'fiber', 'home', 'speed', 'wifi'],
    ),
    _SearchGoal(
      title: 'Budget packages',
      subtitle: 'Compare affordable monthly internet plans nearby.',
      icon: Icons.savings_outlined,
      keywords: ['cheap', 'budget', 'affordable', 'price', 'package'],
    ),
    _SearchGoal(
      title: 'Verified providers',
      subtitle: 'See providers with verified OnaNet profiles.',
      icon: Icons.verified_user_outlined,
      keywords: ['verified', 'trusted', 'safe', 'provider'],
    ),
    _SearchGoal(
      title: 'Coverage near me',
      subtitle: 'Search estates, towns, landmarks, or coverage zones.',
      icon: Icons.location_on_outlined,
      keywords: ['near', 'area', 'coverage', 'estate', 'town'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final providers = await AuthService().getPublicProviders();
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredProviders {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _providers.take(6).toList();

    return _providers.where((provider) {
      final searchable = [
        _providerName(provider),
        _providerType(provider),
        ..._coverageAreas(provider),
        '${_speed(provider)}mbps',
        'kes ${_price(provider)}',
      ].join(' ').toLowerCase();

      return query
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .every(searchable.contains);
    }).toList();
  }

  List<_SearchGoal> get _filteredGoals {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _quickGoals;

    return _quickGoals.where((goal) {
      final searchable = [
        goal.title,
        goal.subtitle,
        ...goal.keywords,
      ].join(' ').toLowerCase();
      return query
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .any(searchable.contains);
    }).toList();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
  }

  void _openProvider(Map<String, dynamic> provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProviderDetailScreen(provider: provider),
      ),
    );
  }

  void _applyGoal(_SearchGoal goal) {
    _searchController.text = goal.title;
    _searchController.selection = TextSelection.collapsed(
      offset: _searchController.text.length,
    );
    _onQueryChanged(goal.title);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedColor = isDark ? AppTheme.gray : AppTheme.darkGray;
    final results = _filteredProviders;
    final goals = _filteredGoals;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.amber,
          backgroundColor: isDark ? AppTheme.navyMid : AppTheme.white,
          onRefresh: _loadProviders,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search OnaNet',
                        style: GoogleFonts.plusJakartaSans(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Type anything: area, speed, price, provider, or goal.',
                        style: GoogleFonts.urbanist(
                          color: mutedColor.withValues(alpha: 0.74),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LiveSearchField(
                        controller: _searchController,
                        onChanged: _onQueryChanged,
                        onClear: () {
                          _searchController.clear();
                          _onQueryChanged('');
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  sliver: SliverList.list(
                    children: [
                      _ResultSummary(
                        query: _query,
                        providerCount: results.length,
                        goalCount: goals.length,
                        hasError: _error != null,
                      ),
                      const SizedBox(height: 14),
                      if (goals.isNotEmpty) ...[
                        _SectionTitle(
                          title: _query.trim().isEmpty
                              ? 'Popular goals'
                              : 'Suggestions',
                        ),
                        const SizedBox(height: 10),
                        ...goals.map(
                          (goal) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _GoalTile(
                              goal: goal,
                              onTap: () => _applyGoal(goal),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _SectionTitle(
                        title: _query.trim().isEmpty
                            ? 'Providers to explore'
                            : 'Matching providers',
                      ),
                      const SizedBox(height: 10),
                      if (_error != null && _providers.isEmpty)
                        _SearchEmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: 'Could not load live providers',
                          subtitle:
                              'You can still type to shape your search goal, then refresh when you are ready.',
                          actionLabel: 'Retry',
                          onAction: _loadProviders,
                        )
                      else if (results.isEmpty)
                        _SearchEmptyState(
                          icon: Icons.manage_search_rounded,
                          title: 'No provider match yet',
                          subtitle:
                              'Try typing an area, package type, speed, or a broader phrase.',
                        )
                      else
                        ...results.map(
                          (provider) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ProviderResultCard(
                              provider: provider,
                              onTap: () => _openProvider(provider),
                            ),
                          ),
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

class _LiveSearchField extends StatelessWidget {
  const _LiveSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? AppTheme.navyMid : AppTheme.white;
    final borderColor = isDark ? AppTheme.navyLight : AppTheme.lightGray;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasText = controller.text.isNotEmpty;
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: AppTheme.navy.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: AppTheme.amber, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: false,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  style: GoogleFonts.plusJakartaSans(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search area, provider, speed, package...',
                    hintStyle: GoogleFonts.urbanist(
                      color: textColor.withValues(alpha: 0.45),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (hasText)
                IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                )
              else
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.amber,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppTheme.white,
                    size: 20,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({
    required this.query,
    required this.providerCount,
    required this.goalCount,
    required this.hasError,
  });

  final String query;
  final int providerCount;
  final int goalCount;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedColor = isDark ? AppTheme.gray : AppTheme.darkGray;
    final hasQuery = query.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              hasQuery ? Icons.troubleshoot_rounded : Icons.explore_rounded,
              color: AppTheme.amber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasQuery
                  ? '$providerCount provider matches and $goalCount helpful suggestions'
                  : hasError
                  ? 'Start with a goal while live providers reload'
                  : 'Start typing to narrow providers instantly',
              style: GoogleFonts.plusJakartaSans(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            hasQuery ? 'Live' : 'Ready',
            style: GoogleFonts.urbanist(
              color: mutedColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        color: isDark ? AppTheme.offWhite : AppTheme.navy,
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal, required this.onTap});

  final _SearchGoal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedColor = isDark ? AppTheme.gray : AppTheme.darkGray;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.navyMid : AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
          ),
        ),
        child: Row(
          children: [
            Icon(goal.icon, color: AppTheme.amber, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    goal.subtitle,
                    style: GoogleFonts.urbanist(
                      color: mutedColor.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.north_west_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ProviderResultCard extends StatelessWidget {
  const _ProviderResultCard({required this.provider, required this.onTap});

  final Map<String, dynamic> provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedColor = isDark ? AppTheme.gray : AppTheme.darkGray;
    final name = _providerName(provider);
    final areas = _coverageAreas(provider);
    final verified = _isVerified(provider);
    final speed = _speed(provider);
    final price = _price(provider);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.navyMid : AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: AppTheme.navy.withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProviderInitials(name: name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (verified)
                        Icon(
                          Icons.verified_rounded,
                          color: AppTheme.green,
                          size: 17,
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    areas.isEmpty
                        ? _providerType(provider)
                        : 'Covers ${areas.take(2).join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.urbanist(
                      color: mutedColor.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ProviderMeta(label: 'From', value: 'KES $price'),
                      _ProviderMeta(label: 'Speed', value: '${speed}Mbps'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.amber),
          ],
        ),
      ),
    );
  }
}

class _ProviderInitials extends StatelessWidget {
  const _ProviderInitials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        initials.isEmpty ? 'ON' : initials,
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.amber,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProviderMeta extends StatelessWidget {
  const _ProviderMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navy : AppTheme.offWhite,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: GoogleFonts.urbanist(
          color: isDark ? AppTheme.offWhite : AppTheme.navy,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedColor = isDark ? AppTheme.gray : AppTheme.darkGray;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.amber, size: 34),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.urbanist(
              color: mutedColor.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.amber),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchGoal {
  const _SearchGoal({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.keywords,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> keywords;
}

String _providerName(Map<String, dynamic> provider) {
  return (provider['name'] ??
          provider['provider_name'] ??
          provider['business_name'] ??
          'OnaNet Provider')
      .toString();
}

String _providerType(Map<String, dynamic> provider) {
  return (provider['providerType'] ??
          provider['provider_type'] ??
          provider['service_type'] ??
          'Internet provider')
      .toString();
}

List<String> _coverageAreas(Map<String, dynamic> provider) {
  final value = provider['coverageAreas'] ?? provider['coverage_areas'];
  if (value is List) {
    return value
        .map((area) {
          if (area is Map) return area['name'] ?? area['area_name'];
          return area;
        })
        .where((area) => area != null && area.toString().trim().isNotEmpty)
        .map((area) => area.toString())
        .toList();
  }
  return [];
}

bool _isVerified(Map<String, dynamic> provider) {
  return provider['verified'] == true || provider['isVerified'] == true;
}

int _speed(Map<String, dynamic> provider) {
  final value = provider['speed'] ?? provider['maxSpeed'] ?? provider['speed_mbps'];
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int _price(Map<String, dynamic> provider) {
  final value =
      provider['price'] ?? provider['startingPrice'] ?? provider['monthly_price'];
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
