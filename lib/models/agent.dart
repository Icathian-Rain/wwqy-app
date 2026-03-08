class Agent {
  final String id;
  final String gameId;
  final String name;
  final String role;

  const Agent({
    required this.id,
    required this.gameId,
    required this.name,
    required this.role,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'game_id': gameId,
        'name': name,
        'role': role,
      };

  factory Agent.fromMap(Map<String, dynamic> map) => Agent(
        id: map['id'] as String,
        gameId: map['game_id'] as String,
        name: map['name'] as String,
        role: map['role'] as String,
      );
}
