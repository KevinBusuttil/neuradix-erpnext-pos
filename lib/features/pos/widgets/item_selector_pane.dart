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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load items:\n$e')),
            data: (list) => list.isEmpty
                ? const Center(child: Text('No items'))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 210,
                      childAspectRatio: 0.78,
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

  String? _imageUrl(String? site) {
    final img = item.image;
    if (img == null || img.isEmpty) return null;
    if (img.startsWith('http')) return img;
    return '${site ?? ''}$img';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = NumberFormat.simpleCurrency(name: item.currency ?? 'EUR');
    final pill = _colors[item.stockIndicator];
    final site = ref.watch(siteUrlProvider).valueOrNull;
    final headers = ref.watch(authHeadersProvider).valueOrNull;
    final url = _imageUrl(site);

    return Card(
      child: InkWell(
        onTap: () => ref.read(cartControllerProvider.notifier).addItem(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: scheme.surfaceContainerHighest,
                    child: url == null
                        ? _abbr(scheme)
                        : Image.network(
                            url,
                            headers: headers,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _abbr(scheme),
                            loadingBuilder: (c, child, progress) =>
                                progress == null
                                    ? child
                                    : const Center(
                                        child: SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                          ),
                  ),
                  if (pill != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: pill,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.actualQty.toStringAsFixed(0),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${fmt.format(item.priceListRate)} / ${item.uom ?? ''}',
                    style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.w700),
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
          ],
        ),
      ),
    );
  }

  Widget _abbr(ColorScheme scheme) {
    final letters = item.itemName.isNotEmpty
        ? item.itemName.trim().substring(0, item.itemName.length >= 2 ? 2 : 1)
        : '?';
    return Center(
      child: Text(
        letters.toUpperCase(),
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: scheme.outline,
        ),
      ),
    );
  }
}
