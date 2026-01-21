import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_ebook_reader/app/di/injection.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_ebook_reader/features/library/presentation/screens/library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

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
      home: const LibraryScreen(),
    );
  }
}
