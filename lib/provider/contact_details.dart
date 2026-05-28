import 'package:flutter/material.dart';
import 'package:ona_net/provider/provider_flow_widgets.dart';
import 'package:ona_net/provider/provider_registration_data.dart';
import 'package:ona_net/provider/verification.dart';

class ContactDetailsScreen extends StatefulWidget {
  const ContactDetailsScreen({super.key, required this.providerKind});

  final ProviderKind providerKind;

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen> {
  final _supportEmailController = TextEditingController();
  final _supportPhoneController = TextEditingController();
  final _websiteController = TextEditingController();

  @override
  void dispose() {
    _supportEmailController.dispose();
    _supportPhoneController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderFlowShell(
      title: widget.providerKind.registrationTitle,
      icon: widget.providerKind.icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StepProgressHeader(currentStep: 5),
          const SizedBox(height: 28),
          const ProviderSectionTitle(
            title: 'Contacts',
            subtitle:
                'Add the contact channels customers can use to reach your team.',
          ),
          const SizedBox(height: 22),
          ProviderTextField(
            controller: _supportEmailController,
            label: 'Support Email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          ProviderTextField(
            controller: _supportPhoneController,
            label: 'Support Phone Number',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          ProviderTextField(
            controller: _websiteController,
            label: 'Website or Social Page',
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 42),
          ProviderPrimaryButton(
            label: 'Continue',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      VerificationScreen(providerKind: widget.providerKind),
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
