import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart'; // Thư viện chọn file
import 'package:epubx/epubx.dart' as epub;    // Thư viện đọc EPUB

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

  @override
  void initState() {
    super.initState();
    initWebview();
  }

  // Khởi tạo trình duyệt ngầm
  Future<void> initWebview() async {
    try {
      await _controller.initialize();
      // Lúc đầu chưa có sách, ta hiện một trang trắng hoặc hướng dẫn
      await _controller.loadStringContent("<h1>Vui lòng chọn một file EPUB để đọc</h1>");
      
      if (!mounted) return;
      setState(() {
        _isWebviewReady = true;
      });
    } catch (e) {
      print("Lỗi khởi tạo Webview: $e");
    }
  }

  // --- HÀM QUAN TRỌNG: MỞ VÀ ĐỌC FILE EPUB ---
  Future<void> _pickAndOpenEpub() async {
    // 1. Mở cửa sổ chọn file của Windows
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'], // Chỉ cho chọn file .epub
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      
      // 2. Đọc file vào bộ nhớ
      List<int> bytes = await file.readAsBytes();
      
      // 3. Dùng thư viện epubx để phân tích cấu trúc
      epub.EpubBook book = await epub.EpubReader.readBook(bytes);

      // 4. Cập nhật giao diện với tên sách
      setState(() {
        _bookTitle = book.Title ?? "Không có tiêu đề";
      });

      // 5. Thử nghiệm: Lấy nội dung chương đầu tiên để hiển thị (Cơ bản)
      // Lưu ý: Đây là cách hiển thị thô sơ để test, chưa có CSS đẹp
      if (book.Chapters!.isNotEmpty) {
        String chapterContent = book.Chapters!.first.HtmlContent ?? "<h1>Chương trống</h1>";
        await _controller.loadStringContent(chapterContent);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_bookTitle), // Hiện tên sách ở đây
        actions: [
          IconButton(
            icon: Icon(Icons.file_open), // Nút mở file
            onPressed: _pickAndOpenEpub, // Gọi hàm mở file khi bấm
            tooltip: "Mở sách EPUB",
          ),
        ],
      ),
      body: Center(
        child: _isWebviewReady
            ? Webview(_controller) // Hiển thị nội dung web
            : CircularProgressIndicator(), // Xoay xoay khi đang tải
      ),
    );
  }
}