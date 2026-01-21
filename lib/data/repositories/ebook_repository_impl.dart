import 'dart:io';
import 'package:archive/archive.dart';
import 'package:epubx/epubx.dart' as epub;
import 'package:epubx/src/readers/content_reader.dart';
import 'package:epubx/src/readers/package_reader.dart';
import 'package:epubx/src/readers/root_file_path_reader.dart';
import 'package:epubx/src/utils/zip_path_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p; // Cần import thư viện này để lấy tên file
import 'package:shared_preferences/shared_preferences.dart';

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

  List<Chapter> _buildChaptersFromSpine(
    epub.EpubBookRef bookRef,
    epub.EpubContent content,
  ) {
    final spineItems = bookRef.Schema?.Package?.Spine?.Items ?? const [];
    final manifestItems =
        bookRef.Schema?.Package?.Manifest?.Items ?? const [];
    final manifestById = {
      for (final item in manifestItems) item.Id: item,
    };

    final chapters = <Chapter>[];
    for (final spineItem in spineItems) {
      final href = manifestById[spineItem.IdRef]?.Href;
      if (href == null) continue;
      final html = content.Html?[href]?.Content;
      if (html == null || html.trim().isEmpty) continue;
      chapters.add(
        Chapter(
          title: p.basenameWithoutExtension(href),
          htmlContent: html,
        ),
      );
    }

    return chapters;
  }

  List<Chapter> _buildChaptersFromHtmlContent(
    Map<String, epub.EpubTextContentFile> htmlMap,
  ) {
    final chapters = <Chapter>[];
    for (final entry in htmlMap.entries) {
      final html = entry.value.Content;
      if (html == null || html.trim().isEmpty) continue;
      chapters.add(
        Chapter(
          title: p.basenameWithoutExtension(entry.key),
          htmlContent: html,
        ),
      );
    }
    return chapters;
  }

  Future<(List<Chapter>, String)> _safeParseBookWithoutNavigation(
    List<int> bytes,
    String filePath,
  ) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final rootFilePath = await RootFilePathReader.getRootFilePath(archive);
    if (rootFilePath == null || rootFilePath.isEmpty) {
      throw Exception("Không tìm thấy đường dẫn OPF trong EPUB.");
    }

    final contentDir = ZipPathUtils.getDirectoryPath(rootFilePath);
    final package = await PackageReader.readPackage(archive, rootFilePath);

    final schema = epub.EpubSchema()
      ..Package = package
      ..ContentDirectoryPath = contentDir;

    final creators = package.Metadata?.Creators ?? <epub.EpubMetadataCreator>[];
    final bookRef = epub.EpubBookRef(archive)
      ..Schema = schema
      ..Title =
          package.Metadata?.Titles?.isNotEmpty == true
              ? package.Metadata!.Titles!.first
              : p.basename(filePath)
      ..AuthorList = creators.map((creator) => creator.Creator).toList()
      ..Author = creators.map((creator) => creator.Creator).join(', ');

    bookRef.Content = ContentReader.parseContentMap(bookRef);
    final content = await epub.EpubReader.readContent(bookRef.Content!);

    var chapters = _buildChaptersFromSpine(bookRef, content);
    if (chapters.isEmpty && content.Html != null) {
      chapters = _buildChaptersFromHtmlContent(content.Html!);
    }
    if (chapters.isEmpty) {
      throw Exception("Không tìm thấy nội dung chương trong file EPUB.");
    }

    return (chapters, bookRef.Title ?? p.basename(filePath));
  }

  @override
  Future<void> saveProgress(
    String filePath,
    int currentChapterIndex,
    int totalChapters,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Lưu vị trí của sách này
    await prefs.setInt('progress_$filePath', currentChapterIndex);
    final denom = (totalChapters - 1) > 0 ? (totalChapters - 1) : 1;
    final percent = (currentChapterIndex / denom).clamp(0.0, 1.0);
    await prefs.setDouble('progress_percent_$filePath', percent);

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

    final bytes = await file.readAsBytes();

    try {
      // Ưu tiên dùng parser an toàn (không phụ thuộc Navigation/TOC)
      return await _safeParseBookWithoutNavigation(bytes, filePath);
    } catch (e) {
      try {
        // Fallback sang parser chuẩn nếu file có TOC hợp lệ
        final epubBook = await epub.EpubReader.readBook(bytes);
        final title = epubBook.Title ?? p.basename(filePath);

        List<Chapter> domainChapters = [];
        if (epubBook.Chapters != null) {
          domainChapters = _flattenChapters(epubBook.Chapters!);
        }
        if (domainChapters.isEmpty && epubBook.Content?.Html != null) {
          domainChapters = _buildChaptersFromHtmlContent(
            epubBook.Content!.Html!,
          );
        }

        if (domainChapters.isEmpty) {
          throw Exception("Không tìm thấy nội dung chương trong file EPUB.");
        }
        return (domainChapters, title);
      } catch (fallbackError) {
        print("Lỗi parse sách: $e");
        print("Lỗi parse sách (fallback): $fallbackError");
        throw Exception("Không thể đọc định dạng sách này.");
      }
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
