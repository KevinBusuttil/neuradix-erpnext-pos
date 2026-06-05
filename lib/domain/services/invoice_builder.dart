import '../models/cart.dart';
import '../models/payment.dart';
import '../models/pos_customer.dart';

/// Builds the Sales Invoice payload the CCJ server expects, matching the Mobile
/// POS contract: a standard Sales Invoice flagged `custom_is_mobile_pos`, with a
/// client-generated `custom_neuropos_uuid` for idempotent submit. The server
/// (`submit_sales_invoice`) runs `set_missing_values` / `calculate_taxes_and_totals`
/// and normalises payments (credit detection, change), so the client sends the
/// minimal source-of-truth fields.
class InvoiceBuilder {
  const InvoiceBuilder();

  Map<String, dynamic> build({
    required Cart cart,
    required ProfileContext ctx,
    List<PaymentEntry> payments = const [],
    String? neuroposUuid,
  }) {
    return {
      'doctype': 'Sales Invoice',
      'customer': cart.customer,
      'pos_profile': ctx.posProfile,
      'set_warehouse': ctx.warehouse,
      'selling_price_list': ctx.priceList,
      'currency': ctx.currency,
      'custom_is_mobile_pos': 1,
      if (neuroposUuid != null) 'custom_neuropos_uuid': neuroposUuid,
      'is_return': cart.isReturn ? 1 : 0,
      'additional_discount_percentage': cart.additionalDiscountPercentage,
      'apply_discount_on': 'Grand Total',
      'items': cart.lines.map((l) => l.toItemJson()).toList(),
      'payments': payments.map((p) => p.toJson()).toList(),
    };
  }
}
