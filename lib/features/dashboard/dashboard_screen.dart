import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/account.dart';
import '../../core/models/transaction.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../income_expense/add_transaction_screen.dart';
import '../loans/add_loan_screen.dart';
import '../loans/loan_list_screen.dart';

/// Masked stand-in shown for any amount while [hideBalancesProvider] is on.
/// A fixed-width glyph run rather than the real digit count, so the mask
/// itself never leaks how large a balance is.
const _maskedAmount = '••••••';

/// Section 6: balance, this-month summary, loan snapshot, quick actions,
/// recent transactions.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final balanceAsync = ref.watch(totalBalanceProvider);
    final monthAsync = ref.watch(monthTotalsProvider);
    final recentAsync = ref.watch(recentTransactionsProvider);
    final hideBalances = ref.watch(hideBalancesProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboardTitle),
        actions: [
          IconButton(
            icon: Icon(hideBalances ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            tooltip: hideBalances ? l10n.dashboardShowBalances : l10n.dashboardHideBalances,
            onPressed: () => _toggleHideBalances(ref, hideBalances),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(totalBalanceProvider);
          ref.invalidate(accountsProvider);
          ref.invalidate(monthTotalsProvider);
          ref.invalidate(recentTransactionsProvider);
          ref.invalidate(loanDashboardTotalsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _BalanceCard(currency: currency, balanceAsync: balanceAsync, hidden: hideBalances),
            const SizedBox(height: 16),
            _AccountsCard(currency: currency, hidden: hideBalances),
            const SizedBox(height: 16),
            _MonthSummaryCard(currency: currency, monthAsync: monthAsync),
            const SizedBox(height: 16),
            _LoanSnapshotCard(currency: currency, totalsAsync: ref.watch(loanDashboardTotalsProvider)),
            const SizedBox(height: 16),
            _QuickActions(),
            const SizedBox(height: 16),
            Text(l10n.dashboardRecentTransactions, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            recentAsync.when(
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(l10n.dashboardNoTransactions),
                    )
                  : Column(children: items.map((t) => _TransactionTile(
                      t, currency, ref.watch(ethiopianCalendarProvider), ref.watch(localeProvider).languageCode,
                    )).toList()),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Could not load transactions: $e'),
            ),
          ],
        ),
      ),
    );
  }

  /// Flips the toggle immediately (so the UI responds right away) and
  /// persists it the same way the Ethiopian-calendar toggle does, so it
  /// survives an app restart.
  Future<void> _toggleHideBalances(WidgetRef ref, bool current) async {
    final next = !current;
    ref.read(hideBalancesProvider.notifier).state = next;
    final repo = ref.read(settingsRepositoryProvider);
    final settings = await repo.getOrCreate();
    await repo.save(settings.copyWith(hideBalances: next));
  }
}

class _BalanceCard extends StatelessWidget {
  final String currency;
  final AsyncValue<double> balanceAsync;
  final bool hidden;
  const _BalanceCard({required this.currency, required this.balanceAsync, required this.hidden});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.dashboardBalance, style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 14)),
          const SizedBox(height: 4),
          balanceAsync.when(
            data: (balance) => Text(
              hidden ? _maskedAmount : formatMoney(balance, currency),
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            loading: () => const SizedBox(height: 34, child: LinearProgressIndicator()),
            error: (e, _) => const Text('—'),
          ),
        ],
      ),
    );
  }
}

