import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_pdfviewer_platform_interface/pdfviewer_platform_interface.dart';
import 'package:url_launcher/url_launcher.dart';

class PdfReaderScreen extends StatefulWidget {
  final String filePath;

  const PdfReaderScreen({super.key, required this.filePath});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final PdfViewerController _controller = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 0;
  int _initialPage = 1;
  bool _pluginAvailable = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _checkPluginAvailable();
  }

  Future<void> _checkPluginAvailable() async {
    try {
      await PdfViewerPlatform.instance.closeDocument('ping');
      _pluginAvailable = true;
    } on MissingPluginException {
      if (mounted) {
        setState(() => _pluginAvailable = false);
      }
      return;
    } catch (_) {
      _pluginAvailable = true;
    }
    if (mounted) {
      setState(() => _pluginAvailable = true);
    }
  }

  Future<void> _openExternal() async {
    final uri = Uri.file(widget.filePath);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPage =
        prefs.getInt('progress_pdf_page_${widget.filePath}') ?? 1;
    if (mounted) {
      setState(() => _initialPage = savedPage);
    }
  }

  Future<void> _saveProgress(int page) async {
    if (_totalPages <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('progress_pdf_page_${widget.filePath}', page);

    final denom = (_totalPages - 1) > 0 ? (_totalPages - 1) : 1;
    final percent = _totalPages <= 1
        ? 1.0
        : ((page - 1) / denom).clamp(0.0, 1.0);
    await prefs.setDouble('progress_percent_${widget.filePath}', percent);
  }

  @override
  Widget build(BuildContext context) {
    final title = p.basename(widget.filePath);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Quay lại thư viện",
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title),
      ),
      body: Column(
        children: [
          Expanded(
            child: _pluginAvailable
                ? SfPdfViewer.file(
                    File(widget.filePath),
                    controller: _controller,
                    onDocumentLoaded: (details) {
                      final total = details.document.pages.count;
                      setState(() => _totalPages = total);
                      if (_initialPage > 1 && _initialPage <= total) {
                        _controller.jumpToPage(_initialPage);
                      }
                      _currentPage = _controller.pageNumber;
                      _saveProgress(_currentPage);
                    },
                    onPageChanged: (details) {
                      setState(() => _currentPage = details.newPageNumber);
                      _saveProgress(_currentPage);
                    },
                    onDocumentLoadFailed: (details) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(details.error)),
                      );
                    },
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.picture_as_pdf, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            "Không thể khởi tạo PDF Viewer trên thiết bị này.",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Hãy chạy lại app sau khi full restart hoặc mở bằng ứng dụng mặc định.",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _openExternal,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text("Mở bằng ứng dụng khác"),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          if (_totalPages > 0)
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _currentPage > 1
                        ? () => _controller.previousPage()
                        : null,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Text("$_currentPage / $_totalPages"),
                  IconButton(
                    onPressed: _currentPage < _totalPages
                        ? () => _controller.nextPage()
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
