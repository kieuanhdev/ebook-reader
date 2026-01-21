part of 'reader_bloc.dart';

abstract class ReaderEvent extends Equatable {
  const ReaderEvent();
  @override
  List<Object?> get props => [];
}

// 1. Cập nhật InitEvent để nhận đường dẫn sách
class ReaderInitEvent extends ReaderEvent {
  final String? filePath; // Có thể null nếu mở lại sách cũ
  const ReaderInitEvent([this.filePath]);

  @override
  List<Object?> get props => [filePath];
}

// 2. XÓA class ReaderPickFileEvent (Không dùng nữa)

class ReaderChangeChapterEvent extends ReaderEvent {
  final int step;
  const ReaderChangeChapterEvent(this.step);
  @override
  List<Object> get props => [step];
}

class ReaderJumpToChapterEvent extends ReaderEvent {
  final int index;
  const ReaderJumpToChapterEvent(this.index);
  @override
  List<Object> get props => [index];
}

class ReaderSettingsUpdateEvent extends ReaderEvent {
  final double? fontSize;
  final bool? isDarkMode;
  const ReaderSettingsUpdateEvent({this.fontSize, this.isDarkMode});
  @override
  List<Object?> get props => [fontSize, isDarkMode];
}
