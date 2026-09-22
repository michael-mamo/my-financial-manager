import '../database/database_helper.dart';
import '../models/person.dart';

class PersonRepository {
  final DatabaseHelper _dbHelper;
  PersonRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<Person>> getAll() async {
    final db = await _dbHelper.database;
    final rows = await db.query('people', orderBy: 'name ASC');
    return rows.map(Person.fromMap).toList();
  }

  Future<Person?> getById(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('people', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Person.fromMap(rows.first);
  }

  /// Finds an existing person by exact name match, or creates one.
  /// Keeps the "type a name, keep going" flow fast (Section 42) without
  /// forcing a separate "add contact first" step.
  Future<int> findOrCreateByName(String name) async {
    final db = await _dbHelper.database;
    final trimmed = name.trim();
    final existing = await db.query('people', where: 'name = ?', whereArgs: [trimmed]);
    if (existing.isNotEmpty) return existing.first['id'] as int;
    return db.insert('people', Person(name: trimmed).toMap());
  }

  Future<int> create(Person person) async {
    final db = await _dbHelper.database;
    return db.insert('people', person.toMap());
  }

  Future<void> update(Person person) async {
    final db = await _dbHelper.database;
    await db.update('people', person.toMap(), where: 'id = ?', whereArgs: [person.id]);
  }

  /// Section 27: for each person, how much they owe the user (loan_type =
  /// 'lent', still outstanding) and how much the user owes them (loan_type
  /// = 'borrowed', still outstanding). Only returns people with at least
  /// one loan on record.
  Future<List<Map<String, Object?>>> peopleWithLoanTotals() async {
    final db = await _dbHelper.database;
    return db.rawQuery('''
      SELECT p.id, p.name, p.phone,
        COALESCE(SUM(CASE WHEN l.loan_type = 'lent' AND l.status != 'fully_paid'
                           THEN l.remaining_amount ELSE 0 END), 0) AS owed_by_them,
        COALESCE(SUM(CASE WHEN l.loan_type = 'borrowed' AND l.status != 'fully_paid'
                           THEN l.remaining_amount ELSE 0 END), 0) AS owed_by_you
      FROM people p
      JOIN loans l ON l.person_id = p.id
      GROUP BY p.id
      ORDER BY p.name ASC
    ''');
  }
}
