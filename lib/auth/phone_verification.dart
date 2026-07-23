import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ona_net/services/api_client.dart';

class PhoneVerificationService {
  PhoneVerificationService({Dio? dio, String? apiBaseUrl})
    : _dio = dio ?? sharedApiClient,
      _apiBaseUrl =
          apiBaseUrl ?? const String.fromEnvironment('ONA_NET_API_BASE_URL');
  final Dio _dio;
  final String _apiBaseUrl;

  bool _isVerified = false;
  String? _verifiedPhone;

  bool get isVerified => _isVerified;
  String? get verifiedPhone => _verifiedPhone;

  static String normalizeKenyanPhone(String input) {
    final normal = input.replaceAll(RegExp(r'[\s\-()]'), '').trim();
    if (normal.startsWith('+')) return normal;
    if (normal.startsWith('254') && normal.length == 12) {
      return '+$normal';
    }
    if (normal.startsWith('0') && normal.length == 10) {
      return '+254${normal.substring(1)}';
    }
    if (RegExp(r'^[17]\d{8}$').hasMatch(normal)) {
      return '+254$normal';
    }
    return normal.startsWith('+') ? normal : '+${normal.replaceAll('+', '')}';
  }

  String _url(String path) => '$_apiBaseUrl$path';
  Future<Options> _authorizedOptions() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return Options(
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
  }

  Future<OtpStartResult> startVerification({required String phoneE164}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _url('/phone/start'),
        data: {'phone': phoneE164},
        options: await _authorizedOptions(),
      );
      final data = response.data ?? const {};
      return OtpStartResult(
        phoneE164: (data['phone'] as String?) ?? phoneE164,
        expiresInSeconds: (data['expires_in_seconds'] as num?)?.toInt() ?? 300,
      );
    } on DioException catch (e) {
      throw PhoneVerificationException(_errorMessage(e));
    }
  }

  Future<OtpVerifyResult> verify({
    required String phoneE164,
    required String otp,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _url('/phone/verify'),
        data: {'phone': phoneE164, 'otp': otp},
        options: await _authorizedOptions(),
      );
      final data = response.data ?? const {};
      _isVerified = true;
      _verifiedPhone = (data['phone'] as String?) ?? phoneE164;
      return OtpVerifyResult(verifiedPhone: true, phoneE164: _verifiedPhone!);
    } on DioException catch (e) {
      throw PhoneVerificationException(_errorMessage(e));
    }
  }

  Future<OtpStatusResult> status() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _url('/phone/status'),
        options: await _authorizedOptions(),
      );

      final data = response.data ?? const {};
      _isVerified = (data['is_phone_verified'] as bool?) ?? false;
      _verifiedPhone = data['phone_number'] as String?;
      return OtpStatusResult(
        phoneNumber: _verifiedPhone,
        isVerified: _isVerified,
      );
    } on DioException catch (e) {
      throw PhoneVerificationException(_errorMessage(e));
    }
  }

  String _errorMessage(DioException error) {
    final code = error.response?.statusCode;
    final detail = (error.response?.data is Map)
        ? (error.response!.data['detail']?.toString())
        : null;

    if (code == 429) {
      return 'Too many attempts. Please wait in a few minutes.';
    }
    if (code == 404) {
      return detail ?? 'Account not set up yet. Please sign in again.';
    }
    if (code == 400) {
      return detail ?? 'Invalid request';
    }
    if (code == 401) {
      return 'Session expired. Please sign in again';
    }
    if (code != null) {
      return detail ?? 'Server error ($code). Please try again.';
    }
    return error.message ?? 'Network error. Please try again.';
  }
}

class OtpStartResult {
  OtpStartResult({required this.phoneE164, required this.expiresInSeconds});
  final String phoneE164;
  final int expiresInSeconds;
}

class OtpVerifyResult {
  OtpVerifyResult({required this.verifiedPhone, required this.phoneE164});
  final bool verifiedPhone;
  final String phoneE164;
}

class OtpStatusResult {
  OtpStatusResult({required this.phoneNumber, required this.isVerified});

  final String? phoneNumber;
  final bool isVerified;
}

class PhoneVerificationException implements Exception {
  PhoneVerificationException(this.message);
  final String message;

  @override
  String toString() => message;
}
