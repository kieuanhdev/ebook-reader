import 'package:injectable/injectable.dart';
import '../entities/book.dart';
import '../repositories/library_repository.dart';

@lazySingleton
class GetBooks {
  final LibraryRepository _repository;

  GetBooks(this._repository);

  Future<List<Book>> call() => _repository.getBooks();
}
