class MCQ {
  final String question;
  final List<String> options;
  final String answer;
  final String explanation;

  MCQ({
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  factory MCQ.fromJson(Map<String, dynamic> json) {
    final opts = json['options'] as List<dynamic>? ?? [];
    return MCQ(
      question: json['question']?.toString() ?? '',
      options: opts.map((e) => e.toString()).toList(),
      answer: json['answer']?.toString() ?? json['correctAnswer']?.toString() ?? 'A',
      explanation: json['explanation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'answer': answer,
    'explanation': explanation,
  };
}
