import '../entities/book.dart';

abstract class LibraryRepository {
  Future<List<Book>> getBooks();
  Future<void> addBook(String filePath);
  Future<void> deleteBook(String id);
}
