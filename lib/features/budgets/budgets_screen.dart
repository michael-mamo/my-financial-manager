import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget.dart';
import '../../core/models/category.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/formatters.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final period = (month: now.month, year: now.year);
    final progressAsync = ref.watch(budgetProgressProvider(period));
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(context, ref, now.month, now.year),
        child: const Icon(Icons.add),
      ),
      body: progressAsync.when(
        data: (items) => items.isEmpty
            ? const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No budgets set for this month yet.'),
              ))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, i) => _BudgetCard(progress: items[i], currency: currency),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load budgets: $e')),
      ),
    );
  }

  void _openAdd(BuildContext context, WidgetRef ref, int month, int year) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddBudgetSheet(month: month, year: year),
    ).then((_) => ref.invalidate(budgetProgressProvider));
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetProgress progress;
  final String currency;
  const _BudgetCard({required this.progress, required this.currency});

  @override
  Widget build(BuildContext context) {
    final color = progress.isOverBudget
        ? Colors.red
        : progress.isNearLimit
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(progress.categoryName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.fraction > 1 ? 1 : progress.fraction,
                minHeight: 8,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Spent ${formatMoney(progress.spent, currency)}'),
                Text('Budget ${formatMoney(progress.budget.amount, currency)}'),
              ],
            ),
            if (progress.isOverBudget)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Over budget by ${formatMoney(-progress.remaining, currency)}',
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              )
            else if (progress.isNearLimit)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${formatMoney(progress.remaining, currency)} remaining — nearly there',
                    style: const TextStyle(color: Colors.orange, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddBudgetSheet extends ConsumerStatefulWidget {
  final int month;
  final int year;
  const _AddBudgetSheet({required this.month, required this.year});

  @override
  ConsumerState<_AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends ConsumerState<_AddBudgetSheet> {
  final _amountController = TextEditingController();
  Category? _category;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final currency = ref.watch(currencyProvider);

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Budget', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
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
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Monthly Budget', suffixText: currency),
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
    final amount = double.tryParse(_amountController.text);
    if (_category?.id == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a category and enter an amount')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(budgetRepositoryProvider).create(Budget(
            categoryId: _category!.id!,
            amount: amount,
            month: widget.month,
            year: widget.year,
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
