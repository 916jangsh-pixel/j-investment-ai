import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/project.dart';
import '../models/trade.dart';
import 'trade_calculator.dart';

class TradeDatabase {
  TradeDatabase._();
  static final TradeDatabase instance = TradeDatabase._();

  static const _databaseName = 'j_investment_ai.db';
  static const _databaseVersion = 3;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final databasePath = await getDatabasesPath();
    final path = p.join(databasePath, _databaseName);

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createProjects(db);
    await _createTrades(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE trades RENAME TO trades_v1_backup');
      await _createProjects(db);

      final projectId = await db.insert('projects', {
        'name': '기존 매매 프로젝트',
        'start_balance': 1000.0,
        'current_balance': 1000.0,
        'target_balance': 10000.0,
        'compound_enabled': 1,
        'margin_percent': 20.0,
        'max_margin_percent': 20.0,
        'max_leverage': 10,
        'max_loss_percent': 2.0,
        'loss_streak': 0,
        'loss_protection_enabled': 1,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'ACTIVE',
      });

      await _createTrades(db);

      await db.execute('''
        INSERT INTO trades (
          project_id, symbol, exchange, timeframe, direction,
          entry, stop, target, exit, leverage, margin_mode, margin,
          fee, funding_fee, price_return_percent, leveraged_return_percent,
          gross_pnl, net_pnl, entry_note, exit_note, review_note,
          status, created_at, closed_at, sync_status
        )
        SELECT
          $projectId, symbol, exchange, timeframe, direction,
          entry, stop, target, exit, leverage, margin_mode, margin,
          fee, funding_fee, NULL, leveraged_percent,
          real_pnl, net_pnl, entry_note, exit_note, review_note,
          status, created_at, closed_at, sync_status
        FROM trades_v1_backup
      ''');
      await db.execute('DROP TABLE trades_v1_backup');
    }

