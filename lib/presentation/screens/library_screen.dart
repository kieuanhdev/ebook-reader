import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_ebook_reader/injection.dart';
import 'package:my_ebook_reader/presentation/bloc/library/library_bloc.dart';
import 'package:my_ebook_reader/presentation/screens/pdf_reader_screen.dart';
import 'package:my_ebook_reader/presentation/screens/reader_screen.dart';
import 'package:path/path.dart' as p;

enum LibraryFilter { all, unread, reading, finished }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  LibraryFilter _filter = LibraryFilter.all;

  bool _matchesFilter(double progress) {
    switch (_filter) {
      case LibraryFilter.unread:
        return progress <= 0;
      case LibraryFilter.reading:
        return progress > 0 && progress < 1;
      case LibraryFilter.finished:
        return progress >= 1;
      case LibraryFilter.all:
        return true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
                allowedExtensions: ['epub', 'pdf'],
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
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Tìm sách theo tên...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text("Tất cả"),
                      selected: _filter == LibraryFilter.all,
                      onSelected: (_) =>
                          setState(() => _filter = LibraryFilter.all),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text("Chưa đọc"),
                      selected: _filter == LibraryFilter.unread,
                      onSelected: (_) =>
                          setState(() => _filter = LibraryFilter.unread),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text("Đang đọc"),
                      selected: _filter == LibraryFilter.reading,
                      onSelected: (_) =>
                          setState(() => _filter = LibraryFilter.reading),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text("Đã đọc"),
                      selected: _filter == LibraryFilter.finished,
                      onSelected: (_) =>
                          setState(() => _filter = LibraryFilter.finished),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<LibraryBloc, LibraryState>(
                builder: (context, state) {
                  if (state is LibraryLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is LibraryLoaded) {
                    final books = state.books.where((book) {
                      final matchesQuery = _query.isEmpty
                          ? true
                          : book.title.toLowerCase().contains(_query);
                      return matchesQuery && _matchesFilter(book.progress);
                    }).toList();

                    if (books.isEmpty) {
                      return Center(
                        child: Text(
                          _query.isEmpty
                              ? "Chưa có sách. Bấm + để thêm!"
                              : "Không tìm thấy sách phù hợp.",
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            childAspectRatio: 0.62,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];

                        final progressPercent = (book.progress * 100)
                            .clamp(0, 100)
                            .toStringAsFixed(0);

                        // --- PHẦN QUAN TRỌNG: SỰ KIỆN BẤM VÀO SÁCH ---
                        return GestureDetector(
                          onTap: () {
                            final extension =
                                p.extension(book.filePath).toLowerCase();
                            final isPdf = extension == '.pdf';

                            // Chuyển sang màn hình đọc và truyền đường dẫn file
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => isPdf
                                    ? PdfReaderScreen(
                                        filePath: book.filePath,
                                      )
                                    : EbookReaderScreen(
                                        bookPath:
                                            book.filePath, // Truyền path tại đây
                                      ),
                              ),
                            ).then((_) {
                              // (Tùy chọn) Khi quay lại tủ sách thì load lại để cập nhật tiến độ đọc
                              context
                                  .read<LibraryBloc>()
                                  .add(LoadLibraryEvent());
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
                                      padding: const EdgeInsets.fromLTRB(
                                        10,
                                        8,
                                        10,
                                        6,
                                      ),
                                      color: Colors.white,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            borderRadius:
                                                BorderRadius.circular(6),
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
                                      final confirmed =
                                          await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          title: const Text("Xóa sách?"),
                                          content: Text(
                                            "Bạn có chắc muốn xóa \"${book.title}\" khỏi tủ sách?",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(
                                                    dialogContext,
                                                    false,
                                                  ),
                                              child: const Text("Hủy"),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(
                                                    dialogContext,
                                                    true,
                                                  ),
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
          ],
        ),
      ),
    );
  }
}
