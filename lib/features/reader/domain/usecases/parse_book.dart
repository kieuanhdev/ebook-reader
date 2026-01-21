import 'package:injectable/injectable.dart';
import '../entities/chapter.dart';
import '../repositories/ebook_repository.dart';

@lazySingleton
class ParseBook {
  final EbookRepository _repository;

  ParseBook(this._repository);

  Future<(List<Chapter>, String)> call(String filePath) =>
      _repository.parseBook(filePath);
}
