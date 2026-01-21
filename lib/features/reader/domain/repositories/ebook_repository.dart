import 'package:my_ebook_reader/core/reader_layout.dart';
import '../entities/chapter.dart';

abstract class EbookRepository {
  Future<(List<Chapter>, String)> pickAndParseBook();
  Future<(List<Chapter>, String)> parseBook(String filePath);
  Future<String> loadChapterHtml(String filePath, Chapter chapter);
  Future<(List<Chapter>, String, int)?> loadLastBook();
  Future<(double, bool, ReaderLayout)> loadSettings();
  Future<void> saveSettings(
    double fontSize,
    bool isDarkMode,
    ReaderLayout layout,
  );
  Future<int> loadProgress(String filePath);
  Future<void> saveProgress(
    String filePath,
    int index,
    int totalChapters,
  );
}
