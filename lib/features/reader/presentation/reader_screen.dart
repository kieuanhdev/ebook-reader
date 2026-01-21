import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_ebook_reader/app/di/injection.dart';
import 'package:webview_windows/webview_windows.dart';

import 'package:my_ebook_reader/core/html_helper.dart';
import 'package:my_ebook_reader/core/reader_layout.dart';
import 'package:my_ebook_reader/features/reader/presentation/bloc/reader_bloc.dart';
import 'package:my_ebook_reader/features/reader/presentation/reader_drawer.dart';
import 'package:my_ebook_reader/features/reader/presentation/reader_settings_dialog.dart';

class EbookReaderScreen extends StatelessWidget {
  final String bookPath;

  const EbookReaderScreen({
    super.key,
    required this.bookPath,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ReaderBloc>()..add(ReaderInitEvent(bookPath)),
      child: const _EbookReaderView(),
    );
  }
}

class _EbookReaderView extends StatefulWidget {
  const _EbookReaderView();

  @override
  State<_EbookReaderView> createState() => _EbookReaderViewState();
}

class _EbookReaderViewState extends State<_EbookReaderView> {
  final _webviewController = WebviewController();
  bool _isWebviewInitialized = false;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _pendingPaginationUpdate = false;
  bool _pendingGoToLastPage = false;

  @override
  void initState() {
    super.initState();
    _initWebview();
  }

  Future<void> _initWebview() async {
    try {
      await _webviewController.initialize();

      _webviewController.loadingState.listen((event) {
        if (event == LoadingState.navigationCompleted &&
            _pendingPaginationUpdate) {
          _pendingPaginationUpdate = false;
          _refreshPagination();
        }
      });

      if (!mounted) return;

      setState(() => _isWebviewInitialized = true);

      final currentBlocState = context.read<ReaderBloc>().state;
      if (!currentBlocState.isLoading && currentBlocState.chapters.isNotEmpty) {
        _syncWebview(currentBlocState);
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Lỗi Webview"),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  void _syncWebview(ReaderState state) {
    if (!_isWebviewInitialized) return;

    _webviewController.setBackgroundColor(
      state.isDarkMode ? const Color(0xFF121212) : Colors.white,
    );

    String html = "";
    if (state.currentChapter != null && state.currentChapter!.hasContent) {
      html = HtmlHelper.generateChapterHtml(
        chapter: state.currentChapter!,
        fontSize: state.fontSize,
        isDarkMode: state.isDarkMode,
        layoutMode: readerLayoutToString(state.layout),
      );
    } else if (state.isLoading) {
      html = HtmlHelper.generateLoadingHtml();
    } else {
      html = HtmlHelper.generateWelcomeHtml();
    }

    if (state.layout != ReaderLayout.scroll) {
      _currentPage = 1;
      _totalPages = 1;
      _pendingPaginationUpdate = true;
    }

    _webviewController.loadStringContent(html);
  }

  Future<void> _refreshPagination() async {
    if (!mounted) return;
    final total = await _callPageScript(
      'window.readerPaging?.getPageCount?.() ?? 1',
      fallback: 1,
    );
    final current = await _callPageScript(
      'window.readerPaging?.getCurrentPage?.() ?? 1',
      fallback: 1,
    );

    if (!mounted) return;
    setState(() {
      _totalPages = total;
      _currentPage = current;
    });

    if (_pendingGoToLastPage) {
      _pendingGoToLastPage = false;
      await _goToPage(_totalPages);
    }
  }

  Future<int> _callPageScript(String script, {int fallback = 1}) async {
    try {
      final raw = await _webviewController.executeScript(script);
      if (raw == null) return fallback;
      final match = RegExp(r'-?\\d+(\\.\\d+)?').firstMatch(raw.toString());
      final parsed = match != null ? double.tryParse(match.group(0)!) : null;
      return parsed?.round() ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _goToPage(int page) async {
    final updated = await _callPageScript(
      'window.readerPaging?.goToPage?.($page) ?? $page',
      fallback: page,
    );
    if (!mounted) return;
    setState(() => _currentPage = updated);
  }

  Future<void> _nextPageOrChapter(ReaderBloc bloc, ReaderState state) async {
    if (state.layout == ReaderLayout.scroll) return;
    if (_currentPage < _totalPages) {
      await _goToPage(_currentPage + 1);
      return;
    }
    if (state.currentIndex < state.chapters.length - 1) {
      bloc.add(const ReaderChangeChapterEvent(1));
    }
  }

  Future<void> _prevPageOrChapter(ReaderBloc bloc, ReaderState state) async {
    if (state.layout == ReaderLayout.scroll) return;
    if (_currentPage > 1) {
      await _goToPage(_currentPage - 1);
      return;
    }
    if (state.currentIndex > 0) {
      _pendingGoToLastPage = true;
      bloc.add(const ReaderChangeChapterEvent(-1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReaderBloc, ReaderState>(
      listenWhen: (prev, curr) =>
          prev.contentUpdateTimestamp != curr.contentUpdateTimestamp,
      listener: (context, state) => _syncWebview(state),
      builder: (context, state) {
        final bloc = context.read<ReaderBloc>();

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: "Quay lại thư viện",
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(state.bookTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ReaderSettingsDialog(
                    isDarkMode: state.isDarkMode,
                    fontSize: state.fontSize,
                    layout: state.layout,
                    onSettingsChanged: (isDark, size) => bloc.add(
                      ReaderSettingsUpdateEvent(
                        isDarkMode: isDark,
                        fontSize: size,
                      ),
                    ),
                    onLayoutChanged: (layout) => bloc.add(
                      ReaderSettingsUpdateEvent(layout: layout),
                    ),
                  ),
                ),
              ),
            ],
          ),
          drawer: ReaderDrawer(
            chapters: state.chapters,
            currentIndex: state.currentIndex,
            onChapterTap: (index) {
              bloc.add(ReaderJumpToChapterEvent(index));
            },
          ),
          body: Column(
            children: [
              Expanded(
                child: _isWebviewInitialized && !state.isLoading
                    ? Webview(_webviewController)
                    : const Center(child: CircularProgressIndicator()),
              ),
              if (state.chapters.isNotEmpty)
                Container(
                  color: state.isDarkMode
                      ? Colors.black87
                      : Colors.grey[200],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: state.layout == ReaderLayout.scroll
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton.icon(
                              onPressed: state.currentIndex > 0
                                  ? () => bloc.add(
                                        const ReaderChangeChapterEvent(-1),
                                      )
                                  : null,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text("Trước"),
                            ),
                            Text(
                              "${state.currentIndex + 1} / ${state.chapters.length}",
                              style: TextStyle(
                                color: state.isDarkMode
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed:
                                  state.currentIndex < state.chapters.length - 1
                                      ? () => bloc.add(
                                            const ReaderChangeChapterEvent(1),
                                          )
                                      : null,
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text("Sau"),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton.icon(
                              onPressed:
                                  _currentPage > 1 || state.currentIndex > 0
                                      ? () => _prevPageOrChapter(bloc, state)
                                      : null,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text("Trước"),
                            ),
                            Text(
                              "Trang $_currentPage / $_totalPages",
                              style: TextStyle(
                                color: state.isDarkMode
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _currentPage < _totalPages ||
                                      state.currentIndex <
                                          state.chapters.length - 1
                                  ? () => _nextPageOrChapter(bloc, state)
                                  : null,
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text("Sau"),
                            ),
                          ],
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}
