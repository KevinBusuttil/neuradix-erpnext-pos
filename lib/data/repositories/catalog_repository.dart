import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/pos_customer.dart';
import '../../domain/models/pos_item.dart';
import '../local/database.dart';
import '../local/tables.dart';
import '../remote/frappe_client.dart';

/// Reads catalogue/customer/profile data. Online-first: live server calls are
/// the primary path; on failure it falls back to the SQLite snapshot cache so a
/// mid-shift network drop still allows browsing and selling.
class CatalogRepository {
  CatalogRepository(this._client, this._db, this._config);

  final FrappeClient _client;
  final AppDatabase _db;
  final AppConfig _config;

  ProfileContext? _ctx;

  /// Resolve (and memoise) the POS session context. Prefers the configured
  /// profile, then the snapshot cache, then the first available profile.
  Future<ProfileContext> profileContext() async {
    if (_ctx != null) return _ctx!;

    var name = await _config.posProfile;
    name ??= await _firstProfileName();
    await _config.setPosProfile(name);

    // Try snapshot cache for price list / warehouse first.
    final cached = await (_db.select(_db.posProfiles)
          ..where((t) => t.name.equals(name!)))
        .getSingleOrNull();
    Map<String, dynamic> p;
    if (cached != null) {
      p = Map<String, dynamic>.from(jsonDecode(cached.json) as Map);
    } else {
      final live = await _client.call(
        'ccj.ccj.page.mobile_pos.mobile_pos.get_pos_profile_data',
        args: {'pos_profile': name},
      );
      p = Map<String, dynamic>.from(live as Map);
    }

    _ctx = ProfileContext(
      posProfile: name!,
      priceList: p['selling_price_list'] as String,
      warehouse: p['warehouse'] as String,
      currency: (p['currency'] as String?) ?? 'EUR',
    );
    return _ctx!;
  }

  Future<String> _firstProfileName() async {
    final cached = await (_db.select(_db.posProfiles)..limit(1)).getSingleOrNull();
    if (cached != null) return cached.name;
    final list =
        await _client.list('POS Profile', fields: ['name'], limit: 1);
    if (list.isEmpty) throw StateError('No POS Profile available');
    return (list.first as Map)['name'] as String;
  }

