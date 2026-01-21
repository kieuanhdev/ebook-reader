class Book {
  final String id;
  final String title;
  final String? author;
  final String filePath;
  final String? coverPath;
  final double progress;

  Book({
    required this.id,
    required this.title,
    this.author,
    required this.filePath,
    this.coverPath,
    this.progress = 0.0,
  });
}
