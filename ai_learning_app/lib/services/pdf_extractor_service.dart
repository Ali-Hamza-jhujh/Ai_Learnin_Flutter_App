import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'api_client.dart';
import 'on_device_ocr_service.dart';

class SpokenWord {
  final String text;
  final Rect bounds;
  final int startOffset;
  final int endOffset;

  const SpokenWord({
    required this.text,
    required this.bounds,
    required this.startOffset,
    required this.endOffset,
  });
}

class SpokenLine {
  final int index;
  final String text;
  final int pageNumber;
  final bool isHeading;
  final List<Rect> lineBounds;
  final List<SpokenWord> words;

  const SpokenLine({
    required this.index,
    required this.text,
    this.pageNumber = 1,
    this.isHeading = false,
    this.lineBounds = const [],
    this.words = const [],
  });
}

class ExtractedDocumentContent {
  final String fullText;
  final int totalPages;
  final List<SpokenLine> lines;

  const ExtractedDocumentContent({
    required this.fullText,
    required this.totalPages,
    required this.lines,
  });
}

class PdfExtractorService {
  /// Splits text into professional spoken lines strictly based on punctuation rules:
  /// Lines end ONLY at '.', '!', '?' or true paragraph boundaries (double newline).
  /// Colon ':' only breaks when the preceding text is short (≤ 80 chars, like a heading).
  /// Comma (,) and semicolon (;) NEVER cause a break — complete thoughts stay intact.
  /// Single newlines from PDF layout wraps are merged into spaces so mid-sentence
  /// layout wraps never split a sentence.
  static List<SpokenLine> splitIntoRuleLines(
    String text, {
    int pageNumber = 1,
    int startIndex = 0,
  }) {
    if (text.trim().isEmpty) return [];

    // Normalize line endings and strip control chars
    var cleanText = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\\+\d+'), '•')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

    // ── STEP 1: Preserve true paragraph breaks (2+ newlines) ──────────────────
    const paraToken = '\x01PARA\x01';
    cleanText = cleanText.replaceAll(RegExp(r'\n{2,}'), paraToken);

    // ── STEP 2: Fix PDF hyphen-wraps: "large-\nscale" → "large-scale" ─────────
    cleanText = cleanText.replaceAllMapped(
      RegExp(r'(\w+)-\n(\w+)'),
      (m) => '${m[1]}-${m[2]}',
    );

    // ── STEP 3: Merge single layout-wrap newlines into spaces ──────────────────
    // (These are visual line wraps from PDF layout, NOT sentence breaks)
    cleanText = cleanText.replaceAll('\n', ' ');

    // Restore paragraph markers
    cleanText = cleanText.replaceAll(paraToken, '\n');

    // Collapse excess whitespace
    cleanText = cleanText.replaceAll(RegExp(r'[ \t]{2,}'), ' ');

    // ── STEP 4: Protect decimal numbers "3.14" from splitting ─────────────────
    cleanText = cleanText.replaceAllMapped(
      RegExp(r'(\d)\.(\d)'),
      (m) => '${m[1]}\x02${m[2]}',
    );

    // ── STEP 5: Protect common abbreviations from splitting ───────────────────
    cleanText = cleanText.replaceAllMapped(
      RegExp(
        r'\b(e\.g\.|i\.e\.|dr\.|mr\.|mrs\.|ms\.|vs\.|approx\.|etc\.|fig\.|al\.|prof\.|sr\.|jr\.)',
        caseSensitive: false,
      ),
      (m) => m[0]!.replaceAll('.', '\x03'),
    );

    // ── STEP 6: Split on sentence-ending punctuation or paragraph breaks ──────
    // Sentence boundaries: . ! ?  OR  paragraph marker \n
    // Colon breaks ONLY when preceding text is short (heading label).
    // Comma and semicolon NEVER break.
    final List<SpokenLine> rawLines = [];
    final buffer = StringBuffer();

    int i = 0;
    while (i < cleanText.length) {
      final ch = cleanText[i];

      if (ch == '\n') {
        // Paragraph break — flush buffer
        final flushed = _restoreTokens(buffer.toString()).trim();
        buffer.clear();
        if (flushed.isNotEmpty && flushed.contains(RegExp(r'[a-zA-Z0-9]'))) {
          rawLines.add(SpokenLine(
            index: 0,
            text: flushed,
            pageNumber: pageNumber,
            isHeading: _detectHeading(flushed),
          ));
        }
      } else if ((ch == '.' || ch == '!' || ch == '?') &&
          i + 1 < cleanText.length &&
          cleanText[i + 1] == ' ') {
        // Sentence-ending punctuation followed by space → emit line
        buffer.write(ch);
        final flushed = _restoreTokens(buffer.toString()).trim();
        buffer.clear();
        if (flushed.isNotEmpty && flushed.contains(RegExp(r'[a-zA-Z0-9]'))) {
          rawLines.add(SpokenLine(
            index: 0,
            text: flushed,
            pageNumber: pageNumber,
            isHeading: _detectHeading(flushed),
          ));
        }
        i++; // skip the trailing space
      } else if (ch == ':' &&
          i + 1 < cleanText.length &&
          cleanText[i + 1] == ' ') {
        // Colon: only break if preceding text is a short heading-like label (≤ 80 chars)
        buffer.write(ch);
        final candidate = _restoreTokens(buffer.toString()).trim();
        if (candidate.length <= 80) {
          buffer.clear();
          if (candidate.isNotEmpty && candidate.contains(RegExp(r'[a-zA-Z0-9]'))) {
            rawLines.add(SpokenLine(
              index: 0,
              text: candidate,
              pageNumber: pageNumber,
              isHeading: _detectHeading(candidate),
            ));
          }
          i++; // skip trailing space
        } else {
          // Long text with colon mid-sentence — don't break
          buffer.write(cleanText[i + 1]);
          i++;
        }
      } else if (ch == '.' && i == cleanText.length - 1) {
        // Period at very end of text — flush
        buffer.write(ch);
        final flushed = _restoreTokens(buffer.toString()).trim();
        buffer.clear();
        if (flushed.isNotEmpty && flushed.contains(RegExp(r'[a-zA-Z0-9]'))) {
          rawLines.add(SpokenLine(
            index: 0,
            text: flushed,
            pageNumber: pageNumber,
            isHeading: _detectHeading(flushed),
          ));
        }
      } else {
        buffer.write(ch);
      }
      i++;
    }

    // Flush any remaining text
    if (buffer.isNotEmpty) {
      final flushed = _restoreTokens(buffer.toString()).trim();
      if (flushed.isNotEmpty && flushed.contains(RegExp(r'[a-zA-Z0-9]'))) {
        rawLines.add(SpokenLine(
          index: 0,
          text: flushed,
          pageNumber: pageNumber,
          isHeading: _detectHeading(flushed),
        ));
      }
    }

    // ── STEP 7: Merge orphaned short fragments (< 15 chars) into next line ────
    final merged = <SpokenLine>[];
    int j = 0;
    while (j < rawLines.length) {
      final current = rawLines[j];
      if (current.text.length < 15 &&
          !current.isHeading &&
          j + 1 < rawLines.length) {
        final next = rawLines[j + 1];
        merged.add(SpokenLine(
          index: 0,
          text: '${current.text} ${next.text}',
          pageNumber: next.pageNumber,
          isHeading: next.isHeading,
        ));
        j += 2;
      } else {
        merged.add(current);
        j++;
      }
    }

    // Re-index sequentially starting from startIndex
    final result = <SpokenLine>[];
    for (int k = 0; k < merged.length; k++) {
      result.add(SpokenLine(
        index: startIndex + k,
        text: merged[k].text,
        pageNumber: merged[k].pageNumber,
        isHeading: merged[k].isHeading,
        lineBounds: merged[k].lineBounds,
        words: merged[k].words,
      ));
    }

    return result;
  }

