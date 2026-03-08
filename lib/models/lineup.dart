class Lineup {
  final String id;
  final String gameId;
  final String mapId;
  final String agentId;
  final String side;
  final String site;
  final String title;
  final String description;
  final DateTime createdAt;

  const Lineup({
    required this.id,
    required this.gameId,
    required this.mapId,
    required this.agentId,
    required this.side,
    required this.site,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'game_id': gameId,
        'map_id': mapId,
        'agent_id': agentId,
        'side': side,
        'site': site,
        'title': title,
        'description': description,
        'created_at': createdAt.toIso8601String(),
      };

  factory Lineup.fromMap(Map<String, dynamic> map) => Lineup(
        id: map['id'] as String,
        gameId: map['game_id'] as String,
        mapId: map['map_id'] as String,
        agentId: map['agent_id'] as String,
        side: map['side'] as String,
        site: map['site'] as String,
        title: map['title'] as String,
        description: map['description'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
