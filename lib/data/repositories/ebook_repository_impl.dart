import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:epubx/epubx.dart' as epub;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p; // Cần import thư viện này để lấy tên file
import 'package:injectable/injectable.dart';

import '../../domain/entities/chapter.dart';
import '../../domain/repositories/ebook_repository.dart';

@LazySingleton(as: EbookRepository)
class EbookRepositoryImpl implements EbookRepository {
  // --- HÀM PHỤ TRỢ (PRIVATE) ---

  // 2. Hàm đệ quy chuyển đổi EpubChapter -> Domain Chapter
  List<Chapter> _flattenChapters(List<epub.EpubChapter> sourceChapters) {
    List<Chapter> flatList = [];
    for (var chapter in sourceChapters) {
      // Chỉ lấy chương có nội dung
      if (chapter.HtmlContent != null && chapter.HtmlContent!.isNotEmpty) {
        flatList.add(
          Chapter(
            title: chapter.Title ?? "Chương không tên",
            htmlContent: chapter.HtmlContent!, // Raw HTML, sẽ bọc ở HtmlHelper
          ),
        );
      }

      // Đệ quy lấy chương con
      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        flatList.addAll(_flattenChapters(chapter.SubChapters!));
      }
    }
    return flatList;
  }

  @override
  Future<void> saveProgress(String filePath, int currentChapterIndex) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Lưu vị trí của sách này
    await prefs.setInt('progress_$filePath', currentChapterIndex);

    // 2. Lưu luôn đây là cuốn sách cuối cùng (để tính năng History hoạt động)
    await prefs.setString('last_book_path', filePath);
  }

  // --- CÁC HÀM CHÍNH (OVERRIDE) ---

  @override
  Future<(List<Chapter>, String)> parseBook(String filePath) async {
    final file = File(filePath);

    // 1. Kiểm tra file tồn tại
    if (!await file.exists()) {
      throw Exception("File sách không tồn tại ở đường dẫn này: $filePath");
    }

    try {
      // 2. Đọc bytes và Parse Epub
      final bytes = await file.readAsBytes();
      final epubBook = await epub.EpubReader.readBook(bytes);

      // 3. Lấy tên sách (Nếu null thì lấy tên file)
      final title = epubBook.Title ?? p.basename(filePath);

      // 4. Chuyển đổi Chapter
      List<Chapter> domainChapters = [];
      if (epubBook.Chapters != null) {
        domainChapters = _flattenChapters(epubBook.Chapters!);
      }

      return (domainChapters, title);
    } catch (e) {
      print("Lỗi parse sách: $e");
      throw Exception("Không thể đọc định dạng sách này.");
    }
  }

  @override
  Future<(List<Chapter>, String)> pickAndParseBook() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );

    if (result == null) throw Exception("Người dùng hủy chọn file");

    String path = result.files.single.path!;

    // Tái sử dụng hàm parseBook ở trên để code gọn hơn
    return await parseBook(path);
  }

  // --- QUẢN LÝ TIẾN ĐỘ ---

  @override
  Future<int> loadProgress(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    // Lấy tiến độ riêng của cuốn sách này
    return prefs.getInt('progress_$filePath') ?? 0;
  }

  @override
  Future<(List<Chapter>, String, int)?> loadLastBook() async {
    final prefs = await SharedPreferences.getInstance();
    String? lastPath = prefs.getString('last_book_path');

    if (lastPath != null && await File(lastPath).exists()) {
      try {
        // Tái sử dụng hàm parseBook
        var (chapters, _) = await parseBook(lastPath);

        // Lấy lại tiến độ cũ của sách đó
        int lastIndex = prefs.getInt('progress_$lastPath') ?? 0;

        return (chapters, lastPath, lastIndex);
      } catch (e) {
        return null; // File lỗi hoặc không tồn tại nữa
      }
    }
    return null; // Chưa có lịch sử
  }

  // --- CÀI ĐẶT (SETTINGS) ---

  @override
  Future<(double, bool)> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    double fontSize =
        prefs.getDouble('settings_font_size') ?? 18.0; // Mặc định 18 cho dễ đọc
    bool isDarkMode = prefs.getBool('settings_dark_mode') ?? false;
    return (fontSize, isDarkMode);
  }

  @override
  Future<void> saveSettings(double fontSize, bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('settings_font_size', fontSize);
    await prefs.setBool('settings_dark_mode', isDarkMode);
  }
}
