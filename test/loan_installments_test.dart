import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/core/models/loan.dart';
import 'package:my_financial_manager/core/utils/loan_installments.dart';

void main() {
  group('LoanInstallmentSchedule.compute (Section 14)', () {
    test('returns null when the loan has no installment amount or frequency set', () {
      final loan = Loan.create(
        personId: 1,
        accountId: 1,
        loanType: LoanType.lent,
        principalAmount: 10000,
        startDate: DateTime(2026, 1, 1),
      );
      expect(LoanInstallmentSchedule.compute(loan), isNull);
    });

    test('a fresh loan with no payments shows all installments remaining', () {
      final loan = Loan.create(
        personId: 1,
        accountId: 1,
        loanType: LoanType.lent,
        principalAmount: 50000,
        startDate: DateTime(2026, 1, 1),
        installmentAmount: 5000,
        frequency: LoanFrequency.monthly,
      );
      final schedule = LoanInstallmentSchedule.compute(loan)!;

      expect(schedule.totalInstallments, 10); // 50,000 / 5,000
      expect(schedule.paidInstallments, 0);
      expect(schedule.remainingInstallments, 10);
      expect(schedule.nextPaymentDate, DateTime(2026, 2, 1)); // one month on
    });

    test('paying half the loan is reflected as half the installments paid', () {
      var loan = Loan.create(
        personId: 1,
        accountId: 1,
        loanType: LoanType.lent,
        principalAmount: 50000,
        startDate: DateTime(2026, 1, 1),
        installmentAmount: 5000,
        frequency: LoanFrequency.monthly,
      );
      loan = loan.copyWith(remainingAmount: 25000); // 25,000 of 50,000 paid

      final schedule = LoanInstallmentSchedule.compute(loan)!;
      expect(schedule.paidInstallments, 5);
      expect(schedule.remainingInstallments, 5);
      expect(schedule.nextPaymentDate, DateTime(2026, 7, 1)); // 6 months from start
    });

    test('a fully paid loan has no remaining installments and no next payment date', () {
      var loan = Loan.create(
        personId: 1,
        accountId: 1,
        loanType: LoanType.borrowed,
        principalAmount: 10000,
        startDate: DateTime(2026, 1, 1),
        installmentAmount: 2000,
        frequency: LoanFrequency.monthly,
      );
      loan = loan.copyWith(remainingAmount: 0);

      final schedule = LoanInstallmentSchedule.compute(loan)!;
      expect(schedule.remainingInstallments, 0);
      expect(schedule.nextPaymentDate, isNull);
    });

    test('an old, unpaid loan has every installment flagged overdue', () {
      final loan = Loan.create(
        personId: 1,
        accountId: 1,
        loanType: LoanType.lent,
        principalAmount: 10000,
        // Deep in the past so every installment date is guaranteed to have
        // elapsed regardless of when this test actually runs.
        startDate: DateTime(2000, 1, 1),
        installmentAmount: 1000,
        frequency: LoanFrequency.monthly,
      );
      final schedule = LoanInstallmentSchedule.compute(loan)!;

      expect(schedule.totalInstallments, 10);
      expect(schedule.overdueInstallments, schedule.remainingInstallments);
      expect(schedule.overdueInstallments, 10);
    });

    test('weekly frequency steps by 7 days per installment', () {
      final loan = Loan.create(
        personId: 1,
        accountId: 1,
        loanType: LoanType.lent,
        principalAmount: 3000,
        startDate: DateTime(2026, 1, 1),
        installmentAmount: 1000,
        frequency: LoanFrequency.weekly,
      );
      final schedule = LoanInstallmentSchedule.compute(loan)!;
      expect(schedule.nextPaymentDate, DateTime(2026, 1, 8));
    });
  });
}
