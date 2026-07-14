import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService {
  SubscriptionService({Dio? dio, String? apiBaseUrl})
    : _dio = dio ?? Dio(),
      _apiBaseUrl =
          apiBaseUrl ?? const String.fromEnvironment('ONA_NET_API_BASE_URL');

  final Dio _dio;
  final String _apiBaseUrl;

  String _url(String path) {
    if (_apiBaseUrl.trim().isEmpty) {
      throw const SubscriptionException(
        'The API address is not configured. Start the app with '
        '--dart-define=ONA_NET_API_BASE_URL=http://<server>:8000.',
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
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) {
      throw const SubscriptionException('Please sign in before upgrading.');
    }

    try {
      await _dio.post<dynamic>(
        _url('/subscriptions/upgrade'),
        data: const {'tier': 'pro', 'duration_days': 30},
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
}

class SubscriptionException implements Exception {
  const SubscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}
