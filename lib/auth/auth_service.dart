import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class AuthService {
  AuthService() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getFirebaseIdToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static String get apiBaseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredUrl.isNotEmpty) {
      return configuredUrl;
    }

    return kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final userCred = await _auth.signInWithCredential(credential);

      try {
        await syncCurrentUserWithApi(authProvider: 'google');
      } on AuthServiceException {
        await _googleSignIn.signOut();
        await _auth.signOut();
        rethrow;
      }
      return userCred;
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_firebaseAuthMessage(e));
    } on AuthServiceException {
      rethrow;
    } catch (e) {
      throw AuthServiceException("Google sign in failed: $e");
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final displayName = _buildDisplayName(firstName, lastName);
      if (displayName != null) {
        await userCred.user?.updateDisplayName(displayName);
      }

      await syncCurrentUserWithApi(
        authProvider: 'password',
        extraProfile: {
          if (firstName != null && firstName.trim().isNotEmpty)
            'first_name': firstName.trim(),
          if (lastName != null && lastName.trim().isNotEmpty)
            'last_name': lastName.trim(),
        },
      );
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_firebaseAuthMessage(e));
    } on AuthServiceException {
      rethrow;
    } catch (e) {
      throw AuthServiceException("Email signup failed: $e");
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

      await syncCurrentUserWithApi(authProvider: 'password');
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_firebaseAuthMessage(e));
    } on AuthServiceException {
      rethrow;
    } catch (e) {
      throw AuthServiceException("Email sign in failed: $e");
    }
  }

  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_firebaseAuthMessage(e));
    } catch (e) {
      throw AuthServiceException("Password reset failed: $e");
    }
  }

  Future<String?> getFirebaseIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  Future<Map<String, dynamic>?> syncCurrentUserWithApi({
    required String authProvider,
    Map<String, dynamic>? extraProfile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    final names = _splitDisplayName(user.displayName);
    final payload = {
      'firebase_uid': user.uid,
      'email': user.email,
      'phone_number': user.phoneNumber,
      'profile_image_url': user.photoURL,
      'auth_provider': authProvider,
      'role': 'user',
      'is_phone_verified': user.phoneNumber != null,
      'is_profile_complete': _isProfileComplete(user, extraProfile),
      if (names.$1 != null) 'first_name': names.$1,
      if (names.$2 != null) 'last_name': names.$2,
      ...?extraProfile,
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/sync',
        data: payload,
      );

      if (response.statusCode != null && response.statusCode! >= 400) {
        throw AuthServiceException(_extractErrorMessage(response.data));
      }

      return response.data;
    } on DioException catch (e) {
      throw AuthServiceException(_extractDioErrorMessage(e));
    }
  }

  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/auth/me');

    if (response.statusCode != null && response.statusCode! >= 400) {
      throw AuthServiceException(_extractErrorMessage(response.data));
    }

    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> submitProviderRegistration(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/providers/register',
        data: payload,
      );

      if (response.statusCode != null && response.statusCode! >= 400) {
        throw AuthServiceException(_extractErrorMessage(response.data));
      }

      return response.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw AuthServiceException(_extractDioErrorMessage(e));
    }
  }

  Future<List<dynamic>> submitProviderServices({
    required String providerId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _dio.post<List<dynamic>>(
        '/providers/$providerId/services',
        data: payload,
      );

      if (response.statusCode != null && response.statusCode! >= 400) {
        throw AuthServiceException(_extractErrorMessage(response.data));
      }

      return response.data ?? <dynamic>[];
    } on DioException catch (e) {
      throw AuthServiceException(_extractDioErrorMessage(e));
    }
  }

  Future<List<dynamic>> submitProviderCoverageAreas({
    required String providerId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _dio.post<List<dynamic>>(
        '/providers/$providerId/coverage-areas',
        data: payload,
      );

      if (response.statusCode != null && response.statusCode! >= 400) {
        throw AuthServiceException(_extractErrorMessage(response.data));
      }

      return response.data ?? <dynamic>[];
    } on DioException catch (e) {
      throw AuthServiceException(_extractDioErrorMessage(e));
    }
  }

  Future<List<dynamic>> submitProviderContacts({
    required String providerId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _dio.post<List<dynamic>>(
        '/providers/$providerId/contacts',
        data: payload,
      );

      if (response.statusCode != null && response.statusCode! >= 400) {
        throw AuthServiceException(_extractErrorMessage(response.data));
      }

      return response.data ?? <dynamic>[];
    } on DioException catch (e) {
      throw AuthServiceException(_extractDioErrorMessage(e));
    }
  }

  Future<Map<String, dynamic>> submitProviderPackage({
    required String providerId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/providers/$providerId/packages',
        data: payload,
      );

      if (response.statusCode != null && response.statusCode! >= 400) {
        throw AuthServiceException(_extractErrorMessage(response.data));
      }

      return response.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw AuthServiceException(_extractDioErrorMessage(e));
    }
  }

  Future<Map<String, dynamic>> uploadProviderDocument({
    required String providerId,
    required String documentType,
    required PlatformFile file,
  }) async {
    try {
      final mimeType =
          lookupMimeType(file.name, headerBytes: file.bytes) ??
          'application/octet-stream';
      final mediaType = MediaType.parse(mimeType);
      final multipartFile = file.path != null
          ? await MultipartFile.fromFile(
              file.path!,
              filename: file.name,
              contentType: mediaType,
            )
          : _multipartFileFromBytes(file, mediaType);

      final formData = FormData.fromMap({
        'document_type': documentType,
        'file': multipartFile,
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/providers/$providerId/documents',
        data: formData,
        options: Options(contentType: Headers.multipartFormDataContentType),
      );

      if (response.statusCode != null && response.statusCode! >= 400) {
        throw AuthServiceException(_extractErrorMessage(response.data));
      }

      return response.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw AuthServiceException(_extractDioErrorMessage(e));
    }
  }

  MultipartFile _multipartFileFromBytes(
    PlatformFile file,
    MediaType mediaType,
  ) {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw AuthServiceException('Could not read ${file.name} for upload.');
    }

    return MultipartFile.fromBytes(
      bytes,
      filename: file.name,
      contentType: mediaType,
    );
  }

  Future<List<dynamic>> getProviderContacts(String providerId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/providers/$providerId/contacts',
      );

      if (response.statusCode != null && response.statusCode! >= 400) {
        throw AuthServiceException(_extractErrorMessage(response.data));
      }

      return response.data ?? <dynamic>[];
    } on DioException catch (e) {
      throw AuthServiceException(_extractDioErrorMessage(e));
    }
  }

  Future<List<dynamic>> getProviderCoverageAreas(String providerId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/providers/$providerId/coverage-areas',
      );

      if (response.statusCode != null && response.statusCode! >= 400) {
        throw AuthServiceException(_extractErrorMessage(response.data));
      }

      return response.data ?? <dynamic>[];
    } on DioException catch (e) {
      throw AuthServiceException(_extractDioErrorMessage(e));
    }
  }

  Future<List<dynamic>> getProviderServices(String providerId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/providers/$providerId/services',
      );

      if (response.statusCode != null && response.statusCode! >= 400) {
        throw AuthServiceException(_extractErrorMessage(response.data));
      }

      return response.data ?? <dynamic>[];
    } on DioException catch (e) {
      throw AuthServiceException(_extractDioErrorMessage(e));
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  static String? _buildDisplayName(String? firstName, String? lastName) {
    final parts = [
      if (firstName != null && firstName.trim().isNotEmpty) firstName.trim(),
      if (lastName != null && lastName.trim().isNotEmpty) lastName.trim(),
    ];

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(' ');
  }

  static (String?, String?) _splitDisplayName(String? displayName) {
    final cleanedName = displayName?.trim();
    if (cleanedName == null || cleanedName.isEmpty) {
      return (null, null);
    }

    final parts = cleanedName.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return (parts.first, null);
    }

    return (parts.first, parts.sublist(1).join(' '));
  }

  static bool _isProfileComplete(
    User user,
    Map<String, dynamic>? extraProfile,
  ) {
    final firstName = extraProfile?['first_name']?.toString().trim();
    final lastName = extraProfile?['last_name']?.toString().trim();
    final hasSignupNames =
        firstName != null &&
        firstName.isNotEmpty &&
        lastName != null &&
        lastName.isNotEmpty;

    return user.email != null &&
        user.email!.trim().isNotEmpty &&
        (hasSignupNames ||
            (user.displayName != null && user.displayName!.trim().isNotEmpty));
  }

  static String _extractErrorMessage(Object? data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'] ?? data['message'] ?? data['error'];
      if (detail != null) {
        return detail.toString();
      }
    }

    return 'Request failed';
  }

  static String _extractDioErrorMessage(DioException error) {
    final responseMessage = _extractErrorMessage(error.response?.data);
    if (responseMessage != 'Request failed') {
      return responseMessage;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Could not reach the API at $apiBaseUrl. Please check that the backend is running and reachable from this device.';
      case DioExceptionType.connectionError:
        return 'Could not connect to the API at $apiBaseUrl. If you are using a real phone, set API_BASE_URL to your computer IP address.';
      case DioExceptionType.badCertificate:
        return 'The API SSL certificate could not be verified.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return error.message ?? 'Request failed';
    }
  }

  static String _firebaseAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'operation-not-allowed':
        return 'This sign-in method is disabled in Firebase. Enable it in Firebase Console > Authentication > Sign-in method.';
      case 'email-already-in-use':
        return 'An account already exists for this email. Try signing in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Please use a stronger password.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'user-not-found':
        return 'No account exists for this email.';
      case 'network-request-failed':
        return 'Firebase could not be reached. Check your internet connection.';
      default:
        return error.message ?? 'Firebase authentication failed.';
    }
  }
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
