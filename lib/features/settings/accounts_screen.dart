import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/account.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/formatters.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddAccount(context, ref),
        child: const Icon(Icons.add),
      ),
      body: accountsAsync.when(
        data: (accounts) {
          final total = accounts.fold<double>(0, (sum, a) => sum + a.currentBalance);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total'),
                    Text(formatMoney(total, currency),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...accounts.map((a) => Card(
                    child: ListTile(
                      title: Text(a.name),
                      subtitle: Text(_typeLabel(a.accountType)),
                      trailing: Text(
                        formatMoney(a.currentBalance, currency),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  )),
              const SizedBox(height: 80),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load accounts: $e')),
      ),
    );
  }

  String _typeLabel(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank';
      case AccountType.mobileMoney:
        return 'Mobile Money';
      case AccountType.other:
        return 'Other';
    }
  }

  void _openAddAccount(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddAccountSheet(),
    ).then((_) => ref.invalidate(accountsProvider));
  }
}

class _AddAccountSheet extends ConsumerStatefulWidget {
  const _AddAccountSheet();

  @override
  ConsumerState<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<_AddAccountSheet> {
  final _nameController = TextEditingController();
  final _openingBalanceController = TextEditingController(text: '0');
  AccountType _type = AccountType.cash;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AccountType>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: AccountType.cash, child: Text('Cash')),
              DropdownMenuItem(value: AccountType.bank, child: Text('Bank')),
              DropdownMenuItem(value: AccountType.mobileMoney, child: Text('Mobile Money')),
              DropdownMenuItem(value: AccountType.other, child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _type = v ?? AccountType.cash),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _openingBalanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Opening Balance', suffixText: currency),
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
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final opening = double.tryParse(_openingBalanceController.text) ?? 0;
    final account = Account(
      name: _nameController.text.trim(),
      accountType: _type,
      currency: ref.read(currencyProvider),
      openingBalance: opening,
      currentBalance: opening,
      createdAt: DateTime.now(),
    );
    try {
      await ref.read(accountRepositoryProvider).create(account);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }
}
