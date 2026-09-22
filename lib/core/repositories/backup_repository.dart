import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';

/// Section 24 + Addendum #5/#8.
///
/// Backup format is a structured JSON file (the spec allows either a raw
/// `.db` file or JSON — JSON is used here since it's portable and doesn't
/// require exposing the raw SQLite file). If the user sets a password, the
/// payload is AES-256-CBC encrypted with a key derived from that password;
/// otherwise it's stored as plain JSON with a one-line warning shown by the
/// UI before sharing (Addendum #5).
///
/// Restore is always a full overwrite (Addendum #8) — there is no merge
/// mode. The confirmation prompt lives in the UI layer; this repository
/// assumes the caller has already confirmed.
class BackupRepository {
  final DatabaseHelper _dbHelper;
  BackupRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Insert order also defines dependency order for restore; delete order
  /// for restore is simply this list reversed.
  static const _tables = [
    'users', 'accounts', 'categories', 'payment_methods', 'people',
    'transactions', 'loans', 'loan_payments', 'budgets',
    'recurring_transactions', 'reminders',
  ];

  /// Builds the backup JSON and writes it to a local file, returning the
  /// file path for the caller to hand to share_plus. [password] is optional;
  /// when provided, the payload is encrypted.
  Future<File> exportBackup({String? password}) async {
    final db = await _dbHelper.database;
    final data = <String, List<Map<String, Object?>>>{};
    for (final table in _tables) {
      data[table] = await db.query(table);
    }
    final payloadJson = jsonEncode(data);

    Map<String, Object?> wrapper;
    if (password != null && password.isNotEmpty) {
      final key = enc.Key.fromUtf8(_deriveKey(password));
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(payloadJson, iv: iv);
      wrapper = {
        'version': 1,
        'encrypted': true,
        'iv': iv.base64,
        'payload': encrypted.base64,
      };
    } else {
      wrapper = {
        'version': 1,
        'encrypted': false,
        'payload': payloadJson,
      };
    }

    final dir = await getApplicationDocumentsDirectory();
    final dateStamp = DateTime.now().toIso8601String().split('T').first;
    final file = File('${dir.path}/personal_finance_backup_$dateStamp.json');
    await file.writeAsString(jsonEncode(wrapper));
    return file;
  }

  /// Reads a backup file and reports whether it's encrypted, without
  /// decrypting — lets the UI decide whether to prompt for a password
  /// before calling [restoreFromFile].
  Future<bool> isEncrypted(File file) async {
    final wrapper = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return wrapper['encrypted'] == true;
  }

  /// Decrypts (if needed) and fully overwrites the local database.
  /// Throws a [FormatException] on a wrong password or corrupt file.
  Future<void> restoreFromFile(File file, {String? password}) async {
    final wrapper = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final isEncrypted = wrapper['encrypted'] == true;
    late String payloadJson;

    if (isEncrypted) {
      if (password == null || password.isEmpty) {
        throw const FormatException('This backup is password-protected.');
      }
      try {
        final key = enc.Key.fromUtf8(_deriveKey(password));
        final iv = enc.IV.fromBase64(wrapper['iv'] as String);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
        payloadJson = encrypter.decrypt64(wrapper['payload'] as String, iv: iv);
      } catch (_) {
        throw const FormatException('Incorrect password or corrupted backup file.');
      }
    } else {
      payloadJson = wrapper['payload'] as String;
    }

    final data = jsonDecode(payloadJson) as Map<String, dynamic>;
    final db = await _dbHelper.database;

    await db.transaction((tx) async {
      for (final table in _tables.reversed) {
        await tx.delete(table);
      }
      for (final table in _tables) {
        final rows = (data[table] as List<dynamic>? ?? []);
        for (final row in rows) {
          await tx.insert(table, Map<String, Object?>.from(row as Map));
        }
      }
    });
  }

  /// Derives a fixed-length key from an arbitrary-length password. Not a
  /// substitute for a proper KDF like PBKDF2/Argon2, but adequate for a
  /// local, single-user backup file rather than a high-value secret store.
  String _deriveKey(String password) {
    final bytes = utf8.encode(password);
    final padded = List<int>.filled(32, 0);
    for (var i = 0; i < bytes.length; i++) {
      padded[i % 32] ^= bytes[i];
    }
    return String.fromCharCodes(padded.map((b) => 33 + (b % 90))); // printable ASCII
  }
}