  /// Item grid / search. Live `get_items`, snapshot fallback when offline.
  Future<List<PosItem>> searchItems(String term) async {
    final ctx = await profileContext();
    try {
      final rows = await _client.getItems(
        posProfile: ctx.posProfile,
        priceList: ctx.priceList,
        searchTerm: term,
      );
      return rows
          .map((e) => PosItem.fromGetItems(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return _searchSnapshotItems(ctx, term);
    }
  }

  Future<List<PosItem>> _searchSnapshotItems(
      ProfileContext ctx, String term) async {
    final q = _db.select(_db.snapItems)..limit(50);
    if (term.isNotEmpty) {
      q.where((t) => t.itemCode.like('%$term%') | t.itemName.like('%$term%'));
    }
    final items = await q.get();
    final out = <PosItem>[];
    for (final it in items) {
      final price = await (_db.select(_db.snapItemPrices)
            ..where((t) =>
                t.itemCode.equals(it.itemCode) &
                t.priceList.equals(ctx.priceList))
            ..limit(1))
          .getSingleOrNull();
      final stock = await (_db.select(_db.snapStock)
            ..where((t) =>
                t.itemCode.equals(it.itemCode) &
                t.warehouse.equals(ctx.warehouse))
            ..limit(1))
          .getSingleOrNull();
      final rate = price?.rate ?? 0;
      out.add(PosItem(
        itemCode: it.itemCode,
        itemName: it.itemName,
        description: it.description,
        image: it.itemImage,
        stockUom: it.stockUom,
        uom: price?.uom ?? it.stockUom,
        isStockItem: it.isStockItem,
        hasBatchNo: it.hasBatchNo,
        hasSerialNo: it.hasSerialNo,
        actualQty: stock?.actualQty ?? 0,
        priceListRate: rate,
        rrp: rate == 0 ? null : rate / 1.18,
        currency: price?.currency ?? ctx.currency,
      ));
    }
    return out;
  }

  /// Customer search. Live filter by allowed groups, snapshot fallback.
  Future<List<PosCustomer>> searchCustomers(String term) async {
    try {
      final rows = await _client.list(
        'Customer',
        filters: term.isEmpty ? null : {'customer_name': ['like', '%$term%']},
        fields: ['name', 'customer_name', 'mobile_no', 'email_id',
          'customer_group', 'loyalty_program'],
        limit: 20,
      );
      return rows
          .map((e) => PosCustomer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      final q = _db.select(_db.snapCustomers)..limit(20);
      if (term.isNotEmpty) {
        q.where((t) => t.name.like('%$term%') | t.customerName.like('%$term%'));
      }
      final rows = await q.get();
      return rows
          .map((c) => PosCustomer(
                name: c.name,
                customerName: c.customerName,
                mobileNo: c.mobileNo,
                emailId: c.emailId,
                customerGroup: c.customerGroup,
                loyaltyProgram: c.loyaltyProgram,
                allowCredit: c.allowCredit,
              ))
          .toList();
    }
  }

  /// Refresh the offline snapshot from the server (opportunistic, while online).
  Future<void> refreshSnapshot() async {
    final ctx = await profileContext();
    final snap = await _client.snapshotPull(ctx.posProfile);
    await _cacheSnapshot(snap);
    await _config.setLastSnapshotAt(DateTime.now().toIso8601String());
  }

  Future<void> _cacheSnapshot(Map<String, dynamic> snap) async {
    List<Map<String, dynamic>> rows(String key) =>
        ((snap[key] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    bool b(Object? v) => v == 1 || v == true;

    // Simple full-replace; snapshot is small and refreshed opportunistically.
    await _db.delete(_db.snapItems).go();
    await _db.delete(_db.snapItemUoms).go();
    await _db.delete(_db.snapItemBarcodes).go();
    await _db.delete(_db.snapItemPrices).go();
    await _db.delete(_db.snapItemTax).go();
    await _db.delete(_db.snapStock).go();
    await _db.delete(_db.snapCustomers).go();
    await _db.delete(_db.modesOfPayment).go();

    await _db.batch((batch) {
        for (final m in rows('items')) {
          batch.insert(
            _db.snapItems,
            SnapItemsCompanion.insert(
              itemCode: m['item_code'] as String,
              itemName: (m['item_name'] ?? m['item_code']) as String,
              description: Value(m['description'] as String?),
              stockUom: Value(m['stock_uom'] as String?),
              itemImage: Value(m['item_image'] as String?),
              isStockItem: Value(b(m['is_stock_item'])),
              hasBatchNo: Value(b(m['has_batch_no'])),
              hasSerialNo: Value(b(m['has_serial_no'])),
              itemGroup: Value(m['item_group'] as String?),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (final m in rows('uoms')) {
          batch.insert(
            _db.snapItemUoms,
            SnapItemUomsCompanion.insert(
              itemCode: m['item_code'] as String,
              uom: m['uom'] as String,
              conversionFactor: Value(d(m['conversion_factor'])),
            ),
          );
        }
        for (final m in rows('barcodes')) {
          batch.insert(
            _db.snapItemBarcodes,
            SnapItemBarcodesCompanion.insert(
              barcode: m['barcode'] as String,
              itemCode: m['item_code'] as String,
              uom: Value(m['uom'] as String?),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (final m in rows('prices')) {
          batch.insert(
            _db.snapItemPrices,
            SnapItemPricesCompanion.insert(
              itemCode: m['item_code'] as String,
              priceList: m['price_list'] as String? ?? '',
              uom: Value(m['uom'] as String?),
              batchNo: Value(m['batch_no'] as String?),
              rate: Value(d(m['price_list_rate'])),
              currency: Value(m['currency'] as String?),
            ),
          );
        }
        for (final m in rows('item_tax')) {
          batch.insert(
            _db.snapItemTax,
            SnapItemTaxCompanion.insert(
              itemCode: m['item_code'] as String,
              taxTemplate: m['item_tax_template'] as String? ?? '',
            ),
          );
        }
        for (final m in rows('stock')) {
          batch.insert(
            _db.snapStock,
            SnapStockCompanion.insert(
              itemCode: m['item_code'] as String,
              warehouse: m['warehouse'] as String,
              actualQty: Value(d(m['actual_qty'])),
            ),
          );
        }
        for (final m in rows('customers')) {
          batch.insert(
            _db.snapCustomers,
            SnapCustomersCompanion.insert(
              name: m['name'] as String,
              customerName: Value(m['customer_name'] as String?),
              mobileNo: Value(m['mobile_no'] as String?),
              emailId: Value(m['email_id'] as String?),
              customerGroup: Value(m['customer_group'] as String?),
              loyaltyProgram: Value(m['loyalty_program'] as String?),
              allowCredit: Value(b(m['allow_credit'])),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (final m in rows('modes_of_payment')) {
          batch.insert(
            _db.modesOfPayment,
            ModesOfPaymentCompanion.insert(
              name: m['mode_of_payment'] as String,
              type: Value(m['type'] as String?),
              isDefault: Value(b(m['default'])),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
    });

    // POS profile doc (separate, single row)
    final profile = snap['pos_profile'];
    if (profile is Map) {
      await _db.into(_db.posProfiles).insertOnConflictUpdate(
            PosProfilesCompanion.insert(
              name: profile['name'] as String,
              json: jsonEncode(profile),
            ),
          );
    }
  }
}
