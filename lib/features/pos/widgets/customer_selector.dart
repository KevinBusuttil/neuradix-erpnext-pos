import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/pos_customer.dart';
import '../cart_controller.dart';
import '../pos_providers.dart';

/// Compact customer chooser shown at the top of the cart pane.
class CustomerSelector extends ConsumerWidget {
  const CustomerSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(cartControllerProvider).customer;
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(customer ?? 'Select customer'),
      trailing: customer == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              icon: const Icon(Icons.close),
              onPressed: () =>
                  ref.read(cartControllerProvider.notifier).setCustomer(null),
            ),
      onTap: () async {
        final picked = await showModalBottomSheet<PosCustomer>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _CustomerPickerSheet(),
        );
        if (picked != null) {
          ref.read(cartControllerProvider.notifier).setCustomer(picked.name);
        }
      },
    );
  }
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();

  @override
  ConsumerState<_CustomerPickerSheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_CustomerPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(customerListProvider);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search customer',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) => ref
                    .read(customerSearchTermProvider.notifier)
                    .state = v.trim(),
              ),
            ),
            Expanded(
              child: results.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (list) => ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return ListTile(
                      title: Text(c.display),
                      subtitle: Text(
                        [c.mobileNo, c.emailId]
                            .where((s) => s != null && s.isNotEmpty)
                            .join(' • '),
                      ),
                      onTap: () => Navigator.pop(context, c),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
