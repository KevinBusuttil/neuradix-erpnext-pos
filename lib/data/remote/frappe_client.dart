import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';

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
      ..receiveTimeout = const Duration(seconds: 30)
      ..headers['Content-Type'] = 'application/json';
    if (key != null && secret != null) {
      _dio.options.headers['Authorization'] = 'token $key:$secret';
    }
  }

  /// Call a whitelisted server method: `/api/method/<dotted.path>`.
  Future<dynamic> call(
    String method, {
    Map<String, dynamic>? args,
    bool post = false,
  }) async {
    await _ensureBase();
    final path = '/api/method/$method';
    final res = post
        ? await _dio.post<Map<String, dynamic>>(path, data: args)
        : await _dio.get<Map<String, dynamic>>(path,
            queryParameters: args);
    return res.data?['message'];
  }

  /// Generic resource list: `/api/resource/<DocType>`.
  Future<List<dynamic>> list(
    String doctype, {
    Map<String, dynamic>? filters,
    List<String>? fields,
    int limit = 50,
  }) async {
    await _ensureBase();
    // Frappe's REST API expects `filters` and `fields` as JSON-encoded strings.
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/resource/$doctype',
      queryParameters: {
        if (filters != null) 'filters': jsonEncode(filters),
        if (fields != null) 'fields': jsonEncode(fields),
        'limit_page_length': limit,
      },
    );
    return (res.data?['data'] as List<dynamic>?) ?? const [];
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
