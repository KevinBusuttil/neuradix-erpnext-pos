import 'package:drift/drift.dart';

/// Sync state of a locally-held invoice.
enum InvoiceSyncState { draft, queued, syncing, synced, error }

// ---------------------------------------------------------------------------
// Outbound + draft (the heart of the offline shim)
// ---------------------------------------------------------------------------

class Invoices extends Table {
  TextColumn get localUuid => text()();
  TextColumn get serverName => text().nullable()();
  TextColumn get customer => text().nullable()();
  TextColumn get postingDate => text().nullable()();
  TextColumn get status => text().nullable()();
  BoolColumn get isReturn => boolean().withDefault(const Constant(false))();
  TextColumn get returnAgainst => text().nullable()();
  TextColumn get docJson => text()(); // full SI payload as JSON
  TextColumn get totalsJson => text().nullable()();
  TextColumn get syncState =>
      textEnum<InvoiceSyncState>().withDefault(const Constant('draft'))();
  TextColumn get errorMsg => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {localUuid};
}

// ---------------------------------------------------------------------------
// Read-only snapshot cache (graceful degradation only)
// ---------------------------------------------------------------------------

class SnapItems extends Table {
  TextColumn get itemCode => text()();
  TextColumn get itemName => text()();
  TextColumn get description => text().nullable()();
  TextColumn get stockUom => text().nullable()();
  TextColumn get itemImage => text().nullable()();
  BoolColumn get isStockItem => boolean().withDefault(const Constant(true))();
  BoolColumn get hasBatchNo => boolean().withDefault(const Constant(false))();
  BoolColumn get hasSerialNo => boolean().withDefault(const Constant(false))();
  TextColumn get itemGroup => text().nullable()();

  @override
  Set<Column> get primaryKey => {itemCode};
}

class SnapItemUoms extends Table {
  TextColumn get itemCode => text()();
  TextColumn get uom => text()();
  RealColumn get conversionFactor =>
      real().withDefault(const Constant(1.0))();
}

class SnapItemBarcodes extends Table {
  TextColumn get barcode => text()();
  TextColumn get itemCode => text()();
  TextColumn get uom => text().nullable()();

  @override
  Set<Column> get primaryKey => {barcode};
}

class SnapItemPrices extends Table {
  TextColumn get itemCode => text()();
  TextColumn get priceList => text()();
  TextColumn get uom => text().nullable()();
  TextColumn get batchNo => text().nullable()();
  RealColumn get rate => real().withDefault(const Constant(0))();
  TextColumn get currency => text().nullable()();
}

class SnapItemTax extends Table {
  TextColumn get itemCode => text()();
  TextColumn get taxTemplate => text()();
  RealColumn get rate => real().nullable()();
  TextColumn get vatCode => text().nullable()();
}

class SnapStock extends Table {
  TextColumn get itemCode => text()();
  TextColumn get warehouse => text()();
  RealColumn get actualQty => real().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class SnapCustomers extends Table {
  TextColumn get name => text()();
  TextColumn get customerName => text().nullable()();
  TextColumn get mobileNo => text().nullable()();
  TextColumn get emailId => text().nullable()();
  TextColumn get customerGroup => text().nullable()();
  TextColumn get loyaltyProgram => text().nullable()();
  BoolColumn get allowCredit => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {name};
}

class PosProfiles extends Table {
  TextColumn get name => text()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {name};
}

class ModesOfPayment extends Table {
  TextColumn get name => text()();
  TextColumn get type => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {name};
}

// ---------------------------------------------------------------------------
// Bookkeeping
// ---------------------------------------------------------------------------

class SyncLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get action => text()();
  TextColumn get status => text()();
  TextColumn get detail => text().nullable()();
  DateTimeColumn get at => dateTime().withDefault(currentDateAndTime)();
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