  /// Builds spoken sentences directly from PDF visual TextLines, preserving
  /// exact line bounding boxes and word bounding boxes for on-page book highlights.
  static List<SpokenLine> buildSpokenLinesFromTextLines(
    List<sf.TextLine> textLines, {
    required int pageNumber,
    int startIndex = 0,
  }) {
    if (textLines.isEmpty) return [];

    final List<SpokenLine> results = [];
    final StringBuffer sentenceBuffer = StringBuffer();
    final List<Rect> currentLineBounds = [];
    final List<SpokenWord> currentWords = [];

    const abbrevs = {
      'e.g.', 'i.e.', 'dr.', 'mr.', 'mrs.', 'ms.', 'vs.', 'approx.',
      'etc.', 'fig.', 'al.', 'prof.', 'sr.', 'jr.', 'u.s.', 'no.',
      'vol.', 'ed.', 'dept.', 'univ.', 'corp.', 'inc.', 'ltd.',
    };

    bool isAbbreviation(String w) {
      final clean = w.toLowerCase().replaceAll(RegExp(r'[^a-z.]'), '');
      return abbrevs.contains(clean);
    }

    for (final line in textLines) {
      final lineText = line.text.trim();
      if (lineText.isEmpty) continue;

      final isHeadingLine = _detectHeading(lineText);

      // If heading encountered and there is an ongoing sentence, flush it first
      if (isHeadingLine && sentenceBuffer.isNotEmpty) {
        final flushed = sentenceBuffer.toString().trim();
        if (flushed.isNotEmpty && flushed.contains(RegExp(r'[a-zA-Z0-9]'))) {
          results.add(SpokenLine(
            index: startIndex + results.length,
            text: flushed,
            pageNumber: pageNumber,
            isHeading: false,
            lineBounds: List.from(currentLineBounds),
            words: List.from(currentWords),
          ));
        }
        sentenceBuffer.clear();
        currentLineBounds.clear();
        currentWords.clear();
      }

      currentLineBounds.add(line.bounds);

      for (final word in line.wordCollection) {
        final wText = word.text;
        if (wText.trim().isEmpty) {
          if (sentenceBuffer.isNotEmpty && !sentenceBuffer.toString().endsWith(' ')) {
            sentenceBuffer.write(' ');
          }
          continue;
        }

        final startOffset = sentenceBuffer.length;
        sentenceBuffer.write(wText);
        final endOffset = sentenceBuffer.length;

        currentWords.add(SpokenWord(
          text: wText,
          bounds: word.bounds,
          startOffset: startOffset,
          endOffset: endOffset,
        ));

        final trimmedWord = wText.trim();
        final hasTerminator = trimmedWord.endsWith('.') ||
            trimmedWord.endsWith('!') ||
            trimmedWord.endsWith('?');

        if (hasTerminator && !isAbbreviation(trimmedWord) && sentenceBuffer.length > 15) {
          final sentence = sentenceBuffer.toString().trim();
          if (sentence.isNotEmpty && sentence.contains(RegExp(r'[a-zA-Z0-9]'))) {
            results.add(SpokenLine(
              index: startIndex + results.length,
              text: sentence,
              pageNumber: pageNumber,
              isHeading: isHeadingLine,
              lineBounds: List.from(currentLineBounds),
              words: List.from(currentWords),
            ));
          }
          sentenceBuffer.clear();
          currentLineBounds.clear();
          currentWords.clear();
        }
      }

      if (isHeadingLine && sentenceBuffer.isNotEmpty) {
        final sentence = sentenceBuffer.toString().trim();
        if (sentence.isNotEmpty && sentence.contains(RegExp(r'[a-zA-Z0-9]'))) {
          results.add(SpokenLine(
            index: startIndex + results.length,
            text: sentence,
            pageNumber: pageNumber,
            isHeading: true,
            lineBounds: List.from(currentLineBounds),
            words: List.from(currentWords),
          ));
        }
        sentenceBuffer.clear();
        currentLineBounds.clear();
        currentWords.clear();
      } else if (sentenceBuffer.isNotEmpty && !sentenceBuffer.toString().endsWith(' ')) {
        sentenceBuffer.write(' ');
      }
    }

    if (sentenceBuffer.isNotEmpty) {
      final sentence = sentenceBuffer.toString().trim();
      if (sentence.isNotEmpty && sentence.contains(RegExp(r'[a-zA-Z0-9]'))) {
        results.add(SpokenLine(
          index: startIndex + results.length,
          text: sentence,
          pageNumber: pageNumber,
          isHeading: false,
          lineBounds: List.from(currentLineBounds),
          words: List.from(currentWords),
        ));
      }
    }

    return results;
  }

