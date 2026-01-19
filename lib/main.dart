import 'package:flutter/material.dart';
import 'package:my_ebook_reader/presentation/screens/reader_screen.dart';
import 'injection.dart'; // Import file cấu hình DI

void main() async {
  // Chuyển thành async
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Gọi hàm setup DI
  configureDependencies();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ebook Reader',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const EbookReaderScreen(),
    );
  }
}
