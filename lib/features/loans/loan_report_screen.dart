import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/loan.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/formatters.dart';
import 'loan_detail_screen.dart';

/// Section 20's "Loan Report": active/paid/overdue counts, money borrowed
/// vs. lent, and lifetime payments — with tap-through to each status group.
class LoanReportScreen extends ConsumerWidget {
  const LoanReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final summaryAsync = ref.watch(loanReportSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Loan Report')),
      body: summaryAsync.when(
        data: (summary) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('By Status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _StatusTile(
                label: 'Active',
                count: summary['activeCount']!.toInt() + summary['partiallyPaidCount']!.toInt(),
                color: Colors.blue,
                onTap: () => _openStatusList(context, LoanStatus.active, 'Active Loans'),
              )),
              const SizedBox(width: 8),
              Expanded(child: _StatusTile(
                label: 'Paid',
                count: summary['fullyPaidCount']!.toInt(),
                color: Colors.green,
                onTap: () => _openStatusList(context, LoanStatus.fullyPaid, 'Paid Loans'),
              )),
              const SizedBox(width: 8),
              Expanded(child: _StatusTile(
                label: 'Overdue',
                count: summary['overdueCount']!.toInt(),
                color: Colors.red,
                onTap: () => _openStatusList(context, LoanStatus.overdue, 'Overdue Loans'),
              )),
            ]),
            const SizedBox(height: 24),
            Text('Lifetime Totals', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _SummaryRow(label: 'Money Borrowed', value: formatMoney(summary['totalBorrowed']!, currency)),
            _SummaryRow(label: 'Money Lent', value: formatMoney(summary['totalLent']!, currency)),
            _SummaryRow(label: 'Loan Payments (All Time)', value: formatMoney(summary['totalPaymentsAllTime']!, currency)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load loan report: $e')),
      ),
    );
  }

  void _openStatusList(BuildContext context, LoanStatus status, String title) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _LoanStatusListScreen(status: status, title: title),
    ));
  }
}

class _LoanStatusListScreen extends ConsumerWidget {
  final LoanStatus status;
  final String title;
  const _LoanStatusListScreen({required this.status, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansByStatusProvider(status));
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: loansAsync.when(
        data: (loans) => loans.isEmpty
            ? const Center(child: Text('Nothing here.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: loans.length,
                itemBuilder: (context, i) {
                  final loan = loans[i];
                  final personNameAsync = ref.watch(personNameProvider(loan.personId));
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loan.id!)),
                      ),
                      title: personNameAsync.when(
                        data: (name) => Text(name),
                        loading: () => const Text('…'),
                        error: (e, _) => const Text('—'),
                      ),
                      subtitle: Text(loan.loanType == LoanType.borrowed ? 'You owe' : 'They owe'),
                      trailing: Text(
                        formatMoney(loan.remainingAmount, currency),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load loans: $e')),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;
  const _StatusTile({required this.label, required this.count, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
