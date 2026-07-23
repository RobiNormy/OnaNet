import 'dart:convert';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedProvidersStore extends ChangeNotifier {
  static const _storageKey = 'onanet_saved_providers';

  final Map<String, Map<String, dynamic>> _providersById = {};
  bool _loaded = false;
  String? _accountId;
  late final StreamSubscription<User?> _authSubscription;

  SavedProvidersStore() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) => _loadForAccount(user?.uid ?? 'guest'),
    );
    _loadForAccount(FirebaseAuth.instance.currentUser?.uid ?? 'guest');
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

  String get _accountStorageKey => '${_storageKey}_${_accountId ?? 'guest'}';

  Future<void> _loadForAccount(String accountId) async {
    if (_accountId == accountId && _loaded) return;
    _accountId = accountId;
    _loaded = false;
    _providersById.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    var saved = prefs.getString(_accountStorageKey);
    if (saved == null && accountId != 'guest') {
      saved = prefs.getString(_storageKey);
      if (saved != null) {
        await prefs.setString(_accountStorageKey, saved);
        await prefs.remove(_storageKey);
      }
    }
    if (_accountId != accountId) return;
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
      await prefs.remove(_accountStorageKey);
      _providersById.clear();
    } finally {
      if (_accountId == accountId) {
        _loaded = true;
        notifyListeners();
      }
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accountStorageKey, jsonEncode(providers));
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
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
