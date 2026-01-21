import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

import 'package:my_ebook_reader/core/reader_layout.dart';
import 'package:my_ebook_reader/features/reader/domain/entities/chapter.dart';
import 'package:my_ebook_reader/features/reader/domain/usecases/load_chapter_html.dart';
import 'package:my_ebook_reader/features/reader/domain/usecases/load_last_book.dart';
import 'package:my_ebook_reader/features/reader/domain/usecases/load_progress.dart';
import 'package:my_ebook_reader/features/reader/domain/usecases/load_settings.dart';
import 'package:my_ebook_reader/features/reader/domain/usecases/parse_book.dart';
import 'package:my_ebook_reader/features/reader/domain/usecases/save_progress.dart';
import 'package:my_ebook_reader/features/reader/domain/usecases/save_settings.dart';

part 'reader_event.dart';
part 'reader_state.dart';

@injectable
class ReaderBloc extends Bloc<ReaderEvent, ReaderState> {
  final LoadSettings _loadSettings;
  final ParseBook _parseBook;
  final LoadProgress _loadProgress;
  final LoadLastBook _loadLastBook;
  final LoadChapterHtml _loadChapterHtml;
  final SaveProgress _saveProgress;
  final SaveSettings _saveSettings;

  ReaderBloc(
    this._loadSettings,
    this._parseBook,
    this._loadProgress,
    this._loadLastBook,
    this._loadChapterHtml,
    this._saveProgress,
    this._saveSettings,
  ) : super(const ReaderState()) {
    on<ReaderInitEvent>(_onInit);
    on<ReaderChangeChapterEvent>(_onChangeChapter);
    on<ReaderJumpToChapterEvent>(_onJumpToChapter);
    on<ReaderSettingsUpdateEvent>(_onSettingsUpdate);
  }

  Future<void> _onInit(ReaderInitEvent event, Emitter<ReaderState> emit) async {
    var (size, isDark, layout) = await _loadSettings();

    emit(
      state.copyWith(
        fontSize: size,
        isDarkMode: isDark,
        layout: layout,
        isLoading: true,
      ),
    );

    try {
      if (event.filePath != null) {
        final path = event.filePath!;

        var (chapters, title) = await _parseBook(path);

        int savedIndex = await _loadProgress(path);

        final safeIndex = savedIndex.clamp(0, chapters.length - 1);
        final currentChapter = await _loadChapterContent(
          path,
          chapters,
          safeIndex,
        );

        emit(
          state.copyWith(
            isLoading: false,
            chapters: chapters,
            currentFilePath: path,
            currentIndex: safeIndex,
            currentChapter: currentChapter,
            bookTitle: title,
            contentUpdateTimestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } else {
        var history = await _loadLastBook();

        if (history != null) {
          var (chapters, path, index) = history;
          String titleFromPath = p.basename(path);

          final safeIndex = index.clamp(0, chapters.length - 1);
          final currentChapter = await _loadChapterContent(
            path,
            chapters,
            safeIndex,
          );

          emit(
            state.copyWith(
              isLoading: false,
              chapters: chapters,
              currentFilePath: path,
              currentIndex: safeIndex,
              currentChapter: currentChapter,
              bookTitle: titleFromPath,
              contentUpdateTimestamp: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        } else {
          emit(state.copyWith(isLoading: false));
        }
      }
    } catch (e) {
      print("❌ Lỗi ReaderBloc: $e");
      emit(state.copyWith(isLoading: false));
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
    if (state.currentFilePath == null ||
        event.index < 0 ||
        event.index >= state.chapters.length) {
      return;
    }

    emit(
      state.copyWith(
        currentIndex: event.index,
        isLoading: true,
        resetCurrentChapter: true,
      ),
    );

    final currentChapter = await _loadChapterContent(
      state.currentFilePath!,
      state.chapters,
      event.index,
    );

    emit(
      state.copyWith(
        isLoading: false,
        currentChapter: currentChapter,
        contentUpdateTimestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    await _saveProgress(
      state.currentFilePath!,
      event.index,
      state.chapters.length,
    );
  }

  Future<void> _onSettingsUpdate(
    ReaderSettingsUpdateEvent event,
    Emitter<ReaderState> emit,
  ) async {
    final newSize = event.fontSize ?? state.fontSize;
    final newMode = event.isDarkMode ?? state.isDarkMode;
    final newLayout = event.layout ?? state.layout;

    await _saveSettings(newSize, newMode, newLayout);

    emit(
      state.copyWith(
        fontSize: newSize,
        isDarkMode: newMode,
        layout: newLayout,
        contentUpdateTimestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<Chapter?> _loadChapterContent(
    String filePath,
    List<Chapter> chapters,
    int index,
  ) async {
    if (index < 0 || index >= chapters.length) return null;
    final chapter = chapters[index];
    if (chapter.hasContent) return chapter;

    try {
      final html = await _loadChapterHtml(filePath, chapter);
      return chapter.copyWith(htmlContent: html);
    } catch (_) {
      return chapter;
    }
  }
}
