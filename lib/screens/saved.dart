import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/screens/provider_detail.dart';
import 'package:ona_net/services/saved_providers_store.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:ona_net/utils/provider_filters.dart';
import 'package:ona_net/widgets/provider_badges.dart';
import 'package:provider/provider.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SavedProvidersStore>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final providers = store.providers;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
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
                      'Saved Providers',
                      style: GoogleFonts.plusJakartaSans(
                        color: isDark ? AppTheme.white : AppTheme.navy,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Keep providers here while you compare packages.',
                      style: GoogleFonts.urbanist(
                        color: AppTheme.gray,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!store.isLoaded)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.amber),
                ),
              )
            else if (providers.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _SavedEmptyState(isDark: isDark),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                sliver: SliverList.separated(
                  itemCount: providers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final provider = providers[index];
                    return _SavedProviderCard(
                      provider: provider,
                      onOpen: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProviderDetailScreen(provider: provider),
                          ),
                        );
                      },
                      onRemove: () => store.remove(provider),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SavedProviderCard extends StatelessWidget {
  const _SavedProviderCard({
    required this.provider,
    required this.onOpen,
    required this.onRemove,
  });

  final Map<String, dynamic> provider;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedColor = isDark ? AppTheme.gray : AppTheme.darkGray;
    final name = _providerName(provider);
    final areas = _coverageAreas(provider);

    return InkWell(
      onTap: onOpen,
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
                    ],
                  ),
                  ProviderBadges(provider: provider),
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
                      _ProviderMeta(
                        label: 'From',
                        value: 'KES ${_price(provider)}',
                      ),
                      _ProviderMeta(
                        label: 'Speed',
                        value: '${_speed(provider)}Mbps',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Remove saved provider',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(width: 34, height: 34),
              onPressed: onRemove,
              icon: const Icon(
                Icons.bookmark_rounded,
                color: AppTheme.amber,
                size: 20,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.amber),
          ],
        ),
      ),
    );
  }
}

class _SavedEmptyState extends StatelessWidget {
  const _SavedEmptyState({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.bookmark_border_rounded,
              color: AppTheme.amber,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No saved providers yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? AppTheme.offWhite : AppTheme.navy,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the bookmark on a provider to keep it here for later.',
            textAlign: TextAlign.center,
            style: GoogleFonts.urbanist(
              color: AppTheme.gray,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
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

String _providerName(Map<String, dynamic> provider) {
  return (provider['name'] ??
          provider['provider_name'] ??
          provider['business_name'] ??
          'OnaNet Provider')
      .toString();
}

String _providerType(Map<String, dynamic> provider) {
  return humanizeBackendValue(
    (provider['providerType'] ??
            provider['provider_type'] ??
            provider['service_type'] ??
            'Internet provider')
        .toString(),
  );
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

int _speed(Map<String, dynamic> provider) {
  final value =
      provider['speed'] ?? provider['maxSpeed'] ?? provider['speed_mbps'];
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int _price(Map<String, dynamic> provider) {
  final value =
      provider['price'] ??
      provider['startingPrice'] ??
      provider['monthly_price'];
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
