import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../payment/payment_screen.dart';
import '../cart_controller.dart';
import '../pos_providers.dart';
import 'customer_selector.dart';

/// Right pane: customer, cart lines, totals and (Phase 2) checkout.
class CartPane extends ConsumerWidget {
  const CartPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final totals = ref.watch(cartTotalsProvider);
    final ctx = ref.watch(profileContextProvider);
    final currency = ctx.valueOrNull?.currency ?? 'EUR';
    final fmt = NumberFormat.simpleCurrency(name: currency);

    return Column(
      children: [
        const CustomerSelector(),
        const Divider(height: 1),
        Expanded(
          child: cart.isEmpty
              ? const Center(child: Text('No items in cart'))
              : ListView.separated(
                  itemCount: cart.lines.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final line = cart.lines[i];
                    return ListTile(
                      title: Text(line.itemName),
                      subtitle: Text(
                          '${fmt.format(line.rate)} × ${line.qty.toStringAsFixed(line.qty % 1 == 0 ? 0 : 2)} ${line.uom}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => ref
                                .read(cartControllerProvider.notifier)
                                .decQty(line.itemCode),
                          ),
                          Text(line.qty.toStringAsFixed(0)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => ref
                                .read(cartControllerProvider.notifier)
                                .incQty(line.itemCode),
                          ),
                          SizedBox(
                            width: 84,
                            child: Text(
                              fmt.format(line.amount),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
                _row('Discount', '-${fmt.format(totals.discountAmount)}'),
              const SizedBox(height: 6),
              _row('Grand Total', fmt.format(totals.roundedTotal), bold: true),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: cart.isEmpty || cart.customer == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PaymentScreen(),
                            ),
                          ),
                  child: Text(
                    cart.customer == null ? 'Select a customer' : 'Checkout',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
