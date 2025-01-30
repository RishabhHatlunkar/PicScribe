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

    return openDatabase(
      path,
      version: 2, // Increased version to 2
      onCreate: _onCreateDb,
      onUpgrade: _onUpgradeDb, // Added onUpgrade handler
    );
  }

  Future<void> _onCreateDb(Database db, int version) async {
    print('Creating new database with version: $version');
    await db.execute('''
      CREATE TABLE conversion_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        imagePath TEXT NOT NULL,
        extractedText TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        instruction TEXT NOT NULL,
        type TEXT 
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

  Future<void> _onUpgradeDb(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');
    if (oldVersion < 2) {
      // Add the 'type' column if it's missing
       try {
          await db.execute('ALTER TABLE conversion_history ADD COLUMN type TEXT;');
           print('Added "type" column to conversion_history.');
      } catch(e){
         print("Error adding the column:$e");
       }
    }
  }

  Future<int> insertConversion(ConversionItem item) async {
    final db = await database;
    try {
      return await db.insert(
        'conversion_history',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
       print('Error inserting conversion: $e');
       rethrow;
    }
  }

  Future<List<ConversionItem>> getConversions() async {
     final db = await database;
     try {
       final List<Map<String, dynamic>> maps = await db.query('conversion_history', orderBy: 'timestamp DESC');
        return List.generate(maps.length, (i) {
           return ConversionItem.fromMap(maps[i]);
        });
    } catch (e) {
          print('Error getting conversions: $e');
          rethrow;
    }
  }

   Future<int> deleteConversion(int id) async {
      final db = await database;
      try {
          return await db.delete(
           'conversion_history',
             where: 'id = ?',
             whereArgs: [id],
           );
      } catch (e) {
           print('Error deleting conversion: $e');
           rethrow;
       }
  }


  Future<int> insertLearningItem(LearningItem item) async {
    final db = await database;
    try{
         return await db.insert(
          'learning_items',
           item.toMap(),
           conflictAlgorithm: ConflictAlgorithm.replace,
         );
    }
    catch (e) {
        print('Error inserting learning item: $e');
        rethrow;
    }
  }

  Future<List<LearningItem>> getLearningItems() async {
    final db = await database;
    try {
         final List<Map<String, dynamic>> maps = await db.query('learning_items', orderBy: 'id DESC');
         return List.generate(maps.length, (i) {
          return LearningItem.fromMap(maps[i]);
       });
     }  catch (e) {
        print('Error getting learning items: $e');
        rethrow;
    }
  }

    Future<int> deleteLearningItem(int id) async {
      final db = await database;
      try {
           return await db.delete(
            'learning_items',
             where: 'id = ?',
             whereArgs: [id],
            );
      } catch (e) {
        print('Error deleting learning item: $e');
        rethrow;
       }
  }
  
  Future<void> close() async {
    final db = await database;
   try {
      await db.close();
     } catch (e) {
       print("Error while closing the db : $e");
       rethrow;
     }
  }
}