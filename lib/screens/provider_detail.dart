import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ona_net/auth/package_service.dart';
import 'package:ona_net/screens/installation_request.dart';
import 'package:ona_net/screens/login.dart';
import 'package:ona_net/services/saved_providers_store.dart';
import 'package:ona_net/services/pro_analytics_service.dart';
import 'package:ona_net/services/provider_share_link.dart';
import 'package:ona_net/themes/app_theme.dart';
import 'package:ona_net/widgets/provider_badges.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class ProviderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> provider;
  final String? selectedArea;

  const ProviderDetailScreen({
    super.key,
    required this.provider,
    this.selectedArea,
  });

  @override
  State<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen> {
  int? _selectedPackageIndex;

  Future<void> _shareProvider(BuildContext shareContext) async {
    final provider = widget.provider;
    final name =
        (provider['name'] ?? provider['business_name'] ?? 'this provider')
            .toString();
    final providerId = provider['id']?.toString().trim() ?? '';
    if (providerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This provider cannot be shared yet.')),
      );
      return;
    }
    final link = providerShareLink(providerId);

    final renderBox = shareContext.findRenderObject();
    final shareOrigin = renderBox is RenderBox && renderBox.hasSize
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : null;

    try {
      await SharePlus.instance.share(
        ShareParams(
          uri: link,
          title: 'Share $name',
          subject: '$name on Ona Net',
          sharePositionOrigin: shareOrigin,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open sharing options.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final providerId = widget.provider['id']?.toString();
    if (providerId != null && providerId.isNotEmpty) {
      ProAnalyticsService().logView(
        providerId: providerId,
        viewType: 'profile',
        area: widget.selectedArea,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = widget.provider;
    final customerReviews = _providerCustomerReviews(provider);
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
                  Consumer<SavedProvidersStore>(
                    builder: (context, savedProviders, _) {
                      final isSaved = savedProviders.isSaved(provider);
                      return Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          tooltip: isSaved
                              ? 'Remove saved provider'
                              : 'Save provider',
                          icon: Icon(
                            isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: isSaved ? AppTheme.amber : Colors.white,
                            size: 20,
                          ),
                          onPressed: () => savedProviders.toggle(provider),
                        ),
                      );
                    },
                  ),
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Builder(
                      builder: (shareContext) => IconButton(
                        tooltip: 'Share provider',
                        icon: const Icon(
                          Icons.ios_share_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () => _shareProvider(shareContext),
                      ),
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
                          final providerId = provider['id']?.toString();
                          if (providerId != null && providerId.isNotEmpty) {
                            ProAnalyticsService().logView(
                              providerId: providerId,
                              viewType: 'package',
                              area: widget.selectedArea,
                              packageId: package['id']?.toString(),
                            );
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PackageDetailScreen(
                                provider: provider,
                                package: package,
                                selectedArea: widget.selectedArea,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      const _SectionHeader(title: 'Reviews'),
                      const SizedBox(height: 12),
                      if (customerReviews.isEmpty)
                        Text(
                          'No reviews yet for this provider.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.gray),
                        )
                      else
                        ...customerReviews.map(
                          (review) => _CustomerReviewCard(review: review),
                        ),
                    ],
                  ),
                ),
              ),
            ],
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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                (provider['name'] ?? provider['business_name'] ?? 'Provider')
                    .toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            ProviderBadges(provider: provider, center: true),
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

    final logo = url == null || url.isEmpty
        ? _LogoInitials(initials: initials, size: size)
        : Transform(
            transform: Matrix4.identity()
              ..translateByDouble(displayOffset.dx, displayOffset.dy, 0, 1)
              ..scaleByDouble(displayScale, displayScale, displayScale, 1),
            child: Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _LogoInitials(initials: initials, size: size),
            ),
          );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(
            child: ColoredBox(
              color: color,
              child: Center(child: logo),
            ),
          ),
          if (border != null)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: border,
                ),
              ),
            ),
        ],
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

List<Map<String, dynamic>> _providerCustomerReviews(
  Map<String, dynamic> provider,
) {
  final value =
      provider['customerReviews'] ??
      provider['customer_reviews'] ??
      provider['recent_reviews'];
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((review) {
        return review.map((key, value) => MapEntry(key.toString(), value));
      })
      .toList(growable: false);
}

