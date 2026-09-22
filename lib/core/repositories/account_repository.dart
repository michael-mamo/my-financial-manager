import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/account.dart';

class AccountRepository {
  final DatabaseHelper _dbHelper;
  AccountRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<Account>> getAll({bool activeOnly = true}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'accounts',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'name ASC',
    );
    return rows.map(Account.fromMap).toList();
  }

  Future<Account?> getById(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Account.fromMap(rows.first);
  }

  Future<int> create(Account account) async {
    final db = await _dbHelper.database;
    return db.insert('accounts', account.toMap());
  }

  Future<void> update(Account account) async {
    final db = await _dbHelper.database;
    await db.update('accounts', account.toMap(), where: 'id = ?', whereArgs: [account.id]);
  }

  Future<void> deactivate(int id) async {
    final db = await _dbHelper.database;
    await db.update('accounts', {'active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  /// Total across all active accounts — powers the dashboard Balance
  /// (Spec Addendum #1: balance is always derived, never separately stored).
  Future<double> totalBalance() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(current_balance), 0) AS total FROM accounts WHERE active = 1',
    );
    return (result.first['total'] as num).toDouble();
  }

  /// Adjusts an account's balance within an existing transaction/batch
  /// context. [delta] is positive to credit, negative to debit.
  Future<void> adjustBalance(DatabaseExecutor executor, int accountId, double delta) async {
    await executor.rawUpdate(
      'UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?',
      [delta, accountId],
    );
  }
}
