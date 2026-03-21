import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wwqy_app/data/database_helper.dart';
import 'package:wwqy_app/data/lineup_repository.dart';
import 'package:wwqy_app/models/lineup.dart';
import 'package:wwqy_app/models/lineup_image.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late LineupRepository repo;

  setUp(() async {
    DatabaseHelper.resetForTest();
    repo = LineupRepository();
    await repo.getGames();
  });

  tearDownAll(() {
    DatabaseHelper.restoreAfterTest();
  });

  group('getGames', () {
    test('返回预置游戏列表', () async {
      final games = await repo.getGames();
      expect(games, isNotEmpty);
      expect(games.any((g) => g.id == 'valorant'), isTrue);
    });
  });

  group('getMapsForGame', () {
    test('返回 valorant 地图', () async {
      final maps = await repo.getMapsForGame('valorant');
      expect(maps.length, greaterThan(0));
      expect(maps.any((m) => m.id == 'bind'), isTrue);
    });

    test('不存在的游戏返回空列表', () async {
      final maps = await repo.getMapsForGame('nonexistent');
      expect(maps, isEmpty);
    });
  });

  group('getAgentsForGame', () {
    test('返回 valorant 特工', () async {
      final agents = await repo.getAgentsForGame('valorant');
      expect(agents.length, greaterThan(0));
      expect(agents.any((a) => a.id == 'brimstone'), isTrue);
    });

    test('特工包含 role 字段', () async {
      final agents = await repo.getAgentsForGame('valorant');
      for (final agent in agents) {
        expect(agent.role, isNotEmpty);
      }
    });
  });

  group('insertLineup / getLineups', () {
    test('插入后可查询到', () async {
      final lineup = _makeLineup('test-1');
      await repo.insertLineup(lineup);

      final results = await repo.getLineups(
        gameId: 'valorant',
        mapId: 'bind',
      );
      expect(results.any((l) => l.id == 'test-1'), isTrue);
    });

    test('按 agentId 筛选', () async {
      await repo.insertLineup(_makeLineup('a1', agentId: 'brimstone'));
      await repo.insertLineup(_makeLineup('a2', agentId: 'viper'));

      final results = await repo.getLineups(
        gameId: 'valorant',
        mapId: 'bind',
        agentId: 'brimstone',
      );
      expect(results.every((l) => l.agentId == 'brimstone'), isTrue);
    });

    test('按 side 筛选', () async {
      await repo.insertLineup(_makeLineup('s1', side: 'attack'));
      await repo.insertLineup(_makeLineup('s2', side: 'defense'));

      final results = await repo.getLineups(
        gameId: 'valorant',
        mapId: 'bind',
        side: 'attack',
      );
      expect(results.every((l) => l.side == 'attack'), isTrue);
    });

    test('按 site 筛选', () async {
      await repo.insertLineup(_makeLineup('site1', site: 'A'));
      await repo.insertLineup(_makeLineup('site2', site: 'B'));

      final results = await repo.getLineups(
        gameId: 'valorant',
        mapId: 'bind',
        site: 'A',
      );
      expect(results.every((l) => l.site == 'A'), isTrue);
    });
  });

  group('getLineupsForGame', () {
    test('返回该游戏所有地图的点位', () async {
      await repo.insertLineup(_makeLineup('g1', mapId: 'bind'));
      await repo.insertLineup(_makeLineup('g2', mapId: 'split'));

      final results = await repo.getLineupsForGame('valorant');
      expect(results.any((l) => l.id == 'g1'), isTrue);
      expect(results.any((l) => l.id == 'g2'), isTrue);
    });
  });

  group('updateLineup', () {
    test('更新标题与特工', () async {
      final lineup = _makeLineup('upd-1', title: '原标题');
      await repo.insertLineup(lineup);
      await repo.insertLineupImage(_makeImage('img-1', 'upd-1'));

      final updated = Lineup(
        id: 'upd-1',
        gameId: lineup.gameId,
        mapId: lineup.mapId,
        agentId: 'viper',
        side: lineup.side,
        site: lineup.site,
        title: '新标题',
        description: lineup.description,
        createdAt: lineup.createdAt,
      );
      final newImage = _makeImage('img-2', 'upd-1', path: '/new/img.jpg');
      await repo.updateLineup(updated, [newImage]);

      final results = await repo.getLineups(gameId: 'valorant', mapId: 'bind');
      final found = results.firstWhere((l) => l.id == 'upd-1');
      expect(found.title, '新标题');
      expect(found.agentId, 'viper');

      final images = await repo.getLineupImages('upd-1');
      expect(images.length, 1);
      expect(images.first.id, 'img-2');
    });

    test('更新后旧图片记录被替换', () async {
      final lineup = _makeLineup('upd-2');
      await repo.insertLineup(lineup);
      await repo.insertLineupImage(_makeImage('old-img', 'upd-2'));

      await repo.updateLineup(lineup, [_makeImage('new-img', 'upd-2')]);

      final images = await repo.getLineupImages('upd-2');
      expect(images.any((i) => i.id == 'old-img'), isFalse);
      expect(images.any((i) => i.id == 'new-img'), isTrue);
    });
  });

  group('deleteLineup', () {
    test('删除后查询不到', () async {
      await repo.insertLineup(_makeLineup('del-1'));
      await repo.deleteLineup('del-1');

      final results = await repo.getLineups(gameId: 'valorant', mapId: 'bind');
      expect(results.any((l) => l.id == 'del-1'), isFalse);
    });

    test('删除点位时同步删除图片记录', () async {
      await repo.insertLineup(_makeLineup('del-2'));
      await repo.insertLineupImage(_makeImage('img-del', 'del-2'));
      await repo.deleteLineup('del-2');

      final images = await repo.getLineupImages('del-2');
      expect(images, isEmpty);
    });
  });

  group('insertLineupsWithImages', () {
    test('批量插入点位与图片', () async {
      final lineups = [_makeLineup('batch-1'), _makeLineup('batch-2')];
      final images = [
        _makeImage('bimg-1', 'batch-1'),
        _makeImage('bimg-2', 'batch-2'),
      ];
      await repo.insertLineupsWithImages(lineups, images);

      final results = await repo.getLineupsForGame('valorant');
      expect(results.any((l) => l.id == 'batch-1'), isTrue);
      expect(results.any((l) => l.id == 'batch-2'), isTrue);

      final imgs1 = await repo.getLineupImages('batch-1');
      expect(imgs1.any((i) => i.id == 'bimg-1'), isTrue);
    });
  });

  group('getFirstImageByLineupIds', () {
    test('返回每个点位的第一张图', () async {
      await repo.insertLineup(_makeLineup('fi-1'));
      await repo.insertLineupImage(_makeImage('fi-img-1', 'fi-1', sortOrder: 0));
      await repo.insertLineupImage(_makeImage('fi-img-2', 'fi-1', sortOrder: 1));

      final result = await repo.getFirstImageByLineupIds(['fi-1']);
      expect(result['fi-1'], '/fake/img.jpg');
    });

    test('空列表返回空 map', () async {
      final result = await repo.getFirstImageByLineupIds([]);
      expect(result, isEmpty);
    });
  });

  group('getLineupCountByMap', () {
    test('返回各地图点位数量', () async {
      await repo.insertLineup(_makeLineup('cnt-1', mapId: 'bind'));
      await repo.insertLineup(_makeLineup('cnt-2', mapId: 'bind'));
      await repo.insertLineup(_makeLineup('cnt-3', mapId: 'split'));

      final counts = await repo.getLineupCountByMap('valorant');
      expect(counts['bind'], greaterThanOrEqualTo(2));
      expect(counts['split'], greaterThanOrEqualTo(1));
    });
  });
}

Lineup _makeLineup(
  String id, {
  String mapId = 'bind',
  String agentId = 'brimstone',
  String side = 'attack',
  String site = 'A',
  String title = '测试点位',
}) =>
    Lineup(
      id: id,
      gameId: 'valorant',
      mapId: mapId,
      agentId: agentId,
      side: side,
      site: site,
      title: title,
      description: '',
      createdAt: DateTime(2026, 1, 1),
    );

LineupImage _makeImage(
  String id,
  String lineupId, {
  String path = '/fake/img.jpg',
  int sortOrder = 0,
}) =>
    LineupImage(
      id: id,
      lineupId: lineupId,
      imagePath: path,
      sortOrder: sortOrder,
    );
