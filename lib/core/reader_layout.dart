enum ReaderLayout { single, spread, scroll }

ReaderLayout readerLayoutFromString(String? value) {
  switch (value) {
    case 'spread':
      return ReaderLayout.spread;
    case 'scroll':
      return ReaderLayout.scroll;
    case 'single':
    default:
      return ReaderLayout.single;
  }
}

String readerLayoutToString(ReaderLayout layout) {
  switch (layout) {
    case ReaderLayout.spread:
      return 'spread';
    case ReaderLayout.scroll:
      return 'scroll';
    case ReaderLayout.single:
      return 'single';
  }
}
