import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedProvidersStore extends ChangeNotifier {
  static const _storageKey = 'onanet_saved_providers';

  final Map<String, Map<String, dynamic>> _providersById = {};
  bool _loaded = false;

  SavedProvidersStore() {
    _load();
  }

  bool get isLoaded => _loaded;

  List<Map<String, dynamic>> get providers => _providersById.values.toList();

  bool isSaved(Map<String, dynamic> provider) {
    return _providersById.containsKey(providerKey(provider));
  }

  Future<void> toggle(Map<String, dynamic> provider) async {
    final key = providerKey(provider);
    if (_providersById.containsKey(key)) {
      _providersById.remove(key);
    } else {
      _providersById[key] = Map<String, dynamic>.from(provider);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> remove(Map<String, dynamic> provider) async {
    _providersById.remove(providerKey(provider));
    notifyListeners();
    await _persist();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    try {
      if (saved == null || saved.isEmpty) return;
      final decoded = jsonDecode(saved);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            final provider = Map<String, dynamic>.from(item);
            _providersById[providerKey(provider)] = provider;
          }
        }
      }
    } catch (_) {
      await prefs.remove(_storageKey);
      _providersById.clear();
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(providers));
  }
}

String providerKey(Map<String, dynamic> provider) {
  return (provider['id'] ??
          provider['provider_id'] ??
          provider['uid'] ??
          provider['name'] ??
          provider['business_name'] ??
          provider.hashCode)
      .toString();
}
