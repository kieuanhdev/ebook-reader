import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/repositories/ebook_repository.dart';
import 'package:injectable/injectable.dart'; // Import

part 'reader_event.dart';
part 'reader_state.dart';

@injectable
class ReaderBloc extends Bloc<ReaderEvent, ReaderState> {
  final EbookRepository _repository;

  ReaderBloc({required EbookRepository repository})
    : _repository = repository,
      super(const ReaderState()) {
    on<ReaderInitEvent>(_onInit);
    on<ReaderPickFileEvent>(_onPickFile);
    on<ReaderChangeChapterEvent>(_onChangeChapter);
    on<ReaderJumpToChapterEvent>(_onJumpToChapter);
    on<ReaderSettingsUpdateEvent>(_onSettingsUpdate);
  }

  Future<void> _onInit(ReaderInitEvent event, Emitter<ReaderState> emit) async {
    var (size, isDark) = await _repository.loadSettings();
    var history = await _repository.loadLastBook();

    if (history != null) {
      var (chapters, path, index) = history;
      emit(
        state.copyWith(
          isLoading: false,
          fontSize: size,
          isDarkMode: isDark,
          chapters: chapters,
          currentFilePath: path,
          currentIndex: index,
          bookTitle: "Đang đọc sách",
          contentUpdateTimestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } else {
      emit(
        state.copyWith(
          isLoading: false,
          fontSize: size,
          isDarkMode: isDark,
          contentUpdateTimestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  Future<void> _onPickFile(
    ReaderPickFileEvent event,
    Emitter<ReaderState> emit,
  ) async {
    try {
      var (chapters, path) = await _repository.pickAndParseBook();
      await _repository.saveProgress(path, 0);
      emit(
        state.copyWith(
          chapters: chapters,
          currentFilePath: path,
          currentIndex: 0,
          bookTitle: "Sách mới",
          contentUpdateTimestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (e) {
      // Xử lý lỗi nếu cần
    }
  }

  Future<void> _onChangeChapter(
    ReaderChangeChapterEvent event,
    Emitter<ReaderState> emit,
  ) async {
    int newIndex = state.currentIndex + event.step;
    if (newIndex >= 0 && newIndex < state.chapters.length) {
      add(ReaderJumpToChapterEvent(newIndex));
    }
  }

  Future<void> _onJumpToChapter(
    ReaderJumpToChapterEvent event,
    Emitter<ReaderState> emit,
  ) async {
    emit(
      state.copyWith(
        currentIndex: event.index,
        contentUpdateTimestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (state.currentFilePath != null) {
      _repository.saveProgress(state.currentFilePath!, event.index);
    }
  }

  Future<void> _onSettingsUpdate(
    ReaderSettingsUpdateEvent event,
    Emitter<ReaderState> emit,
  ) async {
    final newSize = event.fontSize ?? state.fontSize;
    final newMode = event.isDarkMode ?? state.isDarkMode;
    await _repository.saveSettings(newSize, newMode);
    emit(
      state.copyWith(
        fontSize: newSize,
        isDarkMode: newMode,
        contentUpdateTimestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
