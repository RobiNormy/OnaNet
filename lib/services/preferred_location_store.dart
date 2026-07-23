import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferredLocation {
  const PreferredLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory PreferredLocation.fromJson(Map<String, dynamic> json) {
    return PreferredLocation(
      name: (json['name'] ?? '').toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class PreferredLocationStore {
  static String get _key {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'onanet_preferred_location_$uid';
  }

  static Future<PreferredLocation?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == null || value.isEmpty) return null;
    try {
      return PreferredLocation.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
      );
    } catch (_) {
      await prefs.remove(_key);
      return null;
    }
  }

  static Future<void> save(PreferredLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(location.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
