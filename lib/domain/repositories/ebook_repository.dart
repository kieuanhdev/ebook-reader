import '../entities/chapter.dart';

abstract class EbookRepository {
  // 1. Chức năng chọn file từ máy (Nếu bạn vẫn muốn dùng nút folder cũ)
  Future<(List<Chapter>, String)> pickAndParseBook();

  // 2. Chức năng đọc file từ đường dẫn (Dùng cho Tủ Sách)
  Future<(List<Chapter>, String)> parseBook(String filePath);

  // 3. Load lại cuốn sách đọc dở lần trước (History)
  Future<(List<Chapter>, String, int)?> loadLastBook();

  // 4. Cài đặt giao diện (Settings)
  Future<(double, bool)> loadSettings();
  Future<void> saveSettings(double fontSize, bool isDarkMode);

  // 5. Quản lý tiến độ đọc (Progress)
  Future<int> loadProgress(String filePath);

  // Bạn chỉ giữ lại DUY NHẤT 1 dòng saveProgress này thôi:
  Future<void> saveProgress(String filePath, int index);
}
