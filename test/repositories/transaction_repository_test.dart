import 'package:flutter_test/flutter_test.dart';
import 'package:my_financial_manager/core/models/account.dart';
import 'package:my_financial_manager/core/models/category.dart';
import 'package:my_financial_manager/core/models/transaction.dart';
import 'package:my_financial_manager/core/repositories/account_repository.dart';
import 'package:my_financial_manager/core/repositories/category_repository.dart';
import 'package:my_financial_manager/core/repositories/transaction_repository.dart';

import '../test_helpers.dart';

void main() {
  setUpDatabaseForTesting();

  late TransactionRepository txnRepo;
  late AccountRepository accountRepo;
  late CategoryRepository categoryRepo;
  late int cashAccountId;
  late int foodCategoryId;
  late int salaryCategoryId;

  setUp(() async {
    txnRepo = TransactionRepository();
    accountRepo = AccountRepository();
    categoryRepo = CategoryRepository();

    cashAccountId = (await accountRepo.getAll()).first.id!;
    foodCategoryId = (await categoryRepo.getByType(CategoryType.expense))
        .firstWhere((c) => c.nameEn == 'Food')
        .id!;
    salaryCategoryId = (await categoryRepo.getByType(CategoryType.income))
        .firstWhere((c) => c.nameEn == 'Salary')
        .id!;
  });

  Transaction _income(double amount, {DateTime? date}) => Transaction(
        accountId: cashAccountId,
        categoryId: salaryCategoryId,
        type: TransactionType.income,
        amount: amount,
        date: date ?? DateTime(2026, 6, 1),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Transaction _expense(double amount, {DateTime? date}) => Transaction(
        accountId: cashAccountId,
        categoryId: foodCategoryId,
        type: TransactionType.expense,
        amount: amount,
        date: date ?? DateTime(2026, 6, 1),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  group('TransactionRepository — Section 34 atomicity', () {
    test('recording income increases the account balance by the same amount', () async {
      await txnRepo.recordIncomeOrExpense(_income(1000));
      expect(await accountRepo.totalBalance(), 1000);
    });

    test('recording an expense decreases the account balance by the same amount', () async {
      await txnRepo.recordIncomeOrExpense(_income(1000));
      await txnRepo.recordIncomeOrExpense(_expense(400));
      expect(await accountRepo.totalBalance(), 600);
    });

    test('deleting a transaction reverses its effect on the account balance', () async {
      final id = await txnRepo.recordIncomeOrExpense(_income(1000));
      await txnRepo.recordIncomeOrExpense(_expense(300));
      expect(await accountRepo.totalBalance(), 700);

      await txnRepo.delete(id); // undo the +1000 income
      expect(await accountRepo.totalBalance(), -300);
    });
  });

  group('TransactionRepository — transfers (Section 29)', () {
    test('a transfer moves money between accounts without counting as income or expense', () async {
      final otherId = await accountRepo.create(Account(
        name: 'CBE',
        accountType: AccountType.bank,
        currency: 'ETB',
        openingBalance: 0,
        currentBalance: 0,
        createdAt: DateTime(2026, 1, 1),
      ));
      await txnRepo.recordIncomeOrExpense(_income(1000));

      await txnRepo.recordTransfer(
        fromAccountId: cashAccountId,
        toAccountId: otherId,
        amount: 400,
        date: DateTime(2026, 6, 2),
      );

      final cash = await accountRepo.getById(cashAccountId);
      final other = await accountRepo.getById(otherId);
      expect(cash!.currentBalance, 600);
      expect(other!.currentBalance, 400);

      // Total balance across accounts is unaffected by a transfer, and the
      // period totals must not count the transfer as income/expense.
      expect(await accountRepo.totalBalance(), 1000);
      final totals = await txnRepo.incomeExpenseTotals(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 7, 1),
      );
      expect(totals['income'], 1000); // only the original income
      expect(totals['expense'], 0);
    });
  });

  group('TransactionRepository — reporting queries', () {
    test('incomeExpenseTotals only sums transactions inside the given window', () async {
      await txnRepo.recordIncomeOrExpense(_income(500, date: DateTime(2026, 5, 31))); // just outside
      await txnRepo.recordIncomeOrExpense(_income(1000, date: DateTime(2026, 6, 15))); // inside
      await txnRepo.recordIncomeOrExpense(_expense(200, date: DateTime(2026, 6, 20))); // inside
      await txnRepo.recordIncomeOrExpense(_expense(50, date: DateTime(2026, 7, 1))); // just outside (exclusive end)

      final totals = await txnRepo.incomeExpenseTotals(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 7, 1),
      );
      expect(totals['income'], 1000);
      expect(totals['expense'], 200);
    });

    test('categoryBreakdown groups expense totals by category', () async {
      await txnRepo.recordIncomeOrExpense(_expense(300));
      await txnRepo.recordIncomeOrExpense(_expense(200));

      final rows = await txnRepo.categoryBreakdown(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 7, 1),
        type: 'expense',
      );
      expect(rows, hasLength(1));
      expect(rows.first['category'], 'Food');
      expect((rows.first['total'] as num).toDouble(), 500);
    });

    test('search matches on description', () async {
      await txnRepo.recordIncomeOrExpense(Transaction(
        accountId: cashAccountId,
        categoryId: foodCategoryId,
        type: TransactionType.expense,
        amount: 150,
        date: DateTime(2026, 6, 1),
        description: 'Lunch with Abebe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await txnRepo.recordIncomeOrExpense(_expense(75)); // no description

      final results = await txnRepo.search('Abebe');
      expect(results, hasLength(1));
      expect(results.first.description, contains('Abebe'));
    });

    test('page() paginates without loading everything at once (Section 35)', () async {
      for (var i = 0; i < 5; i++) {
        await txnRepo.recordIncomeOrExpense(_expense(10, date: DateTime(2026, 6, 1 + i)));
      }
      final firstPage = await txnRepo.page(limit: 2, offset: 0);
      final secondPage = await txnRepo.page(limit: 2, offset: 2);
      expect(firstPage, hasLength(2));
      expect(secondPage, hasLength(2));
      expect(firstPage.map((t) => t.id), isNot(containsAll(secondPage.map((t) => t.id))));
    });
  });
}
