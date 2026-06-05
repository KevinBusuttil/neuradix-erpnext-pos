import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/cart.dart';
import '../../domain/models/payment.dart';
import '../../domain/pricing/tax_engine.dart';
import '../../domain/services/invoice_builder.dart';
import '../remote/frappe_client.dart';
import 'catalog_repository.dart';
import 'invoice_repository.dart';

enum CheckoutStatus { submitted, queuedOffline, error }

class CheckoutResult {
  const CheckoutResult(this.status, {this.invoiceName, this.message});
  final CheckoutStatus status;
  final String? invoiceName;
  final String? message;
}

/// Drives totals + submission. Online: authoritative totals via
/// `compute_si_taxes` and direct submit. Offline (or on transport failure):
/// totals via the [TaxEngine] fallback and the invoice goes to the outbound
/// queue (idempotent via `custom_neuropos_uuid`).
class CheckoutRepository {
  CheckoutRepository(this._client, this._catalog, this._invoices, this._tax);

  final FrappeClient _client;
  final CatalogRepository _catalog;
  final InvoiceRepository _invoices;
  final TaxEngine _tax;

  static const _uuid = Uuid();
  static const _builder = InvoiceBuilder();

  Future<bool> _isOnline() async {
    final r = await Connectivity().checkConnectivity();
    return r.any((c) => c != ConnectivityResult.none);
  }

  /// Authoritative totals when online; offline fallback otherwise.
  Future<CartTotals> computeTotals(Cart cart) async {
    if (await _isOnline()) {
      try {
        final ctx = await _catalog.profileContext();
        final doc = _builder.build(cart: cart, ctx: ctx);
        final msg = await _client.computeTaxes(doc);
        return CartTotals.fromCompute(msg);
      } catch (_) {
        // fall through to offline calc
      }
    }
    return _tax.compute(cart);
  }

  /// Submit the sale. Returns whether it was submitted live or queued offline.
  Future<CheckoutResult> submit(Cart cart, List<PaymentEntry> payments) async {
    final ctx = await _catalog.profileContext();
    final neuroposUuid = _uuid.v4();
    final doc = _builder.build(
      cart: cart,
      ctx: ctx,
      payments: payments,
      neuroposUuid: neuroposUuid,
    );

    if (!await _isOnline()) {
      final localUuid = await _invoices.saveDraft(doc);
      await _invoices.enqueue(localUuid);
      return const CheckoutResult(CheckoutStatus.queuedOffline);
    }

    try {
      final res = await _client.submitSalesInvoice(doc);
      return CheckoutResult(
        CheckoutStatus.submitted,
        invoiceName: res['name'] as String?,
      );
    } catch (e) {
      // Online but the server rejected it (e.g. validation/stock). Surface the
      // error rather than silently queueing a bad invoice.
      return CheckoutResult(CheckoutStatus.error, message: e.toString());
    }
  }
}
