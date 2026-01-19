import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_ebook_reader/core/html_helper.dart';
import 'package:my_ebook_reader/presentation/screens/reader_drawer.dart';
import 'package:my_ebook_reader/presentation/screens/reader_settings_dialog.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../data/repositories/ebook_repository_impl.dart';

import '../bloc/reader_bloc.dart';

class EbookReaderScreen extends StatelessWidget {
  const EbookReaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject Bloc vào cây Widget
    return BlocProvider(
      create: (context) =>
          ReaderBloc(repository: EbookRepositoryImpl())
            ..add(ReaderInitEvent()), // Gọi Init ngay khi tạo
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

  @override
  void initState() {
    super.initState();
    _initWebview();
  }

  Future<void> _initWebview() async {
    try {
      await _webviewController.initialize();

      if (!mounted) return;

      setState(() => _isWebviewInitialized = true);

      // --- ĐOẠN FIX QUAN TRỌNG ---
      // Ngay khi Webview sẵn sàng, hãy kiểm tra xem BLoC đã có dữ liệu chưa.
      // Nếu BLoC đã load xong từ trước, ta phải nạp dữ liệu đó vào ngay.
      final currentBlocState = context.read<ReaderBloc>().state;

      // Chỉ nạp nếu đã hết loading
      if (!currentBlocState.isLoading) {
        _syncWebview(currentBlocState);
      }
      // ---------------------------
    } catch (e) {
      print("Lỗi khởi tạo Webview: $e");
    }
  }

  // Hàm đồng bộ State -> Webview
  void _syncWebview(ReaderState state) {
    if (!_isWebviewInitialized) return;

    // 1. Cập nhật màu nền
    _webviewController.setBackgroundColor(
      state.isDarkMode ? const Color(0xFF121212) : Colors.white,
    );

    // 2. Tạo HTML và load
    String html = state.chapters.isNotEmpty
        ? HtmlHelper.generateChapterHtml(
            chapter: state.chapters[state.currentIndex],
            fontSize: state.fontSize,
            isDarkMode: state.isDarkMode,
          )
        : HtmlHelper.generateWelcomeHtml();

    _webviewController.loadStringContent(html);
  }

  @override
  Widget build(BuildContext context) {
    // BlocConsumer = Listener (Logic ngầm) + Builder (Vẽ UI)
    return BlocConsumer<ReaderBloc, ReaderState>(
      listenWhen: (prev, curr) =>
          prev.contentUpdateTimestamp != curr.contentUpdateTimestamp,
      listener: (context, state) => _syncWebview(state),

      builder: (context, state) {
        final bloc = context.read<ReaderBloc>();

        return Scaffold(
          appBar: AppBar(
            title: Text(state.bookTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ReaderSettingsDialog(
                    isDarkMode: state.isDarkMode,
                    fontSize: state.fontSize,
                    onSettingsChanged: (isDark, size) => bloc.add(
                      ReaderSettingsUpdateEvent(
                        isDarkMode: isDark,
                        fontSize: size,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.folder_open),
                onPressed: () => bloc.add(ReaderPickFileEvent()),
              ),
            ],
          ),
          drawer: ReaderDrawer(
            chapters: state.chapters,
            currentIndex: state.currentIndex,
            onChapterTap: (index) => bloc.add(ReaderJumpToChapterEvent(index)),
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
                  color: Colors.grey[200],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: state.currentIndex > 0
                            ? () => bloc.add(const ReaderChangeChapterEvent(-1))
                            : null,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text("Trước"),
                      ),
                      Text(
                        "Chương ${state.currentIndex + 1} / ${state.chapters.length}",
                      ),
                      ElevatedButton.icon(
                        onPressed:
                            state.currentIndex < state.chapters.length - 1
                            ? () => bloc.add(const ReaderChangeChapterEvent(1))
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
