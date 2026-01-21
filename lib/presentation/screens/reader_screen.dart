import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_ebook_reader/injection.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../core/html_helper.dart'; // Đảm bảo đường dẫn đúng
import '../bloc/reader_bloc.dart';
import 'reader_drawer.dart';
import 'reader_settings_dialog.dart';

class EbookReaderScreen extends StatelessWidget {
  // 1. Thêm biến nhận đường dẫn sách
  final String bookPath;

  const EbookReaderScreen({
    super.key,
    required this.bookPath, // Bắt buộc phải truyền vào
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // 2. Truyền đường dẫn sách vào Event khởi tạo
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

  @override
  void initState() {
    super.initState();
    _initWebview();
  }

  Future<void> _initWebview() async {
    try {
      await _webviewController.initialize();

      // Quan trọng: Phải lắng nghe URL loading error nếu có
      _webviewController.loadingState.listen((event) {
        if (event == LoadingState.navigationCompleted) {
          // Webview load xong
        }
      });

      if (!mounted) return;

      setState(() => _isWebviewInitialized = true);

      // --- ĐOẠN FIX QUAN TRỌNG ---
      // Kiểm tra xem Bloc đã load xong dữ liệu chưa để nạp vào Webview ngay
      final currentBlocState = context.read<ReaderBloc>().state;
      if (!currentBlocState.isLoading && currentBlocState.chapters.isNotEmpty) {
        _syncWebview(currentBlocState);
      }
      // ---------------------------
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

  // Hàm đồng bộ State -> Webview
  void _syncWebview(ReaderState state) {
    if (!_isWebviewInitialized) return;

    // 1. Cập nhật màu nền
    _webviewController.setBackgroundColor(
      state.isDarkMode ? const Color(0xFF121212) : Colors.white,
    );

    // 2. Tạo HTML và load
    // Kiểm tra danh sách chương có trống không để tránh lỗi IndexOutOfBound
    String html = "";
    if (state.chapters.isNotEmpty &&
        state.currentIndex < state.chapters.length) {
      html = HtmlHelper.generateChapterHtml(
        chapter: state.chapters[state.currentIndex],
        fontSize: state.fontSize,
        isDarkMode: state.isDarkMode,
      );
    } else {
      html = HtmlHelper.generateWelcomeHtml(); // Hoặc HTML báo lỗi/loading
    }

    _webviewController.loadStringContent(html);
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
                    onSettingsChanged: (isDark, size) => bloc.add(
                      ReaderSettingsUpdateEvent(
                        isDarkMode: isDark,
                        fontSize: size,
                      ),
                    ),
                  ),
                ),
              ),
              // 3. ĐÃ XÓA NÚT "CHỌN FILE" (Folder Icon) Ở ĐÂY
              // Vì chọn file giờ là nhiệm vụ của Tủ Sách
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

              // Thanh điều hướng (Next/Prev)
              if (state.chapters.isNotEmpty)
                Container(
                  color: state.isDarkMode
                      ? Colors.black87
                      : Colors.grey[200], // Sửa màu nền theo theme
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

                      // Hiển thị số trang linh hoạt hơn
                      Text(
                        "${state.currentIndex + 1} / ${state.chapters.length}",
                        style: TextStyle(
                          color: state.isDarkMode ? Colors.white : Colors.black,
                        ),
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
