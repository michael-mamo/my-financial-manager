import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/core/models/recurring_transaction.dart';
import 'package:my_financial_manager/core/repositories/account_repository.dart';
import 'package:my_financial_manager/core/repositories/recurring_transaction_repository.dart';
import 'package:my_financial_manager/core/repositories/transaction_repository.dart';

import '../test_helpers.dart';

void main() {
  setUpDatabaseForTesting();

  late RecurringTransactionRepository repo;
  late AccountRepository accountRepo;
  late int cashAccountId;

  setUp(() async {
    repo = RecurringTransactionRepository();
    accountRepo = AccountRepository();
    cashAccountId = (await accountRepo.getAll()).first.id!;
  });

  group('RecurringTransactionRepository — Addendum #7 (app-open catch-up, no background job)', () {
    test('a rule due today creates exactly one transaction and advances next_date', () async {
      final fixedNow = DateTime(2026, 6, 15, 9, 0);
      await repo.create(RecurringTransaction(
        type: 'income',
        amount: 35000,
        accountId: cashAccountId,
        description: 'Monthly salary',
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime(2026, 6, 15, 9, 0), // due exactly at "now"
      ));

      final created = await repo.runCatchUp(clock: () => fixedNow);
      expect(created, 1);
      expect(await accountRepo.totalBalance(), 35000);

      final rules = await repo.getAll();
      expect(rules.first.nextDate, DateTime(2026, 7, 15, 9, 0));
    });

    test('a rule not yet due creates nothing', () async {
      final fixedNow = DateTime(2026, 6, 15);
      await repo.create(RecurringTransaction(
        type: 'expense',
        amount: 1000,
        accountId: cashAccountId,
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime(2026, 7, 1), // in the future relative to fixedNow
      ));

      final created = await repo.runCatchUp(clock: () => fixedNow);
      expect(created, 0);
      expect(await accountRepo.totalBalance(), 0);
    });

    test('the app being closed for 3 missed monthly cycles creates all 3 on next open', () async {
      // Rule was due March 1st; the app isn't opened again until June 10th.
      // Missed cycles: Mar 1, Apr 1, May 1 = 3 — June's own cycle (Jun 1)
      // hasn't been reached as "next" yet until those three are processed.
      await repo.create(RecurringTransaction(
        type: 'expense',
        amount: 2000,
        accountId: cashAccountId,
        description: 'Monthly rent',
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime(2026, 3, 1),
      ));

      final appReopenedOn = DateTime(2026, 6, 10);
      final created = await repo.runCatchUp(clock: () => appReopenedOn);

      // Mar 1, Apr 1, May 1, and Jun 1 are all <= Jun 10, so all four are due.
      expect(created, 4);
      expect(await accountRepo.totalBalance(), -8000); // 4 x 2000 expense

      final rules = await repo.getAll();
      expect(rules.first.nextDate, DateTime(2026, 7, 1)); // advanced past today
    });

    test('an inactive rule is skipped entirely', () async {
      final id = await repo.create(RecurringTransaction(
        type: 'income',
        amount: 500,
        accountId: cashAccountId,
        frequency: RecurringFrequency.daily,
        nextDate: DateTime(2020, 1, 1), // long overdue
      ));
      await repo.setActive(id, false);

      final created = await repo.runCatchUp(clock: () => DateTime(2026, 1, 1));
      expect(created, 0);
      expect(await accountRepo.totalBalance(), 0);
    });

    test('each catch-up cycle is recorded as a real transaction visible in the ledger', () async {
      await repo.create(RecurringTransaction(
        type: 'income',
        amount: 1000,
        accountId: cashAccountId,
        frequency: RecurringFrequency.weekly,
        nextDate: DateTime(2026, 1, 1),
      ));

      await repo.runCatchUp(clock: () => DateTime(2026, 1, 22)); // 4 weekly cycles: 1,8,15,22

      final txnRepo = TransactionRepository();
      final all = await txnRepo.page(limit: 50);
      expect(all, hasLength(4));
      expect(all.every((t) => t.description == null), isTrue); // no description was set on the rule
    });
  });
}
