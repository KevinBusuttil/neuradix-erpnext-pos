import 'package:flutter_test/flutter_test.dart';
import 'package:neuropos/domain/models/cart.dart';
import 'package:neuropos/domain/pricing/tax_engine.dart';

void main() {
  const engine = TaxEngine(defaultVatRate: 18.0);

  CartLine line(double qty, double rate) => CartLine(
        itemCode: 'ITM',
        itemName: 'Item',
        qty: qty,
        uom: 'Nos',
        conversionFactor: 1,
        priceListRate: rate,
        rate: rate,
      );

  test('net total, 18% VAT and grand total', () {
    final cart = Cart(lines: [line(2, 10)]); // net 20
    final t = engine.compute(cart);

    expect(t.netTotal, 20.0);
    expect(t.totalTaxesAndCharges, 3.6); // 18% of 20
    expect(t.grandTotal, 23.6);
    expect(t.taxLines.single.rate, 18.0);
  });

  test('cart-level percentage discount applies on grand total', () {
    final cart = Cart(lines: [line(1, 100)], additionalDiscountPercentage: 10);
    final t = engine.compute(cart);

    expect(t.netTotal, 100.0);
    expect(t.totalTaxesAndCharges, 18.0);
    // gross 118, 10% off => 11.8 discount => 106.2
    expect(t.discountAmount, 11.8);
    expect(t.grandTotal, 106.2);
  });

  // TODO(parity): Phase 3 — feed the same carts to the server's
  // `compute_si_taxes` and assert this engine matches to the cent across a
  // matrix of discounts, multi-rate items and rounding edge cases.
}
