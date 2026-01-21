import 'package:injectable/injectable.dart';
import 'package:my_ebook_reader/core/reader_layout.dart';
import '../repositories/ebook_repository.dart';

@lazySingleton
class SaveSettings {
  final EbookRepository _repository;

  SaveSettings(this._repository);

  Future<void> call(
    double fontSize,
    bool isDarkMode,
    ReaderLayout layout,
  ) =>
      _repository.saveSettings(fontSize, isDarkMode, layout);
}
