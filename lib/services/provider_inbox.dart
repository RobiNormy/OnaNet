import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProviderInbox {
  ProviderInbox({Dio? dio, String? apiBaseUrl})
    : _dio = dio ?? Dio(),
      _apiBaseUrl =
          apiBaseUrl ?? const String.fromEnvironment('ONA_NET_API_BASE_URL');

  final Dio _dio;
  final String _apiBaseUrl;

  String _url(String path) {
    if (_apiBaseUrl.isEmpty) return path;
    final base = Uri.parse(_apiBaseUrl);
    final normalizedBase = base.path.endsWith('/')
        ? base
        : base.replace(path: '${base.path}/');
    return normalizedBase
        .resolve(path.replaceFirst(RegExp(r'^/+'), ''))
        .toString();
  }

  Future<Options> _authorizedOptions() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return Options(
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
  }

  String _errorMessage(DioException error) {
    final code = error.response?.statusCode;
    final detail = (error.response?.data is Map)
        ? (error.response!.data['detail']?.toString())
        : null;

    if (code == 401) return 'Session expired. Please sign in again.';
    if (code == 403) return detail ?? 'You are not registered as a provider.';
    if (code == 404) return detail ?? 'The requested resource was not found.';
    if (code == 409) return detail ?? 'This request can no longer be acted on.';
    if (code != null && code >= 500) {
      return 'Server error. Please try again later ($code).';
    }

    if (code != null) return detail ?? 'Server error ($code).';

    return error.message ??
        'An unexpected error occurred. Please check your connection.';
  }

  Future<List<ProviderInboxItem>> listInbox({String? statusFilter}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        _url(
          statusFilter == null
              ? '/installation-requests/inbox'
              : '/installation-requests/inbox?status_filter=$statusFilter',
        ),
        options: await _authorizedOptions(),
      );
      final data = response.data ?? const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(ProviderInboxItem.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw ProviderInboxException(_errorMessage(e));
    }
  }

  Future<ProviderInboxItem> getOne(String requestId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _url('/installation-requests/inbox/$requestId'),
        options: await _authorizedOptions(),
      );
      if (response.data == null) {
        throw ProviderInboxException('Item not found');
      }
      return ProviderInboxItem.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw ProviderInboxException(_errorMessage(e));
    }
  }

  Future<ProviderInboxItem> accept(String requestId) async {
    return _transition(requestId, '/accept');
  }

  Future<ProviderInboxItem> decline(String requestId, {String? reason}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _url('/installation-requests/$requestId/decline'),
        data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
        options: await _authorizedOptions(),
      );
      return ProviderInboxItem.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw ProviderInboxException(_errorMessage(e));
    }
  }

  Future<ProviderInboxItem> complete(String requestId) async {
    return _transition(requestId, '/complete');
  }

  Future<ProviderInboxItem> _transition(String requestId, String action) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _url('/installation-requests/$requestId$action'),
        options: await _authorizedOptions(),
      );
      return ProviderInboxItem.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw ProviderInboxException(_errorMessage(e));
    }
  }
}

class ProviderInboxItem {
  ProviderInboxItem({
    required this.id,
    required this.userId,
    required this.packageId,
    required this.estateOrBuilding,
    required this.status,
    this.packageName,
    this.houseOrApartment,
    this.landmark,
    this.customerMessage,
    this.gpsLocation,
    this.phoneE164,
    this.declineReason,
    DateTime? preferredDate,
    TimeOfDay? preferredTime,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : _preferredDate = preferredDate,
       _preferredTime = preferredTime,
       _completedAt = completedAt,
       _createdAt = createdAt,
       _updatedAt = updatedAt;

  final String id;
  final String userId;
  final String packageId;
  final String? packageName;
  final String estateOrBuilding;
  final String? houseOrApartment;
  final String? landmark;
  final String? customerMessage;
  final String? gpsLocation;
  final String? phoneE164;
  final String? declineReason;
  final String status;
  final DateTime? _preferredDate;
  final TimeOfDay? _preferredTime;
  final DateTime? _completedAt;
  final DateTime? _createdAt;
  final DateTime? _updatedAt;

  DateTime? get preferredDate => _preferredDate;

  TimeOfDay? get preferredTime => _preferredTime;

  DateTime? get completedAt => _completedAt;

  DateTime? get createdAt => _createdAt;

  DateTime? get updatedAt => _updatedAt;

  factory ProviderInboxItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final dateStr = value.toString().trim();
      if (dateStr.isEmpty) return null;

      return DateTime.tryParse(dateStr);
    }

    TimeOfDay? parseTime(dynamic value) {
      if (value == null) return null;
      final timeStr = value.toString().trim();
      if (timeStr.isEmpty) return null;

      final parts = timeStr.split(':');
      if (parts.length < 2) return null;

      final hour = int.tryParse(parts[0].trim());
      final minute = int.tryParse(parts[1].trim());

      if (hour == null || minute == null) return null;

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return TimeOfDay(hour: hour, minute: minute);
    }

    return ProviderInboxItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      packageId: json['package_id']?.toString() ?? '',
      packageName: json['package_name']?.toString(),
      estateOrBuilding: json['estate_or_building']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      houseOrApartment: json['house_or_apartment']?.toString(),
      landmark: json['landmark']?.toString(),
      customerMessage: json['customer_message']?.toString(),
      gpsLocation: json['gps_location']?.toString(),
      phoneE164: json['phone_e164']?.toString(),
      declineReason: json['decline_reason']?.toString(),
      preferredDate: parseDate(json['preferred_date']),
      preferredTime: parseTime(json['preferred_time']),
      completedAt: parseDate(json['completed_at']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCompleted => status == 'complete' || status == 'completed';
  bool get isDeclined => status == 'declined';
  bool get isCancelled => status == 'cancelled';

  String get statusLabel {
    final cleanStatus = status.trim();
    if (cleanStatus.isEmpty) return 'Unknown';
    switch (cleanStatus) {
      case 'pending':
        return 'New';
      case 'accepted':
        return 'Accepted';
      case 'complete':
      case 'completed':
        return 'Completed';
      case 'declined':
        return 'Declined';
      case 'cancelled':
        return 'Cancelled';
      default:
        return cleanStatus[0].toUpperCase() + cleanStatus.substring(1);
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'complete':
      case 'completed':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}

class ProviderInboxException implements Exception {
  final String message;
  ProviderInboxException(this.message);
  @override
  String toString() => message;
}
