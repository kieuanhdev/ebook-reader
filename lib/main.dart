import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

// Import màn hình chính
import 'presentation/screens/reader_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

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
      home: const EbookReaderScreen(),
    );
  }
}
