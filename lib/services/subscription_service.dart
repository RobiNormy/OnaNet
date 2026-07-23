import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ona_net/services/api_client.dart';

class SubscriptionService {
  SubscriptionService({Dio? dio, String? apiBaseUrl})
    : _dio = dio ?? sharedApiClient,
      _apiBaseUrl = apiBaseUrl ?? onaNetApiBaseUrl;

  final Dio _dio;
  final String _apiBaseUrl;

  String _url(String path) {
    if (_apiBaseUrl.trim().isEmpty) {
      throw const SubscriptionException(
        'The OnaNet API address is not configured.',
      );
    }
    final base = Uri.parse(_apiBaseUrl);
    return (base.path.endsWith('/')
            ? base
            : base.replace(path: '${base.path}/'))
        .resolve(path.replaceFirst(RegExp(r'^/+'), ''))
        .toString();
  }

  Future<void> upgradeToProForTesting() async {
    await _activateTierForTesting('pro');
  }

  Future<void> upgradeToGrowthForTesting() async {
    await _activateTierForTesting('growth');
  }

  Future<void> _activateTierForTesting(String tier) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) {
      throw const SubscriptionException('Please sign in before upgrading.');
    }

    try {
      await _dio.post<dynamic>(
        _url('/subscriptions/upgrade'),
        data: {'tier': tier, 'duration_days': 30},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final detail = data is Map ? data['detail']?.toString() : null;
      throw SubscriptionException(
        detail ?? error.message ?? 'Could not activate the test upgrade.',
      );
    }
  }

  Future<Map<String, dynamic>> getCurrentSubscription() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) {
      throw const SubscriptionException(
        'Please sign in to view your current billing.',
      );
    }

    try {
      final response = await _dio.get<dynamic>(
        _url('/subscriptions/status'),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const SubscriptionException(
        'The subscription status response was invalid.',
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final detail = data is Map ? data['detail']?.toString() : null;
      throw SubscriptionException(
        detail ?? error.message ?? 'Could not load current billing.',
      );
    }
  }
}

class SubscriptionException implements Exception {
  const SubscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}
