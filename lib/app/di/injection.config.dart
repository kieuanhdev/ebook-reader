// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../features/library/data/datasources/local/database_service.dart'
    as _i386;
import '../../features/library/data/repositories/library_repository_impl.dart'
    as _i106;
import '../../features/library/domain/repositories/library_repository.dart'
    as _i1065;
import '../../features/library/domain/usecases/add_book.dart' as _i812;
import '../../features/library/domain/usecases/delete_book.dart' as _i301;
import '../../features/library/domain/usecases/get_books.dart' as _i657;
import '../../features/library/presentation/bloc/library_bloc.dart' as _i460;
import '../../features/reader/data/repositories/ebook_repository_impl.dart'
    as _i644;
import '../../features/reader/domain/repositories/ebook_repository.dart'
    as _i635;
import '../../features/reader/domain/usecases/load_chapter_html.dart' as _i901;
import '../../features/reader/domain/usecases/load_last_book.dart' as _i550;
import '../../features/reader/domain/usecases/load_progress.dart' as _i401;
import '../../features/reader/domain/usecases/load_settings.dart' as _i744;
import '../../features/reader/domain/usecases/parse_book.dart' as _i881;
import '../../features/reader/domain/usecases/save_progress.dart' as _i979;
import '../../features/reader/domain/usecases/save_settings.dart' as _i955;
import '../../features/reader/presentation/bloc/reader_bloc.dart' as _i712;

extension GetItInjectableX on _i174.GetIt {
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i386.DatabaseService>(() => _i386.DatabaseService());
    gh.lazySingleton<_i635.EbookRepository>(() => _i644.EbookRepositoryImpl());
    gh.lazySingleton<_i1065.LibraryRepository>(
      () => _i106.LibraryRepositoryImpl(gh<_i386.DatabaseService>()),
    );
    gh.lazySingleton<_i657.GetBooks>(
      () => _i657.GetBooks(gh<_i1065.LibraryRepository>()),
    );
    gh.lazySingleton<_i812.AddBook>(
      () => _i812.AddBook(gh<_i1065.LibraryRepository>()),
    );
    gh.lazySingleton<_i301.DeleteBook>(
      () => _i301.DeleteBook(gh<_i1065.LibraryRepository>()),
    );
    gh.lazySingleton<_i881.ParseBook>(
      () => _i881.ParseBook(gh<_i635.EbookRepository>()),
    );
    gh.lazySingleton<_i550.LoadLastBook>(
      () => _i550.LoadLastBook(gh<_i635.EbookRepository>()),
    );
    gh.lazySingleton<_i901.LoadChapterHtml>(
      () => _i901.LoadChapterHtml(gh<_i635.EbookRepository>()),
    );
    gh.lazySingleton<_i979.SaveProgress>(
      () => _i979.SaveProgress(gh<_i635.EbookRepository>()),
    );
    gh.lazySingleton<_i744.LoadSettings>(
      () => _i744.LoadSettings(gh<_i635.EbookRepository>()),
    );
    gh.lazySingleton<_i955.SaveSettings>(
      () => _i955.SaveSettings(gh<_i635.EbookRepository>()),
    );
    gh.lazySingleton<_i401.LoadProgress>(
      () => _i401.LoadProgress(gh<_i635.EbookRepository>()),
    );
    gh.factory<_i712.ReaderBloc>(
      () => _i712.ReaderBloc(
        gh<_i744.LoadSettings>(),
        gh<_i881.ParseBook>(),
        gh<_i401.LoadProgress>(),
        gh<_i550.LoadLastBook>(),
        gh<_i901.LoadChapterHtml>(),
        gh<_i979.SaveProgress>(),
        gh<_i955.SaveSettings>(),
      ),
    );
    gh.factory<_i460.LibraryBloc>(
      () => _i460.LibraryBloc(
        gh<_i657.GetBooks>(),
        gh<_i812.AddBook>(),
        gh<_i301.DeleteBook>(),
      ),
    );
    return this;
  }
}
