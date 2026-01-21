import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/repositories/library_repository.dart';

// --- Events ---
abstract class LibraryEvent {}

class LoadLibraryEvent extends LibraryEvent {} // Sự kiện mở tủ sách

class AddBookEvent extends LibraryEvent {
  // Sự kiện thêm sách
  final String filePath;
  AddBookEvent(this.filePath);
}

// --- States ---
abstract class LibraryState {}

class LibraryInitial extends LibraryState {}

class LibraryLoading extends LibraryState {}

class LibraryLoaded extends LibraryState {
  final List<Book> books;
  LibraryLoaded(this.books);
}

// --- Bloc ---
@injectable
class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final LibraryRepository _repository;

  LibraryBloc(this._repository) : super(LibraryInitial()) {
    // Xử lý khi mở tủ sách
    on<LoadLibraryEvent>((event, emit) async {
      emit(LibraryLoading());
      final books = await _repository.getBooks();
      emit(LibraryLoaded(books));
    });

    // Xử lý khi thêm sách mới
    on<AddBookEvent>((event, emit) async {
      emit(LibraryLoading());
      try {
        await _repository.addBook(event.filePath);

        final books = await _repository.getBooks();
        print(
          "📥 Đã load được ${books.length} cuốn sách từ DB",
        ); // Log kiểm tra
        emit(LibraryLoaded(books));
      } catch (e) {
        print("❌ Lỗi trong Bloc: $e");
        final books = await _repository.getBooks();
        emit(LibraryLoaded(books));
      }
    });
  }
}
