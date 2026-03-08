class GameMap {
  final String id;
  final String gameId;
  final String name;

  const GameMap({
    required this.id,
    required this.gameId,
    required this.name,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'game_id': gameId,
        'name': name,
      };

  factory GameMap.fromMap(Map<String, dynamic> map) => GameMap(
        id: map['id'] as String,
        gameId: map['game_id'] as String,
        name: map['name'] as String,
      );
}
