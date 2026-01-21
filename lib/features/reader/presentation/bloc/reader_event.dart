part of 'reader_bloc.dart';

abstract class ReaderEvent extends Equatable {
  const ReaderEvent();
  @override
  List<Object?> get props => [];
}

class ReaderInitEvent extends ReaderEvent {
  final String? filePath;
  const ReaderInitEvent([this.filePath]);

  @override
  List<Object?> get props => [filePath];
}

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
  final ReaderLayout? layout;
  const ReaderSettingsUpdateEvent({
    this.fontSize,
    this.isDarkMode,
    this.layout,
  });
  @override
  List<Object?> get props => [fontSize, isDarkMode, layout];
}
