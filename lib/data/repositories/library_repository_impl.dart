import 'dart:io';
import 'package:epubx/epubx.dart' as epub; // Dùng alias để tránh trùng tên
import 'package:injectable/injectable.dart';
import 'package:my_ebook_reader/data/datasources/local/database_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart'; // Cần thêm package uuid nếu chưa có (flutter pub add uuid)

import '../../domain/entities/book.dart';
import '../../domain/repositories/library_repository.dart';

@LazySingleton(as: LibraryRepository)
class LibraryRepositoryImpl implements LibraryRepository {
  final DatabaseService _dbService;

  LibraryRepositoryImpl(this._dbService);

  @override
  Future<List<Book>> getBooks() async {
    final db = await _dbService.database;
    final maps = await db.query('books');

    return List.generate(maps.length, (i) {
      return Book(
        id: maps[i]['id'] as String,
        title: maps[i]['title'] as String,
        author: maps[i]['author'] as String?,
        filePath: maps[i]['filePath'] as String,
        coverPath: maps[i]['coverPath'] as String?,
        progress: (maps[i]['progress'] as num).toDouble(),
      );
    });
  }

  @override
  Future<void> addBook(String filePath) async {
    // Kiểm tra file có tồn tại không trước
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception("File không tồn tại");
    }

    try {
      final bytes = await file.readAsBytes();

      // Dòng này hay gây crash nhất nếu file epub lỗi
      final epubBook = await epub.EpubReader.readBook(bytes);

      // 2. Lấy tên sách & tác giả (Nếu null thì lấy tên file)
      final title = epubBook.Title ?? p.basename(filePath);
      final author = epubBook.Author ?? "Unknown";

      // ... (Phần xử lý ảnh bìa giữ nguyên) ...

      // 4. Lưu vào Database
      final newBook = Book(
        id: const Uuid().v4(),
        title: title,
        author: author,
        filePath: filePath,
        coverPath: null, // Tạm thời để null để test cho nhanh
      );

      final db = await _dbService.database;
      await db.insert('books', {
        'id': newBook.id,
        'title': newBook.title,
        'author': newBook.author,
        'filePath': newBook.filePath,
        'coverPath': newBook.coverPath,
        'progress': newBook.progress,
      });

      print("✅ Đã thêm sách: $title");
    } catch (e) {
      // Bắt lỗi và in ra console, không cho crash app
      print("❌ LỖI ĐỌC FILE EPUB: $e");
      // Ném lỗi ra ngoài để Bloc biết mà xử lý
      throw Exception("File sách bị lỗi định dạng, không thể mở.");
    }
  }

  @override
  Future<void> deleteBook(String id) async {
    final db = await _dbService.database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }
}
