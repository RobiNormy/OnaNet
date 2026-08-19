// Supabase authentication and authenticated OnaNet API operations.
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:ona_net/core/network/api_client.dart';
import 'package:ona_net/core/notifications/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EmailNotVerifiedException extends AuthServiceException {
  const EmailNotVerifiedException()
    : super('Verify your email before signing in.');
}

class AuthService {
  AuthService({Dio? dio, String? apiBaseUrl})
    : _dio = dio ?? sharedApiClient,
      _apiBaseUrl = apiBaseUrl ?? onaNetApiBaseUrl;

  final GoTrueClient _auth = Supabase.instance.client.auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final Dio _dio;
  final String _apiBaseUrl;

  static const _providerCacheTtl = Duration(minutes: 1);
  static final Map<String, _ProviderCatalogCache> _providerCaches = {};

  Stream<User?> get authStateChanges =>
      _auth.onAuthStateChange.map((state) => state.session?.user);

  User? get currentUser => _auth.currentUser;

  Future<AuthResponse?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthServiceException(
          'Google sign-in did not return a secure identity token.',
        );
      }
      final response = await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      final accessToken = response.session?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw const AuthServiceException(
          'Google sign-in could not be verified. Please try again.',
        );
      }
      await _dio.post<dynamic>(
        _url('/auth/session'),
        data: {'token': accessToken},
      );
      return response;
    } on AuthException catch (e) {
      throw AuthServiceException(_supabaseErrorMessage(e));
    } on DioException catch (e) {
      await _auth.signOut();
      throw AuthServiceException(_errorMessage(e));
    } catch (e) {
      if (e is AuthServiceException) rethrow;
      throw AuthServiceException('Google sign-in failed: $e');
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'first_name': firstName?.trim(),
          'last_name': lastName?.trim(),
          'full_name': [firstName, lastName]
              .whereType<String>()
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .join(' '),
        },
        emailRedirectTo:
            'https://onanet.app/verify-email?source=email-verification',
      );
      final accessToken = response.session?.accessToken;
      if (accessToken != null && accessToken.isNotEmpty) {
        await _dio.post<dynamic>(
          _url('/auth/session'),
          data: {'token': accessToken},
        );
      }
    } on AuthException catch (e) {
      throw AuthServiceException(_supabaseErrorMessage(e));
    } on DioException catch (e) {
      throw AuthServiceException(_errorMessage(e));
    } catch (e) {
      throw AuthServiceException('Sign-up failed: $e');
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final accessToken = response.session?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw const AuthServiceException('Sign-in did not create a session.');
      }
      await _dio.post<dynamic>(
        _url('/auth/session'),
        data: {'token': accessToken},
      );
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        throw const EmailNotVerifiedException();
      }
      throw AuthServiceException(_supabaseErrorMessage(e));
    } on DioException catch (e) {
      await _auth.signOut();
      throw AuthServiceException(_errorMessage(e));
    }
  }

  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'https://onanet.app/reset-password',
      );
    } on AuthException catch (e) {
      throw AuthServiceException(_supabaseErrorMessage(e));
    }
  }

  Future<void> startEmailVerification({required String email}) async {
    try {
      await _auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo:
            'https://onanet.app/verify-email?source=email-verification',
      );
    } on AuthException catch (error) {
      throw AuthServiceException(_supabaseErrorMessage(error));
    }
  }

  Future<bool> completeEmailVerification() async {
    try {
      if (_auth.currentSession != null) await _auth.refreshSession();
      final user = _auth.currentUser;
      final token = _auth.currentSession?.accessToken;
      if (user?.emailConfirmedAt == null || token == null || token.isEmpty) {
        return false;
      }
      await _dio.post<dynamic>(_url('/auth/session'), data: {'token': token});
      return true;
    } on AuthException catch (error) {
      throw AuthServiceException(_supabaseErrorMessage(error));
    } on DioException catch (error) {
      throw AuthServiceException(_errorMessage(error));
    }
  }

  Future<Map<String, dynamic>> getMyAccount() async {
    final response = await _getJson('/auth/me');
    return _asMap(response.data);
  }

  Future<void> syncCurrentSession() async {
    final token = _auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const AuthServiceException('Please sign in again.');
    }
    try {
      await _dio.post<dynamic>(_url('/auth/session'), data: {'token': token});
    } on DioException catch (error) {
      throw AuthServiceException(_errorMessage(error));
    }
  }

  Future<Map<String, dynamic>> getAdminSnapshot() async {
    final response = await _getJson('/admin/snapshot');
    return _asMap(response.data);
  }

  Future<void> reviewAdminDocument(
    String documentId, {
    required String status,
  }) async {
    try {
      await _dio.patch<dynamic>(
        _url('/admin/documents/$documentId'),
        data: {'status': status},
        options: await _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw AuthServiceException(_errorMessage(error));
    }
  }

  Future<void> moderateAdminProvider(
    String providerId, {
    required String status,
    String? reason,
  }) async {
    try {
      await _dio.patch<dynamic>(
        _url('/admin/providers/$providerId/moderation'),
        data: {'status': status, 'reason': reason},
        options: await _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw AuthServiceException(_errorMessage(error));
    }
  }

  Future<void> adminAction(
    String path, {
    required String action,
    String? reason,
    String? value,
  }) async {
    try {
      await _dio.post<dynamic>(
        _url('/admin$path'),
        data: {'action': action, 'reason': reason, 'value': value},
        options: await _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw AuthServiceException(_errorMessage(error));
    }
  }

  Future<void> updateAdminPackage(String id, bool available) async {
    try {
      await _dio.patch<dynamic>(
        _url('/admin/packages/$id'),
        data: {'action': 'availability', 'value': available.toString()},
        options: await _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw AuthServiceException(_errorMessage(error));
    }
  }

  Future<Map<String, dynamic>> updateMyAccount({
    required String firstName,
    required String lastName,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        _url('/auth/me'),
        data: {'first_name': firstName.trim(), 'last_name': lastName.trim()},
        options: await _authorizedOptions(),
      );
      final displayName = [
        firstName,
        lastName,
      ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
      if (displayName.isNotEmpty) {
        await _auth.updateUser(
          UserAttributes(
            data: {
              'first_name': firstName.trim(),
              'last_name': lastName.trim(),
              'full_name': displayName,
            },
          ),
        );
      }
      return _asMap(response.data);
    } on AuthException catch (error) {
      throw AuthServiceException(_supabaseErrorMessage(error));
    } on DioException catch (error) {
      throw AuthServiceException(_errorMessage(error));
    }
  }

  Future<void> requestEmailChange(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException('Please sign in again.');
    }
    try {
      await _auth.updateUser(UserAttributes(email: newEmail.trim()));
    } on AuthException catch (error) {
      throw AuthServiceException(_supabaseErrorMessage(error));
    }
  }

  Future<String?> refreshAccountEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException('Please sign in again.');
    }
    try {
      await _auth.refreshSession();
      await getMyAccount();
      return _auth.currentUser?.email;
    } on AuthException catch (error) {
      throw AuthServiceException(_supabaseErrorMessage(error));
    } on DioException catch (error) {
      throw AuthServiceException(_errorMessage(error));
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthServiceException('Please sign in again.');
    }
    try {
      await _auth.signInWithPassword(email: email, password: currentPassword);
      await _auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (error) {
      throw AuthServiceException(_supabaseErrorMessage(error));
    }
  }

  Future<void> deleteMyAccount({String? password}) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthServiceException('Please sign in again.');
    }
    try {
      final usesPassword =
          user.identities?.any((identity) => identity.provider == 'email') ??
          false;
      if (usesPassword) {
        if (password == null || password.isEmpty) {
          throw const AuthServiceException(
            'Enter your password to delete the account.',
          );
        }
        await _auth.signInWithPassword(email: email, password: password);
      }

      await _postJson('/auth/me/delete', {'confirmation': 'DELETE'});
      await _auth.signOut();
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    } on AuthException catch (error) {
      throw AuthServiceException(_supabaseErrorMessage(error));
    } on DioException catch (error) {
      throw AuthServiceException(_errorMessage(error));
    }
  }

  bool get currentUserUsesPassword {
    return _auth.currentUser?.identities?.any(
          (identity) => identity.provider == 'email',
        ) ??
        false;
  }

  bool get currentUserUsesGoogle {
    return _auth.currentUser?.identities?.any(
          (identity) => identity.provider == 'google',
        ) ??
        false;
  }

  String? get currentUserDisplayName {
    final metadata = _auth.currentUser?.userMetadata;
    return (metadata?['full_name'] ?? metadata?['name'])?.toString();
  }

  Future<List<Map<String, dynamic>>> getMyReviews() async {
    final response = await _getJson('/reviews/me');
    return _asMapList(response.data);
  }

  Future<void> submitReport({
    required String providerId,
    String? reviewId,
    required String reason,
    required String details,
  }) async {
    try {
      await _postJson('/reviews/report', {
        'target_type': reviewId == null ? 'provider' : 'review',
        'provider_id': providerId,
        'review_id': reviewId,
        'reason': reason,
        'details': details.trim(),
      });
    } on DioException catch (error) {
      throw AuthServiceException(_errorMessage(error));
    }
  }

  Future<String?> getAuthAccessToken() async =>
      _auth.currentSession?.accessToken;

  @Deprecated('Use getAuthAccessToken')
  Future<String?> getFirebaseIdToken() => getAuthAccessToken();

  Future<Map<String, dynamic>> submitProviderRegistration(
    Map<String, dynamic> payload,
  ) async {
    final response = await _postJson('/providers/register', payload);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getMyProvider() async {
    final provider = await findMyProvider();
    if (provider == null) {
      throw const AuthServiceException(
        'Provider profile not found for this account.',
      );
    }
    return provider;
  }

  Future<Map<String, dynamic>?> findMyProvider() async {
    try {
      final response = await _dio.get<dynamic>(
        _url('/providers/me'),
        options: await _authorizedOptions(),
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw AuthServiceException(_errorMessage(error));
    }
  }

  Future<Map<String, dynamic>> getProviderDashboardData() async {
    final provider = await getMyProvider();
    final providerId = provider['id']?.toString();
    if (providerId == null || providerId.isEmpty) {
      throw const AuthServiceException(
        'Provider profile did not include a provider ID.',
      );
    }

    try {
      final dashboard = await getDashboard(providerId);
      return {...provider, ...dashboard, 'id': providerId};
    } on AuthServiceException catch (error) {
      if (!error.message.toLowerCase().contains(
        'permission to view dashboard',
      )) {
        rethrow;
      }
      return {...provider, 'id': providerId};
    }
  }

  Future<Map<String, dynamic>> getProviderAccountAccess() async {
    final response = await _getJson('/provider-staff/me');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getProviderStaffAccounts() async {
    final response = await _getJson('/provider-staff');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> createProviderStaffAccount(
    Map<String, dynamic> payload,
  ) async {
    final response = await _postJson('/provider-staff', payload);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> updateProviderStaffAccount(
    String staffId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.patch<dynamic>(
        _url('/provider-staff/$staffId'),
        data: payload,
        options: await _authorizedOptions(),
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw AuthServiceException(_errorMessage(error));
    }
  }

  Future<List<Map<String, dynamic>>> getPublicProviders({
    bool forceRefresh = false,
  }) async {
    final cacheKey = _apiBaseUrl.trim();
    final cache = _providerCaches.putIfAbsent(
      cacheKey,
      _ProviderCatalogCache.new,
    );
    final now = DateTime.now();

    if (forceRefresh) {
      cache.data = null;
      cache.loadedAt = null;
    } else if (cache.data != null &&
        cache.loadedAt != null &&
        now.difference(cache.loadedAt!) < _providerCacheTtl) {
      return cache.data!;
    }

    final pending = cache.pending;
    if (pending != null) return pending;

    final request = _fetchPublicProviders();
    cache.pending = request;
    try {
      final providers = await request;
      cache.data = providers;
      cache.loadedAt = DateTime.now();
      return providers;
    } finally {
      if (identical(cache.pending, request)) cache.pending = null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPublicProviders() async {
    final response = await _getJson('/providers');
    return _asMapList(response.data);
  }

  Future<void> uploadProviderLogo({
    required String providerId,
    required PlatformFile file,
    required double logoDisplaySize,
    required double logoOffsetX,
    required double logoOffsetY,
  }) async {
    await _postMultipart(
      '/providers/$providerId/logo',
      fileFieldName: 'file',
      file: file,
      fields: {
        'logo_display_size': logoDisplaySize.toString(),
        'logo_offset_x': logoOffsetX.toString(),
        'logo_offset_y': logoOffsetY.toString(),
      },
    );
  }

  Future<void> submitProviderCoverageAreas({
    required String providerId,
    required Map<String, dynamic> payload,
  }) async {
    await _postJson('/providers/$providerId/coverage-areas', payload);
  }

  Future<void> submitProviderContacts({
    required String providerId,
    required Map<String, dynamic> payload,
  }) async {
    await _postJson('/providers/$providerId/contacts', payload);
  }

  Future<Map<String, dynamic>> getDashboard(String providerId) async {
    final response = await _getJson('/providers/$providerId/dashboard');
    return _asMap(response.data);
  }

  Future<void> submitProviderServices({
    required String providerId,
    required Map<String, dynamic> payload,
  }) async {
    await _postJson('/providers/$providerId/services', payload);
  }

  Future<void> submitProviderPackage({
    required String providerId,
    required Map<String, dynamic> payload,
  }) async {
    await _postJson('/providers/$providerId/packages', payload);
  }

  Future<Map<String, dynamic>> completeProviderRegistration(
    String providerId,
  ) async {
    final response = await _postJson(
      '/providers/$providerId/complete-registration',
      const {},
    );
    return _asMap(response.data);
  }

  Future<List<Map<String, dynamic>>> getProviderPackages(
    String providerId,
  ) async {
    final response = await _getJson('/providers/$providerId/packages');
    return _asMapList(response.data);
  }

  Future<void> updateProviderPackage(
    String providerId,
    String packageId,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _dio.patch<dynamic>(
        _url('/providers/$providerId/packages/$packageId'),
        data: payload,
        options: await _authorizedOptions(),
      );
    } on DioException catch (e) {
      throw AuthServiceException(_errorMessage(e));
    }
  }

  Future<void> deleteProviderPackage(
    String providerId,
    String packageId,
  ) async {
    try {
      await _dio.delete<dynamic>(
        _url('/providers/$providerId/packages/$packageId'),
        options: await _authorizedOptions(),
      );
    } on DioException catch (e) {
      throw AuthServiceException(_errorMessage(e));
    }
  }

  Future<List<Map<String, dynamic>>> getProviderCoverageAreas(
    String providerId,
  ) async {
    final response = await _getJson('/providers/$providerId/coverage-areas');
    return _asMapList(response.data);
  }

  Future<List<Map<String, dynamic>>> getProviderCustomers() async {
    final response = await _getJson('/providers/me/customers');
    return _asMapList(response.data);
  }

  Future<List<Map<String, dynamic>>> getProviderReviews() async {
    final response = await _getJson('/providers/me/reviews');
    return _asMapList(response.data);
  }

  Future<void> uploadProviderDocument({
    required String providerId,
    required String documentType,
    required PlatformFile file,
  }) async {
    await _postMultipart(
      '/providers/$providerId/documents',
      fileFieldName: 'file',
      file: file,
      fields: {'document_type': documentType},
    );
  }

  Future<List<Map<String, dynamic>>> getProviderDocuments() async {
    final response = await _getJson('/providers/me/documents');
    return _asMapList(response.data);
  }

  Future<void> signOut() async {
    await PushNotificationService.unregisterCurrentDevice();
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Future<Response<dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _dio.post<dynamic>(
        _url(path),
        data: payload,
        options: await _authorizedOptions(),
      );
    } on DioException catch (e) {
      throw AuthServiceException(_errorMessage(e));
    }
  }

  Future<Response<dynamic>> _getJson(String path) async {
    try {
      return await _dio.get<dynamic>(
        _url(path),
        options: await _authorizedOptions(),
      );
    } on DioException catch (e) {
      throw AuthServiceException(_errorMessage(e));
    }
  }

  Future<Response<dynamic>> _postMultipart(
    String path, {
    required String fileFieldName,
    required PlatformFile file,
    required Map<String, String> fields,
  }) async {
    try {
      final formData = FormData.fromMap({
        ...fields,
        fileFieldName: await _multipartFile(file),
      });
      return await _dio.post<dynamic>(
        _url(path),
        data: formData,
        options: await _authorizedOptions(),
      );
    } on DioException catch (e) {
      throw AuthServiceException(_errorMessage(e));
    }
  }

  Future<Options> _authorizedOptions() async {
    final token = await getAuthAccessToken();
    return Options(
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
  }

  Future<MultipartFile> _multipartFile(PlatformFile file) async {
    final mediaType = _mediaTypeFor(file.name);
    final path = file.path;
    if (path != null &&
        !path.startsWith('blob:') &&
        !path.startsWith('data:')) {
      return MultipartFile.fromFile(
        path,
        filename: file.name,
        contentType: mediaType,
      );
    }

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw const AuthServiceException('Could not read the selected file.');
    }

    return MultipartFile.fromBytes(
      bytes,
      filename: file.name,
      contentType: mediaType,
    );
  }

  MediaType? _mediaTypeFor(String fileName) {
    final mimeType = lookupMimeType(fileName);
    if (mimeType == null) return null;
    final parts = mimeType.split('/');
    if (parts.length != 2) return null;
    return MediaType(parts[0], parts[1]);
  }

  String _url(String path) {
    if (_apiBaseUrl.trim().isEmpty) {
      throw const AuthServiceException(
        'The OnaNet API address is not configured.',
      );
    }
    final base = Uri.parse(_apiBaseUrl);
    final normalizedBase = base.path.endsWith('/')
        ? base
        : base.replace(path: '${base.path}/');
    return normalizedBase
        .resolve(path.replaceFirst(RegExp(r'^/+'), ''))
        .toString();
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const AuthServiceException('The API returned an invalid response.');
  }

  List<Map<String, dynamic>> _asMapList(dynamic data) {
    if (data is List) {
      return data.map((item) {
        if (item is Map<String, dynamic>) return item;
        if (item is Map) return Map<String, dynamic>.from(item);
        throw const AuthServiceException(
          'The API returned an invalid provider item.',
        );
      }).toList();
    }
    throw const AuthServiceException('The API returned an invalid response.');
  }

  String _supabaseErrorMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return 'That email is already registered.';
    }
    if (message.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (message.contains('email not confirmed')) {
      return 'Verify your email before signing in.';
    }
    if (message.contains('password') && message.contains('weak')) {
      return 'Please choose a stronger password.';
    }
    if (message.contains('rate') || message.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return error.message;
  }

  String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['error'] ?? data['detail'];
      if (message != null) return message.toString();
    }
    if (data is String && data.trim().isNotEmpty) return data;
    return error.message ?? 'Request failed.';
  }
}

class _ProviderCatalogCache {
  List<Map<String, dynamic>>? data;
  DateTime? loadedAt;
  Future<List<Map<String, dynamic>>>? pending;
}
