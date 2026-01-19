import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:epubx/epubx.dart' as epub;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/chapter.dart';
import '../../domain/repositories/ebook_repository.dart';

class EbookRepositoryImpl implements EbookRepository {
  // Hàm phụ trợ: Chuyển đổi từ EpubChapter (của thư viện) -> Chapter (của Domain)
  // và làm phẳng danh sách lồng nhau.
  List<Chapter> _flattenChapters(List<epub.EpubChapter> sourceChapters) {
    List<Chapter> flatList = [];
    for (var chapter in sourceChapters) {
      // Mapping dữ liệu
      flatList.add(
        Chapter(
          title: chapter.Title ?? "Chương không tên",
          htmlContent: chapter.HtmlContent ?? "",
        ),
      );

      // Đệ quy lấy chương con
      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        flatList.addAll(_flattenChapters(chapter.SubChapters!));
      }
    }
    return flatList;
  }

  // --- 1. CHỌN VÀ ĐỌC SÁCH MỚI ---
  @override
  Future<(List<Chapter>, String)> pickAndParseBook() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );

    if (result == null) throw Exception("Người dùng hủy chọn file");

    String path = result.files.single.path!;
    File file = File(path);

    // Đọc byte và parse
    List<int> bytes = await file.readAsBytes();
    epub.EpubBook book = await epub.EpubReader.readBook(bytes);

    List<Chapter> chapters = [];
    if (book.Chapters != null) {
      chapters = _flattenChapters(book.Chapters!);
    }

    return (chapters, path);
  }

  // --- 2. ĐỌC LẠI SÁCH CŨ TỪ LỊCH SỬ ---
  @override
  Future<(List<Chapter>, String, int)?> loadLastBook() async {
    final prefs = await SharedPreferences.getInstance();
    String? lastPath = prefs.getString('last_book_path');
    int? lastIndex = prefs.getInt('last_chapter_index');

    if (lastPath != null && File(lastPath).existsSync()) {
      // Đọc lại file từ đường dẫn đã lưu
      File file = File(lastPath);
      List<int> bytes = await file.readAsBytes();
      epub.EpubBook book = await epub.EpubReader.readBook(bytes);

      List<Chapter> chapters = [];
      if (book.Chapters != null) {
        chapters = _flattenChapters(book.Chapters!);
      }

      return (chapters, lastPath, lastIndex ?? 0);
    }
    return null; // Không tìm thấy lịch sử
  }

  // --- 3. LƯU TIẾN ĐỘ ---
  @override
  Future<void> saveProgress(String filePath, int currentChapterIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_book_path', filePath);
    await prefs.setInt('last_chapter_index', currentChapterIndex);
  }
}
