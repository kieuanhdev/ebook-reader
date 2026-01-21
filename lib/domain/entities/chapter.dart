class Chapter {
  final String title;
  final String? htmlContent;
  final String? href;

  Chapter({
    required this.title,
    this.htmlContent,
    this.href,
  });

  bool get hasContent => htmlContent != null && htmlContent!.trim().isNotEmpty;

  Chapter copyWith({String? htmlContent}) {
    return Chapter(
      title: title,
      href: href,
      htmlContent: htmlContent ?? this.htmlContent,
    );
  }
}
