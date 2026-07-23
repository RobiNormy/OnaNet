import 'dart:io';

import 'package:csv/csv.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ona_net/services/api_client.dart';
import 'package:share_plus/share_plus.dart';

class ProAnalyticsService {
  ProAnalyticsService({Dio? dio, String? apiBaseUrl})
    : _dio = dio ?? sharedApiClient,
      _apiBaseUrl = apiBaseUrl ?? onaNetApiBaseUrl;

  final Dio _dio;
  final String _apiBaseUrl;

  String _url(String path) {
    final base = Uri.parse(_apiBaseUrl);
    return (base.path.endsWith('/')
            ? base
            : base.replace(path: '${base.path}/'))
        .resolve(path.replaceFirst(RegExp(r'^/+'), ''))
        .toString();
  }

  Future<Options> _options() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> load() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _url('/providers/me/pro-analytics'),
        options: await _options(),
      );
      return response.data ?? const {};
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? e.response?.data['detail']?.toString()
          : null;
      throw ProAnalyticsException(
        detail ?? e.message ?? 'Could not load Pro Analytics.',
      );
    }
  }

  Future<Map<String, dynamic>> comparePackagesByArea(String area) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _url('/providers/me/pro-analytics/package-comparison'),
        queryParameters: {'area': area.trim()},
        options: await _options(),
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      final detail = error.response?.data is Map
          ? error.response?.data['detail']?.toString()
          : null;
      throw ProAnalyticsException(
        detail ?? error.message ?? 'Could not compare packages for this area.',
      );
    }
  }

  Future<void> logSearch({
    required List<Map<String, dynamic>> providers,
    String? queryText,
    String? area,
    double? latitude,
    double? longitude,
    int? speedMbps,
    String? filterName,
  }) async {
    final results = <Map<String, dynamic>>[];
    for (var i = 0; i < providers.length; i++) {
      final id = providers[i]['id']?.toString();
      if (id != null && id.isNotEmpty) {
        results.add({'provider_id': id, 'position': i + 1});
      }
    }
    if (results.isEmpty) return;
    try {
      await _dio.post<dynamic>(
        _url('/telemetry/search'),
        data: {
          'query_text': queryText,
          'area_name': area,
          'latitude': latitude,
          'longitude': longitude,
          'speed_filter_mbps': speedMbps,
          'filter_name': filterName,
          'results': results,
        },
      );
    } catch (_) {
      // Telemetry must never block customer discovery.
    }
  }

  Future<void> logView({
    required String providerId,
    required String viewType,
    String? area,
    String? packageId,
  }) async {
    try {
      await _dio.post<dynamic>(
        _url('/telemetry/view'),
        data: {
          'provider_id': providerId,
          'view_type': viewType,
          'area_name': area,
          'package_id': packageId,
        },
      );
    } catch (_) {}
  }

  Future<void> exportMonthlyPdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final funnel = (data['funnel'] as List? ?? const []).whereType<Map>();
    final revenue = Map<String, dynamic>.from(data['revenue'] as Map? ?? {});
    final market = Map<String, dynamic>.from(
      data['market_share'] as Map? ?? {},
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            '${data['provider_name']} · Monthly Business Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(data['period']?.toString() ?? ''),
          pw.SizedBox(height: 18),
          pw.Text(
            'Conversion Funnel',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.TableHelper.fromTextArray(
            headers: const ['Stage', 'Count', 'Drop-off', 'Platform avg'],
            data: funnel
                .map(
                  (x) => [
                    x['label'],
                    x['value'],
                    '${_n(x['drop_off'])}%',
                    '${_n(x['platform_average'])}%',
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 18),
          pw.Text('Pipeline forecast: KES ${_money(revenue['pipeline'])}'),
          pw.Text('Trend forecast: KES ${_money(revenue['trend_forecast'])}'),
          pw.Text('Tracked market share: ${_n(market['overall'])}%'),
          pw.SizedBox(height: 14),
          pw.Text(
            'Generated by OnaNet Pro Analytics. Competitor identities are anonymized.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    await _shareBytes(
      await pdf.save(),
      'monthly_business_report.pdf',
      'application/pdf',
    );
  }

  Future<void> exportLeadsCsv(Map<String, dynamic> data) async {
    final leads = (data['exports']?['leads'] as List? ?? const [])
        .whereType<Map>();
    final rows = <List<dynamic>>[
      ['Date', 'Area', 'Package', 'Status', 'Completion date'],
    ];
    rows.addAll(
      leads.map(
        (x) => [
          x['created_at'],
          x['area'],
          x['package_name'],
          x['status'],
          x['completed_at'],
        ],
      ),
    );
    await _shareText(Csv().encode(rows), 'lead_export.csv');
  }

  Future<void> exportRevenueCsv(Map<String, dynamic> data) async {
    final leads = (data['exports']?['leads'] as List? ?? const [])
        .whereType<Map>()
        .where((x) => ['complete', 'completed'].contains(x['status']));
    final rows = <List<dynamic>>[
      [
        'Date',
        'Package',
        'Price',
        'OnaNet commission',
        'Net revenue',
        'Completion date',
      ],
    ];
    rows.addAll(
      leads.map(
        (x) => [
          x['created_at'],
          x['package_name'],
          x['package_price'],
          x['commission_amount'],
          x['net_revenue'],
          x['completed_at'],
        ],
      ),
    );
    await _shareText(Csv().encode(rows), 'revenue_report.csv');
  }

  Future<void> exportInstallersCsv(Map<String, dynamic> data) async {
    final installers = (data['exports']?['installers'] as List? ?? const [])
        .whereType<Map>();
    final rows = <List<dynamic>>[
      ['Installer', 'Jobs', 'Completed', 'Average days'],
    ];
    rows.addAll(
      installers.map(
        (x) => [x['installer'], x['jobs'], x['completed'], x['avg_days']],
      ),
    );
    await _shareText(Csv().encode(rows), 'installer_performance.csv');
  }

  Future<void> _shareText(String content, String filename) async {
    await _shareBytes(
      Uint8List.fromList(content.codeUnits),
      filename,
      'text/csv',
    );
  }

  Future<void> _shareBytes(
    Uint8List bytes,
    String filename,
    String mime,
  ) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mime)],
        title: filename,
      ),
    );
  }

  static String _money(dynamic value) =>
      (value as num? ?? 0).toStringAsFixed(0);
  static String _n(dynamic value) => (value as num? ?? 0).toStringAsFixed(1);
}

class ProAnalyticsException implements Exception {
  const ProAnalyticsException(this.message);
  final String message;
  @override
  String toString() => message;
}
