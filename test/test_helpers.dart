import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';
import 'package:my_financial_manager/core/database/database_helper.dart';

/// Call once at the top of a test file's `main()`, before any `test()`
/// blocks. Wires sqflite to the pure-Dart FFI implementation (no platform
/// channels, so no device/emulator/Android SDK needed) and gives every
/// individual test a fresh, isolated in-memory database — Phase 1's
/// `DatabaseHelper` is otherwise unchanged and unaware it's under test.
void setUpDatabaseForTesting() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.debugOverrideDbPath = inMemoryDatabasePath;
  });

  setUp(() async {
    // Closing between tests forces the next `database` access to open a
    // brand-new in-memory DB — SQLite gives each new `:memory:` connection
    // a separate database, so this is sufficient isolation between tests.
    await DatabaseHelper.resetForTesting();
  });

  tearDownAll(() async {
    await DatabaseHelper.resetForTesting();
    DatabaseHelper.debugOverrideDbPath = null;
  });
}
