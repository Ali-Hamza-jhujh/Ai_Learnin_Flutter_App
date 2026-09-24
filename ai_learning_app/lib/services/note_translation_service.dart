import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslatedNoteChapter {
  const TranslatedNoteChapter({
    required this.heading,
    required this.notes,
  });

  final String heading;
  final String notes;

  Map<String, String> toJson() => {
        'chapterName': heading,
        'notes': notes,
      };
}

class NoteTranslationException implements Exception {
  const NoteTranslationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// On-device note translation backed by Google's ML Kit models.
///
/// Models are downloaded only when a language is first used. Translation input
/// is split conservatively so long generated notes remain within native model
/// limits without losing paragraph boundaries.
class NoteTranslationService {
  static const int _maxChunkLength = 3500;

  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  static List<TranslateLanguage> get supportedLanguages {
    final languages = [...TranslateLanguage.values];
    languages.sort((a, b) => displayName(a).compareTo(displayName(b)));
    return languages;
  }

  static String displayName(TranslateLanguage language) {
    return switch (language) {
      TranslateLanguage.chinese => 'Chinese (Simplified)',
      TranslateLanguage.haitian => 'Haitian Creole',
      TranslateLanguage.norwegian => 'Norwegian',
      _ => '${language.name[0].toUpperCase()}${language.name.substring(1)}',
    };
  }

  static TranslateLanguage languageFromStoredValue(String? value) {
    final normalized = switch (value?.trim().toLowerCase()) {
      'eng' || 'english' => 'en',
      'ara' || 'arabic' => 'ar',
      'rus' || 'russian' => 'ru',
      'deu' || 'german' => 'de',
      'chi_sim' || 'chinese' || 'simplified_chinese' => 'zh',
      'italian' => 'it',
      'urdu' => 'ur',
      final code => code ?? 'en',
    };

    for (final language in TranslateLanguage.values) {
      if (language.bcpCode == normalized) return language;
    }
    return TranslateLanguage.english;
  }

  static Future<List<TranslatedNoteChapter>> translateChapters({
    required List<Map<String, dynamic>> chapters,
    required TranslateLanguage sourceLanguage,
    required TranslateLanguage targetLanguage,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (!isSupported) {
      throw const NoteTranslationException(
        'On-device translation is available only in the Android and iOS app.',
      );
    }
    if (sourceLanguage == targetLanguage) {
      throw const NoteTranslationException(
        'Choose a different language for the translation.',
      );
    }
    if (chapters.isEmpty) {
      throw const NoteTranslationException('There are no notes to translate.');
    }

    final modelManager = OnDeviceTranslatorModelManager();
    try {
      final downloaded = await Future.wait([
        modelManager.downloadModel(sourceLanguage.bcpCode),
        modelManager.downloadModel(targetLanguage.bcpCode),
      ]);
      if (downloaded.any((didDownload) => !didDownload)) {
        throw const NoteTranslationException(
          'The required translation models could not be downloaded.',
        );
      }
    } on NoteTranslationException {
      rethrow;
    } catch (_) {
      throw const NoteTranslationException(
        'Could not download translation models. Connect to Wi-Fi and try again.',
      );
    }

    final translator = OnDeviceTranslator(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );

    try {
      final translated = <TranslatedNoteChapter>[];
      for (var index = 0; index < chapters.length; index++) {
        final chapter = chapters[index];
        final originalHeading = chapter['chapterName']?.toString() ??
            chapter['heading']?.toString() ??
            'Section ${index + 1}';
        final originalNotes = chapter['notes']?.toString() ??
            chapter['content']?.toString() ??
            '';

        translated.add(
          TranslatedNoteChapter(
            heading: await _translateText(translator, originalHeading),
            notes: await _translateText(translator, originalNotes),
          ),
        );
        onProgress?.call(index + 1, chapters.length);
      }
      return translated;
    } on NoteTranslationException {
      rethrow;
    } catch (_) {
      throw const NoteTranslationException(
        'This note could not be translated. Please try again.',
      );
    } finally {
      try {
        await translator.close();
      } catch (_) {
        // The translation result is still valid if native cleanup is already done.
      }
    }
  }

  static Future<String> _translateText(
    OnDeviceTranslator translator,
    String text,
  ) async {
    if (text.trim().isEmpty) return text;
    final chunks = _splitIntoChunks(text);
    final translatedChunks = <String>[];
    for (final chunk in chunks) {
      translatedChunks.add(await translator.translateText(chunk));
    }
    return translatedChunks.join();
  }

  static List<String> _splitIntoChunks(String text) {
    if (text.length <= _maxChunkLength) return [text];

    final chunks = <String>[];
    var start = 0;
    while (start < text.length) {
      final preferredEnd = math.min(start + _maxChunkLength, text.length);
      if (preferredEnd == text.length) {
        chunks.add(text.substring(start));
        break;
      }

      final newline = text.lastIndexOf('\n', preferredEnd);
      final sentenceEnd = math.max(
        text.lastIndexOf('. ', preferredEnd),
        math.max(text.lastIndexOf('! ', preferredEnd), text.lastIndexOf('? ', preferredEnd)),
      );
      final boundary = math.max(newline, sentenceEnd);
      final end = boundary > start + 1000 ? boundary + 1 : preferredEnd;
      chunks.add(text.substring(start, end));
      start = end;
    }
    return chunks;
  }
}
