import '../models/game.dart';
import '../models/game_map.dart';
import '../models/agent.dart';

class PresetData {
  static const String valorantId = 'valorant';

  static const Game valorant = Game(id: valorantId, name: '无畏契约');

  static const List<Game> games = [valorant];

  static const List<GameMap> valorantMaps = [
    GameMap(id: 'bind', gameId: valorantId, name: '源工重镇'),
    GameMap(id: 'split', gameId: valorantId, name: '霓虹町'),
    GameMap(id: 'ascent', gameId: valorantId, name: '亚海悬城'),
    GameMap(id: 'icebox', gameId: valorantId, name: '森寒冬港'),
    GameMap(id: 'breeze', gameId: valorantId, name: '微风岛屿'),
    GameMap(id: 'fracture', gameId: valorantId, name: '裂变峡谷'),
    GameMap(id: 'haven', gameId: valorantId, name: '隐世修所'),
    GameMap(id: 'pearl', gameId: valorantId, name: '深海明珠'),
    GameMap(id: 'lotus', gameId: valorantId, name: '莲华古城'),
    GameMap(id: 'sunset', gameId: valorantId, name: '日落之城'),
    GameMap(id: 'abyss', gameId: valorantId, name: '幽邃地窟'),
    GameMap(id: 'corrode', gameId: valorantId, name: '盐海矿镇'),
  ];

  static const List<Agent> valorantAgents = [
    // 决斗者
    Agent(id: 'jett', gameId: valorantId, name: '捷风', role: '决斗者'),
    Agent(id: 'phoenix', gameId: valorantId, name: '不死鸟', role: '决斗者'),
    Agent(id: 'reyna', gameId: valorantId, name: '芮娜', role: '决斗者'),
    Agent(id: 'raze', gameId: valorantId, name: '雷兹', role: '决斗者'),
    Agent(id: 'yoru', gameId: valorantId, name: '夜露', role: '决斗者'),
    Agent(id: 'neon', gameId: valorantId, name: '霓虹', role: '决斗者'),
    Agent(id: 'iso', gameId: valorantId, name: '壹决', role: '决斗者'),
    Agent(id: 'waylay', gameId: valorantId, name: '幻棱', role: '决斗者'),
    // 先锋
    Agent(id: 'sova', gameId: valorantId, name: '猎枭', role: '先锋'),
    Agent(id: 'breach', gameId: valorantId, name: '铁臂', role: '先锋'),
    Agent(id: 'skye', gameId: valorantId, name: '斯凯', role: '先锋'),
    Agent(id: 'kayo', gameId: valorantId, name: 'K/O', role: '先锋'),
    Agent(id: 'fade', gameId: valorantId, name: '黑梦', role: '先锋'),
    Agent(id: 'gekko', gameId: valorantId, name: '盖可', role: '先锋'),
    Agent(id: 'tejo', gameId: valorantId, name: '钛狐', role: '先锋'),
    // 控场者
    Agent(id: 'viper', gameId: valorantId, name: '蝰蛇', role: '控场者'),
    Agent(id: 'brimstone', gameId: valorantId, name: '炼狱', role: '控场者'),
    Agent(id: 'omen', gameId: valorantId, name: '幽影', role: '控场者'),
    Agent(id: 'astra', gameId: valorantId, name: '星礈', role: '控场者'),
    Agent(id: 'harbor', gameId: valorantId, name: '海神', role: '控场者'),
    Agent(id: 'clove', gameId: valorantId, name: '暮蝶', role: '控场者'),
    // 哨卫
    Agent(id: 'sage', gameId: valorantId, name: '贤者', role: '哨卫'),
    Agent(id: 'cypher', gameId: valorantId, name: '零', role: '哨卫'),
    Agent(id: 'killjoy', gameId: valorantId, name: '奇乐', role: '哨卫'),
    Agent(id: 'chamber', gameId: valorantId, name: '尚勃勒', role: '哨卫'),
    Agent(id: 'deadlock', gameId: valorantId, name: '钢锁', role: '哨卫'),
    Agent(id: 'vyse', gameId: valorantId, name: '维斯', role: '哨卫'),
    Agent(id: 'veto', gameId: valorantId, name: '禁灭', role: '哨卫'),
  ];

  static List<GameMap> getMapsForGame(String gameId) {
    if (gameId == valorantId) return valorantMaps;
    return [];
  }

  static List<Agent> getAgentsForGame(String gameId) {
    if (gameId == valorantId) return valorantAgents;
    return [];
  }
}
