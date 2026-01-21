import 'package:injectable/injectable.dart';
import '../repositories/library_repository.dart';

@lazySingleton
class DeleteBook {
  final LibraryRepository _repository;

  DeleteBook(this._repository);

  Future<void> call(String id) => _repository.deleteBook(id);
}
