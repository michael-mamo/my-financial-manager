import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../database/database_helper.dart';
import '../models/app_settings.dart';

/// The `users` table holds exactly one row — this app has no accounts
/// (Section 36), so it's really just "persisted app settings," including
/// the PIN hash. PINs are hashed (never stored in plaintext) but there is
/// intentionally no recovery mechanism beyond restore-or-erase
/// (Addendum #4) — this app has no server to verify identity against.
class SettingsRepository {
  final DatabaseHelper _dbHelper;
  SettingsRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<AppSettings> getOrCreate() async {
    final db = await _dbHelper.database;
    final rows = await db.query('users', limit: 1);
    if (rows.isNotEmpty) return AppSettings.fromMap(rows.first);

    final settings = AppSettings(language: 'en', currency: 'ETB', createdAt: DateTime.now());
    final id = await db.insert('users', settings.toMap());
    return AppSettings.fromMap({...settings.toMap(), 'id': id});
  }

  Future<AppSettings> save(AppSettings settings) async {
    final db = await _dbHelper.database;
    if (settings.id == null) {
      final id = await db.insert('users', settings.toMap());
      return AppSettings.fromMap({...settings.toMap(), 'id': id});
    }
    await db.update('users', settings.toMap(), where: 'id = ?', whereArgs: [settings.id]);
    return settings;
  }

  String hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

  Future<AppSettings> setPin(AppSettings current, String pin) {
    return save(current.copyWith(pinHash: hashPin(pin)));
  }

  Future<AppSettings> clearPin(AppSettings current) {
    return save(current.copyWith(clearPin: true, biometricEnabled: false));
  }

  bool verifyPin(AppSettings settings, String pin) {
    if (!settings.hasPin) return false;
    return settings.pinHash == hashPin(pin);
  }
}
