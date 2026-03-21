import 'dart:io';

import 'package:flutter/material.dart';
import '../models/game.dart';
import '../models/game_map.dart';
import '../models/agent.dart';
import '../models/lineup.dart';
import '../models/lineup_image.dart';
import '../data/lineup_repository.dart';
import '../services/lineup_transfer_service.dart';
import '../utils/image_helper.dart';

class LineupProvider extends ChangeNotifier {
  final LineupRepository _repository = LineupRepository();
  late final LineupTransferService _transferService =
      LineupTransferService(repository: _repository);

  List<Game> _games = [];
  List<GameMap> _maps = [];
  List<Agent> _agents = [];
  List<Lineup> _lineups = [];
  Map<String, int> _mapLineupCounts = {};
  Map<String, String> _lineupFirstImages = {};
  bool _loading = false;
  String? _error;

  String? _selectedAgentId;
  String? _selectedSide;
  String? _selectedSite;

  List<Game> get games => _games;
  List<GameMap> get maps => _maps;
  List<Agent> get agents => _agents;
  List<Lineup> get lineups => _lineups;
  Map<String, int> get mapLineupCounts => _mapLineupCounts;
  Map<String, String> get lineupFirstImages => _lineupFirstImages;
  bool get loading => _loading;
  String? get error => _error;
  String? get selectedAgentId => _selectedAgentId;
  String? get selectedSide => _selectedSide;
  String? get selectedSite => _selectedSite;

  Future<void> loadGames() async {
    _games = await _repository.getGames();
    notifyListeners();
  }

  Future<void> loadMaps(String gameId) async {
    _maps = await _repository.getMapsForGame(gameId);
    _mapLineupCounts = await _repository.getLineupCountByMap(gameId);
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
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _lineups = await _repository.getLineups(
        gameId: gameId,
        mapId: mapId,
        agentId: _selectedAgentId,
        side: _selectedSide,
        site: _selectedSite,
      );
      _lineupFirstImages = await _repository.getFirstImageByLineupIds(
        _lineups.map((lineup) => lineup.id).toList(),
      );
    } catch (e) {
      _error = '加载点位失败：$e';
    } finally {
      _loading = false;
      notifyListeners();
    }
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
    return _repository.getAgentById(agentId);
  }

  Future<void> addLineup(Lineup lineup, List<LineupImage> images) async {
    try {
      await _repository.insertLineup(lineup);
      for (final image in images) {
        await _repository.insertLineupImage(image);
      }
    } catch (e) {
      throw Exception('保存点位失败：$e');
    }
  }

  Future<void> updateLineup(
    Lineup lineup,
    List<LineupImage> images,
    List<String> removedImagePaths,
  ) async {
    try {
      await _repository.updateLineup(lineup, images);
      for (final imagePath in removedImagePaths.toSet()) {
        await ImageHelper.deleteImage(imagePath);
      }
    } catch (e) {
      throw Exception('更新点位失败：$e');
    }
  }

  Future<LineupExportResult> exportLineupsForGame(
    String gameId,
    String gameName,
  ) async {
    try {
      return await _transferService.exportGameBundle(
        gameId: gameId,
        gameName: gameName,
      );
    } catch (e) {
      throw Exception('导出点位失败：$e');
    }
  }

  Future<void> shareExportedBundle(String zipPath) async {
    try {
      await _transferService.shareExportedBundle(zipPath);
    } catch (e) {
      throw Exception('分享导出文件失败：$e');
    }
  }

  Future<LineupImportPreview> previewImportFromZip(String zipPath) async {
    try {
      return await _transferService.previewBundleFromZip(zipPath: zipPath);
    } catch (e) {
      throw Exception('预检导入包失败：$e');
    }
  }

  Future<LineupImportResult> importLineupsFromZip(
    String zipPath, {
    bool skipDuplicates = false,
  }) async {
    try {
      return await _transferService.importBundleFromZip(
        zipPath: zipPath,
        skipDuplicates: skipDuplicates,
      );
    } catch (e) {
      throw Exception('导入点位失败：$e');
    }
  }

  Future<void> deleteLineup(String lineupId) async {
    try {
      final images = await _repository.getLineupImages(lineupId);
      await _repository.deleteLineup(lineupId);
      for (final image in images) {
        final file = File(image.imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      throw Exception('删除点位失败：$e');
    }
  }

  Future<List<LineupImage>> getLineupImages(String lineupId) async {
    return _repository.getLineupImages(lineupId);
  }
}
