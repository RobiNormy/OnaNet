import 'package:flutter/material.dart';
import 'package:ona_net/provider/contact_details.dart';
import 'package:ona_net/provider/provider_flow_widgets.dart';
import 'package:ona_net/provider/provider_registration_data.dart';

class CoverageAreasScreen extends StatefulWidget {
  const CoverageAreasScreen({
    super.key,
    required this.providerKind,
    required this.draft,
  });

  final ProviderKind providerKind;
  final ProviderRegistrationDraft draft;

  @override
  State<CoverageAreasScreen> createState() => _CoverageAreasScreenState();
}

class _CoverageAreasScreenState extends State<CoverageAreasScreen> {
  final _areasController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return ProviderFlowShell(
      title: widget.providerKind.registrationTitle,
      icon: widget.providerKind.icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StepProgressHeader(currentStep: 4),
          const SizedBox(height: 28),
          const ProviderSectionTitle(
            title: 'Coverage Areas',
            subtitle:
                'Tell customers where your service is currently available.',
          ),
          const SizedBox(height: 22),
          ProviderTextField(
            controller: _areasController,
            label: 'Areas Served',
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 42),
          ProviderPrimaryButton(
            label: 'Continue',
            onPressed: () {
              final areaName = _areasController.text.trim();
              if (areaName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter at least one coverage area.'),
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContactDetailsScreen(
                    providerKind: widget.providerKind,
                    draft: widget.draft,
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
