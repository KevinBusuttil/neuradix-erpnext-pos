import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/local/database.dart';
import '../../data/remote/frappe_client.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/pricing/tax_engine.dart';
import '../../sync/sync_manager.dart';
import '../config/app_config.dart';

// ---- Infrastructure ----

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig(ref.watch(secureStorageProvider)),
);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final frappeClientProvider = Provider<FrappeClient>(
  (ref) => FrappeClient(ref.watch(appConfigProvider)),
);

// ---- Domain / repositories ----

final taxEngineProvider = Provider<TaxEngine>((_) => const TaxEngine());

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => InvoiceRepository(ref.watch(databaseProvider)),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(
    ref.watch(frappeClientProvider),
    ref.watch(databaseProvider),
    ref.watch(appConfigProvider),
  ),
);

final syncManagerProvider = Provider<SyncManager>((ref) {
  final mgr = SyncManager(
    ref.watch(frappeClientProvider),
    ref.watch(invoiceRepositoryProvider),
  );
  ref.onDispose(mgr.dispose);
  return mgr;
});

/// Whether the app has a configured site + token.
final isConfiguredProvider = FutureProvider<bool>(
  (ref) => ref.watch(appConfigProvider).isConfigured,
);
