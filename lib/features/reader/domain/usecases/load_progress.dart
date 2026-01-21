import 'package:injectable/injectable.dart';
import '../repositories/ebook_repository.dart';

@lazySingleton
class LoadProgress {
  final EbookRepository _repository;

  LoadProgress(this._repository);

  Future<int> call(String filePath) => _repository.loadProgress(filePath);
}
