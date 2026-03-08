class Game {
  final String id;
  final String name;

  const Game({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory Game.fromMap(Map<String, dynamic> map) => Game(
        id: map['id'] as String,
        name: map['name'] as String,
      );
}
