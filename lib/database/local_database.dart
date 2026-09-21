import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/document_model.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('documents.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        path TEXT NOT NULL,
        type TEXT NOT NULL,
        size INTEGER NOT NULL,
        pages INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertDocument(DocumentModel document) async {
    final db = await instance.database;
    return await db.insert('documents', document.toMap());
  }

  Future<List<DocumentModel>> fetchAllDocuments() async {
    final db = await instance.database;
    final orderBy = 'created_at DESC';
    final result = await db.query('documents', orderBy: orderBy);
    return result.map((json) => DocumentModel.fromMap(json)).toList();
  }

  Future<int> updateDocument(DocumentModel document) async {
    final db = await instance.database;
    return await db.update(
      'documents',
      document.toMap(),
      where: 'id = ?',
      whereArgs: [document.id],
    );
  }

  Future<int> deleteDocument(int id) async {
    final db = await instance.database;
    return await db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await _database;
    if (db != null) {
      await db.close();
    }
  }
}
