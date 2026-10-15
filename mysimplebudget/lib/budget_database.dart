import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Opens the local SQLite database and provides budget insert and read methods.
class BudgetDatabase {
  BudgetDatabase._();

  static final BudgetDatabase instance = BudgetDatabase._();
  static const _databaseName = 'simple_budget.db';
  static const _tableName = 'budgets';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    // Opening a missing database creates it; onCreate adds the budgets table.
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            direction TEXT NOT NULL,
            type TEXT NOT NULL,
            value REAL NOT NULL,
            description TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  Future<int> insertBudget({
    required String direction,
    required String type,
    required double value,
    required String description,
  }) async {
    // The returned row ID indicates that SQLite inserted the entry.
    final db = await database;
    return db.insert(_tableName, {
      'direction': direction,
      'type': type,
      'value': value,
      'description': description,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> getAllBudgets() async {
    final db = await database;
    // Show newest entries first, using the ID to order entries with equal timestamps.
    return db.query(_tableName, orderBy: 'created_at DESC, id DESC');
  }
}