  static String _restoreTokens(String s) {
    return s.replaceAll('\x02', '.').replaceAll('\x03', '.');
  }

  static bool _detectHeading(String line) {
    final trimmed = line.trim();
    if (trimmed.length > 60) return false;

    // Headings must start with an uppercase letter, number, or bracket
    if (!RegExp(r'^[A-Z0-9\(\[\{]').hasMatch(trimmed)) return false;

    // Explicit section numbering: "1. Entities", "1.1 Architecture"
    if (RegExp(r'^\d+(\.\d+)*\.?\s+[A-Z]').hasMatch(trimmed)) {
      return true;
    }
    // Roman numerals: "i) Regular Entities:", "II. Overview"
    if (RegExp(r'^[ivxlcdm]+[\)\.:]\s', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }
    // Chapter / Section keywords: "Chapter 1", "Section 3"
    if (RegExp(r'^(Chapter|Section|Unit|Lecture|Part|Module)\s+\d+', caseSensitive: false)
        .hasMatch(trimmed)) {
      return true;
    }

    // Short section labels ending with ':' that are titles: e.g. "Weak Entities:"
    if (trimmed.endsWith(':') && trimmed.length < 35 && !trimmed.contains('.')) {
      return true;
    }

    // Short all-caps titles: e.g. "OVERVIEW", "INTRODUCTION"
    if (trimmed.length < 35 &&
        trimmed == trimmed.toUpperCase() &&
        RegExp(r'[A-Z]{3,}').hasMatch(trimmed) &&
        !trimmed.endsWith('.')) {
      return true;
    }

    return false;
  }

  /// Checks if extracted text is genuine human-readable language
  /// and not binary font table gibberish.
  static bool isReadableHumanText(String text) {
    if (text.trim().length < 10) return false;
    final printable = RegExp(r'[a-zA-Z0-9\s.,!?:;\-()"\x27]').allMatches(text).length;
    final ratio = printable / text.length;
    // At least 75% must be standard printable characters
    return ratio >= 0.75;
  }

  /// Extracts full text and page-aware lines from a PDF file.
  static Future<ExtractedDocumentContent> extractDocument(
    File file, {
    void Function(String message)? onStatus,
  }) async {
    final fileName = file.path.replaceAll('\\', '/').split('/').last;

    // 1. Primary: Instant On-Device Extraction in Background Isolate (Zero UI Freezing!)
    try {
      onStatus?.call('Preparing document audio…');
      final result = await compute(
        _isolateSyncfusionExtract,
        _PdfExtractParams(file.path, 50),
      );
      if (result != null && result.lines.isNotEmpty) {
        return result;
      }
    } catch (e) {
      debugPrint('Background isolate extraction skipped/error: $e');
    }

    // 2. Fallback: Try Backend Fast Extraction with page mapping
    try {
      onStatus?.call('Parsing document pages via server…');
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/notes/extract-text');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      // Allow adequate timeout for large books (e.g. 50-100MB textbooks)
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawPages = data['pages'] as List<dynamic>?;
        final totalPages = data['totalPages'] as int? ?? rawPages?.length ?? 1;
        final fullText = data['text']?.toString() ?? '';

        final allLines = <SpokenLine>[];

        if (rawPages != null && rawPages.isNotEmpty) {
          for (final p in rawPages) {
            final pageMap = p as Map<String, dynamic>;
            final pageNum = pageMap['pageNumber'] as int? ?? 1;
            final pageText = pageMap['text']?.toString() ?? '';

            // User Rule: Skip pages with no genuine readable sentences
            // (e.g. cover photos, blank pages, image-only pages)
            if (pageText.trim().length < 25 || !isReadableHumanText(pageText)) {
              continue;
            }

            final pageLines = splitIntoRuleLines(
              pageText,
              pageNumber: pageNum,
              startIndex: allLines.length,
            );
            allLines.addAll(pageLines);
          }
        } else if (fullText.trim().isNotEmpty && isReadableHumanText(fullText)) {
          allLines.addAll(splitIntoRuleLines(fullText));
        }

        if (allLines.isNotEmpty) {
          final normalized = List.generate(
            allLines.length,
            (i) => SpokenLine(
              index: i,
              text: allLines[i].text,
              pageNumber: allLines[i].pageNumber,
              isHeading: allLines[i].isHeading,
              lineBounds: allLines[i].lineBounds,
              words: allLines[i].words,
            ),
          );
          return ExtractedDocumentContent(
            fullText: fullText,
            totalPages: totalPages,
            lines: normalized,
          );
        }
      }
    } catch (e) {
      debugPrint('Backend extraction error: $e');
    }

    // 2. Fallback to On-Device OCR if supported (for short or scanned documents)
    if (OnDeviceOcrService.isSupported) {
      try {
        onStatus?.call('Reading document pages locally…');
        final result = await OnDeviceOcrService.extractPdfText(
          pdfFile: file,
          language: OnDeviceOcrLanguage.english,
        );
        if (isReadableHumanText(result.text)) {
          final lines = splitIntoRuleLines(result.text);
          if (lines.isNotEmpty) {
            return ExtractedDocumentContent(
              fullText: result.text,
              totalPages: result.pageCount,
              lines: lines,
            );
          }
        }
      } catch (e) {
        debugPrint('On-device OCR fallback skipped: $e');
      }
    }

    // Never parse raw binary byte streams — that produces corrupt font gibberish
    throw Exception(
      'Could not extract text lines from "$fileName".\n'
      'The original document is still displayed as-is.',
    );
  }
}

