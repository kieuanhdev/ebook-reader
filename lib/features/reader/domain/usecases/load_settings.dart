import 'package:injectable/injectable.dart';
import 'package:my_ebook_reader/core/reader_layout.dart';
import '../repositories/ebook_repository.dart';

@lazySingleton
class LoadSettings {
  final EbookRepository _repository;

  LoadSettings(this._repository);

  Future<(double, bool, ReaderLayout)> call() => _repository.loadSettings();
}
