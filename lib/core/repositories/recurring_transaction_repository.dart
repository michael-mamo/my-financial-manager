import '../database/database_helper.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart' as txn_model;

/// Section 23 + Addendum #7: no background OS jobs. Instead, every app
/// launch calls [runCatchUp], which creates any transactions that came due
/// while the app was closed and advances `next_date` past today.
class RecurringTransactionRepository {
  final DatabaseHelper _dbHelper;
  RecurringTransactionRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<RecurringTransaction>> getAll({bool activeOnly = true}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'recurring_transactions',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'next_date ASC',
    );
    return rows.map(RecurringTransaction.fromMap).toList();
  }

  Future<int> create(RecurringTransaction recurring) async {
    final db = await _dbHelper.database;
    return db.insert('recurring_transactions', recurring.toMap());
  }

  Future<void> setActive(int id, bool active) async {
    final db = await _dbHelper.database;
    await db.update('recurring_transactions', {'active': active ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await _dbHelper.database;
    await db.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Creates every due transaction (possibly several, if the app was closed
  /// across multiple cycles) and advances `next_date` past today, one
  /// recurring rule at a time, each in its own DB transaction alongside the
  /// resulting ledger/account update (Section 34).
  ///
  /// [clock] defaults to the real wall clock; tests pass a fixed function
  /// so "the app was closed for 3 months" scenarios are deterministic
  /// rather than depending on when the test happens to run.
  ///
  /// Returns how many transactions were created, so the caller can show a
  /// "3 recurring transactions were added" notice if desired.
  Future<int> runCatchUp({DateTime Function() clock = DateTime.now}) async {
    final db = await _dbHelper.database;
    final due = await getAll();
    var created = 0;
    final today = clock();

    for (final rule in due) {
      var current = rule;
      // Guard against a runaway loop if a rule's next_date somehow sits far
      // in the past — cap catch-up at 500 cycles per rule per app launch.
      var safety = 0;
      while (!current.nextDate.isAfter(today) && safety < 500) {
        safety++;
        final now = clock();
        final type = current.type == 'income'
            ? txn_model.TransactionType.income
            : txn_model.TransactionType.expense;
        final delta = type == txn_model.TransactionType.income ? current.amount : -current.amount;

        await db.transaction((tx) async {
          await tx.insert('transactions', txn_model.Transaction(
            accountId: current.accountId,
            categoryId: current.categoryId,
            type: type,
            amount: current.amount,
            date: current.nextDate,
            description: current.description,
            createdAt: now,
            updatedAt: now,
          ).toMap());

          await tx.rawUpdate(
            'UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?',
            [delta, current.accountId],
          );

          final advanced = current.advancedDate();
          await tx.update(
            'recurring_transactions',
            {'next_date': advanced.toIso8601String()},
            where: 'id = ?',
            whereArgs: [current.id],
          );
          current = current.copyWith(nextDate: advanced);
        });
        created++;
      }
    }
    return created;
  }
}
