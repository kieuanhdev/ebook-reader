import '../../domain/entities/chapter.dart';

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
    final columnCount = isSpread ? 2 : 1;
    final columnGap = isSpread ? 40 : 0;
    final maxWidth = isSpread || isScroll ? "100%" : "800px";

    return """
      <style>
        body { 
          font-family: Arial, sans-serif; 
          line-height: 1.6; 
          padding: 20px; 
          max-width: $maxWidth; 
          margin: 0 auto;
          font-size: ${fontSize}px;
          color: $cssColor;
          background-color: $cssBg;
          column-count: $columnCount;
          column-gap: ${columnGap}px;
          column-fill: auto;
          height: ${isScroll ? "auto" : "100vh"};
        }
        img { max-width: 100%; height: auto; }
      </style>
      ${chapter.htmlContent}
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
}
