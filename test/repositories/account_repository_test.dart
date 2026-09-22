import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/core/models/account.dart';
import 'package:my_financial_manager/core/repositories/account_repository.dart';
import 'package:my_financial_manager/core/database/database_helper.dart';

import '../test_helpers.dart';

void main() {
  setUpDatabaseForTesting();

  late AccountRepository repo;
  setUp(() => repo = AccountRepository());

  group('AccountRepository', () {
    test('a fresh database is seeded with one default Cash account at zero balance', () async {
      final accounts = await repo.getAll();
      expect(accounts, hasLength(1));
      expect(accounts.first.name, 'Cash');
      expect(accounts.first.currentBalance, 0);
    });

    test('create() adds a new account and it appears in getAll()', () async {
      await repo.create(Account(
        name: 'CBE',
        accountType: AccountType.bank,
        currency: 'ETB',
        openingBalance: 5000,
        currentBalance: 5000,
        createdAt: DateTime(2026, 1, 1),
      ));

      final accounts = await repo.getAll();
      expect(accounts.map((a) => a.name), containsAll(['Cash', 'CBE']));
    });

    test('totalBalance() sums only active accounts (Addendum #1: balance is derived, not stored)', () async {
      final cbeId = await repo.create(Account(
        name: 'CBE',
        accountType: AccountType.bank,
        currency: 'ETB',
        openingBalance: 5000,
        currentBalance: 5000,
        createdAt: DateTime(2026, 1, 1),
      ));

      expect(await repo.totalBalance(), 5000); // Cash (0) + CBE (5000)

      await repo.deactivate(cbeId);
      expect(await repo.totalBalance(), 0); // deactivated account excluded
    });

    test('adjustBalance() moves the stored balance by the given delta', () async {
      final accounts = await repo.getAll();
      final cashId = accounts.first.id!;
      final db = await DatabaseHelper.instance.database;

      await repo.adjustBalance(db, cashId, 1000);
      expect(await repo.totalBalance(), 1000);

      await repo.adjustBalance(db, cashId, -400);
      expect(await repo.totalBalance(), 600);
    });

    test('deactivated accounts are excluded from getAll() by default but included with activeOnly: false', () async {
      final accounts = await repo.getAll();
      await repo.deactivate(accounts.first.id!);

      expect(await repo.getAll(), isEmpty);
      expect(await repo.getAll(activeOnly: false), hasLength(1));
    });
  });
}
