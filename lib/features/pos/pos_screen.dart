import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import 'pos_providers.dart';
import 'widgets/cart_pane.dart';
import 'widgets/item_selector_pane.dart';

/// Main POS workspace: item selector (left) + cart (right). Wires the sync
/// manager so the outbound queue flushes when connectivity allows.
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncManagerProvider).start();
      ref.read(catalogRepositoryProvider).refreshSnapshot().ignore();
    });
  }

  Future<void> _pickProfile() async {
    final profiles = await ref.read(posProfilesProvider.future);
    if (!mounted) return;
    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Select POS Profile'),
        children: [
          for (final p in profiles)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, p),
              child: Text(p),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await ref.read(catalogRepositoryProvider).setProfile(chosen);
    ref
      ..invalidate(profileContextProvider)
      ..invalidate(itemListProvider)
      ..invalidate(paymentModesProvider)
      ..invalidate(companyLogoProvider);
    ref.read(catalogRepositoryProvider).refreshSnapshot().ignore();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(invoiceRepositoryProvider).watchPending();
    final logo = ref.watch(companyLogoProvider).valueOrNull;
    final profile = ref.watch(profileContextProvider).valueOrNull?.posProfile;
    final headers = ref.watch(authHeadersProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (logo != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    logo,
                    headers: headers,
                    height: 30,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            const Text('NeuroPOS'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _pickProfile,
            icon: const Icon(Icons.point_of_sale, color: Colors.white),
            label: Text(
              profile ?? 'Profile',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          StreamBuilder(
            stream: pending,
            builder: (context, snap) {
              final n = snap.data?.length ?? 0;
              if (n == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Chip(
                  avatar: const Icon(Icons.sync, size: 16),
                  label: Text('$n queued'),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh offline snapshot',
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: () async {
              try {
                await ref.read(catalogRepositoryProvider).refreshSnapshot();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Snapshot refreshed')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Snapshot failed: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Row(
        children: [
          const Expanded(flex: 3, child: ItemSelectorPane()),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 2,
            child: Material(
              color: Colors.white,
              child: const CartPane(),
            ),
          ),
        ],
      ),
    );
  }
}