class _CustomerReviewCard extends StatelessWidget {
  const _CustomerReviewCard({required this.review});

  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final muted = isDark ? AppTheme.gray : AppTheme.darkGray;
    final name =
        (review['customer_name'] ?? review['customerName'] ?? 'OnaNet customer')
            .toString();
    final packageName =
        (review['package_name'] ?? review['packageName'] ?? 'Internet package')
            .toString();
    final rating = int.tryParse((review['rating'] ?? '0').toString()) ?? 0;
    final comment = (review['comment'] ?? '').toString().trim();
    final updatedAt = DateTime.tryParse(
      (review['updated_at'] ?? review['updatedAt'] ?? '').toString(),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: AppTheme.amber.withValues(alpha: 0.16),
                child: Text(
                  name.trim().isEmpty ? 'O' : name.trim()[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.amberDark,
                    fontWeight: FontWeight.w900,
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
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$packageName${updatedAt == null ? '' : ' · ${_shortReviewDate(updatedAt.toLocal())}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.amber.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppTheme.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$rating/5',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(comment, style: TextStyle(color: textColor, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

String _shortReviewDate(DateTime value) {
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
    final isPopular = package['popular'] == true;
    final topArea = (package['topArea'] ?? package['top_area'])
        ?.toString()
        .trim();

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
                        if (topArea != null && topArea.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Most installed in $topArea',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppTheme.green,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
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
                    'MOST POPULAR',
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
  final String? selectedArea;

  const PackageDetailScreen({
    super.key,
    required this.provider,
    required this.package,
    this.selectedArea,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reviews = _providerCustomerReviews(provider)
        .where(
          (review) =>
              (review['package_name'] ?? review['packageName'])?.toString() ==
              package['name']?.toString(),
        )
        .toList(growable: false);
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
                if (package['popular'] == true)
                  const _TrustChip(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Most popular',
                  ),
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
            _PackagePopularityCard(package: package, userArea: selectedArea),
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
            if (reviews.isEmpty)
              Text(
                'No reviews yet for this package.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.gray),
              )
            else
              ...reviews.map((review) => _CustomerReviewCard(review: review)),
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

class _PackagePopularityCard extends StatelessWidget {
  const _PackagePopularityCard({required this.package, required this.userArea});

  final Map<String, dynamic> package;
  final String? userArea;

  @override
  Widget build(BuildContext context) {
    final areas = _popularityAreas(package);
    final topArea = (package['topArea'] ?? package['top_area'])
        ?.toString()
        .trim();
    final userMatch = _areaForUser(areas, userArea);
    final topInstalls = areas.isEmpty
        ? 0
        : areas
              .map((area) => _asInt(area['installs']))
              .reduce((a, b) => a > b ? a : b);
    final userInstalls = userMatch == null ? 0 : _asInt(userMatch['installs']);
    final level = _popularityLevel(userInstalls, topInstalls);
    final levelColor = switch (level) {
      'popular' => AppTheme.green,
      'mid' => AppTheme.amber,
      _ => AppTheme.gray,
    };
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final mutedColor = AppTheme.gray;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  color: levelColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _levelTitle(level),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      topArea == null || topArea.isEmpty
                          ? 'No completed installs tracked yet'
                          : 'Most installed in $topArea',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            userArea?.trim().isNotEmpty == true
                ? '${_capitalize(level)} in ${userArea!.trim()}'
                : 'Enable location to compare your area',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: levelColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (areas.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...areas
                .take(5)
                .map(
                  (area) => _PopularityBar(
                    area: area['area']?.toString() ?? 'Area',
                    installs: _asInt(area['installs']),
                    maxInstalls: topInstalls,
                    highlighted:
                        _normalize(area['area']) == _normalize(userArea),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  static List<Map<String, dynamic>> _popularityAreas(
    Map<String, dynamic> package,
  ) {
    final value = package['popularityByArea'] ?? package['popularity_by_area'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (area) => area.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }

  static Map<String, dynamic>? _areaForUser(
    List<Map<String, dynamic>> areas,
    String? userArea,
  ) {
    final normalizedUserArea = _normalize(userArea);
    if (normalizedUserArea.isEmpty) return null;
    for (final area in areas) {
      final normalizedArea = _normalize(area['area']);
      if (normalizedArea.contains(normalizedUserArea) ||
          normalizedUserArea.contains(normalizedArea)) {
        return area;
      }
    }
    return null;
  }

  static int _asInt(Object? value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _normalize(Object? value) {
    return (value ?? '')
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _popularityLevel(int installs, int topInstalls) {
    if (installs <= 0) return 'low';
    if (topInstalls <= 1) return 'popular';
    final ratio = installs / topInstalls;
    if (installs >= 3 || ratio >= .66) return 'popular';
    if (installs >= 1 || ratio >= .33) return 'mid';
    return 'low';
  }

  static String _levelTitle(String level) {
    return switch (level) {
      'popular' => 'Popular package',
      'mid' => 'Growing demand',
      _ => 'Low demand here',
    };
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class _PopularityBar extends StatelessWidget {
  const _PopularityBar({
    required this.area,
    required this.installs,
    required this.maxInstalls,
    required this.highlighted,
  });

  final String area;
  final int installs;
  final int maxInstalls;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final ratio = maxInstalls <= 0 ? 0.0 : installs / maxInstalls;
    final color = highlighted ? AppTheme.amber : AppTheme.green;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  area,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.offWhite : AppTheme.navy,
                  ),
                ),
              ),
              Text(
                '$installs installs',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.gray,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: ratio.clamp(0.04, 1),
              backgroundColor: isDark ? AppTheme.navy : AppTheme.offWhite,
              valueColor: AlwaysStoppedAnimation<Color>(color),
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
              onTap: () async {
                if (FirebaseAuth.instance.currentUser == null) {
                  final signIn = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Account required'),
                      content: const Text(
                        'Sign in or create an account before requesting an installation.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Sign in'),
                        ),
                      ],
                    ),
                  );
                  if (signIn == true && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const Login()),
                    );
                  }
                  return;
                }
                if (!context.mounted) return;
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
        ],
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData icon;
  final VoidCallback onTap;

  const _BottomActionButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.icon,
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
    final embeddedPackages = (widget.provider['packages'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => ProviderPackage.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((package) => package.id.isNotEmpty)
        .toList(growable: false);
    _packagesFuture = embeddedPackages.isNotEmpty
        ? Future.value(embeddedPackages)
        : ProviderPackageService().listForProvider(
            widget.provider['id'].toString(),
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
