import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/core/models/loan.dart';
import 'package:my_financial_manager/core/repositories/account_repository.dart';
import 'package:my_financial_manager/core/repositories/loan_repository.dart';
import 'package:my_financial_manager/core/repositories/person_repository.dart';

import '../test_helpers.dart';

void main() {
  setUpDatabaseForTesting();

  late LoanRepository loanRepo;
  late AccountRepository accountRepo;
  late PersonRepository personRepo;
  late int cashAccountId;
  late int personId;

  setUp(() async {
    loanRepo = LoanRepository();
    accountRepo = AccountRepository();
    personRepo = PersonRepository();
    cashAccountId = (await accountRepo.getAll()).first.id!;
    personId = await personRepo.findOrCreateByName('Abebe');
  });

  group('LoanRepository — Addendum #1 (loans move money through accounts)', () {
    test('borrowing money increases the selected account balance by the principal', () async {
      final loan = Loan.create(
        personId: personId,
        accountId: cashAccountId,
        loanType: LoanType.borrowed,
        principalAmount: 20000,
        startDate: DateTime(2026, 1, 1),
      );
      await loanRepo.createLoan(loan);

      expect(await accountRepo.totalBalance(), 20000);
    });

    test('lending money decreases the selected account balance by the principal', () async {
      final loan = Loan.create(
        personId: personId,
        accountId: cashAccountId,
        loanType: LoanType.lent,
        principalAmount: 10000,
        startDate: DateTime(2026, 1, 1),
      );
      await loanRepo.createLoan(loan);

      expect(await accountRepo.totalBalance(), -10000);
    });
  });

  group('LoanRepository — Addendum #2 (flat, non-compounding interest)', () {
    test('a percentage-interest loan is created with total = principal + flat interest', () async {
      final loan = Loan.create(
        personId: personId,
        accountId: cashAccountId,
        loanType: LoanType.lent,
        principalAmount: 10000,
        interestMode: InterestMode.percentage,
        interestValue: 10,
        startDate: DateTime(2026, 1, 1),
      );
      final id = await loanRepo.createLoan(loan);

      final saved = await loanRepo.getById(id);
      expect(saved!.interestAmount, 1000);
      expect(saved.totalAmount, 11000);
      expect(saved.remainingAmount, 11000);
      expect(saved.status, LoanStatus.active);
    });
  });

  group('LoanRepository — payments and status transitions', () {
    test('a partial payment reduces remaining_amount and sets status to partially_paid', () async {
      final loan = Loan.create(
        personId: personId,
        accountId: cashAccountId,
        loanType: LoanType.lent,
        principalAmount: 10000,
        startDate: DateTime(2026, 1, 1),
      );
      final id = await loanRepo.createLoan(loan);
      final saved = (await loanRepo.getById(id))!;

      await loanRepo.addPayment(
        loan: saved,
        amount: 4000,
        paymentDate: DateTime(2026, 2, 1),
        accountId: cashAccountId,
      );

      final updated = (await loanRepo.getById(id))!;
      expect(updated.remainingAmount, 6000);
      expect(updated.status, LoanStatus.partiallyPaid);

      // Lending 10,000 then receiving 4,000 back nets to -6,000 in the account.
      expect(await accountRepo.totalBalance(), -6000);
    });

    test('paying off the full remaining balance sets status to fully_paid', () async {
      final loan = Loan.create(
        personId: personId,
        accountId: cashAccountId,
        loanType: LoanType.borrowed,
        principalAmount: 5000,
        startDate: DateTime(2026, 1, 1),
      );
      final id = await loanRepo.createLoan(loan);
      final saved = (await loanRepo.getById(id))!;

      await loanRepo.addPayment(
        loan: saved,
        amount: 5000,
        paymentDate: DateTime(2026, 2, 1),
        accountId: cashAccountId,
      );

      final updated = (await loanRepo.getById(id))!;
      expect(updated.remainingAmount, 0);
      expect(updated.status, LoanStatus.fullyPaid);
      expect(await accountRepo.totalBalance(), 0); // borrowed 5000, repaid 5000
    });

    test('a payment larger than the outstanding balance is rejected (Section 34)', () async {
      final loan = Loan.create(
        personId: personId,
        accountId: cashAccountId,
        loanType: LoanType.lent,
        principalAmount: 1000,
        startDate: DateTime(2026, 1, 1),
      );
      final id = await loanRepo.createLoan(loan);
      final saved = (await loanRepo.getById(id))!;

      expect(
        loanRepo.addPayment(
          loan: saved,
          amount: 1500,
          paymentDate: DateTime(2026, 2, 1),
          accountId: cashAccountId,
        ),
        throwsArgumentError,
      );
    });

    test('multiple partial payments accumulate correctly toward fully_paid', () async {
      final loan = Loan.create(
        personId: personId,
        accountId: cashAccountId,
        loanType: LoanType.lent,
        principalAmount: 9000,
        startDate: DateTime(2026, 1, 1),
      );
      final id = await loanRepo.createLoan(loan);

      for (final amount in [3000.0, 3000.0, 3000.0]) {
        final current = (await loanRepo.getById(id))!;
        await loanRepo.addPayment(
          loan: current,
          amount: amount,
          paymentDate: DateTime(2026, 2, 1),
          accountId: cashAccountId,
        );
      }

      final finalLoan = (await loanRepo.getById(id))!;
      expect(finalLoan.remainingAmount, 0);
      expect(finalLoan.status, LoanStatus.fullyPaid);

      final payments = await loanRepo.paymentsForLoan(id);
      expect(payments, hasLength(3));
    });
  });

  group('LoanRepository — Addendum #9 (date-based overdue flag)', () {
    test('a loan past its due date with a balance still owed is flagged overdue on read', () async {
      final loan = Loan.create(
        personId: personId,
        accountId: cashAccountId,
        loanType: LoanType.borrowed,
        principalAmount: 5000,
        startDate: DateTime(2020, 1, 1),
        dueDate: DateTime(2020, 2, 1), // long past
      );
      final id = await loanRepo.createLoan(loan);

      // getAll() triggers the lazy overdue refresh before returning.
      final loans = await loanRepo.getAll();
      final refreshed = loans.firstWhere((l) => l.id == id);
      expect(refreshed.status, LoanStatus.overdue);
    });

    test('a fully paid loan is never marked overdue even past its due date', () async {
      final loan = Loan.create(
        personId: personId,
        accountId: cashAccountId,
        loanType: LoanType.borrowed,
        principalAmount: 1000,
        startDate: DateTime(2020, 1, 1),
        dueDate: DateTime(2020, 2, 1),
      );
      final id = await loanRepo.createLoan(loan);
      final saved = (await loanRepo.getById(id))!;
      await loanRepo.addPayment(
        loan: saved,
        amount: 1000,
        paymentDate: DateTime(2020, 1, 15),
        accountId: cashAccountId,
      );

      final loans = await loanRepo.getAll();
      final refreshed = loans.firstWhere((l) => l.id == id);
      expect(refreshed.status, LoanStatus.fullyPaid);
    });
  });

  group('LoanRepository — dashboard and report aggregates', () {
    test('dashboardTotals reports outstanding you-owe and others-owe-you separately', () async {
      await loanRepo.createLoan(Loan.create(
        personId: personId, accountId: cashAccountId, loanType: LoanType.borrowed,
        principalAmount: 20000, startDate: DateTime(2026, 1, 1),
      ));
      await loanRepo.createLoan(Loan.create(
        personId: personId, accountId: cashAccountId, loanType: LoanType.lent,
        principalAmount: 15000, startDate: DateTime(2026, 1, 1),
      ));

      final totals = await loanRepo.dashboardTotals();
      expect(totals['youOwe'], 20000);
      expect(totals['othersOweYou'], 15000);
    });

    test('reportSummary counts loans by status and totals borrowed/lent lifetime', () async {
      final borrowedId = await loanRepo.createLoan(Loan.create(
        personId: personId, accountId: cashAccountId, loanType: LoanType.borrowed,
        principalAmount: 5000, startDate: DateTime(2026, 1, 1),
      ));
      await loanRepo.createLoan(Loan.create(
        personId: personId, accountId: cashAccountId, loanType: LoanType.lent,
        principalAmount: 3000, startDate: DateTime(2026, 1, 1),
      ));

      final borrowedLoan = (await loanRepo.getById(borrowedId))!;
      await loanRepo.addPayment(
        loan: borrowedLoan, amount: 5000, paymentDate: DateTime(2026, 2, 1), accountId: cashAccountId,
      );

      final summary = await loanRepo.reportSummary();
      expect(summary['fullyPaidCount'], 1);
      expect(summary['activeCount'], 1);
      expect(summary['totalBorrowed'], 5000);
      expect(summary['totalLent'], 3000);
      expect(summary['totalPaymentsAllTime'], 5000);
    });
  });
}
