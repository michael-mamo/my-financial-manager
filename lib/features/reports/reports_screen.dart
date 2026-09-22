import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/formatters.dart';
import '../loans/loan_report_screen.dart';
import 'period_transactions_screen.dart';

const _categoryPalette = [
  Color(0xFF1F7A5C), Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFFEF4444),
  Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF14B8A6), Color(0xFF6366F1),
];

enum _ReportRange { daily, weekly, monthly, yearly }

/// Sections 19-21: monthly (or day/week/year) summary with category
/// breakdown, cash-flow and expense-by-category charts, and a net worth
/// summary. PDF/CSV export and full daily/weekly/yearly drill-down tables
/// remain for a later phase — this covers the range *selector* the spec
/// asks for, applied to the summary, chart, and category breakdown.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _ReportRange _range = _ReportRange.monthly;

  (DateTime, DateTime) _periodBounds() {
    final now = DateTime.now();
    switch (_range) {
      case _ReportRange.daily:
        final start = DateTime(now.year, now.month, now.day);
        return (start, start.add(const Duration(days: 1)));
      case _ReportRange.weekly:
        final start = now.subtract(Duration(days: now.weekday - 1));
        final weekStart = DateTime(start.year, start.month, start.day);
        return (weekStart, weekStart.add(const Duration(days: 7)));
      case _ReportRange.yearly:
        return (DateTime(now.year, 1, 1), DateTime(now.year + 1, 1, 1));
      case _ReportRange.monthly:
        return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 1));
    }
  }

  String _rangeLabel() {
    final now = DateTime.now();
    final useEthiopian = ref.watch(ethiopianCalendarProvider);
    final locale = ref.watch(localeProvider).languageCode;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    switch (_range) {
      case _ReportRange.daily:
        return formatDateDisplay(now, useEthiopian: useEthiopian, locale: locale);
      case _ReportRange.weekly:
        final (start, end) = _periodBounds();
        final lastDay = end.subtract(const Duration(days: 1));
        return '${formatDateDisplay(start, useEthiopian: useEthiopian, locale: locale)} – '
            '${formatDateDisplay(lastDay, useEthiopian: useEthiopian, locale: locale)}';
      case _ReportRange.yearly:
        return yearLabel(DateTime(now.year, 1, 1), useEthiopian: useEthiopian);
      case _ReportRange.monthly:
        return '${months[now.month - 1]} ${now.year}';
    }
  }

  String _granularityKey() {
    switch (_range) {
      case _ReportRange.daily:
        return 'daily';
      case _ReportRange.weekly:
        return 'weekly';
      case _ReportRange.yearly:
        return 'yearly';
      case _ReportRange.monthly:
        return 'monthly';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final (start, end) = _periodBounds();
    final repo = ref.watch(transactionRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_ReportRange>(
            segments: const [
              ButtonSegment(value: _ReportRange.daily, label: Text('Day')),
              ButtonSegment(value: _ReportRange.weekly, label: Text('Week')),
              ButtonSegment(value: _ReportRange.monthly, label: Text('Month')),
              ButtonSegment(value: _ReportRange.yearly, label: Text('Year')),
            ],
            selected: {_range},
            onSelectionChanged: (s) => setState(() => _range = s.first),
          ),
          const SizedBox(height: 16),
          Text(_rangeLabel(), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          FutureBuilder(
            future: repo.incomeExpenseTotals(start: start, end: end),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final totals = snapshot.data!;
              final income = totals['income'] ?? 0;
              final expense = totals['expense'] ?? 0;
              return Row(
                children: [
                  _Stat(label: 'Income', value: formatMoney(income, currency), color: Colors.green),
                  _Stat(label: 'Expenses', value: formatMoney(expense, currency), color: Colors.red),
                  _Stat(label: 'Net', value: formatMoney(income - expense, currency), color: null),
                ],
              );
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PeriodTransactionsScreen(start: start, end: end, title: _rangeLabel()),
              )),
              icon: const Icon(Icons.list_alt, size: 18),
              label: const Text('View Transactions'),
            ),
          ),
          const SizedBox(height: 24),
          const _NetWorthCard(),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoanReportScreen()),
            ),
            icon: const Icon(Icons.assessment_outlined),
            label: const Text('Loan Report'),
          ),
          const SizedBox(height: 28),
          Text('Cash Flow', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          FutureBuilder(
            future: repo.periodSeries(granularity: _granularityKey(), buckets: 6),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
              }
              return _CashFlowChart(series: snapshot.data!, granularity: _granularityKey());
            },
          ),
          const SizedBox(height: 28),
          Text('Expense by Category', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          FutureBuilder(
            future: repo.categoryBreakdown(start: start, end: end, type: 'expense'),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final rows = snapshot.data!;
              final total = rows.fold<double>(0, (sum, r) => sum + (r['total'] as num).toDouble());
              if (rows.isEmpty || total == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No expenses recorded in this period yet.'),
                );
              }
              return _ExpenseByCategory(rows: rows, total: total, currency: currency);
            },
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Loan reports and PDF/CSV export are planned for a later phase — '
              'see Settings → Export Reports.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section 20: Assets (account balances) minus Liabilities (what you still
