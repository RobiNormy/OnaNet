import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ona_net/onanet_provider_dash/blueprint_components.dart';
import 'package:ona_net/services/pro_analytics_service.dart';
import 'package:ona_net/themes/app_theme.dart';

class ProAnalyticsPage extends StatefulWidget {
  const ProAnalyticsPage({
    super.key,
    required this.isPro,
    required this.isUpgradeRunning,
    required this.onUpgradePressed,
    required this.onBackPressed,
    required this.showMenuButton,
    required this.onMenuPressed,
  });
  final bool isPro;
  final bool isUpgradeRunning;
  final VoidCallback onUpgradePressed;
  final VoidCallback onBackPressed;
  final bool showMenuButton;
  final VoidCallback onMenuPressed;

  @override
  State<ProAnalyticsPage> createState() => _ProAnalyticsPageState();
}

class _ProAnalyticsPageState extends State<ProAnalyticsPage> {
  final _service = ProAnalyticsService();
  late Future<Map<String, dynamic>> _future = widget.isPro
      ? _service.load()
      : Future.value(const {});

  void _reload() {
    final nextAnalytics = _service.load();
    setState(() {
      _future = nextAnalytics;
    });
  }

  @override
  void didUpdateWidget(covariant ProAnalyticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isPro && widget.isPro) {
      _future = _service.load();
    } else if (oldWidget.isPro && !widget.isPro) {
      _future = Future.value(const {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPro) {
      return _LockedProPage(
        isUpgradeRunning: widget.isUpgradeRunning,
        onUpgradePressed: widget.onUpgradePressed,
        onBackPressed: widget.onBackPressed,
        showMenuButton: widget.showMenuButton,
        onMenuPressed: widget.onMenuPressed,
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AnalyticsShell(
            onBackPressed: widget.onBackPressed,
            showMenuButton: widget.showMenuButton,
            onMenuPressed: widget.onMenuPressed,
            onRefresh: _reload,
            children: [
              _ProCard(
                title: 'Pro Analytics unavailable',
                badge: false,
                child: Column(
                  children: [
                    Text(snapshot.error.toString()),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        final data = snapshot.data ?? const {};
        return _AnalyticsShell(
          onBackPressed: widget.onBackPressed,
          showMenuButton: widget.showMenuButton,
          onMenuPressed: widget.onMenuPressed,
          onRefresh: _reload,
          children: [
            _CustomerSearchInsightsCard(data: _map(data['search_insights'])),
            _DemandMapCard(zones: _maps(data['demand_zones'])),
            _FunnelCard(data: _maps(data['funnel'])),
            _GrowthAreasCard(items: _maps(data['growth_areas'])),
            _PackageGapsCard(items: _maps(data['package_gaps'])),
            _PriceBenchmarkCard(items: _maps(data['price_benchmarks'])),
            _SearchPositionCard(items: _maps(data['search_positions'])),
            _RevenueForecastCard(data: _map(data['revenue'])),
            _LtvCard(data: _map(data['ltv'])),
            _MarketShareCard(data: _map(data['market_share'])),
            _ZoneShareCard(items: _maps(_map(data['market_share'])['zones'])),
            _ExportsCard(data: data, service: _service),
          ],
        );
      },
    );
  }
}

class _AnalyticsShell extends StatelessWidget {
  const _AnalyticsShell({
    required this.children,
    required this.onBackPressed,
    required this.showMenuButton,
    required this.onMenuPressed,
    this.onRefresh,
  });
  final List<Widget> children;
  final VoidCallback onBackPressed;
  final bool showMenuButton;
  final VoidCallback onMenuPressed;
  final VoidCallback? onRefresh;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final compactPage = MediaQuery.sizeOf(context).width < 700;
    final border = dark
        ? Colors.white.withValues(alpha: .08)
        : const Color(0xFFE5EAF1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(compactPage ? 4 : 22),
          decoration: BoxDecoration(
            color: compactPage
                ? Colors.transparent
                : dark
                ? const Color(0xFF132F42)
                : AppTheme.amberLight,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: compactPage ? Colors.transparent : border,
            ),
            boxShadow: compactPage
                ? const []
                : [
                    BoxShadow(
                      color: (dark ? Colors.black : AppTheme.navy).withValues(
                        alpha: dark ? .2 : .07,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OnaBlueprintHeader(
                      title: 'Analytics',
                      onBack: onBackPressed,
                      onMenu: onMenuPressed,
                    ),
                    if (onRefresh != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: onRefresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Refresh data'),
                        ),
                      ),
                  ],
                );
              }
              return Row(
                children: [
                  if (showMenuButton) ...[
                    IconButton.filledTonal(
                      tooltip: 'Open menu',
                      onPressed: onMenuPressed,
                      icon: const Icon(Icons.menu_rounded),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (!compact) ...[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.auto_graph_rounded,
                        color: AppTheme.amber,
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRO INTELLIGENCE',
                          style: TextStyle(
                            color: dark
                                ? AppTheme.amberLight
                                : AppTheme.amberDark,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Business intelligence, made actionable',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.45,
                              ),
                        ),
                        if (!compact) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Live demand, conversion, pricing and growth signals',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onRefresh != null)
                    IconButton.filledTonal(
                      tooltip: 'Refresh live analytics',
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  const SizedBox(width: 8),
                  if (!compact) const _ProBadge(),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 18.0;
            final twoColumns = constraints.maxWidth >= 980;
            final halfWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: children.map((child) {
                final fullWidth =
                    !twoColumns ||
                    child is _DemandMapCard ||
                    child is _CustomerSearchInsightsCard ||
                    child is _ExportsCard ||
                    child is _LockedProPage;
                return SizedBox(
                  width: fullWidth ? constraints.maxWidth : halfWidth,
                  child: child,
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _LockedProPage extends StatelessWidget {
  const _LockedProPage({
    required this.isUpgradeRunning,
    required this.onUpgradePressed,
    required this.onBackPressed,
    required this.showMenuButton,
    required this.onMenuPressed,
  });
  final bool isUpgradeRunning;
  final VoidCallback onUpgradePressed;
  final VoidCallback onBackPressed;
  final bool showMenuButton;
  final VoidCallback onMenuPressed;
  @override
  Widget build(BuildContext context) => _AnalyticsShell(
    onBackPressed: onBackPressed,
    showMenuButton: showMenuButton,
    onMenuPressed: onMenuPressed,
    children: [
      _ProCard(
        title: 'Unlock Pro Intelligence',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, size: 42, color: AppTheme.amber),
            const SizedBox(height: 12),
            const Text(
              'Upgrade to Pro to unlock the full conversion funnel, demand map, package gaps, anonymous price benchmarks, search position tracking, forecasts, LTV, market share, and exports.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: isUpgradeRunning ? null : onUpgradePressed,
              icon: isUpgradeRunning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.workspace_premium),
              label: Text(
                isUpgradeRunning ? 'Activating Pro...' : 'Upgrade to Pro',
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ProCard extends StatelessWidget {
  const _ProCard({required this.title, required this.child, this.badge = true});
  final String title;
  final Widget child;
  final bool badge;
  @override
  Widget build(BuildContext context) {
    return OnaBlueprintCard(
      title: title,
      action: badge ? const _ProBadge() : null,
      child: child,
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.amber.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(999),
      boxShadow: [
        BoxShadow(color: AppTheme.amber.withValues(alpha: .10), blurRadius: 8),
      ],
    ),
    child: const Text(
      'PRO',
      style: TextStyle(
        color: AppTheme.amberDark,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({required this.data});
  final List<Map<String, dynamic>> data;
  @override
  Widget build(BuildContext context) {
    final peak = data.fold<int>(
      0,
      (current, stage) => math.max(current, _int(stage['value'])),
    );
    return _ProCard(
      title: 'Conversion Funnel',
      child: data.isEmpty
          ? const _Empty()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OnaSemiGauge(
                  value: data.isEmpty
                      ? 0
                      : (_d(data.last['rate']) / 100).clamp(0, 1),
                  centerLabel: 'Conversions',
                  centerValue: '${_int(data.last['value'])}',
                ),
                const SizedBox(height: 12),
                Text(
                  'See where customers progress and where demand drops away.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                ...data.asMap().entries.map((entry) {
                  return _FunnelStageRow(
                    index: entry.key,
                    stage: entry.value,
                    peak: peak,
                    showDivider: entry.key < data.length - 1,
                  );
                }),
              ],
            ),
    );
  }
}

class _FunnelStageRow extends StatelessWidget {
  const _FunnelStageRow({
    required this.index,
    required this.stage,
    required this.peak,
    required this.showDivider,
  });

  final int index;
  final Map<String, dynamic> stage;
  final int peak;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final good = stage['above_average'] == true;
    final color = good ? AppTheme.amber : AppTheme.navyMid;
    final value = _int(stage['value']);
    final progress = peak == 0
        ? 0.0
        : (value / peak).clamp(.04, 1.0).toDouble();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (stage['label'] ?? 'Stage').toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '$value',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: color.withValues(alpha: .1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_num(stage['rate'])}%',
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'avg ${_num(stage['platform_average'])}%',
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: muted.withValues(alpha: .14)),
      ],
    );
  }
}

class _DemandMapCard extends StatefulWidget {
  const _DemandMapCard({required this.zones});
  final List<Map<String, dynamic>> zones;
  @override
  State<_DemandMapCard> createState() => _DemandMapCardState();
}

class _DemandMapCardState extends State<_DemandMapCard> {
  final ScrollController _areaListController = ScrollController();
  Map<String, dynamic>? selected;
  bool _showAreaList = false;
  String _areaQuery = '';

  List<String> _providerNames(Map<String, dynamic> zone) =>
      (zone['provider_names'] as List? ?? const [])
          .map((name) => name.toString().trim())
          .where((name) => name.isNotEmpty)
          .toList();

  Color _zoneColor(Map<String, dynamic> zone) => switch (zone['status']) {
    'green' => Colors.green,
    'red' => Colors.red,
    _ => Colors.amber,
  };

  @override
  void dispose() {
    _areaListController.dispose();
    super.dispose();
  }

  void _openFullMap(
    BuildContext context,
    List<Map<String, dynamic>> zones, {
    Map<String, dynamic>? initialZone,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _DemandMapScreen(zones: zones, initialZone: initialZone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = widget.zones
        .where((z) => z['latitude'] is num && z['longitude'] is num)
        .toList();
    final center = valid.isEmpty
        ? null
        : LatLng(
            (valid.first['latitude'] as num).toDouble(),
            (valid.first['longitude'] as num).toDouble(),
          );
    return _ProCard(
      title: 'Demand by Top Locations',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DemandViewButton(
                    label: 'Map',
                    icon: Icons.map_outlined,
                    selected: !_showAreaList,
                    onTap: () => setState(() {
                      _showAreaList = false;
                    }),
                  ),
                ),
                Expanded(
                  child: _DemandViewButton(
                    label: 'List',
                    icon: Icons.format_list_bulleted_rounded,
                    selected: _showAreaList,
                    onTap: () => setState(() {
                      _showAreaList = true;
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_showAreaList)
            _buildAreaList(context, valid)
          else if (center == null)
            const SizedBox(
              height: 180,
              child: Center(
                child: _Empty(
                  message:
                      'No live provider coverage or customer demand locations yet.',
                ),
              ),
            )
          else
            SizedBox(
              height: 320,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 11,
                      onTap: (_, _) => _openFullMap(context, valid),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.onanet.app',
                      ),
                      CircleLayer(
                        circles: valid.map((z) {
                          final c = _zoneColor(z);
                          return CircleMarker(
                            point: LatLng(
                              (z['latitude'] as num).toDouble(),
                              (z['longitude'] as num).toDouble(),
                            ),
                            radius: math.max(
                              18,
                              ((z['searches'] as num?) ?? 0).toDouble().sqrt(),
                            ),
                            color: c.withValues(alpha: .35),
                            borderColor: c,
                            borderStrokeWidth: 2,
                            useRadiusInMeter: false,
                          );
                        }).toList(),
                      ),
                      MarkerLayer(
                        markers: valid
                            .map(
                              (z) => Marker(
                                point: LatLng(
                                  (z['latitude'] as num).toDouble(),
                                  (z['longitude'] as num).toDouble(),
                                ),
                                width: 44,
                                height: 44,
                                child: GestureDetector(
                                  onTap: () => _openFullMap(
                                    context,
                                    valid,
                                    initialZone: z,
                                  ),
                                  child: const ColoredBox(
                                    color: Colors.transparent,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      elevation: 3,
                      borderRadius: BorderRadius.circular(10),
                      child: TextButton.icon(
                        onPressed: () => _openFullMap(context, valid),
                        icon: const Icon(Icons.fullscreen),
                        label: const Text('Open map'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!_showAreaList) ...[
            const SizedBox(height: 12),
            const Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _DemandLegend(color: Colors.green, label: 'You serve here'),
                _DemandLegend(
                  color: Colors.amber,
                  label: 'You serve here, no leads yet',
                ),
                _DemandLegend(color: Colors.red, label: 'You are not listed'),
              ],
            ),
          ],
          if (!_showAreaList && selected != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _zoneColor(selected!).withValues(alpha: .1),
                border: Border.all(color: _zoneColor(selected!)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected!['area_name']?.toString() ?? 'Coverage area',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_int(selected!['searches'])} searches this month · '
                    '${_int(selected!['providers'])} OnaNet providers',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _providerNames(selected!).isEmpty
                        ? 'No OnaNet provider currently lists this area.'
                        : 'Providers: ${_providerNames(selected!).join(', ')}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    selected!['is_listed'] == true
                        ? 'Your business already covers this area.'
                        : 'Your business is not listed here yet.',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAreaList(
    BuildContext context,
    List<Map<String, dynamic>> valid,
  ) {
    if (valid.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: _Empty(message: 'No provider coverage areas recorded yet.'),
        ),
      );
    }
    final query = _areaQuery.trim().toLowerCase();
    final results = valid.where((zone) {
      if (query.isEmpty) return true;
      final area = zone['area_name']?.toString().toLowerCase() ?? '';
      final providers = _providerNames(zone).join(' ').toLowerCase();
      return area.contains(query) || providers.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (value) => setState(() {
            _areaQuery = value;
          }),
          decoration: InputDecoration(
            hintText: 'Search an area or provider',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixText: '${results.length} areas',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 420,
          child: results.isEmpty
              ? const Center(
                  child: _Empty(message: 'No matching area or provider.'),
                )
              : Scrollbar(
                  controller: _areaListController,
                  thumbVisibility: results.length > 6,
                  child: ListView.separated(
                    controller: _areaListController,
                    primary: false,
                    itemCount: results.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: .14),
                    ),
                    itemBuilder: (context, index) {
                      final zone = results[index];
                      final names = _providerNames(zone);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        onTap: () =>
                            _openFullMap(context, valid, initialZone: zone),
                        leading: Icon(
                          Icons.location_on,
                          color: _zoneColor(zone),
                        ),
                        title: Text(
                          zone['area_name']?.toString() ?? 'Coverage area',
                          softWrap: true,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          names.isEmpty
                              ? 'No OnaNet provider listed'
                              : names.join(', '),
                          softWrap: true,
                        ),
                        trailing: Icon(
                          zone['is_listed'] == true
                              ? Icons.check_circle
                              : Icons.add_location_alt_outlined,
                          color: _zoneColor(zone),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _DemandViewButton extends StatelessWidget {
  const _DemandViewButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? Theme.of(context).colorScheme.surface
        : Colors.transparent,
    borderRadius: BorderRadius.circular(9),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? AppTheme.amber
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DemandMapScreen extends StatefulWidget {
  const _DemandMapScreen({required this.zones, this.initialZone});

  final List<Map<String, dynamic>> zones;
  final Map<String, dynamic>? initialZone;

  @override
  State<_DemandMapScreen> createState() => _DemandMapScreenState();
}

class _DemandMapScreenState extends State<_DemandMapScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  String _query = '';

  List<String> _providerNames(Map<String, dynamic> zone) =>
      (zone['provider_names'] as List? ?? const [])
          .map((name) => name.toString().trim())
          .where((name) => name.isNotEmpty)
          .toList();

  Color _zoneColor(Map<String, dynamic> zone) => switch (zone['status']) {
    'green' => Colors.green,
    'red' => Colors.red,
    _ => Colors.amber,
  };

  LatLng _point(Map<String, dynamic> zone) => LatLng(
    (zone['latitude'] as num).toDouble(),
    (zone['longitude'] as num).toDouble(),
  );

  List<Map<String, dynamic>> get _results {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return widget.zones.where((zone) {
      final area = zone['area_name']?.toString().toLowerCase() ?? '';
      final providers = _providerNames(zone).join(' ').toLowerCase();
      return area.contains(query) || providers.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _focusZone(Map<String, dynamic> zone, {bool showDetails = true}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _query = '';
      _searchController.clear();
    });
    _mapController.move(_point(zone), 14);
    if (showDetails) _showZoneDetails(zone);
  }

  void _zoom(double delta) {
    final camera = _mapController.camera;
    final zoom = (camera.zoom + delta).clamp(3.0, 19.0).toDouble();
    _mapController.move(camera.center, zoom);
  }

  void _showZoneDetails(Map<String, dynamic> zone) {
    final names = _providerNames(zone);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                zone['area_name']?.toString() ?? 'Coverage area',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_int(zone['providers'])} OnaNet providers · '
                '${_int(zone['searches'])} searches this month',
              ),
              const SizedBox(height: 14),
              Text(
                names.isEmpty
                    ? 'No OnaNet provider currently serves this area.'
                    : 'Providers serving this area',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (names.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...names.map(
                  (name) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi_rounded,
                          size: 18,
                          color: _zoneColor(zone),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(name)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                zone['is_listed'] == true
                    ? 'Your provider profile already lists this service area.'
                    : 'Your provider profile does not list this area.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialZone =
        widget.initialZone ??
        (widget.zones.isEmpty ? null : widget.zones.first);
    if (initialZone == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('OnaNet Coverage Map')),
        body: const Center(
          child: _Empty(message: 'No live coverage locations yet.'),
        ),
      );
    }
    final initialCenter = _point(initialZone);
    final results = _results;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'OnaNet Coverage Map',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: widget.initialZone == null ? 11 : 14,
              minZoom: 3,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.onanet.app',
              ),
              CircleLayer(
                circles: widget.zones.map((zone) {
                  final color = _zoneColor(zone);
                  final radiusKm = math.max(1, _d(zone['radius_km']));
                  return CircleMarker(
                    point: _point(zone),
                    radius: radiusKm * 1000,
                    useRadiusInMeter: true,
                    color: color.withValues(alpha: .14),
                    borderColor: color,
                    borderStrokeWidth: 2,
                  );
                }).toList(),
              ),
              MarkerLayer(
                markers: widget.zones.map((zone) {
                  final names = _providerNames(zone);
                  final color = _zoneColor(zone);
                  return Marker(
                    point: _point(zone),
                    width: 190,
                    height: 66,
                    child: GestureDetector(
                      onTap: () => _focusZone(zone),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: .94),
                          border: Border.all(color: color, width: 2),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              zone['area_name']?.toString() ?? 'Coverage area',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              names.isEmpty
                                  ? 'No provider listed'
                                  : names.join(', '),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  elevation: 5,
                  borderRadius: BorderRadius.circular(14),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    onSubmitted: (_) {
                      if (results.isNotEmpty) _focusZone(results.first);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search an area or provider',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  Material(
                    elevation: 5,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: results.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No matching OnaNet coverage area or provider.',
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: results.length,
                              itemBuilder: (context, index) {
                                final zone = results[index];
                                final names = _providerNames(zone);
                                return ListTile(
                                  leading: Icon(
                                    Icons.location_on,
                                    color: _zoneColor(zone),
                                  ),
                                  title: Text(
                                    zone['area_name']?.toString() ??
                                        'Coverage area',
                                  ),
                                  subtitle: Text(
                                    names.isEmpty
                                        ? 'No provider listed'
                                        : names.join(', '),
                                  ),
                                  onTap: () => _focusZone(zone),
                                );
                              },
                            ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 14,
            bottom: 24,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'demand-map-zoom-in',
                  onPressed: () => _zoom(1),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'demand-map-zoom-out',
                  onPressed: () => _zoom(-1),
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemandLegend extends StatelessWidget {
  const _DemandLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 10, color: color),
      const SizedBox(width: 5),
      Text(label),
    ],
  );
}

class _GrowthAreasCard extends StatelessWidget {
  const _GrowthAreasCard({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) => _ProCard(
    title: 'Fastest-Growing Areas',
    child: items.isEmpty
        ? const _Empty(
            message:
                'Growth appears after live searches accumulate across two weekly periods.',
          )
        : Column(
            children: items.indexed.map((entry) {
              final rank = entry.$1 + 1;
              final area = entry.$2;
              final isNew = area['is_new_demand'] == true;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppTheme.amber.withValues(alpha: .15),
                  foregroundColor: AppTheme.amber,
                  child: Text(
                    '$rank',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                title: Text(
                  area['area_name']?.toString() ?? 'Unknown area',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${_int(area['current_searches'])} searches this week · '
                  '${_int(area['previous_searches'])} last week',
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isNew ? 'NEW DEMAND' : '+${_num(area['growth_percent'])}%',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
  );
}

class _CustomerSearchInsightsCard extends StatelessWidget {
  const _CustomerSearchInsightsCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final queries = _maps(data['top_queries']);
    final areas = _maps(data['top_areas']);
    final speeds = _maps(data['top_speeds']);
    final hasDetails =
        queries.isNotEmpty || areas.isNotEmpty || speeds.isNotEmpty;

    return _ProCard(
      title: 'Search Traffic by Top Areas and Needs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _SearchSummaryMetric(
                  value: _int(data['total_searches']).toString(),
                  label: 'Searches in 30 days',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SearchSummaryMetric(
                  value: _int(data['zero_result_searches']).toString(),
                  label: 'Found no provider',
                ),
              ),
            ],
          ),
          if (!hasDetails)
            const _Empty(
              message:
                  'Typed searches, requested speeds, and area demand will appear here live.',
            ),
          if (queries.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SearchInsightSection(
              title: 'Top search phrases',
              icon: Icons.manage_search_rounded,
              items: queries,
              label: (item) => item['query']?.toString() ?? '',
              count: (item) => '${_int(item['searches'])} searches',
            ),
          ],
          if (areas.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SearchInsightSection(
              title: 'Most searched areas',
              icon: Icons.location_on_outlined,
              items: areas,
              label: (item) => item['area_name']?.toString() ?? '',
              count: (item) => '${_int(item['searches'])} searches',
            ),
          ],
          if (speeds.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SearchInsightSection(
              title: 'Most requested speeds',
              icon: Icons.speed_rounded,
              items: speeds,
              label: (item) => '${_int(item['speed_mbps'])} Mbps',
              count: (item) => '${_int(item['searches'])} searches',
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchSummaryMetric extends StatelessWidget {
  const _SearchSummaryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.amber.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.amber.withValues(alpha: .2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        Text(label, softWrap: true),
      ],
    ),
  );
}

class _SearchInsightSection extends StatelessWidget {
  const _SearchInsightSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.label,
    required this.count,
  });

  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) label;
  final String Function(Map<String, dynamic>) count;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      ...items.indexed.map(
        (entry) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.amber.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.amber, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            label(entry.$2),
                            softWrap: true,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          count(entry.$2),
                          softWrap: true,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: (1 - (entry.$1 * .15)).clamp(.2, 1),
                        minHeight: 5,
                        backgroundColor: AppTheme.amber.withValues(alpha: .08),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.amber,
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
    ],
  );
}

extension on double {
  double sqrt() => math.sqrt(this);
}

class _PackageGapsCard extends StatelessWidget {
  const _PackageGapsCard({required this.items});
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) => _ProCard(
    title: 'Package Gap Analysis',
    child: items.isEmpty
        ? const _Empty(message: 'No speed gaps detected yet.')
        : Column(
            children: items
                .map(
                  (x) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.speed, color: AppTheme.amber),
                    title: Text(
                      '${x['speed_filter_mbps']}Mbps searched ${x['searches']} times in ${x['area_name']}',
                    ),
                    subtitle: Text(
                      'You offer: up to ${x['max_speed']}Mbps · '
                      '${x['unmatched_searches']} live searches exceeded that speed',
                    ),
                  ),
                )
                .toList(),
          ),
  );
}

class _PriceBenchmarkCard extends StatelessWidget {
  const _PriceBenchmarkCard({required this.items});
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) => _ProCard(
    title: 'Anonymous Price Benchmarking',
    child: items.isEmpty
        ? const _Empty()
        : Column(
            children: items.map((x) {
              final min = _d(x['min_price']),
                  max = _d(x['max_price']),
                  you = _d(x['your_price']);
              final pos = max > min
                  ? ((you - min) / (max - min)).clamp(0.0, 1.0)
                  : .5;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${x['area_name']} · ${x['speed_mbps']}Mbps · ${x['package_name']}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                      ),
                      child: Slider(value: pos, onChanged: null),
                    ),
                    Text(
                      'KES ${_money(min)} min · ${_money(_d(x['median_price']))} median · ${_money(max)} max   •   You: KES ${_money(you)}',
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
  );
}

class _SearchPositionCard extends StatelessWidget {
  const _SearchPositionCard({required this.items});
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) => _ProCard(
    title: 'Search Position Tracking',
    child: items.isEmpty
        ? const _Empty(
            message: 'Position history will appear as searches accumulate.',
          )
        : SizedBox(
            height: 220,
            child: CustomPaint(painter: _PositionPainter(items)),
          ),
  );
}

class _PositionPainter extends CustomPainter {
  _PositionPainter(this.items);
  final List<Map<String, dynamic>> items;
  @override
  void paint(Canvas c, Size s) {
    final axis = Paint()..color = Colors.grey.withValues(alpha: .35);
    c.drawLine(Offset(28, 8), Offset(28, s.height - 24), axis);
    c.drawLine(
      Offset(28, s.height - 24),
      Offset(s.width - 8, s.height - 24),
      axis,
    );
    if (items.length < 2) return;
    void line(String key, Color color, bool dotted) {
      final p = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = ui.Path();
      for (var i = 0; i < items.length; i++) {
        final v = math.max(1, _d(items[i][key]));
        final x = 28 + (s.width - 40) * i / (items.length - 1);
        final y = 8 + (s.height - 40) * (1 - (1 / v).clamp(0, 1));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      if (dotted) {
        for (final m in path.computeMetrics()) {
          for (double d = 0; d < m.length; d += 8) {
            c.drawLine(
              m.getTangentForOffset(d)!.position,
              m.getTangentForOffset(math.min(d + 4, m.length))!.position,
              p,
            );
          }
        }
      } else {
        c.drawPath(path, p);
      }
    }

    line('your_position', Colors.green, false);
    line('platform_position', Colors.grey, true);
  }

  @override
  bool shouldRepaint(covariant _PositionPainter old) => old.items != items;
}

class _RevenueForecastCard extends StatelessWidget {
  const _RevenueForecastCard({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => _ProCard(
    title: 'Revenue Forecast',
    child: Wrap(
      spacing: 24,
      runSpacing: 12,
      children: [
        _Metric(
          label: 'If all current leads complete',
          value: 'KES ${_money(data['pipeline'])}',
        ),
        _Metric(
          label: 'Based on your trend next month',
          value: '~KES ${_money(data['trend_forecast'])}',
        ),
      ],
    ),
  );
}

class _LtvCard extends StatelessWidget {
  const _LtvCard({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => _ProCard(
    title: 'Customer Lifetime Value',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KES ${_money(data['value'])}',
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
        ),
        Text(
          '${_num(data['months'])} average months × KES ${_money(data['average_price'])} average package',
        ),
        const SizedBox(height: 8),
        Text(
          'If average retention improves by 1 month: +KES ${_money(data['one_month_annual_lift'])} annual revenue',
        ),
      ],
    ),
  );
}

class _MarketShareCard extends StatelessWidget {
  const _MarketShareCard({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => _ProCard(
    title: 'Market Share Indicator',
    child: Row(
      children: [
        SizedBox.square(
          dimension: 118,
          child: CustomPaint(
            painter: _ShareRingPainter(_d(data['overall'])),
            child: Center(
              child: Text(
                '${_num(data['overall'])}%',
                textAlign: TextAlign.center,
                softWrap: true,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.amber,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        const Expanded(
          child: Text(
            'Estimated share of tracked installations in your coverage areas',
          ),
        ),
      ],
    ),
  );
}

class _ShareRingPainter extends CustomPainter {
  const _ShareRingPainter(this.percent);

  final double percent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 9;
    final track = Paint()
      ..color = AppTheme.amber.withValues(alpha: .10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13;
    final value = Paint()
      ..shader = const SweepGradient(
        colors: [AppTheme.amber, AppTheme.navyMid],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 13;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * (percent / 100).clamp(0, 1),
      false,
      value,
    );
  }

  @override
  bool shouldRepaint(covariant _ShareRingPainter oldDelegate) =>
      oldDelegate.percent != percent;
}

class _ZoneShareCard extends StatelessWidget {
  const _ZoneShareCard({required this.items});
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) => _ProCard(
    title: 'Market Share by Zone',
    child: items.isEmpty
        ? const _Empty()
        : Column(
            children: items.map((x) {
              final share = _d(x['share']).clamp(0, 100);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            x['area_name'].toString(),
                            softWrap: true,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '~${_num(x['share'])}%',
                          style: const TextStyle(
                            color: AppTheme.amber,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: share / 100,
                        minHeight: 7,
                        backgroundColor: AppTheme.amber.withValues(alpha: .08),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
  );
}

class _ExportsCard extends StatelessWidget {
  const _ExportsCard({required this.data, required this.service});
  final Map<String, dynamic> data;
  final ProAnalyticsService service;
  @override
  Widget build(BuildContext context) => _ProCard(
    title: 'Exportable Reports',
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: () => service.exportMonthlyPdf(data),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Monthly Business PDF'),
        ),
        OutlinedButton.icon(
          onPressed: () => service.exportLeadsCsv(data),
          icon: const Icon(Icons.table_view),
          label: const Text('Lead CSV'),
        ),
        OutlinedButton.icon(
          onPressed: () => service.exportRevenueCsv(data),
          icon: const Icon(Icons.payments),
          label: const Text('Revenue CSV'),
        ),
        OutlinedButton.icon(
          onPressed: () => service.exportInstallersCsv(data),
          icon: const Icon(Icons.engineering),
          label: const Text('Installer CSV'),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.amber.withValues(alpha: dark ? .08 : .06),
        border: Border.all(color: AppTheme.amber.withValues(alpha: .18)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({this.message = 'No data recorded yet.'});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

List<Map<String, dynamic>> _maps(dynamic v) => (v as List? ?? const [])
    .whereType<Map>()
    .map((x) => Map<String, dynamic>.from(x))
    .toList();
Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : {};
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
String _num(dynamic v) => _d(v).toStringAsFixed(1);
String _money(dynamic v) => _d(v).toStringAsFixed(0);
int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
