import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:ona_net/auth/installation_service_request.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerNotificationStore {
  static const _statusUpdates = {
    'accepted',
    'declined',
    'complete',
    'completed',
  };

  static String get _storageKey {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'onanet_read_customer_notifications_$uid';
  }

  static List<InstallationRequestResult> notificationItems(
    List<InstallationRequestResult> requests,
  ) {
    return requests
        .where(
          (request) =>
              _statusUpdates.contains(request.status.trim().toLowerCase()),
        )
        .toList(growable: false);
  }

  static Future<int> unreadCount(
    List<InstallationRequestResult> requests,
  ) async {
    final read = await _readKeys();
    return notificationItems(
      requests,
    ).where((request) => !read.contains(_notificationKey(request))).length;
  }

  static Future<void> markRead(List<InstallationRequestResult> requests) async {
    final read = await _readKeys();
    read.addAll(notificationItems(requests).map(_notificationKey));
    final retained = read.toList(growable: false);
    final trimmed = retained.length <= 500
        ? retained
        : retained.sublist(retained.length - 500);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(trimmed));
  }

  static String _notificationKey(InstallationRequestResult request) {
    final status = request.status.trim().toLowerCase();
    final changedAt = request.updatedAt?.toUtc().toIso8601String() ?? '';
    return '${request.id}|$status|$changedAt';
  }

  static Future<Set<String>> _readKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_storageKey);
    if (value == null || value.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return <String>{};
      return decoded.map((item) => item.toString()).toSet();
    } catch (_) {
      await prefs.remove(_storageKey);
      return <String>{};
    }
  }
}