class _PdfExtractParams {
  final String filePath;
  final int maxPages;
  const _PdfExtractParams(this.filePath, this.maxPages);
}

Future<ExtractedDocumentContent?> _isolateSyncfusionExtract(_PdfExtractParams params) async {
  try {
    final file = File(params.filePath);
    final bytes = await file.readAsBytes();
    final sf.PdfDocument doc = sf.PdfDocument(inputBytes: bytes);
    final extractor = sf.PdfTextExtractor(doc);
    final totalPages = doc.pages.count;

    final allLines = <SpokenLine>[];
    final fullTextBuffer = StringBuffer();

    final pagesToExtract = totalPages > params.maxPages ? params.maxPages : totalPages;
    for (int i = 0; i < pagesToExtract; i++) {
      final pageNum = i + 1;

      // Extract structured visual text lines with precise bounding boxes
      final textLines = extractor.extractTextLines(
        startPageIndex: i,
        endPageIndex: i,
      );

      if (textLines.isNotEmpty) {
        final pageSpokenLines = PdfExtractorService.buildSpokenLinesFromTextLines(
          textLines,
          pageNumber: pageNum,
          startIndex: allLines.length,
        );

        if (pageSpokenLines.isNotEmpty) {
          for (final sl in pageSpokenLines) {
            fullTextBuffer.writeln(sl.text);
          }
          allLines.addAll(pageSpokenLines);
          continue;
        }
      }

      // Fallback for pages without structured lines (e.g. raw text stream)
      final pageText = extractor.extractText(
        startPageIndex: i,
        endPageIndex: i,
      );

      if (pageText.trim().length < 15 || !PdfExtractorService.isReadableHumanText(pageText)) {
        continue;
      }

      fullTextBuffer.writeln(pageText);
      final pageLines = PdfExtractorService.splitIntoRuleLines(
        pageText,
        pageNumber: pageNum,
        startIndex: allLines.length,
      );
      allLines.addAll(pageLines);
    }
    doc.dispose();

    if (allLines.isNotEmpty) {
      final normalized = List.generate(
        allLines.length,
        (idx) => SpokenLine(
          index: idx,
          text: allLines[idx].text,
          pageNumber: allLines[idx].pageNumber,
          isHeading: allLines[idx].isHeading,
          lineBounds: allLines[idx].lineBounds,
          words: allLines[idx].words,
        ),
      );
      return ExtractedDocumentContent(
        fullText: fullTextBuffer.toString(),
        totalPages: totalPages,
        lines: normalized,
      );
    }
  } catch (e) {
    debugPrint('Isolate Syncfusion extraction error: $e');
  }
  return null;
}
