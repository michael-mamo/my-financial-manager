import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/payment_method.dart';
import '../../core/providers/app_providers.dart';

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodsAsync = ref.watch(paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(context, ref),
        child: const Icon(Icons.add),
      ),
      body: methodsAsync.when(
        data: (methods) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: methods.length,
          itemBuilder: (context, i) {
            final m = methods[i];
            return ListTile(
              title: Text(m.nameEn),
              subtitle: Text(m.nameAm),
              trailing: m.isDefault
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ref.read(paymentMethodRepositoryProvider).deactivate(m.id!);
                        ref.invalidate(paymentMethodsProvider);
                      },
                    ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load payment methods: $e')),
      ),
    );
  }

  void _openAdd(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddPaymentMethodSheet(),
    ).then((_) => ref.invalidate(paymentMethodsProvider));
  }
}

class _AddPaymentMethodSheet extends ConsumerStatefulWidget {
  const _AddPaymentMethodSheet();

  @override
  ConsumerState<_AddPaymentMethodSheet> createState() => _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState extends ConsumerState<_AddPaymentMethodSheet> {
  final _nameEnController = TextEditingController();
  final _nameAmController = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Payment Method', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameEnController,
            decoration: const InputDecoration(labelText: 'Name (English)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameAmController,
            decoration: const InputDecoration(labelText: 'Name (Amharic) — optional'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final nameEn = _nameEnController.text.trim();
    if (nameEn.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(paymentMethodRepositoryProvider).create(PaymentMethod(
            nameEn: nameEn,
            nameAm: _nameAmController.text.trim().isEmpty ? nameEn : _nameAmController.text.trim(),
          ));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }
}
