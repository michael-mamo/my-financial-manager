import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/account.dart';
import '../../core/models/savings_goal.dart';
import '../../core/models/savings_goal_contribution.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';

class GoalDetailScreen extends ConsumerWidget {
  final int goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final goalAsync = ref.watch(savingsGoalByIdProvider(goalId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.savingsGoalsTitle)),
      body: goalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load goal: $e')),
        data: (goal) {
          if (goal == null) return const Center(child: Text('Goal not found'));
          return _GoalDetailBody(goal: goal, l10n: l10n);
        },
      ),
    );
  }
}

class _GoalDetailBody extends ConsumerWidget {
  final SavingsGoal goal;
  final AppLocalizations l10n;
  const _GoalDetailBody({required this.goal, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final useEthiopian = ref.watch(ethiopianCalendarProvider);
    final locale = ref.watch(localeProvider).languageCode;
    final contributionsAsync = ref.watch(savingsGoalContributionsProvider(goal.id!));
    final isComplete = goal.status == SavingsGoalStatus.completed;
    final color = isComplete ? Colors.green : Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(goal.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: goal.progress, minHeight: 12, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.savingsGoalSavedOf(
            formatMoney(goal.currentAmount, currency),
            formatMoney(goal.targetAmount, currency),
          ),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (isComplete)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l10n.savingsGoalCompleted, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
          ),
        if (goal.targetDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${l10n.savingsGoalTargetDate}: ${formatDateDisplay(goal.targetDate!, useEthiopian: useEthiopian, locale: locale)}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.savingsGoalContribute),
                onPressed: () => _openMoveMoney(context, ref, isWithdrawal: false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.remove),
                label: Text(l10n.savingsGoalWithdraw),
                onPressed: goal.currentAmount <= 0
                    ? null
                    : () => _openMoveMoney(context, ref, isWithdrawal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(l10n.savingsGoalHistory, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        contributionsAsync.when(
          data: (items) => items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(l10n.savingsGoalNoHistory),
                )
              : Column(
                  children: items
                      .map((c) => _ContributionTile(
                            contribution: c,
                            currency: currency,
                            useEthiopian: useEthiopian,
                            locale: locale,
                          ))
                      .toList(),
                ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Could not load history: $e'),
        ),
      ],
    );
  }

  void _openMoveMoney(BuildContext context, WidgetRef ref, {required bool isWithdrawal}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MoveMoneySheet(goal: goal, isWithdrawal: isWithdrawal, l10n: l10n),
    ).then((_) {
      ref.invalidate(savingsGoalByIdProvider(goal.id!));
      ref.invalidate(savingsGoalContributionsProvider(goal.id!));
      ref.invalidate(savingsGoalsProvider);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(accountsProvider);
    });
  }
}

class _ContributionTile extends StatelessWidget {
  final SavingsGoalContribution contribution;
  final String currency;
  final bool useEthiopian;
  final String locale;
  const _ContributionTile({
    required this.contribution,
    required this.currency,
    required this.useEthiopian,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final isWithdrawal = contribution.type == SavingsGoalContributionType.withdrawal;
    final sign = isWithdrawal ? '-' : '+';
    final color = isWithdrawal ? Colors.red : Colors.green;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(contribution.note?.isNotEmpty == true ? contribution.note! : (isWithdrawal ? 'Withdrawal' : 'Contribution')),
      subtitle: Text(formatDateDisplay(contribution.date, useEthiopian: useEthiopian, locale: locale)),
      trailing: Text(
        '$sign${formatMoney(contribution.amount, currency)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MoveMoneySheet extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  final bool isWithdrawal;
  final AppLocalizations l10n;
  const _MoveMoneySheet({required this.goal, required this.isWithdrawal, required this.l10n});

  @override
  ConsumerState<_MoveMoneySheet> createState() => _MoveMoneySheetState();
}

class _MoveMoneySheetState extends ConsumerState<_MoveMoneySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  Account? _selectedAccount;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final accountsAsync = ref.watch(accountsProvider);
    final currency = ref.watch(currencyProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isWithdrawal ? l10n.savingsGoalWithdraw : l10n.savingsGoalContribute,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(labelText: l10n.savingsGoalAmount, suffixText: currency),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (value == null || value.isEmpty) return l10n.validationAmountRequired;
                if (parsed == null || parsed <= 0) return l10n.validationAmountPositive;
                if (widget.isWithdrawal && parsed > widget.goal.currentAmount) {
                  return l10n.savingsGoalWithdrawExceeds;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            accountsAsync.when(
              data: (accounts) {
                if (_selectedAccount == null && accounts.isNotEmpty) {
                  _selectedAccount = accounts.firstWhere(
                    (a) => a.id == widget.goal.accountId,
                    orElse: () => accounts.first,
                  );
                }
                return DropdownButtonFormField<Account>(
                  value: _selectedAccount,
                  decoration: InputDecoration(
                    labelText: widget.isWithdrawal ? l10n.savingsGoalToAccount : l10n.savingsGoalFromAccount,
                  ),
                  items: accounts.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
                  onChanged: (v) => setState(() => _selectedAccount = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load accounts: $e'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(labelText: l10n.savingsGoalNote, hintText: l10n.savingsGoalNoteHint),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.actionSave),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _selectedAccount == null) return;
    setState(() => _saving = true);
    final amount = double.parse(_amountController.text);
    final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();
    try {
      final repo = ref.read(savingsGoalRepositoryProvider);
      if (widget.isWithdrawal) {
        await repo.withdraw(
          goal: widget.goal,
          amount: amount,
          date: DateTime.now(),
          accountId: _selectedAccount!.id!,
          note: note,
        );
      } else {
        await repo.contribute(
          goal: widget.goal,
          amount: amount,
          date: DateTime.now(),
          accountId: _selectedAccount!.id!,
          note: note,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }
}
