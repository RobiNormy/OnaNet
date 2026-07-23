import 'package:dio/dio.dart';

/// A single HTTP client shared by API services so connections can be reused.
final Dio sharedApiClient = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ),
);
