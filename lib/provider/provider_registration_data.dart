import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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
    id: 'local_provider',
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

/// A geographic area served by a provider.
///
/// This lives with the registration draft because it is registration data,
/// not search UI state.
class CoverageArea {
  const CoverageArea({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double radiusKm;
}

class ProviderRegistrationDraft {
  const ProviderRegistrationDraft({
    required this.providerType,
    this.adminFullName,
    this.adminEmail,
    this.adminPhone,
    this.adminRole,
    this.providerName,
    this.businessName,
    this.logoUrl,
    this.logoFile,
    this.logoDisplaySize = 1.0,
    this.logoOffsetX = 0.0,
    this.logoOffsetY = 0.0,
    this.yearStarted,
    this.upstreamProvider,
    this.primaryCity,
    this.description,
    this.serviceTypes = const [],
    this.coverageAreas = const [],
    this.contacts = const [],
    this.documents = const [],
    this.hasBusinessDocs = false,
    this.hasLicense = false,
    this.package,
  });

  final String providerType;
  final String? adminFullName;
  final String? adminEmail;
  final String? adminPhone;
  final String? adminRole;
  final String? providerName;
  final String? businessName;
  final String? logoUrl;
  final PlatformFile? logoFile;
  final double logoDisplaySize;
  final double logoOffsetX;
  final double logoOffsetY;
  final int? yearStarted;
  final String? upstreamProvider;
  final String? primaryCity;
  final String? description;
  final List<String> serviceTypes;
  final List<CoverageArea> coverageAreas;
  final List<ProviderContactDraft> contacts;
  final List<ProviderDocumentDraft> documents;
  final bool hasBusinessDocs;
  final bool hasLicense;
  final ProviderPackageDraft? package;

  ProviderRegistrationDraft copyWith({
    String? adminFullName,
    String? adminEmail,
    String? adminPhone,
    String? adminRole,
    String? providerName,
    String? businessName,
    String? logoUrl,
    PlatformFile? logoFile,
    double? logoDisplaySize,
    double? logoOffsetX,
    double? logoOffsetY,
    int? yearStarted,
    String? upstreamProvider,
    String? primaryCity,
    String? description,
    List<String>? serviceTypes,
    List<CoverageArea>? coverageAreas,
    List<ProviderContactDraft>? contacts,
    List<ProviderDocumentDraft>? documents,
    bool? hasBusinessDocs,
    bool? hasLicense,
    ProviderPackageDraft? package,
  }) {
    return ProviderRegistrationDraft(
      providerType: providerType,
      adminFullName: adminFullName ?? this.adminFullName,
      adminEmail: adminEmail ?? this.adminEmail,
      adminPhone: adminPhone ?? this.adminPhone,
      adminRole: adminRole ?? this.adminRole,
      providerName: providerName ?? this.providerName,
      businessName: businessName ?? this.businessName,
      logoUrl: logoUrl ?? this.logoUrl,
      logoFile: logoFile ?? this.logoFile,
      logoDisplaySize: logoDisplaySize ?? this.logoDisplaySize,
      logoOffsetX: logoOffsetX ?? this.logoOffsetX,
      logoOffsetY: logoOffsetY ?? this.logoOffsetY,
      yearStarted: yearStarted ?? this.yearStarted,
      upstreamProvider: upstreamProvider ?? this.upstreamProvider,
      primaryCity: primaryCity ?? this.primaryCity,
      description: description ?? this.description,
      serviceTypes: serviceTypes ?? this.serviceTypes,
      coverageAreas: coverageAreas ?? this.coverageAreas,
      contacts: contacts ?? this.contacts,
      documents: documents ?? this.documents,
      hasBusinessDocs: hasBusinessDocs ?? this.hasBusinessDocs,
      hasLicense: hasLicense ?? this.hasLicense,
      package: package ?? this.package,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider_type': providerType,
    'admin_full_name': adminFullName,
    'admin_email': adminEmail,
    'admin_phone': adminPhone,
    'admin_role': adminRole,
    'provider_name': providerName,
    'business_name': businessName,
    'logo_url': logoUrl,
    'logo_display_size': logoDisplaySize,
    'logo_offset_x': logoOffsetX,
    'logo_offset_y': logoOffsetY,
    'year_started': yearStarted,
    'upstream_provider': upstreamProvider,
    'primary_city': primaryCity,
    'description': description,
    'has_business_docs': hasBusinessDocs,
    'has_license': hasLicense,
  };

  Map<String, dynamic> toProviderServicesJson() => {
    'service_types': serviceTypes,
  };

  Map<String, dynamic> toProviderCoverageAreasJson() => {
    'coverage_areas': coverageAreas
        .map(
          (area) => {
            'area_name': area.name,
            'latitude': area.latitude,
            'longitude': area.longitude,
            'radius_km': area.radiusKm,
          },
        )
        .toList(),
  };

  Map<String, dynamic> toProviderContactsJson() => {
    'contacts': contacts.map((contact) => contact.toJson()).toList(),
  };

  Map<String, dynamic>? toProviderPackageJson() => package?.toJson();
}

class ProviderDocumentDraft {
  const ProviderDocumentDraft({required this.documentType, required this.file});

  final String documentType;
  final PlatformFile file;
}

class ProviderContactDraft {
  const ProviderContactDraft({
    required this.contactType,
    required this.contactValue,
    this.socialPlatform,
  });

  final String contactType;
  final String contactValue;
  final String? socialPlatform;

  Map<String, dynamic> toJson() => {
    'contact_type': contactType,
    'contact_value': contactValue,
    'social_platform': socialPlatform,
  };
}

class ProviderPackageDraft {
  const ProviderPackageDraft({
    this.name,
    this.speedMbps,
    this.monthlyPrice,
    this.installationFee,
    this.fairUsagePolicy,
    this.installationPeriod,
    this.routerIncluded = false,
  });

  final String? name;
  final int? speedMbps;
  final int? monthlyPrice;
  final int? installationFee;
  final String? fairUsagePolicy;
  final String? installationPeriod;
  final bool routerIncluded;

  Map<String, dynamic> toJson() => {
    'package_name': name,
    'speed_mbps': speedMbps,
    'monthly_price': monthlyPrice,
    'installation_fee': installationFee ?? 0,
    'fair_usage_policy': fairUsagePolicy,
    'billing_cycle': 'monthly',
    'contract_type': 'no_contract',
    'installation_period': installationPeriod,
    'router_included': routerIncluded,
  };
}
