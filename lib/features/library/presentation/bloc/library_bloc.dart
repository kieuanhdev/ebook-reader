import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../domain/entities/book.dart';
import '../../domain/usecases/add_book.dart';
import '../../domain/usecases/delete_book.dart';
import '../../domain/usecases/get_books.dart';

abstract class LibraryEvent {}

class LoadLibraryEvent extends LibraryEvent {}

class AddBookEvent extends LibraryEvent {
  final String filePath;
  AddBookEvent(this.filePath);
}

class DeleteBookEvent extends LibraryEvent {
  final Book book;
  DeleteBookEvent(this.book);
}

abstract class LibraryState {}

class LibraryInitial extends LibraryState {}

class LibraryLoading extends LibraryState {}

class LibraryLoaded extends LibraryState {
  final List<Book> books;
  LibraryLoaded(this.books);
}

@injectable
class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final GetBooks _getBooks;
  final AddBook _addBook;
  final DeleteBook _deleteBook;

  LibraryBloc(this._getBooks, this._addBook, this._deleteBook)
      : super(LibraryInitial()) {
    on<LoadLibraryEvent>((event, emit) async {
      emit(LibraryLoading());
      final books = await _getBooks();
      emit(LibraryLoaded(books));
    });

    on<AddBookEvent>((event, emit) async {
      emit(LibraryLoading());
      try {
        await _addBook(event.filePath);
        final books = await _getBooks();
        print("📥 Đã load được ${books.length} cuốn sách từ DB");
        emit(LibraryLoaded(books));
      } catch (e) {
        print("❌ Lỗi trong Bloc: $e");
        final books = await _getBooks();
        emit(LibraryLoaded(books));
      }
    });

    on<DeleteBookEvent>((event, emit) async {
      emit(LibraryLoading());
      try {
        await _deleteBook(event.book.id);
        final books = await _getBooks();
        emit(LibraryLoaded(books));
      } catch (e) {
        print("❌ Lỗi khi xóa sách: $e");
        final books = await _getBooks();
        emit(LibraryLoaded(books));
      }
    });
  }
}
