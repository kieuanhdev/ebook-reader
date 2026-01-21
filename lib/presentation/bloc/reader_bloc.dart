import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p; // Dùng để lấy tên file nếu cần

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
    var (size, isDark) = await _repository.loadSettings();

    // Cập nhật state ban đầu và bật loading
    emit(state.copyWith(fontSize: size, isDarkMode: isDark, isLoading: true));

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

        emit(
          state.copyWith(
            isLoading: false,
            chapters: chapters,
            currentFilePath: path,
            currentIndex: savedIndex,
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

          emit(
            state.copyWith(
              isLoading: false,
              chapters: chapters,
              currentFilePath: path,
              currentIndex: index,
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
    // 1. Cập nhật UI ngay lập tức
    emit(
      state.copyWith(
        currentIndex: event.index,
        contentUpdateTimestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    // 2. Lưu tiến độ xuống ổ cứng (chạy ngầm)
    if (state.currentFilePath != null) {
      await _repository.saveProgress(
        state.currentFilePath!,
        event.index,
        state.chapters.length,
      );
    }
  }

  Future<void> _onSettingsUpdate(
    ReaderSettingsUpdateEvent event,
    Emitter<ReaderState> emit,
  ) async {
    final newSize = event.fontSize ?? state.fontSize;
    final newMode = event.isDarkMode ?? state.isDarkMode;

    // Lưu settings
    await _repository.saveSettings(newSize, newMode);

    // Cập nhật UI
    emit(
      state.copyWith(
        fontSize: newSize,
        isDarkMode: newMode,
        contentUpdateTimestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
