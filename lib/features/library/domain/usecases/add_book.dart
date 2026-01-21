import 'package:injectable/injectable.dart';
import '../repositories/library_repository.dart';

@lazySingleton
class AddBook {
  final LibraryRepository _repository;

  AddBook(this._repository);

  Future<void> call(String filePath) => _repository.addBook(filePath);
}
