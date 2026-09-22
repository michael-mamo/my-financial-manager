import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/account.dart';
import '../../core/models/category.dart';
import '../../core/models/payment_method.dart';
import '../../core/models/transaction.dart' as model;
import '../../core/providers/app_providers.dart';
import '../../l10n/app_localizations.dart';

/// Section 7/8/42: amount -> category -> Save in as few taps as possible.
/// Date/account/payment-method/description default sensibly and only need
/// touching when they should differ from the default.
class AddTransactionScreen extends ConsumerStatefulWidget {
  final model.TransactionType type;
  const AddTransactionScreen({super.key, required this.type});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Category? _selectedCategory;
  Account? _selectedAccount;
  PaymentMethod? _selectedPaymentMethod;
  DateTime _date = DateTime.now();
  bool _showMoreOptions = false;
  bool _saving = false;

  bool get _isIncome => widget.type == model.TransactionType.income;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = _isIncome
        ? ref.watch(incomeCategoriesProvider)
        : ref.watch(expenseCategoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final paymentMethodsAsync = ref.watch(paymentMethodRepositoryProvider).getAll();
    final currency = ref.watch(currencyProvider);
    final languageCode = ref.watch(localeProvider).languageCode;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(_isIncome ? l10n.incomeAddTitle : l10n.expenseAddTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(labelText: l10n.fieldAmount, suffixText: currency),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (value == null || value.isEmpty) return l10n.validationAmountRequired;
                if (parsed == null || parsed <= 0) return l10n.validationAmountPositive;
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text(l10n.fieldCategory, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            categoriesAsync.when(
              // Category names come from the record itself (seeded with
              // both an English and an Amharic name), not from this arb
              // file, so this passes the live language code through
              // instead of a hardcoded 'en' — previously every category
              // chip showed its English name regardless of app language.
              data: (categories) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((c) {
                  final selected = _selectedCategory?.id == c.id;
                  return ChoiceChip(
                    label: Text(c.displayName(languageCode)),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedCategory = c),
                  );
                }).toList(),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load categories: $e'),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => setState(() => _showMoreOptions = !_showMoreOptions),
              icon: Icon(_showMoreOptions ? Icons.expand_less : Icons.expand_more),
              label: Text(l10n.fieldMoreOptions),
            ),
            if (_showMoreOptions) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.fieldDate),
                subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              accountsAsync.when(
                data: (accounts) {
                  _selectedAccount ??= accounts.isNotEmpty ? accounts.first : null;
                  return DropdownButtonFormField<Account>(
                    value: _selectedAccount,
                    decoration: InputDecoration(labelText: l10n.fieldAccount),
                    items: accounts
                        .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedAccount = v),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Could not load accounts: $e'),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<PaymentMethod>>(
                future: paymentMethodsAsync,
                builder: (context, snapshot) {
                  final methods = snapshot.data ?? [];
                  if (methods.isNotEmpty) _selectedPaymentMethod ??= methods.first;
                  return DropdownButtonFormField<PaymentMethod>(
                    value: _selectedPaymentMethod,
                    decoration: InputDecoration(labelText: l10n.fieldPaymentMethod),
                    items: methods
                        .map((m) => DropdownMenuItem(value: m, child: Text(m.displayName(languageCode))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedPaymentMethod = v),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: l10n.fieldDescription, hintText: l10n.fieldDescriptionHint),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : () => _save(accountsAsync.value),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.actionSave),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(List<Account>? accounts) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.validationCategoryRequired)),
      );
      return;
    }
    final account = _selectedAccount ?? (accounts?.isNotEmpty == true ? accounts!.first : null);
    if (account?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.validationAccountRequired)),
      );
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final txn = model.Transaction(
      accountId: account!.id!,
      categoryId: _selectedCategory!.id,
      type: widget.type,
      amount: double.parse(_amountController.text),
      date: _date,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      paymentMethodId: _selectedPaymentMethod?.id,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await ref.read(transactionRepositoryProvider).recordIncomeOrExpense(txn);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(monthTotalsProvider);
      ref.invalidate(recentTransactionsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }
}
