import 'package:flutter/material.dart';

class ReaderSettingsDialog extends StatefulWidget {
  final bool isDarkMode;
  final double fontSize;
  final Function(bool isDark, double size) onSettingsChanged;

  const ReaderSettingsDialog({
    super.key,
    required this.isDarkMode,
    required this.fontSize,
    required this.onSettingsChanged,
  });

  @override
  State<ReaderSettingsDialog> createState() => _ReaderSettingsDialogState();
}

class _ReaderSettingsDialogState extends State<ReaderSettingsDialog> {
  late bool _isDark;
  late double _size;

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
    _size = widget.fontSize;
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
