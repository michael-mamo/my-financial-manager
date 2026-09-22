import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/account.dart';
import '../../core/models/category.dart';
import '../../core/models/recurring_transaction.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/formatters.dart';

/// Section 23. New transactions from these rules are created on app launch
/// (Addendum #7) — there's no "run now" button here by design, since the
/// catch-up already covers it; this screen is for managing the rules.
class RecurringListScreen extends ConsumerWidget {
  const RecurringListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringTransactionsProvider);
    final currency = ref.watch(currencyProvider);
    final useEthiopian = ref.watch(ethiopianCalendarProvider);
    final locale = ref.watch(localeProvider).languageCode;

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Transactions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(context, ref),
        child: const Icon(Icons.add),
      ),
      body: recurringAsync.when(
        data: (items) => items.isEmpty
            ? const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No recurring transactions yet — e.g. monthly salary or rent.'),
              ))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final r = items[i];
                  return Card(
                    child: ListTile(
                      title: Text(r.description?.isNotEmpty == true ? r.description! : (r.type == 'income' ? 'Income' : 'Expense')),
                      subtitle: Text('${_frequencyLabel(r.frequency)} · next ${formatDateDisplay(r.nextDate, useEthiopian: useEthiopian, locale: locale)}'),
                      trailing: Text(
                        '${r.type == 'income' ? '+' : '-'}${formatMoney(r.amount, currency)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: r.type == 'income' ? Colors.green : Colors.red,
                        ),
                      ),
                      onLongPress: () async {
                        await ref.read(recurringTransactionRepositoryProvider).delete(r.id!);
                        ref.invalidate(recurringTransactionsProvider);
                      },
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load recurring transactions: $e')),
      ),
    );
  }

  String _frequencyLabel(RecurringFrequency f) {
    switch (f) {
      case RecurringFrequency.daily:
        return 'Daily';
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }

  void _openAdd(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddRecurringSheet(),
    ).then((_) => ref.invalidate(recurringTransactionsProvider));
  }
}

class _AddRecurringSheet extends ConsumerStatefulWidget {
  const _AddRecurringSheet();

  @override
  ConsumerState<_AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends ConsumerState<_AddRecurringSheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = 'expense';
  Category? _category;
  Account? _account;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  DateTime _nextDate = DateTime.now();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = _type == 'income'
        ? ref.watch(incomeCategoriesProvider)
        : ref.watch(expenseCategoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final currency = ref.watch(currencyProvider);

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Recurring', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _category = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Amount', suffixText: currency),
            ),
            const SizedBox(height: 12),
            categoriesAsync.when(
              data: (categories) => DropdownButtonFormField<Category>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c.nameEn))).toList(),
                onChanged: (v) => setState(() => _category = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load categories: $e'),
            ),
            const SizedBox(height: 12),
            accountsAsync.when(
              data: (accounts) {
                _account ??= accounts.isNotEmpty ? accounts.first : null;
                return DropdownButtonFormField<Account>(
                  value: _account,
                  decoration: const InputDecoration(labelText: 'Account'),
                  items: accounts.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
                  onChanged: (v) => setState(() => _account = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load accounts: $e'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RecurringFrequency>(
              value: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: RecurringFrequency.values
                  .map((f) => DropdownMenuItem(value: f, child: Text(_label(f))))
                  .toList(),
              onChanged: (v) => setState(() => _frequency = v ?? RecurringFrequency.monthly),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Next Date'),
              subtitle: Text(formatDate(_nextDate)),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _nextDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _nextDate = picked);
              },
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description', hintText: 'Optional'),
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
      ),
    );
  }

  String _label(RecurringFrequency f) {
    switch (f) {
      case RecurringFrequency.daily:
        return 'Daily';
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0 || _account?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount and select an account')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(recurringTransactionRepositoryProvider).create(RecurringTransaction(
            type: _type,
            amount: amount,
            categoryId: _category?.id,
            accountId: _account!.id!,
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            frequency: _frequency,
            nextDate: _nextDate,
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
