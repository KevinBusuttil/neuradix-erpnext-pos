import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/di/providers.dart';
import '../../data/repositories/checkout_repository.dart';
import '../../domain/models/payment.dart';
import '../../domain/pricing/tax_engine.dart';
import '../pos/cart_controller.dart';
import '../pos/pos_providers.dart';

/// Payment + complete order. Totals are authoritative (server `compute_si_taxes`
/// when online; offline TaxEngine fallback). Enter the amount tendered per
/// method; leaving everything at 0 records an on-credit sale (left outstanding).
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late Future<CartTotals> _totalsFuture;
  final Map<String, TextEditingController> _amounts = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartControllerProvider);
    _totalsFuture = ref.read(checkoutRepositoryProvider).computeTotals(cart);
  }

  @override
  void dispose() {
    for (final c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String mode) =>
      _amounts.putIfAbsent(mode, () => TextEditingController());

  double get _paid => _amounts.values
      .fold(0.0, (s, c) => s + (double.tryParse(c.text) ?? 0));

  List<PaymentEntry> _entries(List<PaymentMode> modes) => [
        for (final m in modes)
          if ((double.tryParse(_ctrl(m.name).text) ?? 0) != 0)
            PaymentEntry(
              modeOfPayment: m.name,
              type: m.type,
              amount: double.parse(_ctrl(m.name).text),
            ),
      ];

  Future<void> _complete(List<PaymentMode> modes) async {
    setState(() => _submitting = true);
    final cart = ref.read(cartControllerProvider);
    final res = await ref
        .read(checkoutRepositoryProvider)
        .submit(cart, _entries(modes));
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (res.status) {
      case CheckoutStatus.submitted:
        ref.read(cartControllerProvider.notifier).clear();
        _showDone('Invoice ${res.invoiceName} created.');
      case CheckoutStatus.queuedOffline:
        ref.read(cartControllerProvider.notifier).clear();
        _showDone('Saved offline — will sync automatically when online.');
      case CheckoutStatus.error:
        _showError(res.message ?? 'Unknown error');
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(Icons.error_outline,
            color: Theme.of(context).colorScheme.error),
        title: const Text('Could not complete order'),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDone(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
        title: const Text('Order complete'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // dialog
              Navigator.pop(context); // back to POS
            },
            child: const Text('New order'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modesAsync = ref.watch(paymentModesProvider);
    final ctx = ref.watch(profileContextProvider);
    final fmt =
        NumberFormat.simpleCurrency(name: ctx.valueOrNull?.currency ?? 'EUR');
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: FutureBuilder<CartTotals>(
        future: _totalsFuture,
        builder: (context, totalsSnap) {
          if (!totalsSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final totals = totalsSnap.data!;
          return modesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (modes) {
              final remaining = totals.roundedTotal - _paid;
              final change = _paid - totals.roundedTotal;
              return Column(
                children: [
                  // Grand total banner
                  Container(
                    width: double.infinity,
                    color: scheme.primaryContainer,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('Amount Due',
                            style: TextStyle(
                                color: scheme.onPrimaryContainer)),
                        const SizedBox(height: 4),
                        Text(
                          fmt.format(totals.roundedTotal),
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Enter the amount tendered per method. '
                            'Tap a method to fill the remaining amount. '
                            'Leave all at 0 for an on-credit sale.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                        for (final m in modes)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Icon(Icons.payments_outlined,
                                      color: scheme.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(m.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  SizedBox(
                                    width: 140,
                                    child: TextField(
                                      controller: _ctrl(m.name),
                                      textAlign: TextAlign.right,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        hintText: '0.00',
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Fill remaining',
                                    icon: const Icon(Icons.keyboard_tab),
                                    onPressed: () {
                                      final rem = totals.roundedTotal -
                                          (_paid -
                                              (double.tryParse(
                                                      _ctrl(m.name).text) ??
                                                  0));
                                      _ctrl(m.name).text =
                                          (rem > 0 ? rem : 0).toStringAsFixed(2);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _row('Net Total', fmt.format(totals.netTotal)),
                        for (final t in totals.taxLines)
                          _row(t.description, fmt.format(t.taxAmount)),
                        if (totals.discountAmount != 0)
                          _row('Discount',
                              '-${fmt.format(totals.discountAmount)}'),
                        _row('Paid', fmt.format(_paid)),
                        _row(
                          change >= 0 ? 'Change' : 'Remaining',
                          fmt.format(change.abs()),
                          bold: true,
                          color: change < 0 ? scheme.error : null,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _submitting ? null : () => _complete(modes),
                          child: _submitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(_paid == 0
                                  ? 'Complete (On Credit)'
                                  : 'Complete Order'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _row(String label, String value,
      {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 18 : 14,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
