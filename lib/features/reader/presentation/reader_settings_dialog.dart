import 'package:flutter/material.dart';
import 'package:my_ebook_reader/core/reader_layout.dart';

class ReaderSettingsDialog extends StatefulWidget {
  final bool isDarkMode;
  final double fontSize;
  final Function(bool isDark, double size) onSettingsChanged;
  final ReaderLayout layout;
  final Function(ReaderLayout layout) onLayoutChanged;

  const ReaderSettingsDialog({
    super.key,
    required this.isDarkMode,
    required this.fontSize,
    required this.onSettingsChanged,
    required this.layout,
    required this.onLayoutChanged,
  });

  @override
  State<ReaderSettingsDialog> createState() => _ReaderSettingsDialogState();
}

class _ReaderSettingsDialogState extends State<ReaderSettingsDialog> {
  late bool _isDark;
  late double _size;
  late ReaderLayout _layout;

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
    _size = widget.fontSize;
    _layout = widget.layout;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Tùy chỉnh giao diện"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: _isDark,
            onChanged: (val) {
              setState(() => _isDark = val);
              widget.onSettingsChanged(_isDark, _size);
            },
          ),
          Slider(
            min: 12,
            max: 30,
            divisions: 9,
            value: _size,
            onChanged: (val) {
              setState(() => _size = val);
              widget.onSettingsChanged(_isDark, _size);
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ReaderLayout>(
            value: _layout,
            decoration: const InputDecoration(
              labelText: "Chế độ hiển thị",
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: ReaderLayout.single,
                child: Text("1 trang"),
              ),
              DropdownMenuItem(
                value: ReaderLayout.spread,
                child: Text("2 trang"),
              ),
              DropdownMenuItem(
                value: ReaderLayout.scroll,
                child: Text("Cuộn"),
              ),
            ],
            onChanged: (val) {
              if (val == null) return;
              setState(() => _layout = val);
              widget.onLayoutChanged(_layout);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Đóng"),
        ),
      ],
    );
  }
}
