import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';

/// First-run connection setup: site URL + API token. Stored securely and reused
/// while offline.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _site = TextEditingController();
  final _key = TextEditingController();
  final _secret = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _site.dispose();
    _key.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final cfg = ref.read(appConfigProvider);
    await cfg.setSite(_site.text.trim());
    await cfg.setToken(_key.text.trim(), _secret.text.trim());
    ref.invalidate(isConfiguredProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NeuroPOS — Connect')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _site,
                  decoration: const InputDecoration(
                    labelText: 'Site URL',
                    hintText: 'https://erp.ccj.example',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _key,
                  decoration: const InputDecoration(labelText: 'API Key'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _secret,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'API Secret'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Connect'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
