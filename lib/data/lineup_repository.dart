import '../models/game.dart';
import '../models/game_map.dart';
import '../models/agent.dart';
import '../models/lineup.dart';
import '../models/lineup_image.dart';
import 'database_helper.dart';

class LineupRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // --- Games ---
  Future<List<Game>> getGames() async {
    final db = await _dbHelper.database;
    final maps = await db.query('games');
    return maps.map((m) => Game.fromMap(m)).toList();
  }

  // --- Maps ---
  Future<List<GameMap>> getMapsForGame(String gameId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('maps', where: 'game_id = ?', whereArgs: [gameId]);
    return maps.map((m) => GameMap.fromMap(m)).toList();
  }

  // --- Agents ---
  Future<List<Agent>> getAgentsForGame(String gameId) async {
    final db = await _dbHelper.database;
    final agents = await db.query('agents', where: 'game_id = ?', whereArgs: [gameId]);
    return agents.map((m) => Agent.fromMap(m)).toList();
  }

  Future<Agent?> getAgentById(String agentId) async {
    final db = await _dbHelper.database;
    final results = await db.query('agents', where: 'id = ?', whereArgs: [agentId]);
    if (results.isEmpty) return null;
    return Agent.fromMap(results.first);
  }

  // --- Lineups ---
  Future<List<Lineup>> getLineups({
    required String gameId,
    required String mapId,
    String? agentId,
    String? side,
    String? site,
  }) async {
    final db = await _dbHelper.database;
    final where = StringBuffer('game_id = ? AND map_id = ?');
    final whereArgs = <dynamic>[gameId, mapId];

    if (agentId != null) {
      where.write(' AND agent_id = ?');
      whereArgs.add(agentId);
    }
    if (side != null) {
      where.write(' AND side = ?');
      whereArgs.add(side);
    }
    if (site != null) {
      where.write(' AND site = ?');
      whereArgs.add(site);
    }

    final results = await db.query(
      'lineups',
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return results.map((m) => Lineup.fromMap(m)).toList();
  }

  Future<void> insertLineup(Lineup lineup) async {
    final db = await _dbHelper.database;
    await db.insert('lineups', lineup.toMap());
  }

  Future<void> deleteLineup(String lineupId) async {
    final db = await _dbHelper.database;
    // Delete associated images first
    await db.delete('lineup_images', where: 'lineup_id = ?', whereArgs: [lineupId]);
    await db.delete('lineups', where: 'id = ?', whereArgs: [lineupId]);
  }

  // --- Lineup Images ---
  Future<List<LineupImage>> getLineupImages(String lineupId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'lineup_images',
      where: 'lineup_id = ?',
      whereArgs: [lineupId],
      orderBy: 'sort_order ASC',
    );
    return results.map((m) => LineupImage.fromMap(m)).toList();
  }

  Future<void> insertLineupImage(LineupImage image) async {
    final db = await _dbHelper.database;
    await db.insert('lineup_images', image.toMap());
  }
}
