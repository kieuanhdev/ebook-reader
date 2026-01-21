import 'dart:io';
import 'package:archive/archive.dart';
import 'package:epubx/epubx.dart' as epub; // Dùng alias để tránh trùng tên
import 'package:image/image.dart' as img;
import 'package:injectable/injectable.dart';
import 'package:my_ebook_reader/data/datasources/local/database_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_pdfviewer_platform_interface/pdfviewer_platform_interface.dart';
import 'package:uuid/uuid.dart'; // Cần thêm package uuid nếu chưa có (flutter pub add uuid)

import '../../domain/entities/book.dart';
import '../../domain/repositories/library_repository.dart';

@LazySingleton(as: LibraryRepository)
class LibraryRepositoryImpl implements LibraryRepository {
  final DatabaseService _dbService;

  LibraryRepositoryImpl(this._dbService);

  Future<String?> _saveCoverBytes(
    List<int> bytes, {
    String extension = 'jpg',
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final coverDir = Directory(p.join(appDir.path, 'covers'));
    if (!await coverDir.exists()) {
      await coverDir.create();
    }
    final fileName = '${const Uuid().v4()}.$extension';
    final coverFile = File(p.join(coverDir.path, fileName));
    await coverFile.writeAsBytes(bytes);
    return coverFile.path;
  }

  Future<String?> _generatePdfCover(String filePath) async {
    String? documentId;
    try {
      final bytes = await File(filePath).readAsBytes();
      documentId = const Uuid().v4();
      final pageCount = await PdfViewerPlatform.instance
          .initializePdfRenderer(bytes, documentId);
      if (pageCount == null || pageCount.isEmpty) {
        return null;
      }

      final widths =
          await PdfViewerPlatform.instance.getPagesWidth(documentId);
      final heights =
          await PdfViewerPlatform.instance.getPagesHeight(documentId);
      if (widths == null ||
          heights == null ||
          widths.isEmpty ||
          heights.isEmpty) {
        return null;
      }

      final originalWidth = (widths.first as num).toDouble();
      final originalHeight = (heights.first as num).toDouble();
      if (originalWidth <= 0 || originalHeight <= 0) {
        return null;
      }

      final targetWidth = originalWidth > 300 ? 300.0 : originalWidth;
      final scale = targetWidth / originalWidth;
      final targetHeight = (originalHeight * scale).round();
      final width = targetWidth.round().clamp(1, 300);
      final height = targetHeight.clamp(1, 600);

      final raw = await PdfViewerPlatform.instance.getPage(
        1,
        width,
        height,
        documentId,
      );
      if (raw == null || raw.isEmpty) return null;

      final image = img.Image.fromBytes(
        width,
        height,
        raw,
        format: img.Format.rgba,
      );
      final pngBytes = img.encodePng(image);
      return await _saveCoverBytes(pngBytes, extension: 'png');
    } catch (e) {
      print("⚠️ Không thể tạo ảnh bìa PDF: $e");
      return null;
    } finally {
      if (documentId != null) {
        try {
          await PdfViewerPlatform.instance.closeDocument(documentId);
        } catch (_) {}
      }
    }
  }

  List<int>? _findCoverInArchive(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive.files) {
        if (!file.isFile || file.content == null) continue;
        final name = file.name.toLowerCase();
        final isCover = name.contains('cover');
        final isImageExt = name.endsWith('.png') ||
            name.endsWith('.jpg') ||
            name.endsWith('.jpeg') ||
            name.endsWith('.jfif') ||
            name.endsWith('.gif') ||
            name.endsWith('.bmp') ||
            name.endsWith('.webp');
        if (isCover && isImageExt) {
          return file.content as List<int>;
        }
      }
    } catch (e) {
      print("⚠️ Không thể đọc cover từ archive: $e");
    }
    return null;
  }

  @override
  Future<List<Book>> getBooks() async {
    final db = await _dbService.database;
    final maps = await db.query('books');
    final prefs = await SharedPreferences.getInstance();

    print("📂 Đang đọc ${maps.length} dòng từ DB");

    final books = <Book>[];
    for (var i = 0; i < maps.length; i++) {
      // Dùng try-catch nhỏ ở đây để nếu 1 cuốn lỗi thì không chết cả App
      try {
        final filePath = maps[i]['filePath'] as String;
        final savedProgress =
            prefs.getDouble('progress_percent_$filePath');
        final dbProgress = (maps[i]['progress'] as num?)?.toDouble() ?? 0.0;
        final progress = savedProgress ?? dbProgress;

        // Đồng bộ lại DB nếu SharedPreferences mới hơn
        if (savedProgress != null && savedProgress != dbProgress) {
          await db.update(
            'books',
            {'progress': savedProgress},
            where: 'id = ?',
            whereArgs: [maps[i]['id']],
          );
        }

        books.add(
          Book(
          id: maps[i]['id'] as String,
          title: maps[i]['title'] as String,
          author: maps[i]['author'] as String? ?? "Unknown", // Xử lý null
          filePath: filePath,
          coverPath: maps[i]['coverPath'] as String?,
          // Ép kiểu an toàn hơn: Nếu null thì về 0.0
          progress: progress,
        ),
        );
      } catch (e) {
        print("⚠️ Lỗi map dữ liệu sách index $i: $e");
        // Trả về một cuốn sách "bù nhìn" để không crash list
        books.add(
          Book(
            id: "error",
            title: "Lỗi dữ liệu",
            filePath: "",
            progress: 0,
          ),
        );
      }
    }

    return books;
  }

  @override
  Future<void> addBook(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception("File không tồn tại");

    String title = p.basename(filePath); // Mặc định lấy tên file
    String author = "Unknown";
    String? localCoverPath;
    double progress = 0.0;

    final extension = p.extension(filePath).toLowerCase();
    if (extension == '.pdf') {
      localCoverPath = await _generatePdfCover(filePath);
    } else {
      try {
        // 1. Đọc bytes (tránh readBook vì có thể lỗi Navigation)
        final bytes = await file.readAsBytes();

        // 2. Lấy metadata cơ bản (không parse chapters)
        final bookRef = await epub.EpubReader.openBook(bytes);
        title = bookRef.Title ?? title;
        author = bookRef.Author ?? author;

        // 3. LOGIC LẤY ẢNH BÌA THÔNG MINH (IMPROVED)
        List<int>? coverData;
        String coverExt = 'jpg';

        final content =
            bookRef.Content != null
                ? await epub.EpubReader.readContent(bookRef.Content!)
                : null;
        final images =
            content?.Images ?? <String, epub.EpubByteContentFile>{};
        final allFiles =
            content?.AllFiles ?? <String, epub.EpubContentFile>{};

        // Ưu tiên 2: Tìm file ảnh có tên gợi ý "cover"/"front"/"folder"
        String? coverKey;
        if (images.isNotEmpty) {
          for (var key in images.keys) {
            final lower = key.toLowerCase();
            if (lower.contains('cover') ||
                lower.contains('front') ||
                lower.contains('folder')) {
              coverKey = key;
              break;
            }
          }
        }

        if (coverKey != null) {
          coverData = images[coverKey]?.Content;
          final ext = p.extension(coverKey).replaceFirst('.', '');
          if (ext.isNotEmpty) coverExt = ext;
        }

        // Ưu tiên 3: Tìm ảnh theo ContentType/MimeType trong tất cả file
        if (coverData == null && allFiles.isNotEmpty) {
          for (final entry in allFiles.entries) {
            final file = entry.value;
            if (file is! epub.EpubByteContentFile) continue;
            final mime = file.ContentMimeType?.toLowerCase() ?? '';
            final name = entry.key.toLowerCase();
            final isImageMime = mime.startsWith('image/');
            final isImageExt = name.endsWith('.png') ||
                name.endsWith('.jpg') ||
                name.endsWith('.jpeg') ||
                name.endsWith('.jfif') ||
                name.endsWith('.gif') ||
                name.endsWith('.bmp') ||
                name.endsWith('.webp');
            if (isImageMime || isImageExt) {
              coverData = file.Content;
              final ext = p.extension(entry.key).replaceFirst('.', '');
              if (ext.isNotEmpty) coverExt = ext;
              if (coverData != null) break;
            }
          }
        }

        // Ưu tiên 4: Lấy đại cái ảnh đầu tiên từ danh sách Images
        if (coverData == null && images.isNotEmpty) {
          coverData = images.values.first.Content;
        }

        // Ưu tiên 5: Tìm ảnh trong HTML (src của thẻ img)
        if (coverData == null && content?.Html != null) {
          final htmlEntries = content!.Html!.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          final imgReg = RegExp(
            r"""<img[^>]+src=['"]([^'"]+)['"]""",
            caseSensitive: false,
          );
          for (final entry in htmlEntries) {
            final html = entry.value.Content ?? '';
            final match = imgReg.firstMatch(html);
            if (match == null) continue;
            var src = match.group(1) ?? '';
            src = Uri.decodeFull(src).split('#').first.split('?').first;
            if (src.startsWith('/')) {
              src = src.substring(1);
            }
            if (src.isEmpty) continue;

            // Tìm file ảnh khớp trong AllFiles
            for (final fileEntry in allFiles.entries) {
              final key = fileEntry.key;
              if (key == src || key.endsWith('/$src')) {
                final file = fileEntry.value;
                if (file is epub.EpubByteContentFile) {
                  coverData = file.Content;
                  final ext = p.extension(key).replaceFirst('.', '');
                  if (ext.isNotEmpty) coverExt = ext;
                }
                break;
              }
            }
            if (coverData != null) break;
          }
        }

        // Ưu tiên 6: Tìm ảnh cover trực tiếp trong archive
        if (coverData == null) {
          coverData = _findCoverInArchive(bytes);
          coverExt = coverData != null ? 'jpg' : coverExt;
        }

        // 4. Lưu ảnh bìa ra file riêng (Nếu tìm thấy)
        if (coverData != null) {
          final decoded = img.decodeImage(coverData);
          if (decoded != null) {
            final pngBytes = img.encodePng(decoded);
            localCoverPath = await _saveCoverBytes(pngBytes, extension: 'png');
          } else {
            localCoverPath = await _saveCoverBytes(
              coverData,
              extension: coverExt,
            );
          }
        }
      } catch (e) {
        // ⚠️ QUAN TRỌNG: NẾU FILE LỖI (RangeError, FormatError...)
        // Ta chỉ in lỗi ra để biết, nhưng KHÔNG throw exception nữa.
        // Vẫn tiếp tục chạy xuống dưới để lưu sách với thông tin cơ bản (Tên file).
        print("⚠️ File Epub không chuẩn hoặc bị lỗi cấu trúc: $e");
        print("👉 Chuyển sang chế độ Safe Mode: Lưu bằng tên file.");
      }
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
      await prefs.remove('progress_percent_$filePath');
      await prefs.remove('progress_pdf_page_$filePath');
      final lastPath = prefs.getString('last_book_path');
      if (lastPath == filePath) {
        await prefs.remove('last_book_path');
      }
    }
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }
}
