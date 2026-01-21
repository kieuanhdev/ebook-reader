import 'dart:convert';
import 'package:my_ebook_reader/features/reader/domain/entities/chapter.dart';

class HtmlHelper {
  // Hàm thuần túy (Pure Function): Nhận dữ liệu -> Trả về HTML String
  static String generateChapterHtml({
    required Chapter chapter,
    required double fontSize,
    required bool isDarkMode,
    required String layoutMode,
  }) {
    String cssColor = isDarkMode ? "#dddddd" : "#000000";
    String cssBg = isDarkMode ? "#121212" : "#ffffff";
    final isSpread = layoutMode == 'spread';
    final isScroll = layoutMode == 'scroll';
    const padding = 20;
    final columnGap = isSpread ? 40 : 0;

    return """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8" />
        <style>
          html, body {
            margin: 0;
            padding: 0;
            height: 100%;
            width: 100%;
            overflow: ${isScroll ? "auto" : "hidden"};
            background-color: $cssBg;
            color: $cssColor;
          }
          #viewport {
            width: 100%;
            max-width: 1080px;
            height: 100vh;
            overflow: hidden;
            margin: 0 auto;
          }
          #reader {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            font-size: ${fontSize}px;
            box-sizing: border-box;
            height: ${isScroll ? "auto" : "100vh"};
            display: inline-block;
            width: max-content;
          }
          #reader .page {
            width: 100%;
            padding: ${padding}px;
            box-sizing: border-box;
          }
          img {
            max-width: 100%;
            height: auto;
            max-height: 90vh;
            object-fit: contain;
          }
        </style>
      </head>
      <body>
        <div id="viewport">
          <div id="reader"><div class="page"></div></div>
        </div>
        <script>
          (function() {
            const pageMode = ${isScroll ? "false" : "true"};
            const spreadMode = ${isSpread ? "true" : "false"};
            const reader = document.getElementById('reader');
            const viewport = document.getElementById('viewport');
            const page = reader ? reader.querySelector('.page') : null;
            let currentPage = 1;
            let totalPages = 1;
            let columnWidth = 1;
            let columnGap = 0;
            let pageStride = 1;
            const rawContent = ${jsonEncode(chapter.htmlContent ?? "")};
            function pageWidth() {
              if (viewport) {
                const w = viewport.clientWidth;
                if (w && w > 0) return w;
              }
              return window.innerWidth || document.documentElement.clientWidth || 1;
            }
            function pageHeight() {
              if (viewport) {
                const h = viewport.clientHeight;
                if (h && h > 0) return h;
              }
              return window.innerHeight || document.documentElement.clientHeight || 1;
            }
            function setViewport() {
              if (!viewport) return;
              const maxWidth = 1080;
              const targetWidth = Math.min(
                maxWidth,
                window.innerWidth || document.documentElement.clientWidth || maxWidth
              );
              viewport.style.width = targetWidth + 'px';
              viewport.style.height = pageMode ? pageHeight() + 'px' : 'auto';
              viewport.style.overflow = pageMode ? 'hidden' : 'auto';
            }
            function applyLayout() {
              if (!reader) return { columns: 1, gap: 0 };
              const columns = spreadMode ? 2 : 1;
              const gap = spreadMode ? ${columnGap} : 0;
              const width = pageWidth();
              const available = Math.max(1, width);
              const colWidth = columns > 1
                ? Math.max(1, (available - gap) / 2)
                : available;
              reader.style.height = pageMode ? pageHeight() + 'px' : 'auto';
              reader.style.columnGap = gap + 'px';
              reader.style.columnWidth = colWidth + 'px';
              reader.style.columnCount = 'auto';
              reader.style.columnFill = 'auto';
              columnWidth = colWidth;
              columnGap = gap;
              pageStride = Math.max(1, colWidth + gap);
              return { columns, gap, colWidth };
            }
            function setContent() {
              if (!page) return;
              if (!rawContent) {
                page.innerHTML = '';
                return;
              }
              try {
                const doc = new DOMParser().parseFromString(rawContent, 'text/html');
                page.innerHTML = doc.body ? doc.body.innerHTML : rawContent;
              } catch (_) {
                page.innerHTML = rawContent;
              }
            }
            function computeTotalPages() {
              if (!pageMode) return 1;
              if (!reader) return 1;
              const stride = Math.max(1, pageStride);
              const scrollWidth = Math.max(1, reader.scrollWidth || 1);
              return Math.max(1, Math.ceil(scrollWidth / stride));
            }
            function pageCount() {
              if (!pageMode || !reader) return 1;
              return totalPages;
            }
            function clampPage(p) {
              const total = pageCount();
              if (p < 1) return 1;
              if (p > total) return total;
              return p;
            }
            function goToPage(p) {
              if (!pageMode || !reader) return 1;
              currentPage = clampPage(p);
              const left = (currentPage - 1) * pageStride;
              if (viewport) {
                viewport.scrollLeft = left;
              }
              return currentPage;
            }
            function reflow() {
              setViewport();
              const layout = applyLayout();
              totalPages = computeTotalPages();
              if (reader) {
                reader.style.width =
                  (totalPages * pageStride) + 'px';
              }
              if (currentPage > totalPages) currentPage = totalPages;
              goToPage(currentPage);
              return totalPages;
            }
            window.readerPaging = {
              getPageCount: pageCount,
              getCurrentPage: () => currentPage,
              nextPage: () => goToPage(currentPage + 1),
              prevPage: () => goToPage(currentPage - 1),
              goToPage: goToPage,
              reflow: reflow,
              getState: () => JSON.stringify({
                total: totalPages,
                current: currentPage
              })
            };
            window.addEventListener('resize', () => {
              if (pageMode) reflow();
            });
            setContent();
            setViewport();
            if (pageMode) {
              setTimeout(reflow, 60);
              setTimeout(reflow, 200);
            }
            window.addEventListener('load', () => {
              if (pageMode) setTimeout(reflow, 200);
            });
          })();
        </script>
      </body>
      </html>
    """;
  }

  static String generateWelcomeHtml() {
    return """
      <div style="text-align: center; padding-top: 50px; font-family: sans-serif;">
        <h1>Chào mừng!</h1>
        <p>Bấm vào icon thư mục để mở sách EPUB.</p>
      </div>
    """;
  }

  static String generateLoadingHtml() {
    return """
      <div style="text-align: center; padding-top: 50px; font-family: sans-serif;">
        <h2>Đang tải chương...</h2>
      </div>
    """;
  }
}
