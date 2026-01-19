import 'package:flutter/material.dart';
import '../../domain/entities/chapter.dart';

class ReaderDrawer extends StatelessWidget {
  final List<Chapter> chapters;
  final int currentIndex;
  final Function(int) onChapterTap; // Callback bắn sự kiện ra ngoài

  const ReaderDrawer({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.onChapterTap,
  });

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) return const SizedBox();

    return Drawer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 40, bottom: 20, left: 20),
            width: double.infinity,
            color: Colors.blue,
            child: const Text(
              "Mục lục",
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                bool isActive = index == currentIndex;
                return ListTile(
                  title: Text(
                    chapters[index].title,
                    style: TextStyle(
                      color: isActive ? Colors.blue : Colors.black,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: isActive,
                  leading: Icon(
                    Icons.article,
                    color: isActive ? Colors.blue : Colors.grey,
                  ),
                  onTap: () {
                    onChapterTap(index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
