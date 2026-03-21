import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../data/lineup_repository.dart';
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

class LineupImportResult {
  final int lineupCount;
  final int imageCount;

  const LineupImportResult({
    required this.lineupCount,
    required this.imageCount,
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
    final workDir = Directory(
      path.join(tempDir.path, 'wwqy_export_${_uuid.v4()}'),
    );
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
          final fileSize = await copiedFile.length();

          imageAssets.add({
            'id': assetId,
            'path': relativePath,
            'fileName': fileName,
            'sizeBytes': fileSize,
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

      final manifestFile = File(path.join(workDir.path, 'manifest.json'));
      await manifestFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
      );

      final fileName = 'wwqy-lineups-$gameId-${_formatTimestamp(DateTime.now())}.zip';
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

  Future<LineupImportResult> importBundleFromZip({
    required String zipPath,
  }) async {
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw Exception('导入文件不存在');
    }

    final tempDir = await getTemporaryDirectory();
    final extractDir = Directory(
      path.join(tempDir.path, 'wwqy_import_${_uuid.v4()}'),
    );
    await extractDir.create(recursive: true);

    final copiedImagePaths = <String>[];

    try {
      extractFileToDisk(zipFile.path, extractDir.path);

      final manifestFile = File(path.join(extractDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        throw Exception('导入失败，缺少 manifest.json');
      }

      final manifest = jsonDecode(await manifestFile.readAsString());
      if (manifest is! Map<String, dynamic>) {
        throw Exception('导入失败，manifest.json 格式错误');
      }

      _validateManifestHeader(manifest);

      final imageAssets = _parseImageAssets(manifest['images']);
      final lineupEntries = _parseLineups(manifest['lineups']);
      final games = await _repository.getGames();
      final mapsByGame = {
        for (final game in games) game.id: await _repository.getMapsForGame(game.id),
      };
      final agentsByGame = {
        for (final game in games) game.id: await _repository.getAgentsForGame(game.id),
      };

      final importedLineups = <Lineup>[];
      final importedImages = <LineupImage>[];

      for (final lineupEntry in lineupEntries) {
        final gameId = lineupEntry['gameId'] as String;
        final mapId = lineupEntry['mapId'] as String;
        final agentId = lineupEntry['agentId'] as String;
        final side = lineupEntry['side'] as String;
        final site = lineupEntry['site'] as String;
        final title = lineupEntry['title'] as String;
        final description = lineupEntry['description'] as String;
        final createdAt = DateTime.parse(lineupEntry['createdAt'] as String).toLocal();

        final gameExists = games.any((game) => game.id == gameId);
        if (!gameExists) {
          throw Exception('导入失败，未知游戏 ID：$gameId');
        }
        final mapExists = mapsByGame[gameId]!.any((map) => map.id == mapId);
        if (!mapExists) {
          throw Exception('导入失败，未知地图 ID：$mapId');
        }
        final agentExists = agentsByGame[gameId]!.any((agent) => agent.id == agentId);
        if (!agentExists) {
          throw Exception('导入失败，未知特工 ID：$agentId');
        }
        if (side != 'attack' && side != 'defense') {
          throw Exception('导入失败，side 仅支持 attack / defense');
        }
        if (!['A', 'B', 'C'].contains(site)) {
          throw Exception('导入失败，site 仅支持 A / B / C');
        }
        if (title.trim().isEmpty) {
          throw Exception('导入失败，标题不能为空');
        }

        final lineupId = _uuid.v4();
        final imageRefs = (lineupEntry['images'] as List)
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList()
          ..sort((a, b) => (a['sortOrder'] as int).compareTo(b['sortOrder'] as int));

        if (imageRefs.isEmpty) {
          throw Exception('导入失败，点位必须至少包含一张图片');
        }

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
          final imageId = imageRef['imageId'] as String;
          final sortOrder = imageRef['sortOrder'] as int;
          final asset = imageAssets[imageId];
          if (asset == null) {
            throw Exception('导入失败，图片引用不存在：$imageId');
          }

          final relativePath = asset['path'] as String;
          if (!relativePath.startsWith('images/') || relativePath.contains('..')) {
            throw Exception('导入失败，图片路径非法：$relativePath');
          }

          final sourceFile = File(path.join(extractDir.path, relativePath));
          if (!await sourceFile.exists()) {
            throw Exception('导入失败，缺少图片文件：$relativePath');
          }

          final copiedFile = await ImageHelper.copyImageToAppDir(sourceFile);
          copiedImagePaths.add(copiedFile.path);

          importedImages.add(
            LineupImage(
              id: _uuid.v4(),
              lineupId: lineupId,
              imagePath: copiedFile.path,
              sortOrder: sortOrder,
            ),
          );
        }
      }

      await _repository.insertLineupsWithImages(importedLineups, importedImages);

      return LineupImportResult(
        lineupCount: importedLineups.length,
        imageCount: importedImages.length,
      );
    } catch (e) {
      for (final imagePath in copiedImagePaths.toSet()) {
        await ImageHelper.deleteImage(imagePath);
      }
      rethrow;
    } finally {
      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
    }
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
    for (final raw in (rawImages as List)) {
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

  String _formatTimestamp(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$year$month$day-$hour$minute$second';
  }
}
