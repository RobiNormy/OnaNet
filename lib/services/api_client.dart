import 'package:dio/dio.dart';

const String onaNetProductionApiUrl =
    'https://onanet-production.up.railway.app';

const String onaNetApiBaseUrl = String.fromEnvironment(
  'ONA_NET_API_BASE_URL',
  defaultValue: onaNetProductionApiUrl,
);

/// A single HTTP client shared by API services so connections can be reused.
final Dio sharedApiClient = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ),
);
