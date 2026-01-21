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
        appBar: AppBar(
          title: const Text("Tủ Sách Của Tôi"),
          centerTitle: true,
        ),

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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: state.books.length,
                itemBuilder: (context, index) {
                  final book = state.books[index];

                  final progressPercent = (book.progress * 100)
                      .clamp(0, 100)
                      .toStringAsFixed(0);

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
                      elevation: 6,
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Ảnh bìa
                              Expanded(
                                child: book.coverPath != null
                                    ? Image.file(
                                        File(book.coverPath!),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) => const Center(
                                              child: Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                              ),
                                            ),
                                      )
                                    : Container(
                                        color: Colors.blueGrey.shade50,
                                        child: const Center(
                                          child: Icon(
                                            Icons.menu_book_rounded,
                                            size: 48,
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                      ),
                              ),
                              // Tên sách
                              Container(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 8, 10, 6),
                                color: Colors.white,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      book.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        minHeight: 6,
                                        value: (book.progress)
                                            .clamp(0.0, 1.0),
                                        backgroundColor:
                                            Colors.blueGrey.shade100,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "$progressPercent% đã đọc",
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton(
                              tooltip: "Xóa sách",
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text("Xóa sách?"),
                                    content: Text(
                                      "Bạn có chắc muốn xóa \"${book.title}\" khỏi tủ sách?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text("Hủy"),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text("Xóa"),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true && context.mounted) {
                                  context
                                      .read<LibraryBloc>()
                                      .add(DeleteBookEvent(book));
                                }
                              },
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
