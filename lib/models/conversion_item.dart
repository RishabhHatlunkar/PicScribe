class ConversionItem {
  final int? id;
  final String imagePath;
  final String extractedText;
  final DateTime timestamp;
   final String instruction;
final String type;

  ConversionItem({
    this.id,
    required this.imagePath,
    required this.extractedText,
    required this.timestamp,
    required this.instruction,
    required this.type
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'extractedText': extractedText,
      'timestamp': timestamp.toIso8601String(),
      'instruction' : instruction,
      'type' : type,
    };
  }

   factory ConversionItem.fromMap(Map<String, dynamic> map) {
    return ConversionItem(
      id: map['id'],
      imagePath: map['imagePath'],
      extractedText: map['extractedText'],
      timestamp: DateTime.parse(map['timestamp']),
      instruction: map['instruction'] ?? "", // Default value of empty string in case null is present
      type: map['type'] ?? true
    );
  }
}