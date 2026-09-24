class OfflineAIService {
  static Future<Map<String, dynamic>> generateOffline({
    required String extractedText,
    required int numMcqs,
    required String difficulty,
    required bool generateNotes,
    required bool generateMcqs,
  }) async {
    final sentences = extractedText
        .split(RegExp(r'[.!?]\s+'))
        .where((s) => s.trim().length > 20)
        .take(8)
        .toList();

    final notes = generateNotes
        ? sentences
            .map((s) => {
                  'heading': s.split(' ').take(4).join(' '),
                  'content': s.trim(),
                })
            .toList()
        : <Map<String, String>>[];

    final mcqs = generateMcqs
        ? List.generate(numMcqs.clamp(1, 10), (i) {
            final base = sentences.isNotEmpty
                ? sentences[i % sentences.length]
                : 'Study material topic ${i + 1}';
            return {
              'question':
                  'Which statement best reflects: "${base.substring(0, base.length.clamp(0, 80))}"?',
              'options': [
                'A. Correct concept',
                'B. Partial concept',
                'C. Incorrect detail',
                'D. Unrelated idea'
              ],
              'answer': 'A',
              'explanation': 'Option A aligns with the source material.',
              'topic': 'Offline generated',
            };
          })
        : <Map<String, dynamic>>[];

    return {
      'notes': notes,
      'mcqs': mcqs,
      'provider': 'offline_local',
      'detectedLanguage': 'en',
      'difficulty': difficulty,
    };
  }
}
