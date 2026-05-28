import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/provider/packages.dart';
import 'package:ona_net/provider/provider_flow_widgets.dart';
import 'package:ona_net/provider/provider_registration_data.dart';
import 'package:ona_net/themes/app_theme.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key, required this.providerKind});

  final ProviderKind providerKind;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _hasLicense = true;
  bool _hasBusinessDocs = true;

  @override
  Widget build(BuildContext context) {
    return ProviderFlowShell(
      title: widget.providerKind.registrationTitle,
      icon: widget.providerKind.icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepProgressHeader(currentStep: 6),
          SizedBox(height: 28),
          ProviderSectionTitle(
            title: 'Verification',
            subtitle:
                'Confirm the documents you can provide before your profile goes live.',
          ),
          SizedBox(height: 22),
          _CheckRow(
            title: 'Business registration documents',
            value: _hasBusinessDocs,
            onChanged: (value) => setState(() => _hasBusinessDocs = value),
          ),
          _CheckRow(
            title: widget.providerKind.id == 'licensed_isp'
                ? 'Communications license'
                : 'Service ownership or reseller proof',
            value: _hasLicense,
            onChanged: (value) => setState(() => _hasLicense = value),
          ),
          const SizedBox(height: 42),
          ProviderPrimaryButton(
            label: 'Continue',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PackagesScreen(providerKind: widget.providerKind),
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

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CheckboxListTile(
        value: value,
        onChanged: (next) => onChanged(next ?? false),
        activeColor: AppTheme.amber,
        checkColor: AppTheme.navy,
        tileColor: isDark ? AppTheme.navyMid : AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? AppTheme.navyLight : AppTheme.lightGray,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? AppTheme.offWhite : AppTheme.navy,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
