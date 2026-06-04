import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
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
      // Best-effort: warm the offline snapshot cache while online.
      ref.read(catalogRepositoryProvider).refreshSnapshot().ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(invoiceRepositoryProvider).watchPending();
    return Scaffold(
      appBar: AppBar(
        title: const Text('NeuroPOS'),
        actions: [
          StreamBuilder(
            stream: pending,
            builder: (context, snap) {
              final n = snap.data?.length ?? 0;
              if (n == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Chip(label: Text('$n queued')),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh offline snapshot',
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: () async {
              await ref.read(catalogRepositoryProvider).refreshSnapshot();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Snapshot refreshed')),
                );
              }
            },
          ),
        ],
      ),
      body: const Row(
        children: [
          Expanded(flex: 3, child: ItemSelectorPane()),
          VerticalDivider(width: 1),
          Expanded(flex: 2, child: CartPane()),
        ],
      ),
    );
  }
}
