import 'package:flutter/material.dart';
import 'package:ona_net/provider/provider_flow_widgets.dart';
import 'package:ona_net/provider/provider_registration_data.dart';
import 'package:ona_net/provider/services_offered.dart';

class ProviderInfoScreen extends StatefulWidget {
  const ProviderInfoScreen({super.key, required this.providerKind});

  final ProviderKind providerKind;

  @override
  State<ProviderInfoScreen> createState() => _ProviderInfoScreenState();
}

class _ProviderInfoScreenState extends State<ProviderInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _kraPinController = TextEditingController();
  final _cityController = TextEditingController();

  @override
  void dispose() {
    _businessNameController.dispose();
    _registrationNumberController.dispose();
    _kraPinController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderFlowShell(
      title: widget.providerKind.registrationTitle,
      icon: widget.providerKind.icon,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepProgressHeader(currentStep: 2),
            const SizedBox(height: 28),
            ProviderSectionTitle(
              title: widget.providerKind.id == 'licensed_isp'
                  ? 'Company Info'
                  : 'Provider Info',
              subtitle:
                  'Add the business details customers and OnaNet will use to identify your provider account.',
            ),
            const SizedBox(height: 22),
            ProviderTextField(
              controller: _businessNameController,
              label: 'Business Name',
              textInputAction: TextInputAction.next,
              validator: _requiredField,
            ),
            const SizedBox(height: 16),
            ProviderTextField(
              controller: _registrationNumberController,
              label: 'Registration Number',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            ProviderTextField(
              controller: _kraPinController,
              label: 'KRA PIN',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            ProviderTextField(
              controller: _cityController,
              label: 'Primary City / Town',
              textInputAction: TextInputAction.done,
              validator: _requiredField,
            ),
            const SizedBox(height: 42),
            ProviderPrimaryButton(label: 'Continue', onPressed: _continue),
            const SizedBox(height: 24),
            const SecureFooter(),
          ],
        ),
      ),
    );
  }

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ServicesOfferedScreen(providerKind: widget.providerKind),
      ),
    );
  }
}
