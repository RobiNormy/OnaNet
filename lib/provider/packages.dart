import 'package:flutter/material.dart';
import 'package:ona_net/auth/auth_service.dart';
import 'package:ona_net/provider/provider_flow_widgets.dart';
import 'package:ona_net/provider/provider_registration_data.dart';

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({
    super.key,
    required this.providerKind,
    required this.draft,
  });

  final ProviderKind providerKind;
  final ProviderRegistrationDraft draft;

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  String? selectedItem;
  String _routerIncluded = 'Yes';
  String _speedUnit = 'Mbps';
  bool _isSubmitting = false;
  final List<String> installationPeriod = [
    'Same Day (0-12 Hours)',
    '12-24 Hours',
    '24-48 Hours',
    '2-3 Days',
    '3-5 Days',
    '5-7 Days',
    'More Than 7 Days',
    'Custom',
  ];
  final List<String> speedUnits = ['Mbps', 'Gbps'];
  final List<String> routerIncluded = ['Yes', 'No'];
  final _packageNameController = TextEditingController();
  final _speedController = TextEditingController();
  final _priceController = TextEditingController();
  final _installationController = TextEditingController();
  final _fairusage = TextEditingController();
  final _installationperiod = TextEditingController();

  @override
  void dispose() {
    _packageNameController.dispose();
    _speedController.dispose();
    _priceController.dispose();
    _installationController.dispose();
    _fairusage.dispose();
    _installationperiod.dispose();
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
          const StepProgressHeader(currentStep: 7),
          const SizedBox(height: 28),
          const ProviderSectionTitle(
            title: 'Packages',
            subtitle:
                'Add your first internet package. You can add more packages later.',
          ),
          const SizedBox(height: 22),
          ProviderTextField(
            controller: _packageNameController,
            label: 'Package Name',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: ProviderTextField(
                  controller: _speedController,
                  label: 'Speed',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _speedUnit,
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: speedUnits.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _speedUnit = newValue ?? 'Mbps';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProviderTextField(
            controller: _priceController,
            label: 'Monthly Price',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          ProviderTextField(
            controller: _installationController,
            label: 'Installation Fee',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedItem,
            decoration: InputDecoration(
              labelText: 'Installation Period',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: installationPeriod.map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                selectedItem = newValue;
                _installationperiod.text = newValue == 'Custom'
                    ? ''
                    : newValue ?? '';
              });
            },
          ),
          const SizedBox(height: 16),
          ProviderTextField(
            controller: _fairusage,
            label: 'Fair Usage Policy',
            textInputAction: TextInputAction.next,
          ),
          if (selectedItem == 'Custom') ...[
            const SizedBox(height: 16),
            ProviderTextField(
              controller: _installationperiod,
              label: 'Describe Installation Time',
              textInputAction: TextInputAction.done,
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _routerIncluded,
            decoration: InputDecoration(
              labelText: "Router Included",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: routerIncluded.map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _routerIncluded = newValue ?? 'Yes';
              });
            },
          ),
          const SizedBox(height: 42),
          ProviderPrimaryButton(
            label: _isSubmitting ? 'Saving...' : 'Finish',
            onPressed: _isSubmitting ? null : _submitRegistration,
          ),
          const SizedBox(height: 24),
          const SecureFooter(),
        ],
      ),
    );
  }

  Future<void> _submitRegistration() async {
    final packageName = _optionalText(_packageNameController.text);
    final speedMbps = _speedToMbps(_speedController.text, _speedUnit);
    final monthlyPrice = _optionalInt(_priceController.text);

    if (packageName == null || speedMbps == null || monthlyPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Package name, speed, and monthly price are required.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final draft = widget.draft.copyWith(
      package: ProviderPackageDraft(
        name: packageName,
        speedMbps: speedMbps,
        monthlyPrice: monthlyPrice,
        installationFee: _optionalInt(_installationController.text),
        fairUsagePolicy: _optionalText(_fairusage.text),
        installationPeriod: _optionalText(_installationperiod.text),
        routerIncluded: _routerIncluded == 'Yes',
      ),
    );

    try {
      final authService = AuthService();
      final provider = await authService.submitProviderRegistration(
        draft.toJson(),
      );
      final providerId = provider['id']?.toString();
      if (providerId == null || providerId.isEmpty) {
        throw const AuthServiceException(
          'Provider saved, but the API did not return a provider ID.',
        );
      }

      await authService.submitProviderCoverageAreas(
        providerId: providerId,
        payload: draft.toProviderCoverageAreasJson(),
      );

      await authService.submitProviderContacts(
        providerId: providerId,
        payload: draft.toProviderContactsJson(),
      );

      await authService.submitProviderServices(
        providerId: providerId,
        payload: draft.toProviderServicesJson(),
      );

      final packagePayload = draft.toProviderPackageJson();
      if (packagePayload != null) {
        await authService.submitProviderPackage(
          providerId: providerId,
          payload: packagePayload,
        );
      }

      for (final document in draft.documents) {
        await authService.uploadProviderDocument(
          providerId: providerId,
          documentType: document.documentType,
          file: document.file,
        );
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Provider registration saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  int? _optionalInt(String value) {
    final cleaned = value.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  int? _speedToMbps(String value, String unit) {
    final cleaned = value.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;

    final speed = double.tryParse(cleaned);
    if (speed == null) return null;

    final speedMbps = unit == 'Gbps' ? speed * 1000 : speed;
    return speedMbps.round();
  }

  String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
