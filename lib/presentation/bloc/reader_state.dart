part of 'reader_bloc.dart';

// ĐÃ XÓA DÒNG IMPORT Ở ĐÂY

class ReaderState extends Equatable {
  final bool isLoading;
  final String bookTitle;
  final List<Chapter> chapters; // File cha sẽ lo việc import class Chapter này
  final int currentIndex;
  final String? currentFilePath;
  final double fontSize;
  final bool isDarkMode;
  final int contentUpdateTimestamp;

  const ReaderState({
    this.isLoading = true,
    this.bookTitle = "Sách chưa mở",
    this.chapters = const [],
    this.currentIndex = 0,
    this.currentFilePath,
    this.fontSize = 16.0,
    this.isDarkMode = false,
    this.contentUpdateTimestamp = 0,
  });

  ReaderState copyWith({
    bool? isLoading,
    String? bookTitle,
    List<Chapter>? chapters,
    int? currentIndex,
    String? currentFilePath,
    double? fontSize,
    bool? isDarkMode,
    int? contentUpdateTimestamp,
  }) {
    return ReaderState(
      isLoading: isLoading ?? this.isLoading,
      bookTitle: bookTitle ?? this.bookTitle,
      chapters: chapters ?? this.chapters,
      currentIndex: currentIndex ?? this.currentIndex,
      currentFilePath: currentFilePath ?? this.currentFilePath,
      fontSize: fontSize ?? this.fontSize,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      contentUpdateTimestamp:
          contentUpdateTimestamp ?? this.contentUpdateTimestamp,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    bookTitle,
    chapters,
    currentIndex,
    currentFilePath,
    fontSize,
    isDarkMode,
    contentUpdateTimestamp,
  ];
}
