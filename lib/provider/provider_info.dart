import 'package:flutter/material.dart';
import 'package:ona_net/provider/provider_flow_widgets.dart';
import 'package:ona_net/provider/provider_registration_data.dart';
import 'package:ona_net/provider/services_offered.dart';

class ProviderInfoScreen extends StatefulWidget {
  const ProviderInfoScreen({
    super.key,
    required this.providerKind,
    required this.draft,
  });

  final ProviderKind providerKind;
  final ProviderRegistrationDraft draft;

  @override
  State<ProviderInfoScreen> createState() => _ProviderInfoScreenState();
}

class _ProviderInfoScreenState extends State<ProviderInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _providerNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _yearStartedController = TextEditingController();
  final _cityController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _providerNameController.dispose();
    _businessNameController.dispose();
    _logoUrlController.dispose();
    _yearStartedController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
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
              controller: _providerNameController,
              label: 'Provider Name',
              textInputAction: TextInputAction.next,
              validator: _requiredField,
            ),
            const SizedBox(height: 16),
            ProviderTextField(
              controller: _businessNameController,
              label: 'Business Name (Optional)',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            ProviderTextField(
              controller: _logoUrlController,
              label: 'Logo URL (Optional)',
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            ProviderTextField(
              controller: _yearStartedController,
              label: 'Year Started (Optional)',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              validator: _optionalYearValidator,
            ),
            const SizedBox(height: 16),
            ProviderTextField(
              controller: _cityController,
              label: 'Primary City / Town',
              textInputAction: TextInputAction.next,
              validator: _requiredField,
            ),
            const SizedBox(height: 16),
            ProviderTextField(
              controller: _descriptionController,
              label: 'Description (Optional)',
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.done,
              maxLines: 4,
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

  String? _optionalYearValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final year = int.tryParse(trimmed);
    if (year == null) return 'Enter a valid year';
    if (year < 1900) return 'Enter a year after 1900';
    return null;
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;

    final draft = widget.draft.copyWith(
      providerName: _providerNameController.text.trim(),
      businessName: _optionalText(_businessNameController.text),
      logoUrl: _optionalText(_logoUrlController.text),
      yearStarted: _optionalInt(_yearStartedController.text),
      primaryCity: _cityController.text.trim(),
      description: _optionalText(_descriptionController.text),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServicesOfferedScreen(
          providerKind: widget.providerKind,
          draft: draft,
        ),
      ),
    );
  }

  String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _optionalInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }
}
