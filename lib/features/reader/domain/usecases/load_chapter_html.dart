import 'package:injectable/injectable.dart';
import '../entities/chapter.dart';
import '../repositories/ebook_repository.dart';

@lazySingleton
class LoadChapterHtml {
  final EbookRepository _repository;

  LoadChapterHtml(this._repository);

  Future<String> call(String filePath, Chapter chapter) =>
      _repository.loadChapterHtml(filePath, chapter);
}
