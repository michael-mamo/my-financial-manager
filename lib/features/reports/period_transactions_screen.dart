import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/transaction.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/formatters.dart';

/// Section 20: the actual transaction list behind a day/week/month/year
/// report range, reached from the Reports screen's summary numbers.
class PeriodTransactionsScreen extends ConsumerWidget {
  final DateTime start;
  final DateTime end;
  final String title;
  const PeriodTransactionsScreen({super.key, required this.start, required this.end, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final useEthiopian = ref.watch(ethiopianCalendarProvider);
    final locale = ref.watch(localeProvider).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<Transaction>>(
        future: ref.watch(transactionRepositoryProvider).forPeriod(start: start, end: end),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) return const Center(child: Text('No transactions in this period.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final t = items[i];
              final isCredit = t.type.isCredit;
              return ListTile(
                title: Text(t.description?.isNotEmpty == true ? t.description! : _typeLabel(t.type)),
                subtitle: Text(formatDateDisplay(t.date, useEthiopian: useEthiopian, locale: locale)),
                trailing: Text(
                  '${isCredit ? '+' : '-'}${formatMoney(t.amount, currency)}',
                  style: TextStyle(
                    color: isCredit ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.loanInflow:
        return 'Loan Received';
      case TransactionType.loanOutflow:
        return 'Loan Given';
      case TransactionType.loanPaymentIn:
        return 'Loan Payment Received';
      case TransactionType.loanPaymentOut:
        return 'Loan Payment Made';
      case TransactionType.savingsContributionOut:
        return 'Savings Contribution';
      case TransactionType.savingsWithdrawalIn:
        return 'Savings Withdrawal';
    }
  }
}
