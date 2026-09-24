import 'package:hive_flutter/hive_flutter.dart';

class LocalCacheService {
  static Box? _notesBox;
  static Box? _mcqBox;
  static Box? _translationsBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _notesBox = await Hive.openBox('lumio_notes_cache');
    _mcqBox = await Hive.openBox('lumio_mcq_cache');
    _translationsBox = await Hive.openBox('lumio_note_translations');
  }

  static Future<Map<String, dynamic>?> getNotes(String cacheKey) async {
    final entry = _notesBox?.get(cacheKey);
    if (entry == null) return null;

    final map = Map<String, dynamic>.from(entry as Map);
    final cachedAt = DateTime.tryParse(map['cachedAt']?.toString() ?? '');
    if (cachedAt == null ||
        DateTime.now().difference(cachedAt).inDays > 7) {
      await _notesBox?.delete(cacheKey);
      return null;
    }
    return map;
  }

  static Future<Map<String, dynamic>?> getMcq(String cacheKey) async {
    final entry = _mcqBox?.get(cacheKey);
    if (entry == null) return null;

    final map = Map<String, dynamic>.from(entry as Map);
    final cachedAt = DateTime.tryParse(map['cachedAt']?.toString() ?? '');
    if (cachedAt == null ||
        DateTime.now().difference(cachedAt).inDays > 7) {
      await _mcqBox?.delete(cacheKey);
      return null;
    }
    return map;
  }

  static Future<void> saveNotes(
      String cacheKey, Map<String, dynamic> data) async {
    await _notesBox?.put(cacheKey, {
      ...data,
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> saveMcq(String cacheKey, Map<String, dynamic> data) async {
    await _mcqBox?.put(cacheKey, {
      ...data,
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>?> getNoteTranslation(
    String cacheKey,
  ) async {
    final entry = _translationsBox?.get(cacheKey);
    if (entry == null) return null;

    final map = Map<String, dynamic>.from(entry as Map);
    final cachedAt = DateTime.tryParse(map['cachedAt']?.toString() ?? '');
    if (cachedAt == null || DateTime.now().difference(cachedAt).inDays > 30) {
      await _translationsBox?.delete(cacheKey);
      return null;
    }
    return map;
  }

  static Future<void> saveNoteTranslation(
    String cacheKey,
    Map<String, dynamic> data,
  ) async {
    await _translationsBox?.put(cacheKey, {
      ...data,
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> deleteNoteTranslations(String noteId) async {
    final prefix = 'note_translation_${noteId}_';
    final keys = _translationsBox?.keys
            .where((key) => key.toString().startsWith(prefix))
            .toList() ??
        const <dynamic>[];
    if (keys.isNotEmpty) await _translationsBox?.deleteAll(keys);
  }

  static String noteTranslationCacheKey({
    required String noteId,
    required String sourceHash,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return 'note_translation_${noteId}_${sourceLanguage}_${targetLanguage}_$sourceHash';
  }

  static String notesCacheKey({
    required String userId,
    required String pdfHash,
    required List<String> chapters,
    required String summaryType,
  }) {
    return 'notes_${userId}_${pdfHash}_${chapters.join('|')}_$summaryType';
  }

  static String mcqCacheKey({
    required String userId,
    required String pdfHash,
    required List<String> chapters,
    required String difficulty,
    required int numMcqs,
  }) {
    return 'mcq_${userId}_${pdfHash}_${chapters.join('|')}_${difficulty}_$numMcqs';
  }
}
