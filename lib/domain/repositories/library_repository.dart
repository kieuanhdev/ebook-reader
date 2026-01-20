import '../entities/book.dart';

abstract class LibraryRepository {
  Future<List<Book>> getBooks();
  Future<void> addBook(String filePath); // Chỉ cần đưa đường dẫn file epub
  Future<void> deleteBook(String id);
}
