import 'package:flutter/material.dart';

class ProviderKind {
  const ProviderKind({
    required this.id,
    required this.title,
    required this.registrationTitle,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String registrationTitle;
  final String subtitle;
  final IconData icon;
}

const providerKinds = [
  ProviderKind(
    id: 'licensed_isp',
    title: 'Licensed ISP',
    registrationTitle: 'Licensed ISP Registration',
    subtitle: 'Registered internet service provider operating under a license.',
    icon: Icons.apartment_rounded,
  ),
  ProviderKind(
    id: 'local_wireless',
    title: 'Local Fiber / Wireless Provider',
    registrationTitle: 'Local Provider Registration',
    subtitle:
        'Small or medium internet provider serving specific areas or towns.',
    icon: Icons.cell_tower_rounded,
  ),
];

class RegistrationStepInfo {
  const RegistrationStepInfo(this.label);

  final String label;
}

const registrationSteps = [
  RegistrationStepInfo('Admin\nAccount'),
  RegistrationStepInfo('Provider\nInfo'),
  RegistrationStepInfo('Services\nOffered'),
  RegistrationStepInfo('Coverage\nAreas'),
  RegistrationStepInfo('Contacts'),
  RegistrationStepInfo('Verification'),
  RegistrationStepInfo('Packages'),
];
