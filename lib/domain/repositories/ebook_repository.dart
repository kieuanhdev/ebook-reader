import '../entities/chapter.dart';

abstract class EbookRepository {
  // Trả về: (Danh sách chương, Đường dẫn file)
  Future<(List<Chapter>, String)> pickAndParseBook();

  // Trả về: (Danh sách chương, Đường dẫn file, Vị trí chương cũ) hoặc null
  Future<(List<Chapter>, String, int)?> loadLastBook();

  // Lưu lại tiến độ
  Future<void> saveProgress(String filePath, int currentChapterIndex);
}
