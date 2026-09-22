import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/loan.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import 'add_loan_screen.dart';
import 'loan_detail_screen.dart';
import 'loan_report_screen.dart';

class LoanListScreen extends ConsumerStatefulWidget {
  const LoanListScreen({super.key});

  @override
  ConsumerState<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends ConsumerState<LoanListScreen> {
  LoanType? _filter; // null = all

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final totalsAsync = ref.watch(loanDashboardTotalsProvider);
    final loansAsync = ref.watch(loansProvider(_filter));
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navLoans),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            tooltip: 'Loan Report',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoanReportScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddLoanScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.loanTitle),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(loanDashboardTotalsProvider);
          ref.invalidate(loansProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            totalsAsync.when(
              data: (t) => _LoanDashboardCard(currency: currency, totals: t),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load loan totals: $e'),
            ),
            const SizedBox(height: 16),
            SegmentedButton<LoanType?>(
              segments: [
                const ButtonSegment(value: null, label: Text('All')),
                ButtonSegment(value: LoanType.borrowed, label: Text(l10n.loanYouOwe)),
                const ButtonSegment(value: LoanType.lent, label: Text('Owed to You')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
            const SizedBox(height: 16),
            loansAsync.when(
              data: (loans) => loans.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('No loans yet.')),
                    )
                  : Column(children: loans.map((l) => _LoanCard(loan: l, currency: currency)).toList()),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Could not load loans: $e'),
            ),
            const SizedBox(height: 80), // clearance for the FAB
          ],
        ),
      ),
    );
  }
}

class _LoanDashboardCard extends StatelessWidget {
  final String currency;
  final Map<String, double> totals;
  const _LoanDashboardCard({required this.currency, required this.totals});

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
          Row(
            children: [
              _Stat(label: 'Total I Owe', value: formatMoney(totals['youOwe'] ?? 0, currency), color: Colors.orange),
              _Stat(label: 'Total Others Owe Me', value: formatMoney(totals['othersOweYou'] ?? 0, currency), color: Colors.blue),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'Payments This Month', value: formatMoney(totals['paymentsThisMonth'] ?? 0, currency), color: null),
              _Stat(label: 'Overdue Loans', value: '${(totals['overdueCount'] ?? 0).toInt()}', color: Colors.red),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: color)),
        ],
      ),
    );
  }
}

class _LoanCard extends ConsumerWidget {
  final Loan loan;
  final String currency;
  const _LoanCard({required this.loan, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personNameAsync = ref.watch(personNameProvider(loan.personId));
    final isBorrowed = loan.loanType == LoanType.borrowed;
    final useEthiopian = ref.watch(ethiopianCalendarProvider);
    final locale = ref.watch(localeProvider).languageCode;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loan.id!)),
        ),
        title: personNameAsync.when(
          data: (name) => Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          loading: () => const Text('…'),
          error: (e, _) => const Text('—'),
        ),
        subtitle: Text(
          '${isBorrowed ? "You owe" : "They owe"} ${formatMoney(loan.remainingAmount, currency)}'
          '${loan.dueDate != null ? " · due ${formatDateDisplay(loan.dueDate!, useEthiopian: useEthiopian, locale: locale)}" : ""}',
        ),
        trailing: _StatusDot(status: loan.status),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final LoanStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    late Color color;
    switch (status) {
      case LoanStatus.active:
        color = Colors.blue;
        break;
      case LoanStatus.partiallyPaid:
        color = Colors.orange;
        break;
      case LoanStatus.fullyPaid:
        color = Colors.green;
        break;
      case LoanStatus.overdue:
        color = Colors.red;
        break;
    }
    return Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
