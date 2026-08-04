import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/trade.dart';

class TradeDatabase {
  TradeDatabase._();

  static final TradeDatabase instance = TradeDatabase._();

  static const _databaseName = 'j_investment_ai.db';
  static const _databaseVersion = 1;
  static const _tradeTable = 'trades';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final databasePath = await getDatabasesPath();
    final path = p.join(databasePath, _databaseName);

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );

    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tradeTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        symbol TEXT NOT NULL,
        exchange TEXT NOT NULL,
        timeframe TEXT NOT NULL,
        direction TEXT NOT NULL,
        entry REAL NOT NULL,
        stop REAL NOT NULL,
        target REAL NOT NULL,
        exit REAL,
        leverage INTEGER NOT NULL,
        margin_mode TEXT NOT NULL,
        margin REAL NOT NULL,
        fee REAL NOT NULL DEFAULT 0,
        funding_fee REAL NOT NULL DEFAULT 0,
        real_pnl REAL,
        leveraged_percent REAL,
        net_pnl REAL,
        entry_note TEXT NOT NULL DEFAULT '',
        exit_note TEXT NOT NULL DEFAULT '',
        review_note TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'OPEN',
        created_at TEXT NOT NULL,
        closed_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'LOCAL_PENDING'
      )
    ''');
  }

  Future<int> insertTrade(Trade trade) async {
    final db = await database;
    final data = trade.toMap()..remove('id');

    return db.insert(
      _tradeTable,
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Trade>> getTrades() async {
    final db = await database;
    final rows = await db.query(
      _tradeTable,
      orderBy: 'created_at DESC',
    );

    return rows.map(Trade.fromMap).toList();
  }

  Future<int> deleteTrade(int id) async {
    final db = await database;
    return db.delete(
      _tradeTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
