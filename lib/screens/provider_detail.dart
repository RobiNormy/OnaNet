import 'package:flutter/material.dart';
import 'package:ona_net/auth/package_service.dart';
import 'package:ona_net/screens/installation_request.dart';
import 'package:ona_net/themes/app_theme.dart';

class ProviderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> provider;

  const ProviderDetailScreen({super.key, required this.provider});

  @override
  State<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen> {
  int? _selectedPackageIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = widget.provider;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: isDark ? AppTheme.navyMid : AppTheme.navy,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.ios_share_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () {},
                    ),
                  ),
                ],
                title: Text(
                  provider['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _HeroSection(provider: provider),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      _CoverageChips(
                        areas: List<String>.from(
                          provider['coverageAreas'] ?? [],
                        ),
                      ),

                      const SizedBox(height: 24),

                      const _SectionHeader(title: 'Available Packages'),
                      const SizedBox(height: 12),
                      _ProviderPackagesList(
                        provider: provider,
                        selectedIndex: _selectedPackageIndex,
                        onSelected: (index, package) {
                          setState(() => _selectedPackageIndex = index);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PackageDetailScreen(
                                provider: provider,
                                package: package,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      const _SectionHeader(title: 'Reviews'),
                      const SizedBox(height: 12),
                      if ((provider['reviews']?.toString() ?? '0') == '0')
                        Text(
                          'No reviews yet for this provider.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.gray),
                        )
                      else
                        // ..._dummyReviews.map((r) => _ReviewCard(review: r)),
                        const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _StickyBottomBar(providerName: provider['name']),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final Map<String, dynamic> provider;
  const _HeroSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final logoUrl = (provider['logoUrl'] ?? provider['logo_url'])?.toString();
    final logoScale =
        _asDouble(provider['logoScale'] ?? provider['logo_display_size']) ??
        1.0;
    final logoOffset = Offset(
      _asDouble(provider['logoOffsetX'] ?? provider['logo_offset_x']) ?? 0,
      _asDouble(provider['logoOffsetY'] ?? provider['logo_offset_y']) ?? 0,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A2540),
            Color(provider['color']).withValues(alpha: 0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            _ProviderLogoMark(
              logoUrl: logoUrl,
              logoScale: logoScale,
              logoOffset: logoOffset,
              color: Color(provider['color'] ?? 0xFF0D1B2A),
              initials: (provider['initials'] ?? provider['name']?[0] ?? 'ON')
                  .toString(),
              size: 80,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 3,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  (provider['name'] ?? provider['business_name'] ?? 'Provider')
                      .toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppTheme.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 11),
                ),
              ],
            ),

            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded, color: AppTheme.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${provider['rating']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${provider['reviews']} reviews)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class _ProviderLogoMark extends StatelessWidget {
  const _ProviderLogoMark({
    required this.logoUrl,
    required this.logoScale,
    required this.logoOffset,
    required this.color,
    required this.initials,
    required this.size,
    this.border,
  });

  final String? logoUrl;
  final double logoScale;
  final Offset logoOffset;
  final Color color;
  final String initials;
  final double size;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    final displayScale = logoScale.clamp(1.0, 3.0);
    final displayOffset = Offset(
      logoOffset.dx * size / 280,
      logoOffset.dy * size / 280,
    );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? _LogoInitials(initials: initials, size: size)
          : Transform(
              transform: Matrix4.identity()
                ..translate(displayOffset.dx, displayOffset.dy, 0)
                ..scale(displayScale, displayScale, displayScale),
              child: Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _LogoInitials(initials: initials, size: size),
              ),
            ),
    );
  }
}

