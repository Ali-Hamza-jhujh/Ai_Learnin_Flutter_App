class PromptBuilder {
  static String build({
    required String text,
    required int numMcqs,
    required String difficulty,
    required bool generateNotes,
    required bool generateMcqs,
    String summaryType = 'normal',
  }) {
    final noteInstruction = switch (summaryType) {
      'quick' => 'Create 5 concise, exam-focused bullet sections.',
      'deep' => 'Create detailed study notes with key terms and short examples.',
      _ => 'Create concise, well-structured, exam-focused study notes.',
    };

    return '''You are an expert educational writer. Analyze only the study material below.

OUTPUT REQUEST:
- Generate notes: $generateNotes
- Generate MCQs: $generateMcqs
${generateNotes ? '- Notes: $noteInstruction' : ''}
${generateMcqs ? '- Generate exactly $numMcqs $difficulty-difficulty MCQs. Each question must have four plausible options and one unambiguous answer.' : ''}

Return valid JSON only. Do not include markdown or commentary.
Use empty arrays for content that was not requested.

JSON FORMAT:
{
  "mcqs": [
    {
      "question": "...",
      "options": ["A. ...", "B. ...", "C. ...", "D. ..."],
      "answer": "A",
      "explanation": "...",
      "topic": "..."
    }
  ],
  "notes": [
    {
      "heading": "...",
      "content": "..."
    }
  ]
}

STUDY MATERIAL:
$text''';
  }
}
