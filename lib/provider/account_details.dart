import 'package:flutter/material.dart';
import 'package:ona_net/provider/provider_flow_widgets.dart';
import 'package:ona_net/provider/provider_info.dart';
import 'package:ona_net/provider/provider_registration_data.dart';

class ProviderAccountDetails extends StatefulWidget {
  const ProviderAccountDetails({super.key, required this.providerKind});

  final ProviderKind providerKind;

  @override
  State<ProviderAccountDetails> createState() => _ProviderAccountDetailsState();
}

class _ProviderAccountDetailsState extends State<ProviderAccountDetails> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countryCodeController = TextEditingController(text: '+254');
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showPassword = false;

  @override
  void dispose() {
    _nameController.dispose();
    _countryCodeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _roleController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
            const StepProgressHeader(currentStep: 1),
            const SizedBox(height: 28),
            const ProviderSectionTitle(
              title: 'Admin Account',
              subtitle:
                  'This is the main account that will manage your provider dashboard.',
            ),
            const SizedBox(height: 22),
            ProviderTextField(
              controller: _nameController,
              label: 'Full Name',
              textInputAction: TextInputAction.next,
              validator: _requiredField,
            ),
            const SizedBox(height: 16),
            ProviderTextField(
              controller: _emailController,
              label: 'Work Email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _emailValidator,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: ProviderTextField(
                    controller: _countryCodeController,
                    label: 'Code',
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ProviderTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: _requiredField,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ProviderTextField(
              controller: _roleController,
              label: 'Role / Position',
              textInputAction: TextInputAction.next,
              validator: _requiredField,
            ),
            const SizedBox(height: 16),
            ProviderTextField(
              controller: _passwordController,
              label: 'Password',
              obscureText: !_showPassword,
              textInputAction: TextInputAction.next,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              validator: _passwordValidator,
            ),
            const SizedBox(height: 16),
            ProviderTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              validator: _confirmPasswordValidator,
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

  String? _emailValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Required';
    if (!trimmed.contains('@') || !trimmed.contains('.')) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (value.length < 8) return 'Use at least 8 characters';
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProviderInfoScreen(providerKind: widget.providerKind),
      ),
    );
  }
}


