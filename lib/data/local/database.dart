import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

/// The offline-shim SQLite database.
///
/// Holds only what the thin shim needs: the current draft + outbound invoice
/// queue, a read-only catalogue snapshot for graceful degradation, and some
/// bookkeeping. The CCJ server remains authoritative whenever online.
@DriftDatabase(
  tables: [
    Invoices,
    SnapItems,
    SnapItemUoms,
    SnapItemBarcodes,
    SnapItemPrices,
    SnapItemTax,
    SnapStock,
    SnapCustomers,
    PosProfiles,
    ModesOfPayment,
    SyncLogs,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// Queued/draft invoices that still need to reach the server.
  Future<List<Invoice>> pendingInvoices() {
    return (select(invoices)
          ..where((t) => t.syncState.isIn(['queued', 'error']))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Stream<List<Invoice>> watchPending() {
    return (select(invoices)
          ..where((t) => t.syncState.isIn(['queued', 'syncing', 'error'])))
        .watch();
  }
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'neuropos.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
