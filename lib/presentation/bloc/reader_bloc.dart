import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p; // Dùng để lấy tên file nếu cần

import '../../core/reader_layout.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/repositories/ebook_repository.dart';

part 'reader_event.dart';
part 'reader_state.dart';

@injectable
class ReaderBloc extends Bloc<ReaderEvent, ReaderState> {
  final EbookRepository _repository;

  ReaderBloc({required EbookRepository repository})
    : _repository = repository,
      super(const ReaderState()) {
    on<ReaderInitEvent>(_onInit);
    on<ReaderChangeChapterEvent>(_onChangeChapter);
    on<ReaderJumpToChapterEvent>(_onJumpToChapter);
    on<ReaderSettingsUpdateEvent>(_onSettingsUpdate);
  }

  Future<void> _onInit(ReaderInitEvent event, Emitter<ReaderState> emit) async {
    // 1. Load cài đặt giao diện (Font, DarkMode)
    var (size, isDark, layout) = await _repository.loadSettings();

    // Cập nhật state ban đầu và bật loading
    emit(
      state.copyWith(
        fontSize: size,
        isDarkMode: isDark,
        layout: layout,
        isLoading: true,
      ),
    );

    try {
      // 2. Kiểm tra đầu vào: Có đường dẫn file mới hay là resume sách cũ?
      if (event.filePath != null) {
        // --- TRƯỜNG HỢP A: MỞ SÁCH TỪ TỦ SÁCH ---
        final path = event.filePath!;

        // Gọi Repository để parse file epub từ đường dẫn
        // Hàm này trả về: Danh sách chương (List<Chapter>) và Tên sách (String)
        var (chapters, title) = await _repository.parseBook(path);

        // Load tiến độ đọc đã lưu của cuốn sách này (nếu có)
        int savedIndex = await _repository.loadProgress(path);

        final safeIndex = savedIndex.clamp(0, chapters.length - 1);
        final currentChapter = await _loadChapterContent(path, chapters, safeIndex);

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
        // --- TRƯỜNG HỢP B: RESUME (MỞ LẠI APP) ---
        // Load cuốn sách cuối cùng đang đọc dở
        var history = await _repository.loadLastBook();

        if (history != null) {
          var (chapters, path, index) = history;
          // Lấy tên file làm tiêu đề tạm thời vì loadLastBook chỉ trả về path
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
              bookTitle: titleFromPath, // Hoặc để "Đang đọc tiếp..."
              contentUpdateTimestamp: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        } else {
          // Không có lịch sử đọc, tắt loading
          emit(state.copyWith(isLoading: false));
        }
      }
    } catch (e) {
      print("❌ Lỗi ReaderBloc: $e");
      // Tắt loading nếu gặp lỗi để tránh treo màn hình
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

    // 1. Cập nhật UI ngay lập tức
    emit(
      state.copyWith(
        currentIndex: event.index,
        isLoading: true,
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

    // 2. Lưu tiến độ xuống ổ cứng (chạy ngầm)
    await _repository.saveProgress(
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

    // Lưu settings
    await _repository.saveSettings(newSize, newMode, newLayout);

    // Cập nhật UI
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
      final html = await _repository.loadChapterHtml(filePath, chapter);
      return chapter.copyWith(htmlContent: html);
    } catch (_) {
      return chapter;
    }
  }
}
