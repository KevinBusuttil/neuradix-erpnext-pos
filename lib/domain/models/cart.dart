import 'package:collection/collection.dart';

/// A single line in the POS cart. Mirrors the fields the Mobile POS keeps on a
/// Sales Invoice Item row.
class CartLine {
  CartLine({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.uom,
    required this.conversionFactor,
    required this.priceListRate,
    required this.rate,
    this.discountPercentage = 0,
    this.warehouse,
    this.batchNo,
    this.serialNo,
    this.taxTemplate,
  });

  final String itemCode;
  final String itemName;
  double qty;
  String uom;
  double conversionFactor;
  double priceListRate;
  double rate;
  double discountPercentage;
  String? warehouse;
  String? batchNo;
  String? serialNo;
  String? taxTemplate;

  /// Net line amount after the per-line discount (VAT excluded).
  double get amount => qty * rate;

  CartLine copyWith({double? qty, double? rate, double? discountPercentage}) {
    return CartLine(
      itemCode: itemCode,
      itemName: itemName,
      qty: qty ?? this.qty,
      uom: uom,
      conversionFactor: conversionFactor,
      priceListRate: priceListRate,
      rate: rate ?? this.rate,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      warehouse: warehouse,
      batchNo: batchNo,
      serialNo: serialNo,
      taxTemplate: taxTemplate,
    );
  }

  Map<String, dynamic> toItemJson() => {
        'item_code': itemCode,
        'item_name': itemName,
        'qty': qty,
        'uom': uom,
        'conversion_factor': conversionFactor,
        'price_list_rate': priceListRate,
        'rate': rate,
        'discount_percentage': discountPercentage,
        if (warehouse != null) 'warehouse': warehouse,
        if (batchNo != null) 'batch_no': batchNo,
        if (serialNo != null) 'serial_no': serialNo,
        'use_serial_batch_fields': 1,
      };
}

/// The working cart for one invoice.
class Cart {
  Cart({
    this.customer,
    List<CartLine>? lines,
    this.additionalDiscountPercentage = 0,
    this.isReturn = false,
  }) : lines = lines ?? [];

  String? customer;
  final List<CartLine> lines;
  double additionalDiscountPercentage;
  bool isReturn;

  bool get isEmpty => lines.isEmpty;
  double get totalQty => lines.fold(0.0, (s, l) => s + l.qty);
  double get netTotal => lines.fold(0.0, (s, l) => s + l.amount);

  CartLine? lineFor(String itemCode) =>
      lines.firstWhereOrNull((l) => l.itemCode == itemCode);

  /// New Cart instance sharing field values with a fresh `lines` list, so
  /// Riverpod sees a changed reference after a mutation.
  Cart cloneRef() => Cart(
        customer: customer,
        lines: List.of(lines),
        additionalDiscountPercentage: additionalDiscountPercentage,
        isReturn: isReturn,
      );
}
