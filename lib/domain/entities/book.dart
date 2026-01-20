class Book {
  final String id; // ID duy nhất (UUID)
  final String title; // Tên sách
  final String? author; // Tác giả
  final String filePath; // Đường dẫn file .epub gốc
  final String?
  coverPath; // Đường dẫn ảnh bìa (đã được trích xuất ra file ảnh riêng)
  final double progress; // Tiến độ đọc (0.0 -> 1.0)

  Book({
    required this.id,
    required this.title,
    this.author,
    required this.filePath,
    this.coverPath,
    this.progress = 0.0,
  });
}
