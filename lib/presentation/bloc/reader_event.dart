part of 'reader_bloc.dart';

sealed class ReaderEvent extends Equatable {
  const ReaderEvent();

  @override
  // Sửa lỗi: Thêm dấu ? vào Object để đúng chuẩn Equatable
  List<Object?> get props => [];
}

class ReaderInitEvent extends ReaderEvent {}

class ReaderPickFileEvent extends ReaderEvent {}

class ReaderChangeChapterEvent extends ReaderEvent {
  final int step;
  const ReaderChangeChapterEvent(this.step);

  @override
  // Sửa lỗi: Phải đưa biến step vào props để so sánh
  List<Object?> get props => [step];
}

class ReaderJumpToChapterEvent extends ReaderEvent {
  final int index;
  const ReaderJumpToChapterEvent(this.index);

  @override
  // Sửa lỗi: Phải đưa biến index vào props
  List<Object?> get props => [index];
}

class ReaderSettingsUpdateEvent extends ReaderEvent {
  final double? fontSize;
  final bool? isDarkMode;

  const ReaderSettingsUpdateEvent({this.fontSize, this.isDarkMode});

  @override
  // Sửa lỗi: Phải đưa các biến vào props
  List<Object?> get props => [fontSize, isDarkMode];
}
