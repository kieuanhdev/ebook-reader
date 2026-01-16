import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart'; // Thư viện chọn file
import 'package:epubx/epubx.dart' as epub; // Thư viện đọc EPUB

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Tắt chữ Debug xấu xí ở góc
      home: EbookReaderScreen(),
    );
  }
}

class EbookReaderScreen extends StatefulWidget {
  const EbookReaderScreen({super.key});

  @override
  State<EbookReaderScreen> createState() => _EbookReaderScreenState();
}

class _EbookReaderScreenState extends State<EbookReaderScreen> {
  final _controller = WebviewController();
  bool _isWebviewReady = false;
  String _bookTitle = "Chưa mở sách"; // Biến lưu tên sách

  //Các biến quản lý chương sách
  List<epub.EpubChapter> _allChapters = []; //Danh sách toàn bộ chương
  int _currentIndex = 0; //Đang đọc chương số mấy
  bool _hasBook = false; // đã chọn sách chưa

  @override
  void initState() {
    super.initState();
    initWebview();
  }

  // Khởi tạo trình duyệt ngầm
  Future<void> initWebview() async {
    try {
      await _controller.initialize();

      await _controller.setBackgroundColor(Colors.white);

      // Lúc đầu chưa có sách, ta hiện một trang trắng hoặc hướng dẫn
      await _controller.loadStringContent("""
        <div style= "text-align: center; padding-top: 50px; font-family: sans-serif;">
          <h1>Chào mừng! </h1>
          <p>Bấm vào icon thư mực góc trên để mở sách. </p>
        </div>
      """);

      if (!mounted) return;
      setState(() {
        _isWebviewReady = true;
      });
    } catch (e) {
      print("Lỗi khởi tạo Webview: $e");
    }
  }

  // Hàm đệ quy để lấy tất cả chương con ra ngoài, làm phẳng
  List<epub.EpubChapter> _flattenChapters(List<epub.EpubChapter> chapters) {
    List<epub.EpubChapter> flatList = [];
    for (var chapter in chapters) {
      flatList.add(chapter);
      flatList.addAll(_flattenChapters(chapter.SubChapters!));
    }
    return flatList;
  }

  Future<void> _pickAndOpenEpub() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      List<int> bytes = await file.readAsBytes();
      epub.EpubBook book = await epub.EpubReader.readBook(bytes);

      List<epub.EpubChapter> flatChapters = [];
      if (book.Chapters != null) {
        flatChapters = _flattenChapters(book.Chapters!);
      }

      setState(() {
        _bookTitle = book.Title ?? "Không có tiêu đề";
        _allChapters = flatChapters;
        _currentIndex = 0;
        _hasBook = true;
      });

      _loadCurrentChapter();
    }
  }

  void _loadCurrentChapter() {
    if (_allChapters.isEmpty) return;

    var chapter = _allChapters[_currentIndex];
    String content = chapter.HtmlContent ?? "<h1>Chương trống</h1>";

    String stylizedContent =
        """
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; padding: 20px; max-width: 800px; margin: 0 auto; }
        img { max-width: 100%; height: auto; }
      </style>

      $content 
    """;

    _controller.loadStringContent(stylizedContent);
  }

  void _nextChapter() {
    if (_currentIndex < _allChapters.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _loadCurrentChapter();
    }
  }

  void _prevChapter() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _loadCurrentChapter();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_bookTitle, style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            onPressed: _pickAndOpenEpub,
            icon: Icon(Icons.folder_open),
            tooltip: "Mở sách",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isWebviewReady
                ? Webview(_controller)
                : Center(child: CircularProgressIndicator()),
          ),
          if (_hasBook)
            Container(
              color: Colors.grey[200],
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _currentIndex > 0
                        ? _prevChapter
                        : null, // Disable nếu là trang đầu
                    icon: Icon(Icons.arrow_back),
                    label: Text("Trước"),
                  ),
                  Text("Chương ${_currentIndex + 1} / ${_allChapters.length}"),
                  ElevatedButton.icon(
                    onPressed: _currentIndex < _allChapters.length - 1
                        ? _nextChapter
                        : null,
                    icon: Icon(Icons.arrow_forward),
                    label: Text("Sau"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
