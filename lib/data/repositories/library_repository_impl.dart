import 'dart:io';
import 'package:epubx/epubx.dart' as epub; // Dùng alias để tránh trùng tên
import 'package:injectable/injectable.dart';
import 'package:my_ebook_reader/data/datasources/local/database_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
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

    print("📂 Đang đọc ${maps.length} dòng từ DB");

    return List.generate(maps.length, (i) {
      // Dùng try-catch nhỏ ở đây để nếu 1 cuốn lỗi thì không chết cả App
      try {
        return Book(
          id: maps[i]['id'] as String,
          title: maps[i]['title'] as String,
          author: maps[i]['author'] as String? ?? "Unknown", // Xử lý null
          filePath: maps[i]['filePath'] as String,
          coverPath: maps[i]['coverPath'] as String?,
          // Ép kiểu an toàn hơn: Nếu null thì về 0.0
          progress: (maps[i]['progress'] as num?)?.toDouble() ?? 0.0,
        );
      } catch (e) {
        print("⚠️ Lỗi map dữ liệu sách index $i: $e");
        // Trả về một cuốn sách "bù nhìn" để không crash list
        return Book(
          id: "error",
          title: "Lỗi dữ liệu",
          filePath: "",
          progress: 0,
        );
      }
    });
  }

  @override
  Future<void> addBook(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception("File không tồn tại");

    String title = p.basename(filePath); // Mặc định lấy tên file
    String author = "Unknown";
    String? localCoverPath;
    double progress = 0.0;

    try {
      // 1. Cố gắng đọc file chuẩn
      final bytes = await file.readAsBytes();
      final epubBook = await epub.EpubReader.readBook(bytes);

      // 2. Nếu đọc thành công, cập nhật thông tin xịn
      title = epubBook.Title ?? title;
      author = epubBook.Author ?? author;

      // 3. LOGIC LẤY ẢNH BÌA THÔNG MINH (IMPROVED)
      List<int>? coverData;

      // Ưu tiên 1: Ảnh bìa được khai báo trong Metadata
      if (epubBook.CoverImage != null) {
        // epubx trả về Image object, ta cần encode sang PNG/JPG
        // Tuy nhiên, thường CoverImage trong epubx khá phức tạp để convert ngược lại bytes ngay.
        // Mẹo: Hầu hết các sách, ảnh bìa cũng nằm trong danh sách Images.
      }

      final images = epubBook.Content?.Images ??
          <String, epub.EpubByteContentFile>{};

      // Ưu tiên 2: Tìm file ảnh có tên chứa chữ "cover" trong danh sách ảnh
      if (images.isNotEmpty) {
        for (var key in images.keys) {
          if (key.toLowerCase().contains('cover')) {
            coverData = images[key]!.Content;
            break;
          }
        }
      }

      // Ưu tiên 3: Lấy đại cái ảnh đầu tiên tìm thấy trong sách (Còn hơn là không có)
      if (coverData == null && images.isNotEmpty) {
        coverData = images.values.first.Content;
      }

      // 4. Lưu ảnh bìa ra file riêng (Nếu tìm thấy)
      if (coverData != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final coverDir = Directory(p.join(appDir.path, 'covers'));
        if (!await coverDir.exists()) {
          await coverDir.create();
        }
        final fileName = '${const Uuid().v4()}.jpg';
        final coverFile = File(p.join(coverDir.path, fileName));
        await coverFile.writeAsBytes(coverData);
        localCoverPath = coverFile.path;
      }
    } catch (e) {
      // ⚠️ QUAN TRỌNG: NẾU FILE LỖI (RangeError, FormatError...)
      // Ta chỉ in lỗi ra để biết, nhưng KHÔNG throw exception nữa.
      // Vẫn tiếp tục chạy xuống dưới để lưu sách với thông tin cơ bản (Tên file).
      print("⚠️ File Epub không chuẩn hoặc bị lỗi cấu trúc: $e");
      print("👉 Chuyển sang chế độ Safe Mode: Lưu bằng tên file.");
    }

    // 5. LƯU VÀO DB (Dù file chuẩn hay lỗi thì vẫn chạy đoạn này)
    final newBook = Book(
      id: const Uuid().v4(),
      title: title,
      author: author,
      filePath: filePath,
      coverPath: localCoverPath,
      progress: progress,
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

    print("✅ Đã lưu sách vào Tủ: ${newBook.title}");
  }

  @override
  Future<void> deleteBook(String id) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'books',
      columns: ['coverPath', 'filePath'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final coverPath =
        rows.isNotEmpty ? rows.first['coverPath'] as String? : null;
    final filePath =
        rows.isNotEmpty ? rows.first['filePath'] as String? : null;
    if (coverPath != null && coverPath.isNotEmpty) {
      final coverFile = File(coverPath);
      if (await coverFile.exists()) {
        await coverFile.delete();
      }
    }
    if (filePath != null && filePath.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('progress_$filePath');
      final lastPath = prefs.getString('last_book_path');
      if (lastPath == filePath) {
        await prefs.remove('last_book_path');
      }
    }
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }
}