/// owe on borrowed loans) = estimated net worth. "Estimated" because it
/// doesn't include non-financial assets — this app only tracks cash-like
/// accounts and loans, per its scope.
class _NetWorthCard extends ConsumerWidget {
  const _NetWorthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final assetsAsync = ref.watch(totalBalanceProvider);
    final loanTotalsAsync = ref.watch(loanDashboardTotalsProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: assetsAsync.when(
        data: (assets) => loanTotalsAsync.when(
          data: (loanTotals) {
            final liabilities = loanTotals['youOwe'] ?? 0;
            final netWorth = assets - liabilities;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Estimated Net Worth', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text(formatMoney(netWorth, currency),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Stat(label: 'Assets', value: formatMoney(assets, currency), color: null),
                    _Stat(label: 'Liabilities', value: formatMoney(liabilities, currency), color: null),
                  ],
                ),
              ],
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Could not load loan totals: $e'),
        ),
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('Could not load balances: $e'),
      ),
    );
  }
}

class _CashFlowChart extends StatelessWidget {
  final List<Map<String, Object?>> series;
  final String granularity;
  const _CashFlowChart({required this.series, required this.granularity});

  @override
  Widget build(BuildContext context) {
    final maxVal = series.fold<double>(1, (m, r) {
      final income = (r['income'] as num?)?.toDouble() ?? 0;
      final expense = (r['expense'] as num?)?.toDouble() ?? 0;
      return [m, income, expense].reduce((a, b) => a > b ? a : b);
    });

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxVal * 1.15,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= series.length) return const SizedBox.shrink();
                  final date = series[i]['periodStart'] as DateTime;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_labelFor(date), style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(series.length, (i) {
            final income = (series[i]['income'] as num?)?.toDouble() ?? 0;
            final expense = (series[i]['expense'] as num?)?.toDouble() ?? 0;
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: income, color: Colors.green, width: 8, borderRadius: BorderRadius.circular(3)),
              BarChartRodData(toY: expense, color: Colors.red, width: 8, borderRadius: BorderRadius.circular(3)),
            ]);
          }),
        ),
      ),
    );
  }

  String _labelFor(DateTime d) {
    const monthLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    switch (granularity) {
      case 'daily':
        return '${d.day}';
      case 'weekly':
        return '${d.day}/${d.month}';
      case 'yearly':
        return '${d.year}';
      case 'monthly':
      default:
        return monthLabels[d.month - 1];
    }
  }
}

class _ExpenseByCategory extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  final double total;
  final String currency;
  const _ExpenseByCategory({required this.rows, required this.total, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: List.generate(rows.length, (i) {
                final amount = (rows[i]['total'] as num).toDouble();
                final fraction = total == 0 ? 0.0 : amount / total;
                return PieChartSectionData(
                  value: amount,
                  color: _categoryPalette[i % _categoryPalette.length],
                  title: fraction >= 0.08 ? '${(fraction * 100).round()}%' : '',
                  radius: 50,
                  titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(rows.length, (i) {
          final amount = (rows[i]['total'] as num).toDouble();
          final label = (rows[i]['category'] as String?) ?? 'Uncategorized';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(
                  color: _categoryPalette[i % _categoryPalette.length], shape: BoxShape.circle,
                )),
                const SizedBox(width: 8),
                Expanded(child: Text(label)),
                Text(formatMoney(amount, currency)),
              ],
            ),
          );
        }),
      ],
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
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
