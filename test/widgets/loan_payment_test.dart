import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/core/models/loan.dart';
import 'package:my_financial_manager/core/repositories/account_repository.dart';
import 'package:my_financial_manager/core/repositories/loan_repository.dart';
import 'package:my_financial_manager/core/repositories/person_repository.dart';
import 'package:my_financial_manager/features/loans/loan_detail_screen.dart';

import '../test_helpers.dart';
import 'widget_test_helpers.dart';

Future<Loan> _seedBorrowedLoan({double principal = 1000}) async {
  final accountId = (await AccountRepository().getAll()).first.id!;
  final personId = await PersonRepository().findOrCreateByName('Kebede');
  final loanRepo = LoanRepository();
  final id = await loanRepo.createLoan(Loan.create(
    personId: personId,
    accountId: accountId,
    loanType: LoanType.borrowed,
    principalAmount: principal,
    startDate: DateTime.now(),
  ));
  return (await loanRepo.getById(id))!;
}

void main() {
  setUpDatabaseForTesting();

  group('LoanDetailScreen — Record Payment', () {
    testWidgets('a partial payment reduces the outstanding balance and status', (tester) async {
      final loan = await _seedBorrowedLoan(principal: 1000);

      await tester.pumpWidget(wrapPushable(LoanDetailScreen(loanId: loan.id!)));
      await openPushedScreen(tester);

      expect(find.text('You owe'), findsOneWidget);
      expect(find.text('No payments recorded yet.'), findsOneWidget);

      await tester.tap(find.text('Record Payment'));
      await pumpUntilSettled(tester); // bottom sheet animation + accounts load

      expect(find.text('Save Payment'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '400');
      await tester.tap(find.text('Save Payment'));
      await pumpUntilSettled(tester);

      // Sheet closed, back on the detail screen with updated figures.
      expect(find.text('Save Payment'), findsNothing);

      final payments = await LoanRepository().paymentsForLoan(loan.id!);
      expect(payments, hasLength(1));
      expect(payments.single.amount, 400);

      final refreshed = await LoanRepository().getById(loan.id!);
      expect(refreshed!.remainingAmount, 600);
      expect(refreshed.status, LoanStatus.partiallyPaid);
    });

    testWidgets('a payment covering the full balance marks the loan fully paid', (tester) async {
      final loan = await _seedBorrowedLoan(principal: 250);

      await tester.pumpWidget(wrapPushable(LoanDetailScreen(loanId: loan.id!)));
      await openPushedScreen(tester);

      await tester.tap(find.text('Record Payment'));
      await pumpUntilSettled(tester);
      await tester.enterText(find.byType(TextFormField).first, '250');
      await tester.tap(find.text('Save Payment'));
      await pumpUntilSettled(tester);

      final refreshed = await LoanRepository().getById(loan.id!);
      expect(refreshed!.remainingAmount, 0);
      expect(refreshed.status, LoanStatus.fullyPaid);

      // A fully-paid loan no longer offers a payment button.
      expect(find.text('Record Payment'), findsNothing);
    });

    testWidgets('an amount over the outstanding balance is rejected client-side', (tester) async {
      final loan = await _seedBorrowedLoan(principal: 100);

      await tester.pumpWidget(wrapPushable(LoanDetailScreen(loanId: loan.id!)));
      await openPushedScreen(tester);

      await tester.tap(find.text('Record Payment'));
      await pumpUntilSettled(tester);
      await tester.enterText(find.byType(TextFormField).first, '150');
      await tester.tap(find.text('Save Payment'));
      await tester.pump();

      expect(find.text('Exceeds outstanding balance'), findsOneWidget);
      expect(await LoanRepository().paymentsForLoan(loan.id!), isEmpty);
    });
  });
}
