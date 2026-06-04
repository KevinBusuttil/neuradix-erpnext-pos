import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/pos_item.dart';
import '../cart_controller.dart';
import '../pos_providers.dart';

/// Left pane: search box + item grid. Tapping a card adds the item to the cart.
class ItemSelectorPane extends ConsumerStatefulWidget {
  const ItemSelectorPane({super.key});

  @override
  ConsumerState<ItemSelectorPane> createState() => _ItemSelectorPaneState();
}

class _ItemSelectorPaneState extends ConsumerState<ItemSelectorPane> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemListProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search by item code, name or barcode',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _search.clear();
                  ref.read(itemSearchTermProvider.notifier).state = '';
                },
              ),
            ),
            onSubmitted: (v) =>
                ref.read(itemSearchTermProvider.notifier).state = v.trim(),
          ),
        ),
        Expanded(
          child: items.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load items:\n$e')),
            data: (list) => list.isEmpty
                ? const Center(child: Text('No items'))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _ItemCard(item: list[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ItemCard extends ConsumerWidget {
  const _ItemCard({required this.item});
  final PosItem item;

  static const _colors = {
    'green': Color(0xFF16A34A),
    'orange': Color(0xFFEA580C),
    'red': Color(0xFFDC2626),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.simpleCurrency(name: item.currency ?? 'EUR');
    final pill = _colors[item.stockIndicator];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ref.read(cartControllerProvider.notifier).addItem(item),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (pill != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: pill,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.actualQty.toStringAsFixed(0),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                item.itemName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '${fmt.format(item.priceListRate)} / ${item.uom ?? ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (item.rrp != null)
                Text(
                  'Exc VAT: ${fmt.format(item.rrp)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).hintColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
