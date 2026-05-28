import 'package:flutter/material.dart';

enum ProviderType {
  licensedISP,
  localWISP,
}

class ProviderDetails extends ChangeNotifier {
  final String name;
  final ProviderType type;
  final String contactInfo;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final businessNameController = TextEditingController();
  final kraPinController = TextEditingController();
  final regNumberController = TextEditingController();
  final cityController = TextEditingController();

  ProviderDetails({
    required this.name,
    required this.type,
    required this.contactInfo,
  });

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    businessNameController.dispose();
    kraPinController.dispose();
    regNumberController.dispose();
    cityController.dispose();
    super.dispose();
  }
}
