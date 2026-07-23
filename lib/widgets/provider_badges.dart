import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/utils/provider_filters.dart';

class ProviderBadges extends StatelessWidget {
  const ProviderBadges({
    super.key,
    required this.provider,
    this.center = false,
  });

  final Map<String, dynamic> provider;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final verified = isVerifiedProvider(provider);
    final tier = providerPlanTier(provider);
    if (!verified && tier == 'free') return const SizedBox.shrink();

    return Wrap(
      alignment: center ? WrapAlignment.center : WrapAlignment.start,
      spacing: 6,
      runSpacing: 6,
      children: [
        if (verified)
          const _ProviderBadge(
            label: 'Verified',
            icon: Icons.verified_rounded,
            color: Color(0xFF2563EB),
          ),
        if (tier == 'growth')
          const _ProviderBadge(
            label: 'Growth',
            icon: Icons.trending_up_rounded,
            color: Color(0xFFD97706),
          ),
        if (tier == 'pro')
          const _ProviderBadge(
            label: 'Pro',
            icon: Icons.workspace_premium_rounded,
            color: Color(0xFF7C3AED),
          ),
      ],
    );
  }
}

class _ProviderBadge extends StatelessWidget {
  const _ProviderBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
