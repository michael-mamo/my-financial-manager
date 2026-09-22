import '../database/database_helper.dart';
import '../models/budget.dart';

class BudgetRepository {
  final DatabaseHelper _dbHelper;
  BudgetRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<int> create(Budget budget) async {
    final db = await _dbHelper.database;
    return db.insert('budgets', budget.toMap());
  }

  Future<void> update(Budget budget) async {
    final db = await _dbHelper.database;
    await db.update('budgets', budget.toMap(), where: 'id = ?', whereArgs: [budget.id]);
  }

  Future<void> delete(int id) async {
    final db = await _dbHelper.database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Budget>> forMonth({required int month, required int year}) async {
    final db = await _dbHelper.database;
    final rows = await db.query('budgets', where: 'month = ? AND year = ?', whereArgs: [month, year]);
    return rows.map(Budget.fromMap).toList();
  }

  /// Joins each budget with its category name and actual spend for the
  /// period — powers the Section 22 "Budget / Spent / Remaining" display
  /// and the near-limit/over-budget warnings.
  Future<List<BudgetProgress>> progressForMonth({required int month, required int year}) async {
    final db = await _dbHelper.database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();

    final rows = await db.rawQuery('''
      SELECT b.id, b.category_id, b.amount, b.month, b.year, c.name_en AS category_name,
        COALESCE((
          SELECT SUM(t.amount) FROM transactions t
          WHERE t.category_id = b.category_id AND t.type = 'expense'
            AND t.date >= ? AND t.date < ?
        ), 0) AS spent
      FROM budgets b
      LEFT JOIN categories c ON c.id = b.category_id
      WHERE b.month = ? AND b.year = ?
      ORDER BY c.name_en ASC
    ''', [start, end, month, year]);

    return rows.map((row) {
      final budget = Budget(
        id: row['id'] as int?,
        categoryId: row['category_id'] as int,
        amount: (row['amount'] as num).toDouble(),
        month: row['month'] as int,
        year: row['year'] as int,
      );
      return BudgetProgress(
        budget: budget,
        categoryName: (row['category_name'] as String?) ?? 'Uncategorized',
        spent: (row['spent'] as num).toDouble(),
      );
    }).toList();
  }
}
