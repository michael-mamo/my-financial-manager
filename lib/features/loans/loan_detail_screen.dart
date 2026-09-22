import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/loan.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/loan_installments.dart';
import '../../l10n/app_localizations.dart';

/// Fetches a single loan by id. Split out from an inline `Future` in
/// `build()` so that recording a payment can invalidate *this* alongside
/// `_loanPaymentsProvider` — without it, the payment list refreshed but
/// `loan.remainingAmount`/`loan.status` (and therefore whether "Record
/// Payment" is still shown) kept showing the pre-payment snapshot, since
/// nothing ever asked for the loan again.
final _loanDetailProvider = FutureProvider.autoDispose.family<Loan?, int>((ref, loanId) async {
  return ref.watch(loanRepositoryProvider).getById(loanId);
});

class LoanDetailScreen extends ConsumerWidget {
  final int loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final loanAsync = ref.watch(_loanDetailProvider(loanId));

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.loanTitle)),
      body: loanAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load loan: $e')),
        data: (loan) {
          if (loan == null) return const Center(child: Text('Loan not found'));
          return _LoanDetailBody(loan: loan, currency: currency);
        },
      ),
    );
  }
}

class _LoanDetailBody extends ConsumerWidget {
  final Loan loan;
  final String currency;
  const _LoanDetailBody({required this.loan, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personNameAsync = ref.watch(personNameProvider(loan.personId));
    final paymentsAsync = ref.watch(_loanPaymentsProvider(loan.id!));
    final isBorrowed = loan.loanType == LoanType.borrowed;
    final useEthiopian = ref.watch(ethiopianCalendarProvider);
    final locale = ref.watch(localeProvider).languageCode;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        personNameAsync.when(
          data: (name) => Text(name, style: Theme.of(context).textTheme.headlineSmall),
          loading: () => const SizedBox(height: 28),
          error: (e, _) => const Text('—'),
        ),
        const SizedBox(height: 4),
        Text(isBorrowed ? 'You owe' : 'They owe you', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        Text(
          formatMoney(loan.remainingAmount, currency),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text('of ${formatMoney(loan.totalAmount, currency)} total', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        _StatusChip(status: loan.status),
        const SizedBox(height: 20),
        _InfoRow(label: 'Principal', value: formatMoney(loan.principalAmount, currency)),
        if (loan.interestAmount > 0)
          _InfoRow(label: 'Interest', value: formatMoney(loan.interestAmount, currency)),
        _InfoRow(label: 'Start Date', value: formatDateDisplay(loan.startDate, useEthiopian: useEthiopian, locale: locale)),
        if (loan.dueDate != null) _InfoRow(label: 'Due Date', value: formatDateDisplay(loan.dueDate!, useEthiopian: useEthiopian, locale: locale)),
        if (loan.description?.isNotEmpty == true)
          _InfoRow(label: 'Note', value: loan.description!),
        if (LoanInstallmentSchedule.compute(loan) != null) ...[
          const SizedBox(height: 16),
          _InstallmentCard(
            schedule: LoanInstallmentSchedule.compute(loan)!,
            useEthiopian: useEthiopian,
            locale: locale,
          ),
        ],
        const SizedBox(height: 24),
        if (loan.status != LoanStatus.fullyPaid)
          FilledButton.icon(
            onPressed: () => _openAddPayment(context, ref, loan),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Record Payment'),
          ),
        const SizedBox(height: 24),
        Text('Payment History', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        paymentsAsync.when(
          data: (payments) => payments.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No payments recorded yet.'),
                )
              : Table(
                  columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2)},
                  children: [
                    const TableRow(children: [
                      Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Payment', style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Remaining', style: TextStyle(fontWeight: FontWeight.bold))),
                    ]),
                    ..._buildPaymentRows(payments, loan.totalAmount, currency, useEthiopian, locale),
                  ],
                ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Could not load payments: $e'),
        ),
      ],
    );
  }

  List<TableRow> _buildPaymentRows(
    List<LoanPayment> payments, double totalAmount, String currency, bool useEthiopian, String locale,
  ) {
    var running = totalAmount;
    final rows = <TableRow>[];
    for (final p in payments) {
      running -= p.amount;
      rows.add(TableRow(children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(formatDateDisplay(p.paymentDate, useEthiopian: useEthiopian, locale: locale))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(formatMoney(p.amount, currency))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(formatMoney(running < 0 ? 0 : running, currency))),
      ]));
    }
    return rows;
  }

  void _openAddPayment(BuildContext context, WidgetRef ref, Loan loan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddPaymentSheet(loan: loan),
    ).then((_) {
      ref.invalidate(_loanDetailProvider(loan.id!));
      ref.invalidate(_loanPaymentsProvider(loan.id!));
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(loanDashboardTotalsProvider);
      ref.invalidate(loansProvider);
    });
  }
}

final _loanPaymentsProvider = FutureProvider.autoDispose.family<List<LoanPayment>, int>((ref, loanId) async {
  return ref.watch(loanRepositoryProvider).paymentsForLoan(loanId);
});

class _AddPaymentSheet extends ConsumerStatefulWidget {
  final Loan loan;
  const _AddPaymentSheet({required this.loan});

  @override
  ConsumerState<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends ConsumerState<_AddPaymentSheet> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  int? _accountId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
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
            Text('Record Payment', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Outstanding: ${formatMoney(widget.loan.remainingAmount, currency)}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Amount', suffixText: currency),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (value == null || value.isEmpty) return 'Enter an amount';
                if (parsed == null || parsed <= 0) return 'Amount must be greater than zero';
                if (parsed > widget.loan.remainingAmount) return 'Exceeds outstanding balance';
                return null;
              },
            ),
            const SizedBox(height: 12),
            accountsAsync.when(
              data: (accounts) {
                _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;
                return DropdownButtonFormField<int>(
                  value: _accountId,
                  decoration: const InputDecoration(labelText: 'Account'),
                  items: accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _accountId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load accounts: $e'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Payment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_accountId == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(loanRepositoryProvider).addPayment(
            loan: widget.loan,
            amount: double.parse(_amountController.text),
            paymentDate: _date,
            accountId: _accountId!,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }
}

class _StatusChip extends StatelessWidget {
  final LoanStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    late Color color;
    late String label;
    switch (status) {
      case LoanStatus.active:
        color = Colors.blue;
        label = '🔵 Active';
        break;
      case LoanStatus.partiallyPaid:
        color = Colors.orange;
        label = '🟡 Partially Paid';
        break;
      case LoanStatus.fullyPaid:
        color = Colors.green;
        label = '🟢 Fully Paid';
        break;
      case LoanStatus.overdue:
        color = Colors.red;
        label = '🔴 Overdue';
        break;
    }
    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.15),
      side: BorderSide(color: color.withOpacity(0.4)),
    );
  }
}

class _InstallmentCard extends StatelessWidget {
  final LoanInstallmentSchedule schedule;
  final bool useEthiopian;
  final String locale;
  const _InstallmentCard({required this.schedule, required this.useEthiopian, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Installments', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat(label: 'Paid', value: '${schedule.paidInstallments}/${schedule.totalInstallments}'),
              _MiniStat(label: 'Remaining', value: '${schedule.remainingInstallments}'),
              if (schedule.overdueInstallments > 0)
                _MiniStat(label: 'Overdue', value: '${schedule.overdueInstallments}', color: Colors.red),
            ],
          ),
          if (schedule.nextPaymentDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Next payment: ${formatDateDisplay(schedule.nextPaymentDate!, useEthiopian: useEthiopian, locale: locale)}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
