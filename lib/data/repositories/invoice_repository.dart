import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/database.dart';
import '../local/tables.dart';

/// Owns the lifecycle of locally-held invoices: the working draft and the
/// outbound queue. The full Sales Invoice payload is stored as JSON in
/// `docJson`; structured columns are denormalised for listing/filtering.
class InvoiceRepository {
  InvoiceRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Persist (or replace) the current working draft.
  Future<String> saveDraft(Map<String, dynamic> doc) async {
    final localUuid = (doc['custom_neuropos_uuid'] as String?) ?? _uuid.v4();
    doc['custom_neuropos_uuid'] = localUuid;
    await _db.into(_db.invoices).insertOnConflictUpdate(
          InvoicesCompanion.insert(
            localUuid: localUuid,
            customer: Value(doc['customer'] as String?),
            postingDate: Value(doc['posting_date'] as String?),
            isReturn: Value(doc['is_return'] == 1 || doc['is_return'] == true),
            docJson: jsonEncode(doc),
            syncState: const Value(InvoiceSyncState.draft),
          ),
        );
    return localUuid;
  }

  /// Move a draft into the outbound queue (offline checkout).
  Future<void> enqueue(String localUuid) async {
    await (_db.update(_db.invoices)
          ..where((t) => t.localUuid.equals(localUuid)))
        .write(const InvoicesCompanion(
      syncState: Value(InvoiceSyncState.queued),
    ));
  }

  Future<void> markSynced(String localUuid, String serverName) async {
    await (_db.update(_db.invoices)
          ..where((t) => t.localUuid.equals(localUuid)))
        .write(InvoicesCompanion(
      syncState: const Value(InvoiceSyncState.synced),
      serverName: Value(serverName),
    ));
  }

  Future<void> markError(String localUuid, String message) async {
    await (_db.update(_db.invoices)
          ..where((t) => t.localUuid.equals(localUuid)))
        .write(InvoicesCompanion(
      syncState: const Value(InvoiceSyncState.error),
      errorMsg: Value(message),
    ));
  }

  Future<List<Invoice>> pending() => _db.pendingInvoices();
  Stream<List<Invoice>> watchPending() => _db.watchPending();

  Map<String, dynamic> decode(Invoice row) =>
      Map<String, dynamic>.from(jsonDecode(row.docJson) as Map);
}
