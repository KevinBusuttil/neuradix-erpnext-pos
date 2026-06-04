import 'dart:math' as math;

import '../models/cart.dart';

/// Computed totals for a cart, matching the fields the Mobile POS shows.
class CartTotals {
  const CartTotals({
    required this.netTotal,
    required this.totalTaxesAndCharges,
    required this.discountAmount,
    required this.grandTotal,
    required this.roundedTotal,
    required this.taxLines,
  });

  final double netTotal;
  final double totalTaxesAndCharges;
  final double discountAmount;
  final double grandTotal;
  final double roundedTotal;
  final List<TaxLine> taxLines;
}

class TaxLine {
  const TaxLine({
    required this.description,
    required this.rate,
    required this.taxAmount,
    this.accountHead,
  });

  final String description;
  final double rate;
  final double taxAmount;
  final String? accountHead;

  Map<String, dynamic> toJson() => {
        'description': description,
        'rate': rate,
        'tax_amount_after_discount_amount': taxAmount,
        if (accountHead != null) 'account_head': accountHead,
      };
}

/// Offline fallback for ERPNext's `calculate_taxes_and_totals`.
///
/// IMPORTANT: this is the **offline fallback only**. While online, totals come
/// from the server's `compute_si_taxes` (authoritative). This Dart port must be
/// validated by the parity harness in `test/pricing/` before offline submit is
/// enabled.
///
/// v1 supports the subset the CCJ Mobile POS actually uses:
///   - per-line discount already applied into `rate`
///   - a single VAT rate applied "On Net Total" (Malta 18% default)
///   - cart-level additional discount as a percentage on Grand Total
///   - rounded total (round-half-to-even, like Frappe's `rounded()`)
class TaxEngine {
  const TaxEngine({this.defaultVatRate = 18.0, this.precision = 2});

  final double defaultVatRate;
  final int precision;

  CartTotals compute(Cart cart) {
    final netTotal = _round(cart.netTotal);

    // Single "On Net Total" VAT row. When per-item tax templates differ this
    // should be split per rate — tracked as a follow-up before go-live.
    final vatRate = defaultVatRate;
    final taxAmount = _round(netTotal * vatRate / 100.0);
    final taxLines = <TaxLine>[
      if (taxAmount != 0)
        TaxLine(
          description: 'VAT @ $vatRate%',
          rate: vatRate,
          taxAmount: taxAmount,
        ),
    ];

    final grossBeforeDiscount = _round(netTotal + taxAmount);

    final discountAmount =
        _round(grossBeforeDiscount * cart.additionalDiscountPercentage / 100.0);

    var grandTotal = _round(grossBeforeDiscount - discountAmount);
    if (grandTotal < 0) grandTotal = 0;

    return CartTotals(
      netTotal: netTotal,
      totalTaxesAndCharges: taxAmount,
      discountAmount: discountAmount,
      grandTotal: grandTotal,
      roundedTotal: _bankersRound(grandTotal),
      taxLines: taxLines,
    );
  }

  double _round(double v) {
    final f = math.pow(10, precision).toDouble();
    return (v * f).roundToDouble() / f;
  }

  /// Frappe's default rounding is round-half-to-even on the integer currency.
  double _bankersRound(double v) {
    final floor = v.floorToDouble();
    final diff = v - floor;
    if (diff < 0.5) return floor;
    if (diff > 0.5) return floor + 1;
    // exactly .5 -> round to even
    return floor % 2 == 0 ? floor : floor + 1;
  }
}
