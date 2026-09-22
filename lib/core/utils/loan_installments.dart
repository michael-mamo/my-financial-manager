import '../models/loan.dart';

/// Section 14: derives an installment schedule from a loan's total amount,
/// installment amount, and frequency — no separate schedule table is
/// persisted; this is computed on read from data already on the loan.
class LoanInstallmentSchedule {
  final int totalInstallments;
  final int paidInstallments;
  final int remainingInstallments;
  final int overdueInstallments;
  final DateTime? nextPaymentDate;

  const LoanInstallmentSchedule({
    required this.totalInstallments,
    required this.paidInstallments,
    required this.remainingInstallments,
    required this.overdueInstallments,
    required this.nextPaymentDate,
  });

  /// Returns null if the loan has no installment amount/frequency set —
  /// not every loan uses installments (Section 14 is optional).
  static LoanInstallmentSchedule? compute(Loan loan) {
    final installmentAmount = loan.installmentAmount;
    final frequency = loan.frequency;
    if (installmentAmount == null || installmentAmount <= 0 || frequency == null) {
      return null;
    }

    final totalInstallments = (loan.totalAmount / installmentAmount).ceil();
    final amountPaid = loan.totalAmount - loan.remainingAmount;
    // Approximate: how many installments' worth has been paid, regardless
    // of whether individual payments matched the installment amount exactly
    // (partial payments are allowed — Section 13).
    final paidInstallments = totalInstallments == 0
        ? 0
        : (amountPaid / installmentAmount).floor().clamp(0, totalInstallments);
    final remainingInstallments = totalInstallments - paidInstallments;

    DateTime? nextPaymentDate;
    if (remainingInstallments > 0) {
      var date = loan.startDate;
      for (var i = 0; i < paidInstallments + 1; i++) {
        date = _step(date, frequency);
      }
      nextPaymentDate = date;
    }

    // How many installment dates have already passed without being paid
    // for. Date-based only (Addendum #9 spirit) — doesn't touch amounts.
    var overdue = 0;
    if (remainingInstallments > 0) {
      var date = loan.startDate;
      final now = DateTime.now();
      var elapsedSlots = 0;
      for (var i = 0; i < totalInstallments; i++) {
        date = _step(date, frequency);
        if (date.isBefore(now)) elapsedSlots++;
      }
      overdue = (elapsedSlots - paidInstallments).clamp(0, remainingInstallments);
    }

    return LoanInstallmentSchedule(
      totalInstallments: totalInstallments,
      paidInstallments: paidInstallments,
      remainingInstallments: remainingInstallments,
      overdueInstallments: overdue,
      nextPaymentDate: nextPaymentDate,
    );
  }

  static DateTime _step(DateTime date, LoanFrequency frequency) {
    switch (frequency) {
      case LoanFrequency.daily:
        return date.add(const Duration(days: 1));
      case LoanFrequency.weekly:
        return date.add(const Duration(days: 7));
      case LoanFrequency.biweekly:
        return date.add(const Duration(days: 14));
      case LoanFrequency.monthly:
        return DateTime(date.year, date.month + 1, date.day);
      case LoanFrequency.custom:
        // No defined cadence for "custom" — treat like monthly as a
        // reasonable default rather than refusing to compute at all.
        return DateTime(date.year, date.month + 1, date.day);
    }
  }
}
