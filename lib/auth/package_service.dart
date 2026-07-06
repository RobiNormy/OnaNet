import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ProviderPackageService {


  ProviderPackageService({Dio? dio, String? apiBaseUrl})
      : _dio = dio ?? Dio(),
        _apiBaseUrl = apiBaseUrl ??
            const String.fromEnvironment('ONA_NET_API_BASE_URL');

  final Dio _dio;
  final String _apiBaseUrl;

  String _url(String path) {
    if (_apiBaseUrl.isEmpty) return path;
    final base = Uri.parse(_apiBaseUrl);
    final normalizedBase =
        base.path.endsWith('/') ? base : base.replace(path: '${base.path}/');
    return normalizedBase
        .resolve(path.replaceFirst(RegExp(r'^/+'), ''))
        .toString();
  }

  Future<Options> _authorizedOptions() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return Options(
      headers:  {if (token != null) 'Authorization' : 'Bearer $token'},
    );
  }
  Future <List<ProviderPackage>> listForProvider(String providerId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        _url('/providers/$providerId/packages'),
        options: await _authorizedOptions(),
      );
      final list = response.data ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(ProviderPackage.fromJson)
          .toList();
    } on DioException catch (e) {
      print('PACKAGE FETCH ERROR: ${e.message}');
      print('PACKAGE FETCH URL: $_apiBaseUrl/providers/$providerId/packages');
      print('PACKAGE FETCH RESPONSE: ${e.response?.data}');
      print('PACKAGE FETCH STATUS: ${e.response?.statusCode}');
      throw PackageServiceException(_errorMessage(e));
    }
  }
  String _errorMessage(DioException error){
    final code = error.response?.statusCode;
    if (code ==404) return 'Provider not found.';
    if (code ==401) return 'Session expired. Please sign in again.';
    if(code !=null) return 'Server error ($code).';
    return  error.message ?? 'Network error.';
  }
}

class ProviderPackage {
  ProviderPackage({
    required this.id,
    required this.providerId,
    required this.name,
    required this.speed,
    required this.contract,
    required this.price,
    required this.installationFee,
    this.fairUsage,
    this.routerIncluded = false,
    this.installationTime,
    this.coverageAreas = const [],
    this.trustLabel,
    this.subscriberCount,
    this.popular = false,
  });

  final String id;
  final String providerId;
  final String name;
  final String speed;
  final String contract;
  final String price;
  final String installationFee;
  final String? fairUsage;
  final bool routerIncluded;
  final String? installationTime;
  final List<String> coverageAreas;
  final String? trustLabel;
  final String? subscriberCount;
  final bool popular;

  static String _speedLabel(dynamic mbps, dynamic fallback) {
    if (mbps is num) return '${mbps.toInt()}Mbps';
    return (fallback ?? '').toString();
  }

  static String _formatMoney(dynamic amount) {
    if (amount == null) return '0';
    if(amount is num) return amount.toStringAsFixed(0);
    return amount.toString();
  }
  factory ProviderPackage.fromJson(Map<String, dynamic> json) {
    return ProviderPackage(
      id: (json['id'] ?? '').toString(),
      providerId: (json['provider_id'] ?? '').toString(),
      name: (json['package_name'] ?? json['name'] ?? '').toString(),
      speed: _speedLabel(json['speed_mbps'], json['speed']),
      contract: (json['contract_type'] ?? json['contract'] ?? 'No contract').toString(),
      price: _formatMoney(json['monthly_price'] ?? json['price']),
      installationFee: _formatMoney(json['installation_fee']),
      fairUsage: json['fair_usage'] as String?,
      routerIncluded: json['router_included'] as bool? ?? false,
      installationTime: json['installation_time']?.toString(),
      coverageAreas: (json['coverage_areas'] as List?)
          ?.whereType<String>()
          .toList() ??
          const [],
      trustLabel: json['trust_label']?.toString(),
      subscriberCount: json['subscriber_count']?.toString(),
      popular: json['popular'] as bool? ?? false,
    );
  }
  Map <String,dynamic> toUiMap() => {
    'id': id,
    'providerId':providerId,
    'name':name,
    'speed': speed,
    'contract': contract,
    'price': price,
    'installationFee': installationFee,
    'fairUsage': fairUsage,
    'routerIncluded': routerIncluded,
    'installationTime': installationTime,
    'coverageAreas': coverageAreas,
    'trustLabel': trustLabel,
    'subscriberCount': subscriberCount,
    'popular': popular,
  };
}
class PackageServiceException implements Exception {
  PackageServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
