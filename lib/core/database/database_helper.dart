import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Central access point for the local SQLite database.
///
/// Schema follows spec Section 33, with the `account_id` addition on
/// `loans` per Spec Addendum #1 (loans <-> accounts linkage).
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _dbName = 'personal_finance_manager.db';
  static const currentVersion = 6;

  Database? _db;

  /// Test-only hook. When non-null, [_initDb] opens this path directly
  /// instead of resolving a real on-device documents directory via
  /// path_provider — set it to `inMemoryDatabasePath` from
  /// `sqflite_common_ffi` in test setup. Never set outside tests; left
  /// null, production behavior is completely unchanged.
  static String? debugOverrideDbPath;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = debugOverrideDbPath ?? await _resolveDefaultPath();
    return openDatabase(
      dbPath,
      version: currentVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<String> _resolveDefaultPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, _dbName);
  }

  /// Test-only: closes the current connection so the next [database] access
  /// opens a fresh one (a new in-memory DB, when [debugOverrideDbPath] is
  /// set) — call between tests to avoid state leaking across them.
  static Future<void> resetForTesting() async {
    await instance.close();
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        language TEXT NOT NULL DEFAULT 'en',
        currency TEXT NOT NULL DEFAULT 'ETB',
        pin_hash TEXT,
        biometric_enabled INTEGER NOT NULL DEFAULT 0,
        backup_reminder_frequency TEXT,
        onboarding_complete INTEGER NOT NULL DEFAULT 0,
        theme_mode TEXT NOT NULL DEFAULT 'system',
        use_ethiopian_calendar INTEGER NOT NULL DEFAULT 0,
        hide_balances INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        account_type TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'ETB',
        opening_balance REAL NOT NULL DEFAULT 0,
        current_balance REAL NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name_en TEXT NOT NULL,
        name_am TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
        icon TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name_en TEXT NOT NULL,
        name_am TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE people (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        note TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        category_id INTEGER REFERENCES categories(id),
        type TEXT NOT NULL CHECK (type IN (
          'income', 'expense', 'transfer', 'loan_inflow', 'loan_outflow',
          'loan_payment_in', 'loan_payment_out',
          'savings_contribution_out', 'savings_withdrawal_in'
        )),
        amount REAL NOT NULL CHECK (amount > 0),
        date TEXT NOT NULL,
        description TEXT,
        payment_method_id INTEGER REFERENCES payment_methods(id),
        reference TEXT,
        related_loan_id INTEGER,
        related_goal_id INTEGER,
        related_transfer_account_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_id INTEGER NOT NULL REFERENCES people(id),
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        loan_type TEXT NOT NULL CHECK (loan_type IN ('borrowed', 'lent')),
        principal_amount REAL NOT NULL CHECK (principal_amount > 0),
        interest_mode TEXT NOT NULL DEFAULT 'none' CHECK (
          interest_mode IN ('none', 'fixed', 'percentage')
        ),
        interest_value REAL NOT NULL DEFAULT 0,
        interest_amount REAL NOT NULL DEFAULT 0,
        total_amount REAL NOT NULL,
        remaining_amount REAL NOT NULL,
        start_date TEXT NOT NULL,
        due_date TEXT,
        installment_amount REAL,
        frequency TEXT CHECK (
          frequency IN ('daily', 'weekly', 'biweekly', 'monthly', 'custom')
        ),
        status TEXT NOT NULL DEFAULT 'active' CHECK (
          status IN ('active', 'partially_paid', 'fully_paid', 'overdue')
        ),
        description TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE loan_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER NOT NULL REFERENCES loans(id),
        amount REAL NOT NULL CHECK (amount > 0),
        payment_date TEXT NOT NULL,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL REFERENCES categories(id),
        amount REAL NOT NULL CHECK (amount > 0),
        month INTEGER NOT NULL,
        year INTEGER NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE recurring_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
        amount REAL NOT NULL CHECK (amount > 0),
        category_id INTEGER REFERENCES categories(id),
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        description TEXT,
        frequency TEXT NOT NULL CHECK (
          frequency IN ('daily', 'weekly', 'monthly', 'yearly')
        ),
        next_date TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    batch.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        reminder_date TEXT NOT NULL,
        related_loan_id INTEGER REFERENCES loans(id),
        completed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE savings_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL CHECK (target_amount > 0),
        current_amount REAL NOT NULL DEFAULT 0,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        target_date TEXT,
        status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed')),
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE savings_goal_contributions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL REFERENCES savings_goals(id),
        amount REAL NOT NULL CHECK (amount > 0),
        type TEXT NOT NULL CHECK (type IN ('contribution', 'withdrawal')),
        contribution_date TEXT NOT NULL,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Indexes (Section 35 performance requirement).
    batch.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    batch.execute('CREATE INDEX idx_tx_type ON transactions(type)');
    batch.execute('CREATE INDEX idx_tx_category ON transactions(category_id)');
    batch.execute('CREATE INDEX idx_tx_account ON transactions(account_id)');
    batch.execute('CREATE INDEX idx_loans_person ON loans(person_id)');
    batch.execute('CREATE INDEX idx_loans_status ON loans(status)');
    batch.execute('CREATE INDEX idx_loan_payments_loan ON loan_payments(loan_id)');
    batch.execute('CREATE INDEX idx_goals_status ON savings_goals(status)');
    batch.execute('CREATE INDEX idx_goal_contributions_goal ON savings_goal_contributions(goal_id)');

    await batch.commit(noResult: true);
    await _seedDefaults(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE users ADD COLUMN onboarding_complete INTEGER NOT NULL DEFAULT 0',
      );
      // Anyone upgrading from v1 already has data, i.e. already completed
      // onboarding in the old (unpersisted) flow — mark any existing row so
      // they aren't sent back through the setup wizard.
      await db.rawUpdate('UPDATE users SET onboarding_complete = 1');
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE users ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'system'");
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE users ADD COLUMN use_ethiopian_calendar INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE users ADD COLUMN hide_balances INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 6) {
      // Widening `transactions.type`'s CHECK constraint (to allow the new
      // savings_* values) and adding `related_goal_id` both need a column
      // set SQLite's ALTER TABLE can't express directly — its ALTER TABLE
      // only supports add/rename/drop column, never touching a CHECK. The
      // standard workaround: rename the old table aside, create the new
      // schema in its place, copy every row across, then drop the old one.
      await db.execute('ALTER TABLE transactions RENAME TO transactions_old');
      await db.execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id INTEGER NOT NULL REFERENCES accounts(id),
          category_id INTEGER REFERENCES categories(id),
          type TEXT NOT NULL CHECK (type IN (
            'income', 'expense', 'transfer', 'loan_inflow', 'loan_outflow',
            'loan_payment_in', 'loan_payment_out',
            'savings_contribution_out', 'savings_withdrawal_in'
          )),
          amount REAL NOT NULL CHECK (amount > 0),
          date TEXT NOT NULL,
          description TEXT,
          payment_method_id INTEGER REFERENCES payment_methods(id),
          reference TEXT,
          related_loan_id INTEGER,
          related_goal_id INTEGER,
          related_transfer_account_id INTEGER,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        INSERT INTO transactions (
          id, account_id, category_id, type, amount, date, description,
          payment_method_id, reference, related_loan_id, related_goal_id,
          related_transfer_account_id, created_at, updated_at
        )
        SELECT
          id, account_id, category_id, type, amount, date, description,
          payment_method_id, reference, related_loan_id, NULL,
          related_transfer_account_id, created_at, updated_at
        FROM transactions_old
      ''');
      await db.execute('DROP TABLE transactions_old');
      // Recreating the table drops its indexes with it — put them back.
      await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
      await db.execute('CREATE INDEX idx_tx_type ON transactions(type)');
      await db.execute('CREATE INDEX idx_tx_category ON transactions(category_id)');
      await db.execute('CREATE INDEX idx_tx_account ON transactions(account_id)');

      await db.execute('''
        CREATE TABLE savings_goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          target_amount REAL NOT NULL CHECK (target_amount > 0),
          current_amount REAL NOT NULL DEFAULT 0,
          account_id INTEGER NOT NULL REFERENCES accounts(id),
          target_date TEXT,
          status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed')),
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE savings_goal_contributions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          goal_id INTEGER NOT NULL REFERENCES savings_goals(id),
          amount REAL NOT NULL CHECK (amount > 0),
          type TEXT NOT NULL CHECK (type IN ('contribution', 'withdrawal')),
          contribution_date TEXT NOT NULL,
          account_id INTEGER NOT NULL REFERENCES accounts(id),
          note TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX idx_goals_status ON savings_goals(status)');
      await db.execute(
        'CREATE INDEX idx_goal_contributions_goal ON savings_goal_contributions(goal_id)',
      );
    }
  }

  Future<void> _seedDefaults(Database db) async {
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();

    const incomeCategories = [
      ['Salary', 'ደሞዝ'],
      ['Business', 'ንግድ'],
      ['Freelance', 'ፍሪላንስ'],
      ['Investment', 'ኢንቨስትመንት'],
      ['Rental Income', 'የኪራይ ገቢ'],
      ['Gift', 'ስጦታ'],
      ['Interest', 'ወለድ'],
      ['Other', 'ሌላ'],
    ];
    const expenseCategories = [
      ['Food', 'ምግብ'],
      ['Transport', 'ትራንስፖርት'],
      ['Rent', 'ኪራይ'],
      ['Utilities', 'አገልግሎቶች'],
      ['Phone', 'ስልክ'],
      ['Internet', 'ኢንተርኔት'],
      ['Shopping', 'ግብይት'],
      ['Entertainment', 'መዝናኛ'],
      ['Medical', 'ህክምና'],
      ['Education', 'ትምህርት'],
      ['Family', 'ቤተሰብ'],
      ['Clothing', 'አልባሳት'],
      ['Fuel', 'ነዳጅ'],
      ['House', 'ቤት'],
      ['Travel', 'ጉዞ'],
      ['Other', 'ሌላ'],
    ];
    for (final c in incomeCategories) {
      batch.insert('categories', {
        'name_en': c[0],
        'name_am': c[1],
        'type': 'income',
        'active': 1,
        'is_default': 1,
      });
    }
    for (final c in expenseCategories) {
      batch.insert('categories', {
        'name_en': c[0],
        'name_am': c[1],
        'type': 'expense',
        'active': 1,
        'is_default': 1,
      });
    }

    const paymentMethods = [
      ['Cash', 'ጥሬ ገንዘብ'],
      ['Bank', 'ባንክ'],
      ['Telebirr', 'ቴሌብር'],
      ['CBE Birr', 'ሲቢኢ ብር'],
      ['Card', 'ካርድ'],
      ['Other', 'ሌላ'],
    ];
    for (final m in paymentMethods) {
      batch.insert('payment_methods', {
        'name_en': m[0],
        'name_am': m[1],
        'active': 1,
        'is_default': 1,
      });
    }

    // Default "Cash" account so a first transaction never blocks on
    // account setup.
    batch.insert('accounts', {
      'name': 'Cash',
      'account_type': 'cash',
      'currency': 'ETB',
      'opening_balance': 0,
      'current_balance': 0,
      'active': 1,
      'created_at': now,
    });

    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  /// Wipes every table, including `users` (so the PIN and onboarding flag
  /// go with it), then reseeds default categories/payment methods/account.
  /// Used only by the "Forgot PIN? Erase all data" recovery path
  /// (Addendum #4) — this is deliberately destructive and irreversible.
  Future<void> eraseAllData() async {
    final db = await database;
    const tables = [
      'reminders', 'recurring_transactions', 'budgets', 'loan_payments',
      'loans', 'savings_goal_contributions', 'savings_goals', 'transactions',
      'people', 'payment_methods', 'categories', 'accounts', 'users',
    ];
    await db.transaction((tx) async {
      for (final table in tables) {
        await tx.delete(table);
      }
    });
    await _seedDefaults(db);
  }
}
