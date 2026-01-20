import 'dart:io';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

@lazySingleton // Để DI tự khởi tạo 1 lần duy nhất
class DatabaseService {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    // Cấu hình cho Windows
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbFolder = await getApplicationDocumentsDirectory();
    final path = join(dbFolder.path, 'ebook_reader.db');
    print("📍 DATABASE PATH: $path");
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tạo bảng Books
        await db.execute('''
          CREATE TABLE books(
            id TEXT PRIMARY KEY,
            title TEXT,
            author TEXT,
            filePath TEXT,
            coverPath TEXT,
            progress REAL
          )
        ''');
      },
    );
  }
}
