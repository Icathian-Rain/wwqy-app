class LineupImage {
  final String id;
  final String lineupId;
  final String imagePath;
  final int sortOrder;

  const LineupImage({
    required this.id,
    required this.lineupId,
    required this.imagePath,
    required this.sortOrder,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'lineup_id': lineupId,
        'image_path': imagePath,
        'sort_order': sortOrder,
      };

  factory LineupImage.fromMap(Map<String, dynamic> map) => LineupImage(
        id: map['id'] as String,
        lineupId: map['lineup_id'] as String,
        imagePath: map['image_path'] as String,
        sortOrder: map['sort_order'] as int,
      );
}
