import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:epubx/epubx.dart' as epub;
import 'package:epubx/src/readers/package_reader.dart';
import 'package:epubx/src/readers/root_file_path_reader.dart';
import 'package:epubx/src/utils/zip_path_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_ebook_reader/core/reader_layout.dart';
import 'package:my_ebook_reader/features/reader/domain/entities/chapter.dart';
import 'package:my_ebook_reader/features/reader/domain/repositories/ebook_repository.dart';

@LazySingleton(as: EbookRepository)
class EbookRepositoryImpl implements EbookRepository {
  List<Chapter> _buildChaptersFromSpine(
    epub.EpubBookRef bookRef,
    Archive archive,
    String contentDir,
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
      final fullPath = ZipPathUtils.combine(contentDir, href) ?? href;
      final entry = archive.findFile(fullPath) ?? archive.findFile(href);
      if (entry == null || entry.size == 0) continue;
      chapters.add(
        Chapter(
          title: p.basenameWithoutExtension(href),
          href: href,
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
      if (entry.value.Content == null || entry.value.Content!.trim().isEmpty) {
        continue;
      }
      chapters.add(
        Chapter(
          title: p.basenameWithoutExtension(entry.key),
          href: entry.key,
        ),
      );
    }
    return chapters;
  }

  List<Chapter> _buildChaptersFromManifest(
    List<epub.EpubManifestItem> items,
    Archive archive,
    String contentDir,
  ) {
    final chapters = <Chapter>[];
    for (final item in items) {
      final href = item.Href;
      if (href == null || href.isEmpty) continue;
      final mediaType = (item.MediaType ?? '').toLowerCase();
      if (!mediaType.contains('html')) continue;
      final fullPath = ZipPathUtils.combine(contentDir, href) ?? href;
      final entry = archive.findFile(fullPath) ?? archive.findFile(href);
      if (entry == null || entry.size == 0) continue;
      chapters.add(
        Chapter(
          title: p.basenameWithoutExtension(href),
          href: href,
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

    var chapters = _buildChaptersFromSpine(bookRef, archive, contentDir);
    if (chapters.isEmpty && package.Manifest?.Items != null) {
      chapters = _buildChaptersFromManifest(
        package.Manifest!.Items!,
        archive,
        contentDir,
      );
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

    await prefs.setInt('progress_$filePath', currentChapterIndex);
    final denom = (totalChapters - 1) > 0 ? (totalChapters - 1) : 1;
    final percent = (currentChapterIndex / denom).clamp(0.0, 1.0);
    await prefs.setDouble('progress_percent_$filePath', percent);

    await prefs.setString('last_book_path', filePath);
  }

  @override
  Future<(List<Chapter>, String)> parseBook(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw Exception("File sách không tồn tại ở đường dẫn này: $filePath");
    }

    final bytes = await file.readAsBytes();

    try {
      return await _safeParseBookWithoutNavigation(bytes, filePath);
    } catch (e) {
      try {
        final epubBook = await epub.EpubReader.readBook(bytes);
        final title = epubBook.Title ?? p.basename(filePath);

        List<Chapter> domainChapters = [];
        if (epubBook.Content?.Html != null) {
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
  Future<String> loadChapterHtml(String filePath, Chapter chapter) async {
    if (chapter.htmlContent != null && chapter.htmlContent!.isNotEmpty) {
      return chapter.htmlContent!;
    }
    if (chapter.href == null || chapter.href!.isEmpty) {
      throw Exception("Không tìm thấy đường dẫn chương để load nội dung.");
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception("File sách không tồn tại ở đường dẫn này: $filePath");
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final rootFilePath = await RootFilePathReader.getRootFilePath(archive);
    if (rootFilePath == null || rootFilePath.isEmpty) {
      throw Exception("Không tìm thấy đường dẫn OPF trong EPUB.");
    }
    final contentDir = ZipPathUtils.getDirectoryPath(rootFilePath);
    final fullPath =
        ZipPathUtils.combine(contentDir, chapter.href!) ?? chapter.href!;
    final entry = archive.findFile(fullPath) ?? archive.findFile(chapter.href!);
    if (entry == null) {
      throw Exception("Không tìm thấy nội dung chương trong EPUB.");
    }

    final contentBytes = entry.content as List<int>;
    return utf8.decode(contentBytes, allowMalformed: true);
  }

  @override
  Future<(List<Chapter>, String)> pickAndParseBook() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );

    if (result == null) throw Exception("Người dùng hủy chọn file");

    String path = result.files.single.path!;

    return await parseBook(path);
  }

  @override
  Future<int> loadProgress(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('progress_$filePath') ?? 0;
  }

  @override
  Future<(List<Chapter>, String, int)?> loadLastBook() async {
    final prefs = await SharedPreferences.getInstance();
    String? lastPath = prefs.getString('last_book_path');

    if (lastPath != null && await File(lastPath).exists()) {
      try {
        var (chapters, _) = await parseBook(lastPath);

        int lastIndex = prefs.getInt('progress_$lastPath') ?? 0;

        return (chapters, lastPath, lastIndex);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<(double, bool, ReaderLayout)> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    double fontSize =
        prefs.getDouble('settings_font_size') ?? 18.0;
    bool isDarkMode = prefs.getBool('settings_dark_mode') ?? false;
    final layoutValue = prefs.getString('settings_layout');
    final layout = readerLayoutFromString(layoutValue);
    return (fontSize, isDarkMode, layout);
  }

  @override
  Future<void> saveSettings(
    double fontSize,
    bool isDarkMode,
    ReaderLayout layout,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('settings_font_size', fontSize);
    await prefs.setBool('settings_dark_mode', isDarkMode);
    await prefs.setString('settings_layout', readerLayoutToString(layout));
  }
}
