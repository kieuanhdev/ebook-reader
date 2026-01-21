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
    final columnWidth = isScroll
        ? "auto"
        : isSpread
            ? "calc((100vw - ${columnGap}px) / 2)"
            : "100vw";

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
          #reader {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            font-size: ${fontSize}px;
            box-sizing: border-box;
            height: ${isScroll ? "auto" : "100vh"};
            width: 100vw;
            --page-padding: ${padding}px;
            --column-gap: ${isScroll ? 0 : columnGap}px;
            --column-width: $columnWidth;
            --page-width: calc(var(--column-width) - (var(--page-padding) * 2));
            column-gap: var(--column-gap);
            column-width: var(--column-width);
            column-fill: auto;
          }
          #reader .page {
            width: ${isScroll ? "auto" : "var(--page-width)"};
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
        <div id="reader">
          <div class="page">
            ${chapter.htmlContent ?? ""}
          </div>
        </div>
        <script>
          (function() {
            const pageMode = ${isScroll ? "false" : "true"};
            const spreadMode = ${isSpread ? "true" : "false"};
            const reader = document.getElementById('reader');
            let currentPage = 1;
            const imgPlaceholder =
              'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';
            function pageWidth() {
              return window.innerWidth || document.documentElement.clientWidth || 1;
            }
            function columnStride() {
              if (!reader) return pageWidth();
              const styles = window.getComputedStyle(reader);
              const colWidth = parseFloat(styles.columnWidth || '0');
              const gap = parseFloat(styles.columnGap || '0');
              if (!colWidth || Number.isNaN(colWidth)) return pageWidth();
              return colWidth + gap;
            }
            function pageCount() {
              if (!pageMode || !reader) return 1;
              const total = Math.ceil(reader.scrollWidth / columnStride());
              return Math.max(1, total);
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
              const left = (currentPage - 1) * columnStride();
              window.scrollTo(left, 0);
              document.documentElement.scrollLeft = left;
              document.body.scrollLeft = left;
              updateImagesForPage();
              return currentPage;
            }
            function reflow() {
              const total = pageCount();
              if (currentPage > total) currentPage = total;
              goToPage(currentPage);
              return total;
            }
            function optimizeImages() {
              const imgs = document.images;
              for (let i = 0; i < imgs.length; i++) {
                const img = imgs[i];
                img.loading = 'lazy';
                img.decoding = 'async';
                if (!img.dataset.src) {
                  img.dataset.src = img.getAttribute('src') || '';
                }
                if (pageMode) {
                  img.setAttribute('src', imgPlaceholder);
                }
              }
            }
            function updateImagesForPage() {
              if (!pageMode) return;
              const width = columnStride();
              const pagesVisible = spreadMode ? 2 : 1;
              const left = (currentPage - 1) * width;
              const right = left + (width * pagesVisible);
              const imgs = document.images;
              for (let i = 0; i < imgs.length; i++) {
                const img = imgs[i];
                const rect = img.getBoundingClientRect();
                const imgLeft = rect.left + window.scrollX;
                const imgRight = rect.right + window.scrollX;
                const visible = imgRight >= left && imgLeft <= right;
                if (visible) {
                  if (img.dataset.src && img.getAttribute('src') !== img.dataset.src) {
                    img.setAttribute('src', img.dataset.src);
                  }
                } else {
                  if (img.getAttribute('src') !== imgPlaceholder) {
                    img.setAttribute('src', imgPlaceholder);
                  }
                }
              }
            }
            window.readerPaging = {
              getPageCount: pageCount,
              getCurrentPage: () => currentPage,
              nextPage: () => goToPage(currentPage + 1),
              prevPage: () => goToPage(currentPage - 1),
              goToPage: goToPage,
              reflow: reflow
            };
            window.addEventListener('resize', () => {
              if (pageMode) reflow();
            });
            if (pageMode) {
              setTimeout(reflow, 30);
            }
            optimizeImages();
            updateImagesForPage();
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
