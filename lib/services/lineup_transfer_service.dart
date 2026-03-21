import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../data/lineup_repository.dart';
import '../models/game_map.dart';
import '../models/lineup.dart';
import '../models/lineup_image.dart';
import '../utils/image_helper.dart';

class LineupExportResult {
  final String zipPath;
  final int lineupCount;
  final int imageCount;

  const LineupExportResult({
    required this.zipPath,
    required this.lineupCount,
    required this.imageCount,
  });
}

class LineupImportPreview {
  final int lineupCount;
  final int imageCount;
  final int duplicateCount;
  final List<String> mapNames;
  final List<String> warnings;
  final List<String> blockingIssues;

  const LineupImportPreview({
    required this.lineupCount,
    required this.imageCount,
    required this.duplicateCount,
    required this.mapNames,
    required this.warnings,
    required this.blockingIssues,
  });

  bool get canImport => blockingIssues.isEmpty && lineupCount > 0;
}

class LineupImportResult {
  final int lineupCount;
  final int imageCount;
  final int skippedLineupCount;

  const LineupImportResult({
    required this.lineupCount,
    required this.imageCount,
    required this.skippedLineupCount,
  });
}

class LineupTransferService {
  LineupTransferService({LineupRepository? repository})
      : _repository = repository ?? LineupRepository();

  final LineupRepository _repository;
  final Uuid _uuid = const Uuid();

