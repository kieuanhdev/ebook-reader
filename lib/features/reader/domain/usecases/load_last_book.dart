import 'package:injectable/injectable.dart';
import '../entities/chapter.dart';
import '../repositories/ebook_repository.dart';

@lazySingleton
class LoadLastBook {
  final EbookRepository _repository;

  LoadLastBook(this._repository);

  Future<(List<Chapter>, String, int)?> call() => _repository.loadLastBook();
}
