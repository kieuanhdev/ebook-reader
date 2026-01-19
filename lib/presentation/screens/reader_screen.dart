import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

// Import các file Clean Architecture
import '../../domain/entities/chapter.dart';
import '../../domain/repositories/ebook_repository.dart';
import '../../data/repositories/ebook_repository_impl.dart';

class EbookReaderScreen extends StatefulWidget {
  const EbookReaderScreen({super.key});

  @override
  State<EbookReaderScreen> createState() => _EbookReaderScreenState();
}

class _EbookReaderScreenState extends State<EbookReaderScreen> {
  final _controller = WebviewController();

  // Khởi tạo Repository (Lớp Data)
  final EbookRepository _repository = EbookRepositoryImpl();

  bool _isWebviewReady = false;
  String _bookTitle = "Sách chưa mở";

  List<Chapter> _chapters = [];
  int _currentIndex = 0;
  String? _currentFilePath;

  double _fontSize = 16.0;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    initWebview();
  }

  Future<void> initWebview() async {
    try {
      await _controller.initialize();
      // await _controller.setBackgroundColor(Colors.white);

      if (!mounted) return;
      setState(() => _isWebviewReady = true);

      // Đợi Webview ổn định
      await Future.delayed(const Duration(milliseconds: 500));

      // 1. LOAD SETTINGS TRƯỚC
      var (size, isDark) = await _repository.loadSettings();
      setState(() {
        _fontSize = size;
        _isDarkMode = isDark;
      });
      // Cập nhật màu nền Webview ngay lập tức cho đỡ nháy
      await _updateWebviewBackground();

      // Gọi lớp Data để lấy lịch sử
      var history = await _repository.loadLastBook();

      if (history != null) {
        // Tách dữ liệu trả về (Dart 3 Pattern Matching)
        var (chapters, path, index) = history;
        _loadBookToUI(chapters, path, index);
      } else {
        _showWelcome();
      }
    } catch (e) {
      print("Lỗi init: $e");
    }
  }

  // Hàm phụ để set màu nền cho khung Webview (tránh viền trắng khi ở Dark mode)
  Future<void> _updateWebviewBackground() async {
    if (_isDarkMode) {
      await _controller.setBackgroundColor(
        const Color(0xFF121212),
      ); // Màu đen xám
    } else {
      await _controller.setBackgroundColor(Colors.white);
    }
  }

  // Hàm cập nhật giao diện khi có dữ liệu sách
  void _loadBookToUI(List<Chapter> chapters, String path, int index) {
    setState(() {
      _chapters = chapters;
      _currentFilePath = path;
      // Kiểm tra index hợp lệ
      _currentIndex = (index >= 0 && index < chapters.length) ? index : 0;
      _bookTitle = "Đang đọc sách";
    });
    _displayCurrentChapter();
  }

  // Sự kiện bấm nút mở file
  Future<void> _onPickFile() async {
    try {
      var (chapters, path) = await _repository.pickAndParseBook();
      _loadBookToUI(chapters, path, 0); // Mở sách mới thì về chương 0
      _repository.saveProgress(path, 0); // Lưu lại ngay
    } catch (e) {
      print("Lỗi hoặc hủy chọn file: $e");
    }
  }

  // Hiển thị nội dung HTML lên Webview
  void _displayCurrentChapter() {
    if (_chapters.isEmpty) return;
    var chapter = _chapters[_currentIndex];

    // --- CSS ĐỘNG DỰA TRÊN SETTINGS ---
    String cssColor = _isDarkMode ? "#dddddd" : "#000000"; // Màu chữ
    String cssBg = _isDarkMode ? "#121212" : "#ffffff"; // Màu nền

    // CSS làm đẹp
    String html =
        """
      <style>
        body { 
          font-family: Arial, sans-serif; 
          line-height: 1.6; 
          padding: 20px; 
          max-width: 800px; 
          margin: 0 auto;
          
          /* Áp dụng biến settings */
          font-size: ${_fontSize}px;
          color: $cssColor;
          background-color: $cssBg;
        }
        img { max-width: 100%; height: auto; }
      </style>
      ${chapter.htmlContent}
    """;
    _controller.loadStringContent(html);

    _updateWebviewBackground();
  }

  void _showWelcome() {
    _controller.loadStringContent("""
      <div style="text-align: center; padding-top: 50px; font-family: sans-serif;">
        <h1>Chào mừng!</h1>
        <p>Bấm vào icon thư mục để mở sách EPUB.</p>
      </div>
    """);
  }

  void _changeChapter(int step) {
    int newIndex = _currentIndex + step;
    if (newIndex >= 0 && newIndex < _chapters.length) {
      setState(() => _currentIndex = newIndex);
      _displayCurrentChapter();

      // Gọi repository để lưu tiến độ
      if (_currentFilePath != null) {
        _repository.saveProgress(_currentFilePath!, _currentIndex);
      }
    }
  }

  // --- UI MỤC LỤC ---
  Widget? _buildDrawer() {
    // Nếu chưa có sách thì không hiện mục lục
    if (_chapters.isEmpty) return null;

    return Drawer(
      child: Column(
        children: [
          // Phần tiêu đề đầu mục lục
          Container(
            padding: const EdgeInsets.only(top: 40, bottom: 20, left: 20),
            width: double.infinity,
            color: Colors.blue,
            child: const Text(
              "Mục lục",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Danh sách cuộn
          Expanded(
            child: ListView.builder(
              itemCount: _chapters.length,
              itemBuilder: (context, index) {
                // Kiểm tra xem đây có phải chương đang đọc không
                bool isActive = index == _currentIndex;

                return ListTile(
                  title: Text(
                    _chapters[index].title,
                    style: TextStyle(
                      color: isActive
                          ? Colors.blue
                          : Colors.black, // Tô màu xanh nếu đang đọc
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: isActive,
                  selectedTileColor: Colors.blue.withOpacity(0.1), // Tô nền nhẹ
                  leading: Icon(
                    Icons.article,
                    color: isActive ? Colors.blue : Colors.grey,
                  ),
                  onTap: () {
                    // 1. Cập nhật chương mới
                    setState(() => _currentIndex = index);
                    _displayCurrentChapter();

                    // 2. Lưu lại ngay
                    if (_currentFilePath != null) {
                      _repository.saveProgress(
                        _currentFilePath!,
                        _currentIndex,
                      );
                    }

                    // 3. Đóng Menu lại
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        // Dùng StatefulBuilder để cập nhật UI trong Dialog
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Tùy chỉnh giao diện"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Chuyển đổi Dark Mode
                  SwitchListTile(
                    title: const Text("Chế độ tối (Dark Mode)"),
                    value: _isDarkMode,
                    onChanged: (val) {
                      setStateDialog(() => _isDarkMode = val); // Update switch
                      setState(() {}); // Update màn hình chính
                      _displayCurrentChapter(); // Reload lại webview với CSS mới
                      _repository.saveSettings(_fontSize, _isDarkMode); // Lưu
                    },
                  ),
                  const SizedBox(height: 20),
                  // 2. Slider chỉnh cỡ chữ
                  Text("Cỡ chữ: ${_fontSize.toInt()}"),
                  Slider(
                    min: 12,
                    max: 30,
                    divisions: 9,
                    value: _fontSize,
                    onChanged: (val) {
                      setStateDialog(() => _fontSize = val);
                      setState(() {});
                      _displayCurrentChapter();
                      _repository.saveSettings(_fontSize, _isDarkMode);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Đóng"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_bookTitle),
        actions: [
          IconButton(
            onPressed: _showSettingsDialog, // Gọi hàm mở dialog
            icon: const Icon(Icons.settings),
            tooltip: "Cài đặt",
          ),
          IconButton(
            onPressed: _onPickFile,
            icon: const Icon(Icons.folder_open),
            tooltip: "Mở file",
          ),
        ],
      ),

      drawer: _buildDrawer(),

      body: Column(
        children: [
          Expanded(
            child: _isWebviewReady
                ? Webview(_controller)
                : const Center(child: CircularProgressIndicator()),
          ),
          // Chỉ hiện thanh điều hướng khi đã có sách
          if (_chapters.isNotEmpty)
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _currentIndex > 0
                        ? () => _changeChapter(-1)
                        : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Trước"),
                  ),
                  Text("Chương ${_currentIndex + 1} / ${_chapters.length}"),
                  ElevatedButton.icon(
                    onPressed: _currentIndex < _chapters.length - 1
                        ? () => _changeChapter(1)
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
  }
}
