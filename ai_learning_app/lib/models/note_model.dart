class Note {
  final String heading;
  final String content;

  Note({
    required this.heading,
    required this.content,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      heading: json['heading']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'heading': heading,
    'content': content,
  };
}
