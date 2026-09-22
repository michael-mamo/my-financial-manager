import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/payment_method.dart';

class CategoryRepository {
  final DatabaseHelper _dbHelper;
  CategoryRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<Category>> getByType(CategoryType type, {bool activeOnly = true}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'categories',
      where: activeOnly ? 'type = ? AND active = 1' : 'type = ?',
      whereArgs: [type.name],
      orderBy: 'name_en ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<int> create(Category category) async {
    final db = await _dbHelper.database;
    return db.insert('categories', category.toMap());
  }

  Future<void> update(Category category) async {
    final db = await _dbHelper.database;
    await db.update('categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
  }

  /// Soft-delete only. Default categories (Section 7/8) are never hard
  /// deleted since historical transactions reference them.
  Future<void> deactivate(int id) async {
    final db = await _dbHelper.database;
    await db.update('categories', {'active': 0}, where: 'id = ?', whereArgs: [id]);
  }
}

class PaymentMethodRepository {
  final DatabaseHelper _dbHelper;
  PaymentMethodRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<PaymentMethod>> getAll({bool activeOnly = true}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'payment_methods',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'name_en ASC',
    );
    return rows.map(PaymentMethod.fromMap).toList();
  }

  Future<int> create(PaymentMethod method) async {
    final db = await _dbHelper.database;
    return db.insert('payment_methods', method.toMap());
  }

  Future<void> deactivate(int id) async {
    final db = await _dbHelper.database;
    await db.update('payment_methods', {'active': 0}, where: 'id = ?', whereArgs: [id]);
  }
}
