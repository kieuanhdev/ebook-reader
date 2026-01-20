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

import 'data/datasources/local/database_service.dart' as _i386;
import 'data/repositories/ebook_repository_impl.dart' as _i644;
import 'data/repositories/library_repository_impl.dart' as _i106;
import 'domain/repositories/ebook_repository.dart' as _i635;
import 'domain/repositories/library_repository.dart' as _i1065;
import 'presentation/bloc/library/library_bloc.dart' as _i460;
import 'presentation/bloc/reader_bloc.dart' as _i712;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i386.DatabaseService>(() => _i386.DatabaseService());
    gh.lazySingleton<_i635.EbookRepository>(() => _i644.EbookRepositoryImpl());
    gh.factory<_i712.ReaderBloc>(
      () => _i712.ReaderBloc(repository: gh<_i635.EbookRepository>()),
    );
    gh.lazySingleton<_i1065.LibraryRepository>(
      () => _i106.LibraryRepositoryImpl(gh<_i386.DatabaseService>()),
    );
    gh.factory<_i460.LibraryBloc>(
      () => _i460.LibraryBloc(gh<_i1065.LibraryRepository>()),
    );
    return this;
  }
}
