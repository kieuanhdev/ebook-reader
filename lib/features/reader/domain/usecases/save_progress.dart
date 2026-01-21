import 'package:injectable/injectable.dart';
import '../repositories/ebook_repository.dart';

@lazySingleton
class SaveProgress {
  final EbookRepository _repository;

  SaveProgress(this._repository);

  Future<void> call(String filePath, int index, int totalChapters) =>
      _repository.saveProgress(filePath, index, totalChapters);
}
