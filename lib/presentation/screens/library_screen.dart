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
    // Cung cấp Bloc cho màn hình này
    return BlocProvider(
      create: (context) => getIt<LibraryBloc>()..add(LoadLibraryEvent()),
      child: Scaffold(
        appBar: AppBar(title: const Text("Tủ Sách Của Tôi")),

        // Nút thêm sách (+)
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () async {
              // 1. Mở cửa sổ chọn file
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['epub'], // Chỉ cho chọn file epub
              );

              if (result != null && result.files.single.path != null) {
                // 2. Gửi sự kiện thêm sách vào Bloc
                context.read<LibraryBloc>().add(
                  AddBookEvent(result.files.single.path!),
                );
              }
            },
          ),
        ),

        // Danh sách sách (Grid)
        body: BlocBuilder<LibraryBloc, LibraryState>(
          builder: (context, state) {
            if (state is LibraryLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is LibraryLoaded) {
              if (state.books.isEmpty) {
                return const Center(
                  child: Text("Chưa có sách nào. Bấm + để thêm!"),
                );
              }

              // Hiển thị lưới sách
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 3 cột
                  childAspectRatio: 0.7, // Tỷ lệ khung hình chữ nhật đứng
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: state.books.length,
                itemBuilder: (context, index) {
                  final book = state.books[index];
                  return GestureDetector(
                    onTap: () {
                      // Bấm vào thì mở sách
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          // Tạm thời vẫn mở màn hình cũ, ta sẽ sửa logic truyền file sau
                          builder: (context) => const EbookReaderScreen(),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.book, size: 40, color: Colors.blue),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              book.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
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
