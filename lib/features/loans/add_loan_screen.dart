import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/account.dart';
import '../../core/models/loan.dart';
import '../../core/providers/app_providers.dart';
import '../../l10n/app_localizations.dart';

/// Sections 10 (Borrowed), 11/12 (Lent), 15 (interest). One screen with a
/// type toggle rather than two near-identical screens.
class AddLoanScreen extends ConsumerStatefulWidget {
  final LoanType initialType;
  const AddLoanScreen({super.key, this.initialType = LoanType.borrowed});

  @override
  ConsumerState<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends ConsumerState<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _personNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _interestValueController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _installmentAmountController = TextEditingController();

  late LoanType _loanType;
  Account? _selectedAccount;
  InterestMode _interestMode = InterestMode.none;
  DateTime _startDate = DateTime.now();
  DateTime? _dueDate;
  LoanFrequency? _frequency;
  bool _showMoreOptions = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loanType = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final currency = ref.watch(currencyProvider);
    final isBorrowed = _loanType == LoanType.borrowed;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.loanTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<LoanType>(
              segments: const [
                ButtonSegment(value: LoanType.borrowed, label: Text('Money I Borrowed')),
                ButtonSegment(value: LoanType.lent, label: Text('Money I Lent')),
              ],
              selected: {_loanType},
              onSelectionChanged: (s) => setState(() => _loanType = s.first),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _personNameController,
              decoration: InputDecoration(labelText: isBorrowed ? 'Loan From' : 'Person'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(labelText: 'Amount', suffixText: currency),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (value == null || value.isEmpty) return 'Enter an amount';
                if (parsed == null || parsed <= 0) return 'Amount must be greater than zero';
                return null;
              },
            ),
            const SizedBox(height: 12),
            accountsAsync.when(
              data: (accounts) {
                _selectedAccount ??= accounts.isNotEmpty ? accounts.first : null;
                return DropdownButtonFormField<Account>(
                  value: _selectedAccount,
                  decoration: InputDecoration(
                    labelText: isBorrowed ? 'Deposit To' : 'Pay From',
                  ),
                  items: accounts
                      .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedAccount = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load accounts: $e'),
            ),
            const SizedBox(height: 20),
            Text('Interest', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('No Interest'),
                  selected: _interestMode == InterestMode.none,
                  onSelected: (_) => setState(() => _interestMode = InterestMode.none),
                ),
                ChoiceChip(
                  label: const Text('Fixed Amount'),
                  selected: _interestMode == InterestMode.fixed,
                  onSelected: (_) => setState(() => _interestMode = InterestMode.fixed),
                ),
                ChoiceChip(
                  label: const Text('Percentage'),
                  selected: _interestMode == InterestMode.percentage,
                  onSelected: (_) => setState(() => _interestMode = InterestMode.percentage),
                ),
              ],
            ),
            if (_interestMode != InterestMode.none) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _interestValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _interestMode == InterestMode.fixed
                      ? 'Interest Amount ($currency)'
                      : 'Interest Rate (%)',
                ),
                validator: (value) {
                  if (_interestMode == InterestMode.none) return null;
                  final parsed = double.tryParse(value ?? '');
                  if (value == null || value.isEmpty) return 'Enter a value';
                  if (parsed == null || parsed < 0) return 'Enter a valid value';
                  return null;
                },
              ),
              const SizedBox(height: 4),
              Text(
                'Interest is calculated once, as a flat amount — it does not '
                'change over time or compound.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => setState(() => _showMoreOptions = !_showMoreOptions),
              icon: Icon(_showMoreOptions ? Icons.expand_less : Icons.expand_more),
              label: const Text('More Options'),
            ),
            if (_showMoreOptions) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due Date'),
                subtitle: Text(_dueDate == null
                    ? 'Not set'
                    : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? _startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
                },
              ),
              DropdownButtonFormField<LoanFrequency>(
                value: _frequency,
                decoration: const InputDecoration(labelText: 'Payment Frequency'),
                items: LoanFrequency.values
                    .map((f) => DropdownMenuItem(value: f, child: Text(_frequencyLabel(f))))
                    .toList(),
                onChanged: (v) => setState(() => _frequency = v),
              ),
              if (_frequency != null) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _installmentAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Installment Amount',
                    suffixText: currency,
                    helperText: 'Optional — lets the loan show a payment schedule (Section 14).',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description', hintText: 'Optional'),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : () => _save(accountsAsync.value),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _frequencyLabel(LoanFrequency f) {
    switch (f) {
      case LoanFrequency.daily:
        return 'Daily';
      case LoanFrequency.weekly:
        return 'Weekly';
      case LoanFrequency.biweekly:
        return 'Biweekly';
      case LoanFrequency.monthly:
        return 'Monthly';
      case LoanFrequency.custom:
        return 'Custom';
    }
  }

  Future<void> _save(List<Account>? accounts) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final account = _selectedAccount ?? (accounts?.isNotEmpty == true ? accounts!.first : null);
    if (account?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an account')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final personId =
          await ref.read(personRepositoryProvider).findOrCreateByName(_personNameController.text);

      final loan = Loan.create(
        personId: personId,
        accountId: account!.id!,
        loanType: _loanType,
        principalAmount: double.parse(_amountController.text),
        interestMode: _interestMode,
        interestValue: _interestMode == InterestMode.none
            ? 0
            : double.parse(_interestValueController.text),
        startDate: _startDate,
        dueDate: _dueDate,
        frequency: _frequency,
        installmentAmount: _installmentAmountController.text.trim().isEmpty
            ? null
            : double.tryParse(_installmentAmountController.text.trim()),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      await ref.read(loanRepositoryProvider).createLoan(loan);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(loanDashboardTotalsProvider);
      ref.invalidate(loansProvider);
      ref.invalidate(recentTransactionsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }
}
