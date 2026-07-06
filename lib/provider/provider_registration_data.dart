import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ona_net/utils/search.dart';

typedef JsonMap = Map<String, dynamic>;

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

const List<ProviderKind> providerKinds = [
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

const List<RegistrationStepInfo> registrationSteps = [
  RegistrationStepInfo('Admin\nAccount'),
  RegistrationStepInfo('Provider\nInfo'),
  RegistrationStepInfo('Services\nOffered'),
  RegistrationStepInfo('Coverage\nAreas'),
  RegistrationStepInfo('Contacts'),
  RegistrationStepInfo('Verification'),
  RegistrationStepInfo('Packages'),
];

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

  JsonMap toJson() => {
    ProviderRegistrationKeys.providerType: providerType,
    ProviderRegistrationKeys.adminFullName: adminFullName,
    ProviderRegistrationKeys.adminEmail: adminEmail,
    ProviderRegistrationKeys.adminPhone: adminPhone,
    ProviderRegistrationKeys.adminRole: adminRole,
    ProviderRegistrationKeys.providerName: providerName,
    ProviderRegistrationKeys.businessName: businessName,
    ProviderRegistrationKeys.logoUrl: logoUrl,
    ProviderRegistrationKeys.logoDisplaySize: logoDisplaySize,
    ProviderRegistrationKeys.logoOffsetX: logoOffsetX,
    ProviderRegistrationKeys.logoOffsetY: logoOffsetY,
    ProviderRegistrationKeys.yearStarted: yearStarted,
    ProviderRegistrationKeys.upstreamProvider: upstreamProvider,
    ProviderRegistrationKeys.primaryCity: primaryCity,
    ProviderRegistrationKeys.description: description,
    ProviderRegistrationKeys.hasBusinessDocs: hasBusinessDocs,
    ProviderRegistrationKeys.hasLicense: hasLicense,
  };

  JsonMap toProviderServicesJson() => {
    ProviderRegistrationKeys.serviceTypes: serviceTypes,
  };

  JsonMap toProviderCoverageAreasJson() => {
    ProviderRegistrationKeys.coverageAreas: coverageAreas
        .map((area) => area.toProviderJson())
        .toList(),
  };

  JsonMap toProviderContactsJson() => {
    ProviderRegistrationKeys.contacts: contacts
        .map((contact) => contact.toJson())
        .toList(),
  };

  JsonMap? toProviderPackageJson() => package?.toJson();
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

  JsonMap toJson() => {
    ProviderRegistrationKeys.contactType: contactType,
    ProviderRegistrationKeys.contactValue: contactValue,
    ProviderRegistrationKeys.socialPlatform: socialPlatform,
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

  JsonMap toJson() => {
    ProviderRegistrationKeys.packageName: name,
    ProviderRegistrationKeys.speedMbps: speedMbps,
    ProviderRegistrationKeys.monthlyPrice: monthlyPrice,
    ProviderRegistrationKeys.installationFee: installationFee ?? 0,
    ProviderRegistrationKeys.fairUsagePolicy: fairUsagePolicy,
    ProviderRegistrationKeys.billingCycle: 'monthly',
    ProviderRegistrationKeys.contractType: 'no_contract',
    ProviderRegistrationKeys.installationPeriod: installationPeriod,
    ProviderRegistrationKeys.routerIncluded: routerIncluded,
  };
}

extension CoverageAreaProviderJson on CoverageArea {
  JsonMap toProviderJson() => {
    ProviderRegistrationKeys.areaName: name,
    ProviderRegistrationKeys.latitude: latitude,
    ProviderRegistrationKeys.longitude: longitude,
    ProviderRegistrationKeys.radiusKm: radiusKm,
  };
}

abstract final class ProviderRegistrationKeys {
  static const providerType = 'provider_type';
  static const adminFullName = 'admin_full_name';
  static const adminEmail = 'admin_email';
  static const adminPhone = 'admin_phone';
  static const adminRole = 'admin_role';
  static const providerName = 'provider_name';
  static const businessName = 'business_name';
  static const logoUrl = 'logo_url';
  static const logoDisplaySize = 'logo_display_size';
  static const logoOffsetX = 'logo_offset_x';
  static const logoOffsetY = 'logo_offset_y';
  static const yearStarted = 'year_started';
  static const upstreamProvider = 'upstream_provider';
  static const primaryCity = 'primary_city';
  static const description = 'description';
  static const hasBusinessDocs = 'has_business_docs';
  static const hasLicense = 'has_license';

  static const serviceTypes = 'service_types';
  static const coverageAreas = 'coverage_areas';
  static const contacts = 'contacts';

  static const areaName = 'area_name';
  static const latitude = 'latitude';
  static const longitude = 'longitude';
  static const radiusKm = 'radius_km';

  static const contactType = 'contact_type';
  static const contactValue = 'contact_value';
  static const socialPlatform = 'social_platform';

  static const packageName = 'package_name';
  static const speedMbps = 'speed_mbps';
  static const monthlyPrice = 'monthly_price';
  static const installationFee = 'installation_fee';
  static const fairUsagePolicy = 'fair_usage_policy';
  static const billingCycle = 'billing_cycle';
  static const contractType = 'contract_type';
  static const installationPeriod = 'installation_period';
  static const routerIncluded = 'router_included';
}
