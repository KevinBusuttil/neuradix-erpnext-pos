import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../domain/models/pos_customer.dart';
import '../../domain/models/pos_item.dart';
import '../../domain/pricing/tax_engine.dart';
import 'cart_controller.dart';

/// Current item-search term (submitted from the search box).
final itemSearchTermProvider = StateProvider<String>((_) => '');

/// Item grid contents for the current search term.
final itemListProvider = FutureProvider.autoDispose<List<PosItem>>((ref) {
  final term = ref.watch(itemSearchTermProvider);
  return ref.watch(catalogRepositoryProvider).searchItems(term);
});

/// Resolved POS session context (profile/price list/warehouse).
final profileContextProvider = FutureProvider<ProfileContext>(
  (ref) => ref.watch(catalogRepositoryProvider).profileContext(),
);

/// Customer search results.
final customerSearchTermProvider = StateProvider<String>((_) => '');
final customerListProvider =
    FutureProvider.autoDispose<List<PosCustomer>>((ref) {
  final term = ref.watch(customerSearchTermProvider);
  return ref.watch(catalogRepositoryProvider).searchCustomers(term);
});

/// Offline-fallback totals for the current cart. While online, Phase 2 replaces
/// this with the server's `compute_si_taxes`.
final cartTotalsProvider = Provider<CartTotals>((ref) {
  final cart = ref.watch(cartControllerProvider);
  return ref.watch(taxEngineProvider).compute(cart);
});
