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
    // 1. Đọc file epub để lấy thông tin
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final epubBook = await epub.EpubReader.readBook(bytes);

    // 2. Lấy tên sách & tác giả
    final title = epubBook.Title ?? p.basename(filePath);
    final author = epubBook.Author;

    // 3. Trích xuất và lưu ảnh bìa (Nếu có)
    String? localCoverPath;
    if (epubBook.CoverImage != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final coverDir = Directory(p.join(appDir.path, 'covers'));
      if (!await coverDir.exists()) {
        await coverDir.create();
      }

      final fileName = '${const Uuid().v4()}.jpg';
      final coverFile = File(p.join(coverDir.path, fileName));

      // Convert Image object của thư viện epubx sang bytes và lưu
      // Lưu ý: epubx trả về Image package, cần encode lại,
      // nhưng để đơn giản ta sẽ lưu bytes thô nếu thư viện hỗ trợ hoặc bỏ qua bước encode phức tạp tạm thời.
      // *Mẹo*: Thường cover image trong epubx là danh sách bytes sẵn.
      // Ở đây tôi giả định xử lý đơn giản, nếu phức tạp ta sẽ chỉnh sau.
      // (Đoạn này tạm thời để null coverPath nếu chưa xử lý ảnh sâu)
    }

    // 4. Lưu vào Database
    final newBook = Book(
      id: const Uuid().v4(),
      title: title,
      author: author,
      filePath: filePath,
      coverPath: localCoverPath,
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
  }

  @override
  Future<void> deleteBook(String id) async {
    final db = await _dbService.database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }
}
