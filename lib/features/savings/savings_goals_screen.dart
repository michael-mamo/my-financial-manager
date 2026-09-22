import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/account.dart';
import '../../core/models/savings_goal.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import 'goal_detail_screen.dart';

/// Phase 11: savings goals list + creation. Each goal is tied to an
/// account (Spec Addendum #1's pattern, applied to goals) — contributions
/// and withdrawals move real money through that account, tracked on the
/// detail screen.
class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currency = ref.watch(currencyProvider);
    final goalsAsync = ref.watch(savingsGoalsProvider(null));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.savingsGoalsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddGoal(context, ref),
        child: const Icon(Icons.add),
      ),
      body: goalsAsync.when(
        data: (goals) => goals.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.savingsGoalNoGoals, textAlign: TextAlign.center),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: goals.length,
                itemBuilder: (context, i) => _GoalCard(
                  goal: goals[i],
                  currency: currency,
                  l10n: l10n,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: goals[i].id!)),
                  ).then((_) => ref.invalidate(savingsGoalsProvider)),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load savings goals: $e')),
      ),
    );
  }

  void _openAddGoal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddGoalSheet(),
    ).then((_) => ref.invalidate(savingsGoalsProvider));
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final String currency;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  const _GoalCard({required this.goal, required this.currency, required this.l10n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isComplete = goal.status == SavingsGoalStatus.completed;
    final color = isComplete ? Colors.green : Theme.of(context).colorScheme.primary;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(goal.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (isComplete)
                    Chip(
                      label: Text(l10n.savingsGoalStatusCompleted, style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.green.withOpacity(0.15),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: goal.progress, minHeight: 8, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.savingsGoalSavedOf(
                  formatMoney(goal.currentAmount, currency),
                  formatMoney(goal.targetAmount, currency),
                ),
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddGoalSheet extends ConsumerStatefulWidget {
  const _AddGoalSheet();

  @override
  ConsumerState<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<_AddGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  Account? _selectedAccount;
  DateTime? _targetDate;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            Text(l10n.savingsGoalAdd, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.savingsGoalName),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.savingsGoalValidationNameRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _targetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.savingsGoalTargetAmount, suffixText: currency),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (value == null || value.isEmpty) return l10n.savingsGoalValidationTargetRequired;
                if (parsed == null || parsed <= 0) return l10n.validationAmountPositive;
                return null;
              },
            ),
            const SizedBox(height: 12),
            accountsAsync.when(
              data: (accounts) {
                _selectedAccount ??= accounts.isNotEmpty ? accounts.first : null;
                return DropdownButtonFormField<Account>(
                  value: _selectedAccount,
                  decoration: InputDecoration(labelText: l10n.fieldAccount),
                  items: accounts.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
                  onChanged: (v) => setState(() => _selectedAccount = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load accounts: $e'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.savingsGoalTargetDate),
              subtitle: Text(_targetDate == null
                  ? l10n.savingsGoalTargetDateOptional
                  : formatDate(_targetDate!)),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _targetDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _targetDate = picked);
              },
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
    try {
      await ref.read(savingsGoalRepositoryProvider).create(SavingsGoal(
            name: _nameController.text.trim(),
            targetAmount: double.parse(_targetController.text),
            accountId: _selectedAccount!.id!,
            targetDate: _targetDate,
            createdAt: DateTime.now(),
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
