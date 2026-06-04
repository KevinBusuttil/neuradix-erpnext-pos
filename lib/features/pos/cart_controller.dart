import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/cart.dart';
import '../../domain/models/pos_item.dart';

/// Holds the working cart. Each mutation emits a fresh [Cart] reference so
/// watchers rebuild.
class CartController extends Notifier<Cart> {
  @override
  Cart build() => Cart();

  void _emit(void Function() mutate) {
    mutate();
    state = state.cloneRef();
  }

  void setCustomer(String? customer) => _emit(() => state.customer = customer);

  void addItem(PosItem item) => _emit(() {
        final existing = state.lineFor(item.itemCode);
        if (existing != null) {
          existing.qty += 1;
        } else {
          state.lines.add(CartLine(
            itemCode: item.itemCode,
            itemName: item.itemName,
            qty: 1,
            uom: item.uom ?? item.stockUom ?? 'Nos',
            conversionFactor: item.conversionFactor,
            priceListRate: item.priceListRate,
            rate: item.priceListRate,
            warehouse: null,
            batchNo: item.batchNo,
            taxTemplate: null,
          ));
        }
      });

  void setQty(String itemCode, double qty) => _emit(() {
        final line = state.lineFor(itemCode);
        if (line == null) return;
        if (qty <= 0) {
          state.lines.removeWhere((l) => l.itemCode == itemCode);
        } else {
          line.qty = qty;
        }
      });

  void incQty(String itemCode) {
    final line = state.lineFor(itemCode);
    if (line != null) setQty(itemCode, line.qty + 1);
  }

  void decQty(String itemCode) {
    final line = state.lineFor(itemCode);
    if (line != null) setQty(itemCode, line.qty - 1);
  }

  void removeItem(String itemCode) =>
      _emit(() => state.lines.removeWhere((l) => l.itemCode == itemCode));

  void setDiscountPercentage(double pct) =>
      _emit(() => state.additionalDiscountPercentage = pct);

  void clear() => _emit(() {
        state.lines.clear();
        state.customer = null;
        state.additionalDiscountPercentage = 0;
        state.isReturn = false;
      });
}

final cartControllerProvider =
    NotifierProvider<CartController, Cart>(CartController.new);
