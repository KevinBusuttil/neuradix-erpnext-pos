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
/// when online; offline TaxEngine fallback). Zero payment = credit sale, which
/// the server leaves outstanding.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late Future<CartTotals> _totalsFuture;
  final Map<String, TextEditingController> _amounts = {};
  bool _submitting = false;
  bool _prefilled = false;

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

  double get _paid => _amounts.values.fold(
        0.0,
        (s, c) => s + (double.tryParse(c.text) ?? 0),
      );

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
    final res =
        await ref.read(checkoutRepositoryProvider).submit(cart, _entries(modes));
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: ${res.message}')),
        );
    }
  }

  void _showDone(String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
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
              // Prefill the default (or first) mode with the grand total once.
              if (!_prefilled && modes.isNotEmpty) {
                final def =
                    modes.firstWhere((m) => m.isDefault, orElse: () => modes.first);
                _ctrl(def.name).text = totals.roundedTotal.toStringAsFixed(2);
                _prefilled = true;
              }
              final change = _paid - totals.roundedTotal;
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final m in modes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller: _ctrl(m.name),
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: InputDecoration(
                                labelText: m.name,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.payments_outlined),
                              ),
                              onChanged: (_) => setState(() {}),
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
                        _row('Grand Total', fmt.format(totals.roundedTotal),
                            bold: true),
                        _row('Paid', fmt.format(_paid)),
                        _row(
                          change >= 0 ? 'Change' : 'To Be Paid',
                          fmt.format(change.abs()),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _submitting ? null : () => _complete(modes),
                            child: _submitting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Complete Order'),
                          ),
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

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
