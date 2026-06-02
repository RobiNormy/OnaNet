import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/provider/coverage_areas.dart';
import 'package:ona_net/provider/provider_flow_widgets.dart';
import 'package:ona_net/provider/provider_registration_data.dart';
import 'package:ona_net/themes/app_theme.dart';

class ServicesOfferedScreen extends StatefulWidget {
  const ServicesOfferedScreen({
    super.key,
    required this.providerKind,
    required this.draft,
  });

  final ProviderKind providerKind;
  final ProviderRegistrationDraft draft;

  @override
  State<ServicesOfferedScreen> createState() => _ServicesOfferedScreenState();
}

class _ServicesOfferedScreenState extends State<ServicesOfferedScreen> {
  final Set<String> _selectedServiceTypes = {'home_fiber', 'wireless_home'};

  @override
  Widget build(BuildContext context) {
    return ProviderFlowShell(
      title: widget.providerKind.registrationTitle,
      icon: widget.providerKind.icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StepProgressHeader(currentStep: 3),
          const SizedBox(height: 28),
          const ProviderSectionTitle(
            title: 'Services Offered',
            subtitle:
                'Select all the internet services your business provides.',
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 430;
              final cardWidth = isWide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _serviceOptions.map((service) {
                  return SizedBox(
                    width: cardWidth,
                    child: _ServiceCard(
                      service: service,
                      isSelected: _selectedServiceTypes.contains(service.id),
                      onTap: () {
                        setState(() {
                          if (_selectedServiceTypes.contains(service.id)) {
                            _selectedServiceTypes.remove(service.id);
                          } else {
                            _selectedServiceTypes.add(service.id);
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 34),
          ProviderPrimaryButton(
            label: 'Continue',
            onPressed: () {
              if (_selectedServiceTypes.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Select at least one service.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              final draft = widget.draft.copyWith(
                serviceTypes: _selectedServiceTypes.toList(),
              );

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CoverageAreasScreen(
                    providerKind: widget.providerKind,
                    draft: draft,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const SecureFooter(),
        ],
      ),
    );
  }
}

class _ServiceOption {
  const _ServiceOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
}

const _serviceOptions = [
  _ServiceOption(
    id: 'home_fiber',
    title: 'Home Fiber',
    subtitle: 'Fiber internet installed to homes.',
    icon: Icons.home_outlined,
    tint: AppTheme.amber,
  ),
  _ServiceOption(
    id: 'wireless_home',
    title: 'Wireless Home Internet',
    subtitle: 'Internet delivered using wireless technology.',
    icon: Icons.cell_tower_rounded,
    tint: AppTheme.amber,
  ),
  _ServiceOption(
    id: 'shared_wifi',
    title: 'Shared WiFi',
    subtitle: 'Shared internet for apartments, plots, or managed buildings.',
    icon: Icons.apartment_rounded,
    tint: Color(0xFF7C3AED),
  ),
  _ServiceOption(
    id: 'business',
    title: 'Business Internet',
    subtitle: 'Internet solutions for businesses and offices.',
    icon: Icons.business_center_outlined,
    tint: Color(0xFF2563EB),
  ),
  _ServiceOption(
    id: 'hotspot',
    title: 'Hotspot WiFi',
    subtitle: 'Public WiFi access with vouchers or time plans.',
    icon: Icons.wifi_tethering_rounded,
    tint: Color(0xFFFF6B4A),
  ),
  _ServiceOption(
    id: 'satellite',
    title: 'Satellite Internet',
    subtitle: 'Internet provided via satellite technology.',
    icon: Icons.satellite_alt_rounded,
    tint: Color(0xFF16A34A),
  ),
];

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.isSelected,
    required this.onTap,
  });

  final _ServiceOption service;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final borderColor = isSelected
        ? AppTheme.amber
        : isDark
        ? AppTheme.navyLight
        : AppTheme.lightGray;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 142),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.navyMid : AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: service.tint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(service.icon, color: service.tint, size: 25),
                ),
                const SizedBox(height: 14),
                Text(
                  service.title,
                  style: GoogleFonts.plusJakartaSans(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  service.subtitle,
                  style: GoogleFonts.urbanist(
                    color: isDark ? AppTheme.gray : AppTheme.darkGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Icon(
                isSelected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: isSelected ? AppTheme.amber : AppTheme.gray,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
