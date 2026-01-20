import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_ebook_reader/injection.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Import thư viện SQLite

import 'presentation/screens/library_screen.dart';

void main() async {
  // 1. Đảm bảo Flutter Binding đã sẵn sàng
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Khởi tạo SQLite cho Windows (BẮT BUỘC có dòng này ở main)
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 3. Khởi tạo Dependency Injection (GetIt)
  // Nếu hàm setup của bạn tên khác (vd: initGetIt), hãy sửa lại cho đúng
  configureDependencies();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ebook Reader',
      theme: ThemeData(primarySwatch: Colors.blue),
      // Mở màn hình Tủ Sách đầu tiên
      home: const LibraryScreen(),
    );
  }
}
