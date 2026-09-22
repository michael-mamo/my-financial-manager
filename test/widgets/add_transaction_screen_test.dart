import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/core/models/transaction.dart' as model;
import 'package:my_financial_manager/core/repositories/account_repository.dart';
import 'package:my_financial_manager/core/repositories/transaction_repository.dart';
import 'package:my_financial_manager/features/income_expense/add_transaction_screen.dart';

import '../test_helpers.dart';
import 'widget_test_helpers.dart';

void main() {
  setUpDatabaseForTesting();

  group('AddTransactionScreen', () {
    testWidgets('saving an income picks the default Cash account and records it',
        (tester) async {
      await tester.pumpWidget(
        wrapPushable(const AddTransactionScreen(type: model.TransactionType.income)),
      );
      await openPushedScreen(tester);

      expect(find.text('Add Income'), findsOneWidget);

      // Amount is the very first field on the screen.
      await tester.enterText(find.byType(TextFormField).first, '1500');
      await tester.pump();

      // Categories load from the (seeded) DB — pick one.
      await tester.tap(find.text('Salary'));
      await tester.pump();

      await tester.tap(find.text('Save'));
      await pumpUntilSettled(tester);

      // Pops back to the placeholder route underneath.
      expect(find.text('Add Income'), findsNothing);
      expect(find.text('open'), findsOneWidget);

      final txns = await TransactionRepository().recent();
      expect(txns, hasLength(1));
      expect(txns.first.amount, 1500);
      expect(txns.first.type, model.TransactionType.income);

      // The default seeded "Cash" account absorbed the balance change —
      // no account picker was ever touched (it's behind "More Options").
      final total = await AccountRepository().totalBalance();
      expect(total, 1500);
    });

    testWidgets('rejects a zero amount and never touches the repository', (tester) async {
      await tester.pumpWidget(
        wrapPushable(const AddTransactionScreen(type: model.TransactionType.expense)),
      );
      await openPushedScreen(tester);

      await tester.enterText(find.byType(TextFormField).first, '0');
      await tester.tap(find.text('Food'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Form validation blocks the save — still on the same screen.
      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('Amount must be greater than zero'), findsOneWidget);

      final txns = await TransactionRepository().recent();
      expect(txns, isEmpty);
    });

    testWidgets('requires a category before saving', (tester) async {
      await tester.pumpWidget(
        wrapPushable(const AddTransactionScreen(type: model.TransactionType.expense)),
      );
      await openPushedScreen(tester);

      await tester.enterText(find.byType(TextFormField).first, '250');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Select a category'), findsOneWidget); // SnackBar
      expect(find.text('Add Expense'), findsOneWidget); // still open

      final txns = await TransactionRepository().recent();
      expect(txns, isEmpty);
    });

    testWidgets('More Options reveals the account/payment-method/description fields',
        (tester) async {
      await tester.pumpWidget(
        wrapPushable(const AddTransactionScreen(type: model.TransactionType.expense)),
      );
      await openPushedScreen(tester);

      expect(find.text('Description'), findsNothing);
      await tester.tap(find.text('More Options'));
      await pumpUntilSettled(tester);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Payment Method'), findsOneWidget);
    });
  });
}
