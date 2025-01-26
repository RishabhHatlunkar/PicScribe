import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:pixelsheet/models/conversion_item.dart';
import 'package:pixelsheet/models/learning_item.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initializeDatabase();
    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'conversion_history.db');

    return openDatabase(path, version: 1, onCreate: _createDb);
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversion_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        imagePath TEXT NOT NULL,
        extractedText TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        instruction TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE learning_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        imagePath TEXT NOT NULL,
        description TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertConversion(ConversionItem item) async {
    final db = await database;
    return await db.insert(
      'conversion_history',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ConversionItem>> getConversions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('conversion_history', orderBy: 'timestamp DESC');
    return List.generate(maps.length, (i) {
      return ConversionItem.fromMap(maps[i]);
    });
  }

   Future<int> deleteConversion(int id) async {
      final db = await database;
      return db.delete(
          'conversion_history',
          where: 'id = ?',
          whereArgs: [id],
      );
  }


  Future<int> insertLearningItem(LearningItem item) async {
    final db = await database;
    return await db.insert(
      'learning_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LearningItem>> getLearningItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('learning_items', orderBy: 'id DESC');
    return List.generate(maps.length, (i) {
      return LearningItem.fromMap(maps[i]);
    });
  }

    Future<int> deleteLearningItem(int id) async {
    final db = await database;
    return db.delete(
      'learning_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}