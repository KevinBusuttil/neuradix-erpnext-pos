import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../data/remote/frappe_client.dart';
import '../data/repositories/invoice_repository.dart';

/// Flushes the outbound invoice queue when connectivity returns.
///
/// Submission is idempotent: each queued invoice carries a
/// `custom_neuropos_uuid`, so a retried submit returns the already-created
/// Sales Invoice rather than duplicating it (see `ccj` `submit_sales_invoice`).
class SyncManager {
  SyncManager(this._client, this._invoices);

  final FrappeClient _client;
  final InvoiceRepository _invoices;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _flushing = false;

  void start() {
    _sub ??= Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) unawaited(flush());
    });
    unawaited(flush());
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Attempt to submit every queued/errored invoice, oldest first. Stops on the
  /// first hard failure to avoid thrashing; the connectivity listener retries.
  Future<int> flush() async {
    if (_flushing) return 0;
    _flushing = true;
    var ok = 0;
    try {
      for (final row in await _invoices.pending()) {
        try {
          final doc = _invoices.decode(row);
          final res = await _client.submitSalesInvoice(doc);
          final name = res['name'] as String?;
          if (name == null) throw StateError('No invoice name returned');
          await _invoices.markSynced(row.localUuid, name);
          ok++;
        } catch (e) {
          await _invoices.markError(row.localUuid, e.toString());
          break;
        }
      }
    } finally {
      _flushing = false;
    }
    return ok;
  }
}
