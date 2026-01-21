part of 'reader_bloc.dart';

class ReaderState extends Equatable {
  final bool isLoading;
  final String bookTitle;
  final List<Chapter> chapters;
  final int currentIndex;
  final Chapter? currentChapter;
  final String? currentFilePath;
  final double fontSize;
  final bool isDarkMode;
  final ReaderLayout layout;
  final int contentUpdateTimestamp;

  const ReaderState({
    this.isLoading = true,
    this.bookTitle = "Sách chưa mở",
    this.chapters = const [],
    this.currentIndex = 0,
    this.currentChapter,
    this.currentFilePath,
    this.fontSize = 16.0,
    this.isDarkMode = false,
    this.layout = ReaderLayout.single,
    this.contentUpdateTimestamp = 0,
  });

  ReaderState copyWith({
    bool? isLoading,
    String? bookTitle,
    List<Chapter>? chapters,
    int? currentIndex,
    Chapter? currentChapter,
    bool resetCurrentChapter = false,
    String? currentFilePath,
    double? fontSize,
    bool? isDarkMode,
    ReaderLayout? layout,
    int? contentUpdateTimestamp,
  }) {
    return ReaderState(
      isLoading: isLoading ?? this.isLoading,
      bookTitle: bookTitle ?? this.bookTitle,
      chapters: chapters ?? this.chapters,
      currentIndex: currentIndex ?? this.currentIndex,
      currentChapter:
          resetCurrentChapter ? null : (currentChapter ?? this.currentChapter),
      currentFilePath: currentFilePath ?? this.currentFilePath,
      fontSize: fontSize ?? this.fontSize,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      layout: layout ?? this.layout,
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
    currentChapter,
    currentFilePath,
    fontSize,
    isDarkMode,
    layout,
    contentUpdateTimestamp,
  ];
}