    if (oldVersion < 3) {
      final columns = await db.rawQuery('PRAGMA table_info(projects)');
      final names = columns.map((row) => row['name']).toSet();

      if (!names.contains('is_active')) {
        await db.execute(
          'ALTER TABLE projects ADD COLUMN is_active INTEGER NOT NULL DEFAULT 0',
        );
      }

      final firstActive = await db.query(
        'projects',
        where: "status = 'ACTIVE'",
        orderBy: 'created_at ASC',
        limit: 1,
      );

      if (firstActive.isNotEmpty) {
        await db.update(
          'projects',
          {'is_active': 1},
          where: 'id = ?',
          whereArgs: [firstActive.first['id']],
        );
      }
    }
  }

  Future<void> _createProjects(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_balance REAL NOT NULL,
        current_balance REAL NOT NULL,
        target_balance REAL NOT NULL,
        compound_enabled INTEGER NOT NULL,
        margin_percent REAL NOT NULL,
        max_margin_percent REAL NOT NULL,
        max_leverage INTEGER NOT NULL,
        max_loss_percent REAL NOT NULL,
        loss_streak INTEGER NOT NULL DEFAULT 0,
        loss_protection_enabled INTEGER NOT NULL DEFAULT 1,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'ACTIVE'
      )
    ''');
  }

  Future<void> _createTrades(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
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
        price_return_percent REAL,
        leveraged_return_percent REAL,
        gross_pnl REAL,
        net_pnl REAL,
        entry_note TEXT NOT NULL DEFAULT '',
        exit_note TEXT NOT NULL DEFAULT '',
        review_note TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'OPEN',
        created_at TEXT NOT NULL,
        closed_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'LOCAL_PENDING',
        FOREIGN KEY(project_id) REFERENCES projects(id)
      )
    ''');
  }

  Future<List<Project>> getProjects({bool includeArchived = false}) async {
    final db = await database;
    final rows = await db.query(
      'projects',
      where: includeArchived ? null : "status = 'ACTIVE'",
      orderBy: 'is_active DESC, created_at DESC',
    );
    return rows.map(Project.fromMap).toList();
  }

  Future<Project?> getProject(int id) async {
    final db = await database;
    final rows = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Project.fromMap(rows.first);
  }

  Future<Project?> getActiveProject() async {
    final db = await database;

    final rows = await db.query(
      'projects',
      where: "status = 'ACTIVE' AND is_active = 1",
      limit: 1,
    );
    if (rows.isNotEmpty) return Project.fromMap(rows.first);

    final fallback = await db.query(
      'projects',
      where: "status = 'ACTIVE'",
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (fallback.isEmpty) return null;

    final project = Project.fromMap(fallback.first);
    if (project.id != null) {
      await setActiveProject(project.id!);
      return project.copyWith(isActive: true);
    }
    return project;
  }

  Future<int> insertProject(Project project) async {
    final db = await database;
    final existing = await db.query(
      'projects',
      where: "status = 'ACTIVE'",
      limit: 1,
    );
    final shouldBeActive = existing.isEmpty || project.isActive;

    return db.transaction((txn) async {
      if (shouldBeActive) {
        await txn.update(
          'projects',
          {'is_active': 0},
          where: "status = 'ACTIVE'",
        );
      }

      final data = project.copyWith(isActive: shouldBeActive).toMap()
        ..remove('id');

      return txn.insert('projects', data);
    });
  }

  Future<int> updateProject(Project project) async {
    final id = project.id;
    if (id == null) throw StateError('프로젝트 ID가 없습니다.');

    final db = await database;
    final data = project.toMap()..remove('id');

    return db.update(
      'projects',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setActiveProject(int projectId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'projects',
        {'is_active': 0},
        where: "status = 'ACTIVE'",
      );
      await txn.update(
        'projects',
        {'is_active': 1},
        where: "id = ? AND status = 'ACTIVE'",
        whereArgs: [projectId],
      );
    });
  }

  Future<void> archiveProject(int projectId) async {
    final db = await database;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'projects',
        columns: ['is_active'],
        where: 'id = ?',
        whereArgs: [projectId],
        limit: 1,
      );

      final wasActive =
          rows.isNotEmpty && (rows.first['is_active'] as int) == 1;

      await txn.update(
        'projects',
        {'status': 'ARCHIVED', 'is_active': 0},
        where: 'id = ?',
        whereArgs: [projectId],
      );

      if (wasActive) {
        final fallback = await txn.query(
          'projects',
          where: "status = 'ACTIVE'",
          orderBy: 'created_at DESC',
          limit: 1,
        );

        if (fallback.isNotEmpty) {
          await txn.update(
            'projects',
            {'is_active': 1},
            where: 'id = ?',
            whereArgs: [fallback.first['id']],
          );
        }
      }
    });
  }

  Future<int> insertTrade(Trade trade) async {
    final db = await database;
    final data = trade.toMap()..remove('id');
    return db.insert('trades', data);
  }

  Future<List<Trade>> getTrades({int? projectId}) async {
    final db = await database;
    final rows = await db.query(
      'trades',
      where: projectId == null ? null : 'project_id = ?',
      whereArgs: projectId == null ? null : [projectId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Trade.fromMap).toList();
  }

  Future<int> deleteTrade(int id) async {
    final db = await database;
    return db.delete('trades', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> closeTrade({
    required Trade trade,
    required double exit,
    required double fee,
    required double fundingFee,
    required String exitNote,
    required String reviewNote,
  }) async {
    final db = await database;
    final project = await getProject(trade.projectId);
    if (project == null) throw StateError('프로젝트를 찾을 수 없습니다.');

    final result = TradeCalculator.calculate(
      direction: trade.direction,
      entry: trade.entry,
      exit: exit,
      leverage: trade.leverage,
      margin: trade.margin,
      fee: fee,
      fundingFee: fundingFee,
    );

    await db.transaction((txn) async {
      await txn.update(
        'trades',
        {
          'exit': exit,
          'fee': fee,
          'funding_fee': fundingFee,
          'price_return_percent': result.priceReturnPercent,
          'leveraged_return_percent': result.leveragedReturnPercent,
          'gross_pnl': result.grossPnl,
          'net_pnl': result.netPnl,
          'exit_note': exitNote,
          'review_note': reviewNote,
          'status': 'CLOSED',
          'closed_at': DateTime.now().toIso8601String(),
          'sync_status': 'LOCAL_PENDING',
        },
        where: 'id = ?',
        whereArgs: [trade.id],
      );

      await txn.update(
        'projects',
        {
          'current_balance': project.currentBalance + result.netPnl,
          'loss_streak':
              result.netPnl < 0 ? project.lossStreak + 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [project.id],
      );
    });
  }

  Future<double> getProjectClosedNetPnl(int projectId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(net_pnl), 0) AS total
      FROM trades
      WHERE project_id = ? AND status = 'CLOSED'
      ''',
      [projectId],
    );
    return (rows.first['total'] as num).toDouble();
  }

  Future<int> getProjectOpenTradeCount(int projectId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM trades
      WHERE project_id = ? AND status = 'OPEN'
      ''',
      [projectId],
    );
    return (rows.first['total'] as num).toInt();
  }
}
