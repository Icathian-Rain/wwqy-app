import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'preset_data.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'wwqy_app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE games (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE maps (
        id TEXT PRIMARY KEY,
        game_id TEXT NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (game_id) REFERENCES games (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE agents (
        id TEXT PRIMARY KEY,
        game_id TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        FOREIGN KEY (game_id) REFERENCES games (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE lineups (
        id TEXT PRIMARY KEY,
        game_id TEXT NOT NULL,
        map_id TEXT NOT NULL,
        agent_id TEXT NOT NULL,
        side TEXT NOT NULL,
        site TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (game_id) REFERENCES games (id),
        FOREIGN KEY (map_id) REFERENCES maps (id),
        FOREIGN KEY (agent_id) REFERENCES agents (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE lineup_images (
        id TEXT PRIMARY KEY,
        lineup_id TEXT NOT NULL,
        image_path TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        FOREIGN KEY (lineup_id) REFERENCES lineups (id) ON DELETE CASCADE
      )
    ''');

    // Insert preset data
    await _insertPresetData(db);
  }

  Future<void> _insertPresetData(Database db) async {
    for (final game in PresetData.games) {
      await db.insert('games', game.toMap());
    }
    for (final map in PresetData.valorantMaps) {
      await db.insert('maps', map.toMap());
    }
    for (final agent in PresetData.valorantAgents) {
      await db.insert('agents', agent.toMap());
    }
  }
}
