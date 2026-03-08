import 'dart:io';

import 'package:flutter/material.dart';
import '../models/game.dart';
import '../models/game_map.dart';
import '../models/agent.dart';
import '../models/lineup.dart';
import '../models/lineup_image.dart';
import '../data/lineup_repository.dart';

class LineupProvider extends ChangeNotifier {
  final LineupRepository _repository = LineupRepository();

  List<Game> _games = [];
  List<GameMap> _maps = [];
  List<Agent> _agents = [];
  List<Lineup> _lineups = [];

  // Filter state
  String? _selectedAgentId;
  String? _selectedSide;
  String? _selectedSite;

  List<Game> get games => _games;
  List<GameMap> get maps => _maps;
  List<Agent> get agents => _agents;
  List<Lineup> get lineups => _lineups;
  String? get selectedAgentId => _selectedAgentId;
  String? get selectedSide => _selectedSide;
  String? get selectedSite => _selectedSite;

  Future<void> loadGames() async {
    _games = await _repository.getGames();
    notifyListeners();
  }

  Future<void> loadMaps(String gameId) async {
    _maps = await _repository.getMapsForGame(gameId);
    notifyListeners();
  }

  Future<void> loadAgents(String gameId) async {
    _agents = await _repository.getAgentsForGame(gameId);
    notifyListeners();
  }

  Future<void> loadLineups({
    required String gameId,
    required String mapId,
  }) async {
    _lineups = await _repository.getLineups(
      gameId: gameId,
      mapId: mapId,
      agentId: _selectedAgentId,
      side: _selectedSide,
      site: _selectedSite,
    );
    notifyListeners();
  }

  void setAgentFilter(String? agentId) {
    _selectedAgentId = agentId;
    notifyListeners();
  }

  void setSideFilter(String? side) {
    _selectedSide = side;
    notifyListeners();
  }

  void setSiteFilter(String? site) {
    _selectedSite = site;
    notifyListeners();
  }

  void clearFilters() {
    _selectedAgentId = null;
    _selectedSide = null;
    _selectedSite = null;
    notifyListeners();
  }

  Future<Agent?> getAgentById(String agentId) async {
    return await _repository.getAgentById(agentId);
  }

  Future<void> addLineup(Lineup lineup, List<LineupImage> images) async {
    await _repository.insertLineup(lineup);
    for (final image in images) {
      await _repository.insertLineupImage(image);
    }
  }

  Future<void> deleteLineup(String lineupId) async {
    // Get images before deleting from DB
    final images = await _repository.getLineupImages(lineupId);
    await _repository.deleteLineup(lineupId);
    // Delete image files from disk
    for (final img in images) {
      final file = File(img.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<List<LineupImage>> getLineupImages(String lineupId) async {
    return await _repository.getLineupImages(lineupId);
  }
}