/// Per-account breakdown backing the Balance card's total (Phase 10 #1) —
/// each active account with its own balance, masked in lockstep with the
/// total via the same [hidden] flag.
class _AccountsCard extends ConsumerWidget {
  final String currency;
  final bool hidden;
  const _AccountsCard({required this.currency, required this.hidden});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accountsAsync = ref.watch(accountsProvider);
    return _Card(
      title: l10n.dashboardAccounts,
      child: accountsAsync.when(
        data: (accounts) => accounts.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.dashboardNoAccounts),
              )
            : Column(
                children: accounts
                    .map((a) => _AccountRow(account: a, currency: currency, hidden: hidden, l10n: l10n))
                    .toList(),
              ),
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('Could not load accounts: $e'),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final Account account;
  final String currency;
  final bool hidden;
  final AppLocalizations l10n;
  const _AccountRow({required this.account, required this.currency, required this.hidden, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(_typeIcon(account.accountType), size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name, overflow: TextOverflow.ellipsis),
                Text(
                  _typeLabel(account.accountType),
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            hidden ? _maskedAmount : formatMoney(account.currentBalance, currency),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.payments_outlined;
      case AccountType.bank:
        return Icons.account_balance_outlined;
      case AccountType.mobileMoney:
        return Icons.phone_android_outlined;
      case AccountType.other:
        return Icons.wallet_outlined;
    }
  }

  String _typeLabel(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return l10n.accountTypeCash;
      case AccountType.bank:
        return l10n.accountTypeBank;
      case AccountType.mobileMoney:
        return l10n.accountTypeMobileMoney;
      case AccountType.other:
        return l10n.accountTypeOther;
    }
  }
}

class _MonthSummaryCard extends StatelessWidget {
  final String currency;
  final AsyncValue<Map<String, double>> monthAsync;
  const _MonthSummaryCard({required this.currency, required this.monthAsync});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _Card(
      title: l10n.dashboardThisMonth,
      child: monthAsync.when(
        data: (totals) {
          final income = totals['income'] ?? 0;
          final expense = totals['expense'] ?? 0;
          final net = income - expense;
          return Row(
            children: [
              _StatColumn(label: l10n.dashboardIncome, value: formatMoney(income, currency), color: Colors.green),
              _StatColumn(label: l10n.dashboardExpenses, value: formatMoney(expense, currency), color: Colors.red),
              _StatColumn(label: l10n.dashboardNet, value: formatMoney(net, currency), color: null),
            ],
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('Could not load summary: $e'),
      ),
    );
  }
}

class _LoanSnapshotCard extends StatelessWidget {
  final String currency;
  final AsyncValue<Map<String, double>> totalsAsync;
  const _LoanSnapshotCard({required this.currency, required this.totalsAsync});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _Card(
      title: l10n.navLoans,
      child: totalsAsync.when(
        data: (totals) => Row(
          children: [
            _StatColumn(
              label: l10n.dashboardYouOwe,
              value: formatMoney(totals['youOwe'] ?? 0, currency),
              color: Colors.orange,
            ),
            _StatColumn(
              label: l10n.dashboardOthersOweYou,
              value: formatMoney(totals['othersOweYou'] ?? 0, currency),
              color: Colors.blue,
            ),
          ],
        ),
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('Could not load loan totals: $e'),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.add_circle_outline,
            label: l10n.actionAddIncome,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddTransactionScreen(type: TransactionType.income)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.remove_circle_outline,
            label: l10n.actionAddExpense,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddTransactionScreen(type: TransactionType.expense)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.handshake_outlined,
            label: l10n.actionAddLoan,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddLoanScreen()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.payments_outlined,
            label: l10n.actionAddPayment,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoanListScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction txn;
  final String currency;
  final bool useEthiopian;
  final String locale;
  const _TransactionTile(this.txn, this.currency, this.useEthiopian, this.locale);

  @override
  Widget build(BuildContext context) {
    final isCredit = txn.type.isCredit;
    final sign = isCredit ? '+' : '-';
    final color = isCredit ? Colors.green : Colors.red;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(txn.description?.isNotEmpty == true ? txn.description! : txn.type.dbValue),
      subtitle: Text(formatDateDisplay(txn.date, useEthiopian: useEthiopian, locale: locale)),
      trailing: Text(
        '$sign${formatMoney(txn.amount, currency)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatColumn({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