class _LogoInitials extends StatelessWidget {
  const _LogoInitials({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      initials,
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.35,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _CoverageChips extends StatelessWidget {
  final List<String> areas;
  const _CoverageChips({required this.areas});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: areas.map((area) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.navyMid : AppTheme.offWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 12,
                color: AppTheme.gray,
              ),
              const SizedBox(width: 4),
              Text(
                area,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isDark ? AppTheme.lightGray : AppTheme.darkGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> package;
  final bool isSelected;
  final VoidCallback onTap;
  const _PackageCard({
    required this.package,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPopular = package['popular'] as bool;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.amber.withValues(alpha: isDark ? 0.16 : 0.12)
              : isDark
              ? AppTheme.navyMid
              : AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.amber
                : isDark
                ? AppTheme.navyLight
                : AppTheme.lightGray,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: AppTheme.navy.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Package info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                package['name'],
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),

                            if (isSelected) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppTheme.amber,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          package['speed'],
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.gray,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          package['contract'],
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppTheme.gray),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'KES ${package['price']}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppTheme.offWhite
                                    : AppTheme.navy,
                              ),
                            ),
                            TextSpan(
                              text: '/mo',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.gray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isSelected
                            ? AppTheme.amber
                            : isDark
                            ? AppTheme.gray
                            : AppTheme.darkGray,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (isPopular)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: AppTheme.amber,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(
                      color: AppTheme.navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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

class PackageDetailScreen extends StatelessWidget {
  final Map<String, dynamic> provider;
  final Map<String, dynamic> package;

  const PackageDetailScreen({
    super.key,
    required this.provider,
    required this.package,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // final reviews = _dummyReviews
    //     .where((review) => review['packageName'] == package['name'])
    //     .toList();
    final coverageAreas = List<String>.from(
      provider['coverageAreas'] ??
          package['coverageAreas'] ??
          ['Westlands', 'Kilimani', 'Lavington'],
    );
    final mainIspProvider =
        (provider['mainIspProvider'] ?? provider['upstream_provider'])
            ?.toString()
            .trim();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.navyMid : AppTheme.white,
        elevation: 0,
        title: Text(
          package['name']?.toString() ?? 'Package Details',
          style: TextStyle(
            color: isDark ? AppTheme.white : AppTheme.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? AppTheme.white : AppTheme.navy,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: _PackageBottomBar(
        provider: provider,
        package: package,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PackageTrustHeader(provider: provider, package: package),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (package['trustLabel'] != null)
                  _TrustChip(
                    icon: Icons.trending_up_rounded,
                    label: package['trustLabel'].toString(),
                  ),
                if (package['subscriberCount'] != null)
                  _TrustChip(
                    icon: Icons.groups_rounded,
                    label: package['subscriberCount'].toString(),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionHeader(title: 'Package Details'),
            const SizedBox(height: 12),
            _PackageInfoCard(
              rows: [
                _PackageInfoRowData('Speed', '${package['speed']}'),
                _PackageInfoRowData(
                  'Main ISP Provider',
                  mainIspProvider == null || mainIspProvider.isEmpty
                      ? 'Not specified'
                      : mainIspProvider,
                ),
                _PackageInfoRowData(
                  'Monthly Price',
                  'KES ${package['price']}/mo',
                ),
                _PackageInfoRowData(
                  'Installation Fee',
                  'KES ${package['installationFee']}',
                ),
                _PackageInfoRowData(
                  'Contract Duration',
                  package['contract']?.toString() ?? 'No contract',
                ),
                _PackageInfoRowData(
                  'Fair Usage Policy',
                  package['fairUsage']?.toString() ?? 'None',
                ),
                _PackageInfoRowData(
                  'Router Included',
                  package['routerIncluded'] == true ? 'Yes' : 'No',
                ),
                _PackageInfoRowData(
                  'Expected Installation',
                  '${package['installationTime']}',
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionHeader(title: 'Coverage Areas'),
            const SizedBox(height: 12),
            _CoverageChips(areas: coverageAreas),
            const SizedBox(height: 22),
            _SectionHeader(title: 'Reviews for ${package['name']}'),
            const SizedBox(height: 12),
            // if (reviews.isEmpty)
            //   Text(
            //     'No reviews yet for this package.',
            //     style: Theme.of(
            //       context,
            //     ).textTheme.bodySmall?.copyWith(color: AppTheme.gray),
            //   )
            // else
            //   ...reviews.map((review) => _ReviewCard(review: review)),
          ],
        ),
      ),
    );
  }
}

class _PackageTrustHeader extends StatelessWidget {
  final Map<String, dynamic> provider;
  final Map<String, dynamic> package;

  const _PackageTrustHeader({required this.provider, required this.package});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoUrl = (provider['logoUrl'] ?? provider['logo_url'])?.toString();
    final logoScale =
        _asDouble(provider['logoScale'] ?? provider['logo_display_size']) ??
        1.0;
    final logoOffset = Offset(
      _asDouble(provider['logoOffsetX'] ?? provider['logo_offset_x']) ?? 0,
      _asDouble(provider['logoOffsetY'] ?? provider['logo_offset_y']) ?? 0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
      ),
      child: Row(
        children: [
          _ProviderLogoMark(
            logoUrl: logoUrl,
            logoScale: logoScale,
            logoOffset: logoOffset,
            color: Color(provider['color'] ?? 0xFF0D1B2A),
            initials: (provider['initials'] ?? provider['name']?[0] ?? 'ON')
                .toString(),
            size: 56,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (provider['name'] ?? provider['business_name'] ?? 'Provider')
                      .toString(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  package['name']?.toString() ?? 'Package',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.amber,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${package['speed'] ?? ''} • KES ${package['price'] ?? ''}/mo',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppTheme.gray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class _TrustChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.amber.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.amber, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isDark ? AppTheme.offWhite : AppTheme.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageInfoRowData {
  final String label;
  final String value;

  const _PackageInfoRowData(this.label, this.value);
}

class _PackageInfoCard extends StatelessWidget {
  final List<_PackageInfoRowData> rows;

  const _PackageInfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final row = entry.value;
          final isLast = entry.key == rows.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
                      ),
                    ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: AppTheme.gray),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.value,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.offWhite : AppTheme.navy,
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
}

class _PackageBottomBar extends StatelessWidget {
  final Map<String, dynamic> provider;
  final Map<String, dynamic> package;

  const _PackageBottomBar({required this.provider, required this.package});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _BottomActionButton(
              label: 'Request Installation',
              color: AppTheme.amber,
              textColor: AppTheme.navy,
              icon: Icons.handyman_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InstallationRequestScreen(
                      provider: provider,
                      package: package,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BottomActionButton(
              label: 'Chat on WhatsApp',
              color: const Color(0xFF25D366),
              textColor: Colors.white,
              imageAsset: 'lib/images/whatsapp.webp',
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final String? imageAsset;
  final VoidCallback onTap;

  const _BottomActionButton({
    required this.label,
    required this.color,
    required this.textColor,
    this.icon,
    this.imageAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imageAsset != null)
              Image.asset(imageAsset!, width: 18, height: 18)
            else
              Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyBottomBar extends StatelessWidget {
  final String providerName;
  const _StickyBottomBar({required this.providerName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'lib/images/whatsapp.webp',
                      width: 18,
                      height: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'WhatsApp',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.navy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Request Callback',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderPackagesList extends StatefulWidget {
  final Map<String, dynamic> provider;
  final int? selectedIndex;
  final void Function(int index, Map<String, dynamic> package) onSelected;

  const _ProviderPackagesList({
    required this.provider,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  State<_ProviderPackagesList> createState() => _ProviderPackagesListState();
}

class _ProviderPackagesListState extends State<_ProviderPackagesList> {
  late Future<List<ProviderPackage>> _packagesFuture;
  @override
  void initState() {
    super.initState();
    _packagesFuture = ProviderPackageService().listForProvider(
      widget.provider['id'] as String,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _packagesFuture = ProviderPackageService().listForProvider(
        widget.provider['id'] as String,
      );
    });
  }

  Widget _buildPackagesList(List<Map<String, dynamic>> packagesList) {
    return Column(
      children: packagesList.asMap().entries.map((entry) {
        return _PackageCard(
          package: entry.value,
          isSelected: entry.key == widget.selectedIndex,
          onTap: () => widget.onSelected(entry.key, entry.value),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProviderPackage>>(
      future: _packagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text('Could not load packages: ${snapshot.error}'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        final packages = snapshot.data ?? const [];
        if (packages.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text('This provider has no packages yet.'),
          );
        }
        final uiMaps = packages.map((p) => p.toUiMap()).toList();
        return _buildPackagesList(uiMaps);
      },
    );
  }
}
