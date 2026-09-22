import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/core/models/account.dart';
import 'package:my_financial_manager/core/repositories/account_repository.dart';
import 'package:my_financial_manager/core/repositories/settings_repository.dart';
import 'package:my_financial_manager/features/dashboard/dashboard_screen.dart';

import '../test_helpers.dart';
import 'widget_test_helpers.dart';

void main() {
  setUpDatabaseForTesting();

  group('DashboardScreen', () {
    testWidgets('shows every active account with its balance', (tester) async {
      // Seed default "Cash" account (0) plus a second account with a
      // non-zero balance so the list has something distinctive to assert on.
      await AccountRepository().create(Account(
        name: 'Bank of Abyssinia',
        accountType: AccountType.bank,
        currency: 'ETB',
        openingBalance: 5000,
        currentBalance: 5000,
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(wrapAsRoot(const DashboardScreen()));
      await pumpUntilSettled(tester);

      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Cash'), findsWidgets); // account name + type label both say "Cash"
      expect(find.text('Bank of Abyssinia'), findsOneWidget);
      // The Balance card's total and the account row both show the same
      // figure, since Cash (the only other active account) is still 0.
      expect(find.text('5,000 ETB'), findsNWidgets(2));
    });

    testWidgets('the eye icon masks every balance and the total, and un-masks on a second tap',
        (tester) async {
      await AccountRepository().create(Account(
        name: 'Savings',
        accountType: AccountType.bank,
        currency: 'ETB',
        openingBalance: 1200,
        currentBalance: 1200,
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(wrapAsRoot(const DashboardScreen()));
      await pumpUntilSettled(tester);

      // Visible before any tap: the account balance and the total (same
      // value here, since Cash is 0) both render as real numbers.
      expect(find.text('1,200 ETB'), findsNWidgets(2));
      expect(find.text('••••••'), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await pumpUntilSettled(tester);

      // Every real amount is replaced by the mask; none of the real
      // figures remain on screen.
      expect(find.text('1,200 ETB'), findsNothing);
      expect(find.text('••••••'), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await pumpUntilSettled(tester);

      expect(find.text('1,200 ETB'), findsNWidgets(2));
      expect(find.text('••••••'), findsNothing);
    });

    testWidgets('the hide-balances choice survives a rebuild via persisted settings', (tester) async {
      await tester.pumpWidget(wrapAsRoot(const DashboardScreen()));
      await pumpUntilSettled(tester);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await pumpUntilSettled(tester);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      // Re-reading settings from the DB (as bootstrapProvider does on the
      // next launch) reflects the persisted choice, not just in-memory state.
      final settings = await SettingsRepository().getOrCreate();
      expect(settings.hideBalances, isTrue);
    });
  });
}
