import 'package:flutter/material.dart';
import 'package:ona_net/provider/provider_flow_widgets.dart';
import 'package:ona_net/provider/provider_registration_data.dart';

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key, required this.providerKind});

  final ProviderKind providerKind;

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  String? selectedItem;
  final List<String> installationPeriod = ['12-24 hrs', '24-48 hrs'];
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
          ProviderTextField(
            controller: _speedController,
            label: 'Speed',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
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
            value: selectedItem,
            decoration:  InputDecoration(
              labelText: 'Installation Period',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),

            ),
            items: installationPeriod.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                selectedItem = newValue;
                _installationperiod.text = newValue ?? '';
              });
            },
          ),
          const SizedBox(height: 16),
          ProviderTextField(
            controller: _fairusage,
            label: 'Fair Usage Policy',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          ProviderTextField(
            controller: _installationperiod,
            label: 'Installation Period (Manual Override)',
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: routerIncluded.first,
              decoration: InputDecoration(
                labelText: "Router Included",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: routerIncluded.map((String value){
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  // Logic to handle router selection
                });
              }),
          const SizedBox(height: 42),
          ProviderPrimaryButton(
            label: 'Finish',
            onPressed: () {
              final packageData = {
                'name': _packageNameController.text,
                'speed': _speedController.text,
                'price': _priceController.text,
                'installation': _installationController.text,
                'fairUsage': _fairusage.text,
                'installationPeriod': _installationperiod.text,
              };
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Provider registration draft saved.'),
                ),
              );
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          const SizedBox(height: 24),
          const SecureFooter(),
        ],
      ),
    );
  }
}
