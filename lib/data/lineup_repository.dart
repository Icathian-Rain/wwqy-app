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

  /// 返回指定点位列表中每个点位的第一张图路径，key 为 lineup_id
  Future<Map<String, String>> getFirstImageByLineupIds(List<String> lineupIds) async {
    if (lineupIds.isEmpty) return {};
    final db = await _dbHelper.database;
    final placeholders = lineupIds.map((_) => '?').join(',');
    final results = await db.rawQuery(
      'SELECT lineup_id, image_path FROM lineup_images WHERE lineup_id IN ($placeholders) GROUP BY lineup_id ORDER BY sort_order ASC',
      lineupIds,
    );
    return {for (final r in results) r['lineup_id'] as String: r['image_path'] as String};
  }

  /// 返回指定游戏下每张地图的点位数量，key 为 map_id
  Future<Map<String, int>> getLineupCountByMap(String gameId) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery(
      'SELECT map_id, COUNT(*) as cnt FROM lineups WHERE game_id = ? GROUP BY map_id',
      [gameId],
    );
    return {for (final r in results) r['map_id'] as String: r['cnt'] as int};
  }
}
