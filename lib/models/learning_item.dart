class LearningItem {
  final int? id;
  final String imagePath;
  final String description;

  LearningItem({
    this.id,
    required this.imagePath,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'description': description,
    };
  }

  factory LearningItem.fromMap(Map<String, dynamic> map) {
    return LearningItem(
      id: map['id'],
      imagePath: map['imagePath'],
      description: map['description'],
    );
  }
}