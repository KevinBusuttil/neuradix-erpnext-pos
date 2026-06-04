import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';

/// Shell for the main POS workspace. Phase 1 fills the left pane with the item
/// selector and the right pane with the cart; for now it wires the sync manager
/// and shows the pending-queue badge so the offline shim is observable.
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  @override
  void initState() {
    super.initState();
    // Start flushing the outbound queue when connectivity allows.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncManagerProvider).start();
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
        ],
      ),
      body: const Row(
        children: [
          Expanded(
            flex: 3,
            child: _Placeholder(
              icon: Icons.grid_view,
              label: 'Item selector (Phase 1)',
            ),
          ),
          VerticalDivider(width: 1),
          Expanded(
            flex: 2,
            child: _Placeholder(
              icon: Icons.shopping_cart_outlined,
              label: 'Cart + payment (Phase 1–2)',
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).disabledColor),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
