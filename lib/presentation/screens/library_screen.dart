import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_ebook_reader/injection.dart';
import 'package:my_ebook_reader/presentation/bloc/library/library_bloc.dart';
import 'package:my_ebook_reader/presentation/screens/reader_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<LibraryBloc>()..add(LoadLibraryEvent()),
      child: Scaffold(
        appBar: AppBar(title: const Text("Tủ Sách Của Tôi")),

        // Nút thêm sách (+)
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['epub'],
              );

              if (result != null && result.files.single.path != null) {
                // Gửi sự kiện thêm sách
                context.read<LibraryBloc>().add(
                  AddBookEvent(result.files.single.path!),
                );
              }
            },
          ),
        ),

        // Danh sách sách
        body: BlocBuilder<LibraryBloc, LibraryState>(
          builder: (context, state) {
            if (state is LibraryLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is LibraryLoaded) {
              if (state.books.isEmpty) {
                return const Center(
                  child: Text("Chưa có sách. Bấm + để thêm!"),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 3 cột
                  childAspectRatio: 0.65, // Tỷ lệ bìa sách
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: state.books.length,
                itemBuilder: (context, index) {
                  final book = state.books[index];

                  // --- PHẦN QUAN TRỌNG: SỰ KIỆN BẤM VÀO SÁCH ---
                  return GestureDetector(
                    onTap: () {
                      // Chuyển sang màn hình đọc và truyền đường dẫn file
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EbookReaderScreen(
                            bookPath: book.filePath, // Truyền path tại đây
                          ),
                        ),
                      ).then((_) {
                        // (Tùy chọn) Khi quay lại tủ sách thì load lại để cập nhật tiến độ đọc
                        context.read<LibraryBloc>().add(LoadLibraryEvent());
                      });
                    },
                    child: Card(
                      elevation: 4,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Ảnh bìa
                          Expanded(
                            child: book.coverPath != null
                                ? Image.file(
                                    File(book.coverPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.book,
                                      size: 40,
                                      color: Colors.blue,
                                    ),
                                  ),
                          ),
                          // Tên sách
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            color: Colors.white,
                            child: Text(
                              book.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }
}
