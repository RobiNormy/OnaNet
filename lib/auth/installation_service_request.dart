import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
class InstallationServiceRequest {
  InstallationServiceRequest({Dio? dio, String? apiBaseUrl})
    : _dio = dio ?? Dio(),
      _apiBaseUrl = apiBaseUrl ??
          String.fromEnvironment("ONA_NET_BASE_URL");

  final Dio _dio;
  final String _apiBaseUrl;

  String _url(String path) => '$_apiBaseUrl$path';

  Future <Options> _authorizedOptions() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return Options(
      headers: {if (token != null)'Authorization':'Bearer $token'},
    );
  }

  String _errorMessage(DioException error){
    final code = error.response?.statusCode;
    final detail = (error.response?.data is Map)
        ? (error.response!.data['detail']?.toString())
        : null;

    if (code == 403){
      return detail ?? 'Please verify your phone number before submitting a request.';
    }
    if (code == 404){
      return detail ?? 'Account not set up. Please sign in again.';
    }
    if (code == 400){
      return detail ?? 'Invalid request. Please check your input.';
    }
    if (code == 401){
      return 'Session expired. Please sign in again';
    }
    if (code == 500){
      return 'Server error. Please try again later.';
    }
    if (code != null){
      return detail ?? "Server error {$code}. Please try again";
    }
    return error.message ?? "Network error. Please try again.";
  }

  Future<InstallationRequestResult> submit({
    required String providerId,

    required String packageId,

    required String phoneE164,

    String? gpsLocation,

    required String estateOrBuilding,

    String? houseOrApartment,

    String? landmark,

    required DateTime preferredDate,

    required TimeOfDay preferredTime,

}) async {
    final body = <String,dynamic>{
      'provider_id': providerId,
      'package_id': packageId,
      'phone_e164': phoneE164,

      'gps_location': gpsLocation,

      'estate_or_building': estateOrBuilding,
      if(houseOrApartment != null && houseOrApartment.trim().isNotEmpty)
        'house_or_apartment': houseOrApartment.trim(),
      if(landmark != null && landmark.trim().isNotEmpty)
        'landmark': landmark.trim(),

      'preferred_date':
          '${preferredDate.year.toString().padLeft(4, '0')}-'
          '${preferredDate.month.toString().padLeft(2, '0')}-'
          '${preferredDate.day.toString().padLeft(2, '0')}',
      'preferred_time':
          '${preferredTime.hour.toString().padLeft(2, '0')}:'
          '${preferredTime.minute.toString().padLeft(2, '0')}:00',
    };
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _url('/installation-requests'),
        data: body,
        options: await _authorizedOptions(),
      );
      return InstallationRequestResult.fromJson(response.data ?? const {});
    } on DioException catch(e){
      throw InstallationRequestException(_errorMessage(e));
    }
  }
  Future <List<InstallationRequestResult>> myRequests() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        _url('/installation-requests/me'),
        options:  await _authorizedOptions(),
      );
      final list = response.data ?? const [];
      return list
          .whereType<Map<String,dynamic>>()
          .map(InstallationRequestResult.fromJson)
          .toList(growable: false);
    } on DioException catch (e){
      throw InstallationRequestException(_errorMessage(e));
    }
  }

}

class InstallationRequestResult {
  InstallationRequestResult({
    required this.id,
    required this.providerId,
    required this.packageId,
    required this.status,
    required this.estateOrBuilding,
    this.houseOrApartment,
    this.landmark,
    this.gpsLocation,
    this.phoneE164,
    DateTime? preferredDate,
    DateTime? preferredTime,
    DateTime? createdAt,
    DateTime? updatedAt,
}) : _preferredDate = preferredDate,
    _preferredTime = preferredTime,
    _createdAt = createdAt,
    _updatedAt = updatedAt;

  final String id;
  final String providerId;
  final String packageId;
  final String status;
  final String estateOrBuilding;
  final String? houseOrApartment;
  final String? landmark;
  final String? gpsLocation;
  final String? phoneE164;

  final DateTime? _preferredDate;
  final DateTime? _preferredTime;
  final DateTime? _createdAt;
  final DateTime? _updatedAt;

  DateTime? get preferredDate => _preferredDate;
  DateTime? get preferredTime => _preferredTime;
  DateTime? get createdAt => _createdAt;
  DateTime? get updatedAt => _updatedAt;

  factory InstallationRequestResult.fromJson(Map<String,dynamic> json){
    DateTime? parseDate(dynamic v)=> v is String ? DateTime.tryParse(v) : null;
    DateTime? parseTime(dynamic v){
      if (v is! String) return null;
      final parts = v.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = parts.length > 2 ?(int.tryParse(parts[2]) ?? 0) : 0;
      return DateTime(2000, 1, 1,h, m, s);
    }

    return InstallationRequestResult(
      id: (json['id'] ?? '').toString(),
      providerId: (json['provider_id'] ?? '').toString(),
      packageId: (json['package_id'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      estateOrBuilding: (json['estate_or_building'] ?? '').toString(),
      houseOrApartment: json['house_or_apartment'] as String?,
      landmark: json['landmark'] as String?,
      gpsLocation: json['gps_location']as String?,
      phoneE164: json['phone_e164'] as String?,
      preferredDate: parseDate(json['preferred_date']),
      preferredTime: parseTime(json['preferred_time']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

}
class InstallationRequestException implements Exception {
  InstallationRequestException(this.message);
  final String message;
  @override
  String toString() => message;
}