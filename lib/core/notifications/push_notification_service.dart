import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ona_net/core/network/api_client.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> onaNetPushBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<AuthState>? _authSubscription;
  static bool _initialised = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'onanet_updates',
    'OnaNet updates',
    description: 'Installation, provider and account updates from OnaNet.',
    importance: Importance.high,
  );

  static Future<void> initialise() async {
    if (_initialised || kIsWeb) return;
    _initialised = true;

    FirebaseMessaging.onBackgroundMessage(onaNetPushBackgroundHandler);
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      _registerToken,
    );
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      event,
    ) async {
      if (event.session != null) {
        await registerCurrentDevice();
      } else if (event.event == AuthChangeEvent.signedOut) {
        await _messaging.deleteToken();
      }
    });

    if (Supabase.instance.client.auth.currentSession != null) {
      await registerCurrentDevice();
    }
  }

  static Future<void> registerCurrentDevice() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null || kIsWeb) return;
    try {
      final permission = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (error) {
      debugPrint('Push registration unavailable: ${error.runtimeType}');
    }
  }

  static Future<void> unregisterCurrentDevice() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null || kIsWeb) return;
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await sharedApiClient.delete<dynamic>(
          '$onaNetApiBaseUrl/notifications/devices',
          data: {'token': token},
          options: Options(
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          ),
        );
      }
      await _messaging.deleteToken();
    } catch (error) {
      debugPrint('Push cleanup unavailable: ${error.runtimeType}');
    }
  }

  static Future<void> _registerToken(String token) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    try {
      final package = await PackageInfo.fromPlatform();
      await sharedApiClient.post<dynamic>(
        '$onaNetApiBaseUrl/notifications/devices',
        data: {
          'token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'app_version': '${package.version}+${package.buildNumber}',
        },
        options: Options(
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        ),
      );
    } catch (error) {
      debugPrint('Push token sync failed: ${error.runtimeType}');
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: message.messageId.hashCode,
      title: notification.title ?? 'OnaNet',
      body: notification.body ?? 'You have a new update.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'onanet_updates',
          'OnaNet updates',
          channelDescription:
              'Installation, provider and account updates from OnaNet.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data['route']?.toString(),
    );
  }

  static Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _authSubscription?.cancel();
    _initialised = false;
  }
}