  Future<LineupExportResult> exportGameBundle({
    required String gameId,
    required String gameName,
  }) async {
    final lineups = await _repository.getLineupsForGame(gameId);
    if (lineups.isEmpty) {
      throw Exception('当前游戏暂无可导出的点位');
    }

    final tempDir = await getTemporaryDirectory();
    final workDir = Directory(path.join(tempDir.path, 'wwqy_export_${_uuid.v4()}'));
    final imagesDir = Directory(path.join(workDir.path, 'images'));
    await imagesDir.create(recursive: true);

    try {
      final imageAssets = <Map<String, dynamic>>[];
      final lineupPayloads = <Map<String, dynamic>>[];
      var totalImageCount = 0;

      for (final lineup in lineups) {
        final lineupImages = await _repository.getLineupImages(lineup.id);
        if (lineupImages.isEmpty) {
          continue;
        }

        final imageRefs = <Map<String, dynamic>>[];
        for (final image in lineupImages) {
          final sourceFile = File(image.imagePath);
          if (!await sourceFile.exists()) {
            throw Exception('导出失败，图片不存在：${image.imagePath}');
          }

          final assetId = _uuid.v4();
          final ext = path.extension(sourceFile.path);
          final fileName = '$assetId$ext';
          final relativePath = path.join('images', fileName).replaceAll('\\', '/');
          final copiedFile = await sourceFile.copy(path.join(imagesDir.path, fileName));

          imageAssets.add({
            'id': assetId,
            'path': relativePath,
            'fileName': fileName,
            'sizeBytes': await copiedFile.length(),
          });
          imageRefs.add({
            'imageId': assetId,
            'sortOrder': image.sortOrder,
          });
          totalImageCount++;
        }

        lineupPayloads.add({
          'id': lineup.id,
          'gameId': lineup.gameId,
          'mapId': lineup.mapId,
          'agentId': lineup.agentId,
          'side': lineup.side,
          'site': lineup.site,
          'title': lineup.title,
          'description': lineup.description,
          'createdAt': lineup.createdAt.toUtc().toIso8601String(),
          'images': imageRefs,
        });
      }

      if (lineupPayloads.isEmpty) {
        throw Exception('当前游戏暂无可导出的有效点位');
      }

      final manifest = {
        'format': 'wwqy.lineup-bundle',
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'lineups': lineupPayloads,
        'images': imageAssets,
      };

      await File(path.join(workDir.path, 'manifest.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
      );

      final safeGameName = _safeFileSegment(gameName.isEmpty ? gameId : gameName);
      final fileName = 'wwqy-lineups-$safeGameName-${_formatTimestamp(DateTime.now())}.zip';
      final zipPath = path.join(tempDir.path, fileName);
      final encoder = ZipFileEncoder();
      encoder.zipDirectory(workDir, filename: zipPath);

      return LineupExportResult(
        zipPath: zipPath,
        lineupCount: lineupPayloads.length,
        imageCount: totalImageCount,
      );
    } finally {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
    }
  }

  Future<void> shareExportedBundle(String zipPath) async {
    await Share.shareXFiles([XFile(zipPath)]);
  }

  Future<LineupImportPreview> previewBundleFromZip({
    required String zipPath,
  }) async {
    final prepared = await _prepareBundle(zipPath);
    try {
      return prepared.preview;
    } finally {
      if (await prepared.extractDir.exists()) {
        await prepared.extractDir.delete(recursive: true);
      }
    }
  }

  Future<LineupImportResult> importBundleFromZip({
    required String zipPath,
    bool skipDuplicates = false,
  }) async {
    final prepared = await _prepareBundle(zipPath);
    final copiedImagePaths = <String>[];

    try {
      if (!prepared.preview.canImport) {
        throw Exception(prepared.preview.blockingIssues.join('\n'));
      }

      final importedLineups = <Lineup>[];
      final importedImages = <LineupImage>[];
      final seenImportedSignatures = <String>{};
      var skippedLineupCount = 0;

      for (final lineupEntry in prepared.lineupEntries) {
        final gameId = lineupEntry['gameId'] as String;
        final mapId = lineupEntry['mapId'] as String;
        final agentId = lineupEntry['agentId'] as String;
        final side = lineupEntry['side'] as String;
        final site = lineupEntry['site'] as String;
        final title = lineupEntry['title'] as String;
        final description = lineupEntry['description'] as String;
        final createdAt = DateTime.parse(lineupEntry['createdAt'] as String).toLocal();
        final signature = _buildLineupSignature(
          gameId: gameId,
          mapId: mapId,
          agentId: agentId,
          side: side,
          site: site,
          title: title,
          description: description,
        );

        if (skipDuplicates &&
            (prepared.existingSignatures.contains(signature) ||
                seenImportedSignatures.contains(signature))) {
          skippedLineupCount++;
          continue;
        }

        seenImportedSignatures.add(signature);
        final lineupId = _uuid.v4();
        final imageRefs = (lineupEntry['images'] as List)
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList()
          ..sort((a, b) => (a['sortOrder'] as int).compareTo(b['sortOrder'] as int));

        importedLineups.add(
          Lineup(
            id: lineupId,
            gameId: gameId,
            mapId: mapId,
            agentId: agentId,
            side: side,
            site: site,
            title: title,
            description: description,
            createdAt: createdAt,
          ),
        );

        for (final imageRef in imageRefs) {
          final asset = prepared.imageAssets[imageRef['imageId'] as String]!;
          final sourceFile = File(path.join(prepared.extractDir.path, asset['path'] as String));
          final copiedFile = await ImageHelper.copyImageToAppDir(sourceFile);
          copiedImagePaths.add(copiedFile.path);

          importedImages.add(
            LineupImage(
              id: _uuid.v4(),
              lineupId: lineupId,
              imagePath: copiedFile.path,
              sortOrder: imageRef['sortOrder'] as int,
            ),
          );
        }
      }

      if (importedLineups.isNotEmpty) {
        await _repository.insertLineupsWithImages(importedLineups, importedImages);
      }

      return LineupImportResult(
        lineupCount: importedLineups.length,
        imageCount: importedImages.length,
        skippedLineupCount: skippedLineupCount,
      );
    } catch (e) {
      for (final imagePath in copiedImagePaths.toSet()) {
        await ImageHelper.deleteImage(imagePath);
      }
      rethrow;
    } finally {
      if (await prepared.extractDir.exists()) {
        await prepared.extractDir.delete(recursive: true);
      }
    }
  }

  Future<_PreparedBundle> _prepareBundle(String zipPath) async {
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw Exception('导入文件不存在');
    }

    final tempDir = await getTemporaryDirectory();
    final extractDir = Directory(path.join(tempDir.path, 'wwqy_import_${_uuid.v4()}'));
    await extractDir.create(recursive: true);

    extractFileToDisk(zipFile.path, extractDir.path);

    final manifestFile = File(path.join(extractDir.path, 'manifest.json'));
    if (!await manifestFile.exists()) {
      await extractDir.delete(recursive: true);
      throw Exception('导入失败，缺少 manifest.json');
    }

    final manifest = jsonDecode(await manifestFile.readAsString());
    if (manifest is! Map<String, dynamic>) {
      await extractDir.delete(recursive: true);
      throw Exception('导入失败，manifest.json 格式错误');
    }

    _validateManifestHeader(manifest);

    final imageAssets = _parseImageAssets(manifest['images']);
    final lineupEntries = _parseLineups(manifest['lineups']);
    final games = await _repository.getGames();
    final warnings = <String>[];
    final blockingIssues = <String>[];
    final mapNames = <String>{};
    final existingSignatures = <String>{};
    final seenBundleSignatures = <String>{};
    var duplicateCount = 0;
    var imageCount = 0;

    final gameIds = lineupEntries
        .map((entry) => entry['gameId'])
        .whereType<String>()
        .toSet();
    final mapsByGame = <String, List<GameMap>>{};
    final agentsByGame = <String, Set<String>>{};

    for (final gameId in gameIds) {
      final existingLineups = await _repository.getLineupsForGame(gameId);
      for (final lineup in existingLineups) {
        existingSignatures.add(
          _buildLineupSignature(
            gameId: lineup.gameId,
            mapId: lineup.mapId,
            agentId: lineup.agentId,
            side: lineup.side,
            site: lineup.site,
            title: lineup.title,
            description: lineup.description,
          ),
        );
      }
      final maps = await _repository.getMapsForGame(gameId);
      final agents = await _repository.getAgentsForGame(gameId);
      mapsByGame[gameId] = maps;
      agentsByGame[gameId] = agents.map((agent) => agent.id).toSet();
    }

    for (var index = 0; index < lineupEntries.length; index++) {
      final entry = lineupEntries[index];
      final label = '第 ${index + 1} 条点位';
      final gameId = entry['gameId'] as String?;
      final mapId = entry['mapId'] as String?;
      final agentId = entry['agentId'] as String?;
      final side = entry['side'] as String?;
      final site = entry['site'] as String?;
      final title = entry['title'] as String?;
      final description = (entry['description'] as String?) ?? '';
      final createdAt = entry['createdAt'] as String?;
      final imageRefs = entry['images'];

      if (gameId == null || gameId.isEmpty) {
        blockingIssues.add('$label 缺少 gameId');
        continue;
      }
      if (!games.any((game) => game.id == gameId)) {
        blockingIssues.add('$label 的 gameId 不存在：$gameId');
        continue;
      }
      if (mapId == null || !mapsByGame[gameId]!.any((map) => map.id == mapId)) {
        blockingIssues.add('$label 的 mapId 不存在：${mapId ?? 'null'}');
        continue;
      }
      if (agentId == null || !agentsByGame[gameId]!.contains(agentId)) {
        blockingIssues.add('$label 的 agentId 不存在：${agentId ?? 'null'}');
        continue;
      }
      if (side != 'attack' && side != 'defense') {
        blockingIssues.add('$label 的 side 非法：${side ?? 'null'}');
        continue;
      }
      if (site == null || !['A', 'B', 'C'].contains(site)) {
        blockingIssues.add('$label 的 site 非法：${site ?? 'null'}');
        continue;
      }
      if (title == null || title.trim().isEmpty) {
        blockingIssues.add('$label 的标题不能为空');
        continue;
      }
      if (createdAt == null) {
        blockingIssues.add('$label 缺少 createdAt');
        continue;
      }
      try {
        DateTime.parse(createdAt);
      } catch (_) {
        blockingIssues.add('$label 的 createdAt 格式非法');
        continue;
      }
      if (imageRefs is! List || imageRefs.isEmpty) {
        blockingIssues.add('$label 至少需要一张图片');
        continue;
      }

      final mapName = mapsByGame[gameId]!
          .firstWhere((map) => map.id == mapId)
          .name;
      mapNames.add(mapName);

      final signature = _buildLineupSignature(
        gameId: gameId,
        mapId: mapId,
        agentId: agentId,
        side: side!,
        site: site,
        title: title,
        description: description,
      );
      if (existingSignatures.contains(signature)) {
        duplicateCount++;
      }
      if (!seenBundleSignatures.add(signature)) {
        warnings.add('$label 与导入包内其他点位重复');
      }

      for (final rawImageRef in imageRefs) {
        final imageRef = Map<String, dynamic>.from(rawImageRef as Map);
        final imageId = imageRef['imageId'] as String?;
        final sortOrder = imageRef['sortOrder'];
        if (imageId == null || imageId.isEmpty) {
          blockingIssues.add('$label 存在无效图片引用');
          continue;
        }
        if (sortOrder is! int) {
          blockingIssues.add('$label 存在无效图片排序');
          continue;
        }
        final asset = imageAssets[imageId];
        if (asset == null) {
          blockingIssues.add('$label 引用了不存在的图片：$imageId');
          continue;
        }
        final relativePath = asset['path'] as String?;
        if (relativePath == null ||
            !relativePath.startsWith('images/') ||
            relativePath.contains('..')) {
          blockingIssues.add('$label 的图片路径非法：${relativePath ?? 'null'}');
          continue;
        }
        final sourceFile = File(path.join(extractDir.path, relativePath));
        if (!await sourceFile.exists()) {
          blockingIssues.add('$label 缺少图片文件：$relativePath');
          continue;
        }
        imageCount++;
      }
    }

    final preview = LineupImportPreview(
      lineupCount: lineupEntries.length,
      imageCount: imageCount,
      duplicateCount: duplicateCount,
      mapNames: mapNames.toList()..sort(),
      warnings: warnings,
      blockingIssues: blockingIssues,
    );

    return _PreparedBundle(
      extractDir: extractDir,
      imageAssets: imageAssets,
      lineupEntries: lineupEntries,
      existingSignatures: existingSignatures,
      preview: preview,
    );
  }

