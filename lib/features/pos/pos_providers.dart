import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../domain/models/payment.dart';
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

/// Instant offline-calculated totals for the live cart pane (responsive). The
/// authoritative server totals are fetched at checkout (see CheckoutRepository).
final cartTotalsProvider = Provider<CartTotals>((ref) {
  final cart = ref.watch(cartControllerProvider);
  return ref.watch(taxEngineProvider).compute(cart);
});

/// Payment methods available for the current POS profile.
final paymentModesProvider = FutureProvider<List<PaymentMode>>(
  (ref) => ref.watch(catalogRepositoryProvider).paymentModes(),
);

/// Configured site URL (for building absolute image/logo URLs).
final siteUrlProvider = FutureProvider<String?>(
  (ref) => ref.watch(appConfigProvider).siteUrl,
);

/// Auth headers for fetching (possibly private) ERPNext files/images.
final authHeadersProvider = FutureProvider<Map<String, String>>((ref) async {
  final cfg = ref.watch(appConfigProvider);
  final key = await cfg.apiKey;
  final secret = await cfg.apiSecret;
  if (key == null || secret == null) return const {};
  return {'Authorization': 'token $key:$secret'};
});

/// Available POS profiles (for the profile picker).
final posProfilesProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(catalogRepositoryProvider).listProfiles(),
);

/// Company logo URL for app branding.
final companyLogoProvider = FutureProvider<String?>(
  (ref) => ref.watch(catalogRepositoryProvider).companyLogoUrl(),
);
