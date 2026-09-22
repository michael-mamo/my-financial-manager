import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/core/models/loan.dart';

void main() {
  group('calculateInterestAmount (Spec Addendum #2 — flat, non-compounding)', () {
    test('no interest returns zero', () {
      expect(
        calculateInterestAmount(principal: 10000, mode: InterestMode.none, value: 0),
        0,
      );
    });

    test('fixed interest returns the flat value regardless of principal', () {
      expect(
        calculateInterestAmount(principal: 10000, mode: InterestMode.fixed, value: 1000),
        1000,
      );
    });

    test('percentage interest is principal * rate, applied once', () {
      expect(
        calculateInterestAmount(principal: 10000, mode: InterestMode.percentage, value: 10),
        1000,
      );
    });
  });

  group('Loan.create', () {
    test('total_amount = principal + interest, fixed at creation', () {
      final loan = Loan.create(
        personId: 1,
        accountId: 1,
        loanType: LoanType.lent,
        principalAmount: 10000,
        interestMode: InterestMode.percentage,
        interestValue: 10,
        startDate: DateTime(2026, 9, 1),
      );
      expect(loan.interestAmount, 1000);
      expect(loan.totalAmount, 11000);
      expect(loan.remainingAmount, 11000); // fully outstanding at creation
      expect(loan.status, LoanStatus.active);
    });
  });
}
