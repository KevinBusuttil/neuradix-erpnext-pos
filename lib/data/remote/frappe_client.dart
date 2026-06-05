import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';

/// A clean, human-readable error parsed from a Frappe response.
class FrappeException implements Exception {
  FrappeException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Thin wrapper over the Frappe/ERPNext REST + whitelisted-method API.
///
/// Authentication uses a token pair (`Authorization: token <key>:<secret>`),
/// which is preferred over a session cookie because it survives long offline
/// periods. All POS reads/writes go through here while online.
class FrappeClient {
  FrappeClient(this._config) : _dio = Dio();

  final AppConfig _config;
  final Dio _dio;

  Future<void> _ensureBase() async {
    final url = await _config.siteUrl;
    final key = await _config.apiKey;
    final secret = await _config.apiSecret;
    if (url == null || url.isEmpty) {
      throw StateError('Site URL not configured');
    }
    _dio.options
      ..baseUrl = url
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 60)
      ..headers['Content-Type'] = 'application/json'
      ..headers['X-Frappe-CSRF-Token'] = '';
    if (key != null && secret != null) {
      _dio.options.headers['Authorization'] = 'token $key:$secret';
    }
  }

  /// Turn a DioException into a [FrappeException] carrying the server's actual
  /// message (`_server_messages` / `exception`) instead of an opaque HTTP code.
  Never _rethrow(DioException e) {
    final data = e.response?.data;
    final code = e.response?.statusCode;
    String? msg;
    if (data is Map) {
      // _server_messages is a JSON string of a list of JSON strings.
      final sm = data['_server_messages'];
      if (sm is String && sm.isNotEmpty) {
        try {
          final list = (jsonDecode(sm) as List)
              .map((e) => jsonDecode(e as String) as Map)
              .map((m) => (m['message'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .toList();
          if (list.isNotEmpty) msg = list.join('\n');
        } catch (_) {}
      }
      msg ??= (data['exception'] ?? data['_error_message'] ?? data['message'])
          ?.toString();
    }
    msg = _stripHtml(msg ?? e.message ?? 'Request failed');
    throw FrappeException(msg, statusCode: code);
  }

  String _stripHtml(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  /// Call a whitelisted server method: `/api/method/<dotted.path>`.
  Future<dynamic> call(
    String method, {
    Map<String, dynamic>? args,
    bool post = false,
  }) async {
    await _ensureBase();
    final path = '/api/method/$method';
    try {
      final res = post
          ? await _dio.post<Map<String, dynamic>>(path, data: args)
          : await _dio.get<Map<String, dynamic>>(path, queryParameters: args);
      return res.data?['message'];
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  /// Generic resource list: `/api/resource/<DocType>`.
  Future<List<dynamic>> list(
    String doctype, {
    Map<String, dynamic>? filters,
    List<String>? fields,
    int limit = 50,
  }) async {
    await _ensureBase();
    try {
      // Frappe's REST API expects `filters` / `fields` as JSON-encoded strings.
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/resource/$doctype',
        queryParameters: {
          if (filters != null) 'filters': jsonEncode(filters),
          if (fields != null) 'fields': jsonEncode(fields),
          'limit_page_length': limit,
        },
      );
      return (res.data?['data'] as List<dynamic>?) ?? const [];
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  /// List POS Profile names available to the user.
  Future<List<String>> listProfiles() async {
    final rows = await list('POS Profile',
        filters: {'disabled': 0}, fields: ['name'], limit: 50);
    return rows.map((e) => (e as Map)['name'] as String).toList();
  }

  /// A single field value from a doc (uses frappe.client.get_value).
  Future<dynamic> getValue(
      String doctype, String name, String fieldname) async {
    final msg = await call('frappe.client.get_value', args: {
      'doctype': doctype,
      'filters': name,
      'fieldname': fieldname,
    });
    return (msg as Map?)?[fieldname];
  }

  // ---- POS-specific convenience methods (mirror the Mobile POS page) ----

  Future<Map<String, dynamic>> snapshotPull(String posProfile) async {
    final msg = await call('ccj.neuropos.snapshot.pull',
        args: {'pos_profile': posProfile});
    return Map<String, dynamic>.from(msg as Map);
  }

  Future<List<dynamic>> getItems({
    required String posProfile,
    required String priceList,
    String searchTerm = '',
    int start = 0,
    int pageLength = 34,
  }) async {
    final msg = await call(
      'ccj.ccj.page.mobile_pos.mobile_pos.get_items',
      args: {
        'start': start,
        'page_length': pageLength,
        'price_list': priceList,
        'pos_profile': posProfile,
        'search_term': searchTerm,
      },
    );
    return (msg?['items'] as List<dynamic>?) ?? const [];
  }

  Future<dynamic> getStockAvailability(String itemCode, String warehouse) {
    return call(
      'erpnext.accounts.doctype.pos_invoice.pos_invoice.get_stock_availability',
      args: {'item_code': itemCode, 'warehouse': warehouse},
    );
  }

  Future<Map<String, dynamic>> computeTaxes(Map<String, dynamic> doc) async {
    final msg = await call(
      'ccj.ccj.page.mobile_pos.mobile_pos.compute_si_taxes',
      args: {'doc_json': doc},
      post: true,
    );
    return Map<String, dynamic>.from(msg as Map);
  }

  Future<Map<String, dynamic>> submitSalesInvoice(
      Map<String, dynamic> doc) async {
    final msg = await call(
      'ccj.ccj.page.mobile_pos.mobile_pos.submit_sales_invoice',
      args: {'doc': doc},
      post: true,
    );
    return Map<String, dynamic>.from(msg as Map);
  }

  Future<List<dynamic>> checkOpeningEntry(String user) async {
    final msg = await call(
      'erpnext.selling.page.point_of_sale.point_of_sale.check_opening_entry',
      args: {'user': user},
    );
    return (msg as List<dynamic>?) ?? const [];
  }
}