  void _validateManifestHeader(Map<String, dynamic> manifest) {
    if (manifest['format'] != 'wwqy.lineup-bundle') {
      throw Exception('导入失败，不支持的包格式');
    }
    if (manifest['version'] != 1) {
      throw Exception('导入失败，不支持的版本');
    }
    if (manifest['lineups'] is! List || (manifest['lineups'] as List).isEmpty) {
      throw Exception('导入失败，缺少点位数据');
    }
    if (manifest['images'] is! List || (manifest['images'] as List).isEmpty) {
      throw Exception('导入失败，缺少图片数据');
    }
  }

  Map<String, Map<String, dynamic>> _parseImageAssets(dynamic rawImages) {
    final assets = <String, Map<String, dynamic>>{};
    for (final raw in rawImages as List) {
      final image = Map<String, dynamic>.from(raw as Map);
      final id = image['id'] as String?;
      if (id == null || id.isEmpty) {
        throw Exception('导入失败，存在无效图片 ID');
      }
      if (assets.containsKey(id)) {
        throw Exception('导入失败，图片 ID 重复：$id');
      }
      assets[id] = image;
    }
    return assets;
  }

  List<Map<String, dynamic>> _parseLineups(dynamic rawLineups) {
    return (rawLineups as List)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  String _buildLineupSignature({
    required String gameId,
    required String mapId,
    required String agentId,
    required String side,
    required String site,
    required String title,
    required String description,
  }) {
    return [
      gameId,
      mapId,
      agentId,
      side,
      site,
      title.trim().toLowerCase(),
      description.trim().toLowerCase(),
    ].join('|');
  }

  String _formatTimestamp(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$year$month$day-$hour$minute$second';
  }

  String _safeFileSegment(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(' ', '_');
  }
}

class _PreparedBundle {
  final Directory extractDir;
  final Map<String, Map<String, dynamic>> imageAssets;
  final List<Map<String, dynamic>> lineupEntries;
  final Set<String> existingSignatures;
  final LineupImportPreview preview;

  const _PreparedBundle({
    required this.extractDir,
    required this.imageAssets,
    required this.lineupEntries,
    required this.existingSignatures,
    required this.preview,
  });
}
