import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/core/models/loan.dart';
import 'package:my_financial_manager/core/repositories/loan_repository.dart';
import 'package:my_financial_manager/core/repositories/person_repository.dart';
import 'package:my_financial_manager/features/loans/add_loan_screen.dart';

import '../test_helpers.dart';
import 'widget_test_helpers.dart';

void main() {
  setUpDatabaseForTesting();

  group('AddLoanScreen', () {
    testWidgets('records a no-interest borrowed loan against the person and the default account',
        (tester) async {
      await tester.pumpWidget(wrapPushable(const AddLoanScreen()));
      await openPushedScreen(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Marta'); // Loan From
      await tester.enterText(fields.at(1), '2000'); // Amount
      await tester.pump();

      await tester.tap(find.text('Save'));
      await pumpUntilSettled(tester);

      expect(find.text('open'), findsOneWidget); // popped back

      final loans = await LoanRepository().getAll();
      expect(loans, hasLength(1));
      final loan = loans.single;
      expect(loan.loanType, LoanType.borrowed);
      expect(loan.principalAmount, 2000);
      expect(loan.interestAmount, 0);
      expect(loan.totalAmount, 2000);
      expect(loan.remainingAmount, 2000);

      final person = await PersonRepository().getById(loan.personId);
      expect(person?.name, 'Marta');
    });

    testWidgets('switching to "Money I Lent" saves that loan type', (tester) async {
      await tester.pumpWidget(wrapPushable(const AddLoanScreen()));
      await openPushedScreen(tester);

      await tester.tap(find.text('Money I Lent'));
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Dawit');
      await tester.enterText(fields.at(1), '500');
      await tester.tap(find.text('Save'));
      await pumpUntilSettled(tester);

      final loan = (await LoanRepository().getAll()).single;
      expect(loan.loanType, LoanType.lent);
    });

    testWidgets('flat percentage interest is calculated once at creation, per Addendum #2',
        (tester) async {
      await tester.pumpWidget(wrapPushable(const AddLoanScreen()));
      await openPushedScreen(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Selam');
      await tester.enterText(fields.at(1), '1000'); // principal

      await tester.tap(find.text('Percentage'));
      await tester.pump();

      // The interest-value field only appears once a mode is chosen —
      // it's the 3rd TextFormField on screen now.
      await tester.enterText(find.byType(TextFormField).at(2), '10'); // 10%
      await tester.tap(find.text('Save'));
      await pumpUntilSettled(tester);

      final loan = (await LoanRepository().getAll()).single;
      expect(loan.interestMode, InterestMode.percentage);
      expect(loan.interestAmount, 100); // 1000 * 10%
      expect(loan.totalAmount, 1100);
      expect(loan.remainingAmount, 1100);
    });

    testWidgets('rejects a blank person name', (tester) async {
      await tester.pumpWidget(wrapPushable(const AddLoanScreen()));
      await openPushedScreen(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '300');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Enter a name'), findsOneWidget);
      expect(await LoanRepository().getAll(), isEmpty);
    });
  });
}
