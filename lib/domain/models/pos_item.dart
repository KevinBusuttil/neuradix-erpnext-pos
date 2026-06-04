/// A catalogue item as shown in the POS item grid, combining item master,
/// price and (advisory) stock. Built from either the live `get_items` response
/// or the offline snapshot cache.
class PosItem {
  const PosItem({
    required this.itemCode,
    required this.itemName,
    this.description,
    this.image,
    this.stockUom,
    this.uom,
    this.isStockItem = true,
    this.hasBatchNo = false,
    this.hasSerialNo = false,
    this.actualQty = 0,
    this.priceListRate = 0,
    this.rrp,
    this.currency,
    this.batchNo,
  });

  final String itemCode;
  final String itemName;
  final String? description;
  final String? image;
  final String? stockUom;
  final String? uom;
  final bool isStockItem;
  final bool hasBatchNo;
  final bool hasSerialNo;
  final double actualQty;
  final double priceListRate;
  final double? rrp; // ex-VAT unit price (price / 1.18)
  final String? currency;
  final String? batchNo;

  double get conversionFactor => 1;

  /// Stock indicator colour bucket used by the grid (mirrors Mobile POS).
  String get stockIndicator {
    if (!isStockItem) return '';
    if (actualQty > 10) return 'green';
    if (actualQty <= 0) return 'red';
    return 'orange';
  }

  factory PosItem.fromGetItems(Map<String, dynamic> m) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    bool b(Object? v) => v == 1 || v == true;
    return PosItem(
      itemCode: m['item_code'] as String,
      itemName: (m['item_name'] ?? m['item_code']) as String,
      description: m['description'] as String?,
      image: m['item_image'] as String?,
      stockUom: m['stock_uom'] as String?,
      uom: (m['uom'] ?? m['stock_uom']) as String?,
      isStockItem: b(m['is_stock_item']),
      actualQty: d(m['actual_qty']),
      priceListRate: d(m['price_list_rate']),
      rrp: m['rrp'] == null ? null : d(m['rrp']),
      currency: m['currency'] as String?,
      batchNo: m['batch_no'] as String?,
    );
  }
}
