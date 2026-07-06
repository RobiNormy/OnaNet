import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({Dio? dio, String? apiBaseUrl})
    : _dio = dio ?? Dio(),
      _apiBaseUrl =
          apiBaseUrl ?? const String.fromEnvironment('ONA_NET_API_BASE_URL');

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final Dio _dio;
  final String _apiBaseUrl;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      return _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_firebaseErrorMessage(e));
    } catch (e) {
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
      await _dio.post<dynamic>(
        _url('/auth/signup'),
        data: {
          'email': email.trim(),
          'password': password,
          'first_name': firstName?.trim(),
          'last_name': lastName?.trim(),
        },
      );

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final displayName = [firstName, lastName]
          .where((part) => part != null && part.trim().isNotEmpty)
          .map((part) => part!.trim())
          .join(' ');
      if (displayName.isNotEmpty) {
        await credential.user?.updateDisplayName(displayName);
      }
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_firebaseErrorMessage(e));
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
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_firebaseErrorMessage(e));
    }
  }

  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_firebaseErrorMessage(e));
    }
  }

  Future<String?> getFirebaseIdToken() async => _auth.currentUser?.getIdToken();

  Future<Map<String, dynamic>> submitProviderRegistration(
    Map<String, dynamic> payload,
  ) async {
    final response = await _postJson('/providers/register', payload);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getMyProvider() async {
    final response = await _getJson('/providers/me');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getProviderDashboardData() async {
    final provider = await getMyProvider();
    final providerId = provider['id']?.toString();
    if (providerId == null || providerId.isEmpty) {
      throw const AuthServiceException(
        'Provider profile did not include a provider ID.',
      );
    }

    return getDashboard(providerId);
  }

  Future<List<Map<String, dynamic>>> getPublicProviders() async {
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

  Future<void> signOut() => _auth.signOut();

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
    final token = await getFirebaseIdToken();
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
        'ONA_NET_API_BASE_URL is not configured. Run Flutter with '
        '--dart-define=ONA_NET_API_BASE_URL=http://<computer-lan-ip>:8000. '
        'On a physical phone, do not use localhost.',
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

  String _firebaseErrorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' => 'That email is already registered.',
      'invalid-email' => 'Please enter a valid email address.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' => 'No account was found for that email.',
      'wrong-password' || 'invalid-credential' => 'Invalid email or password.',
      'weak-password' => 'Please choose a stronger password.',
      'network-request-failed' => 'Network error. Please try again.',
      _ => error.message ?? 'Authentication failed.',
    };
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
