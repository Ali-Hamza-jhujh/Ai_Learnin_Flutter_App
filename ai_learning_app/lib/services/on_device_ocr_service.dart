import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

/// Languages deliberately shipped for on-device OCR.  Do not add a language
/// here without also adding its traineddata asset in `assets/tessdata/`.
enum OnDeviceOcrLanguage {
  english('English', 'eng'),
  arabic('Arabic', 'ara'),
  russian('Russian', 'rus'),
  german('German', 'deu'),
  simplifiedChinese('Simplified Chinese', 'chi_sim');

  const OnDeviceOcrLanguage(this.label, this.tesseractCode);

  final String label;
  final String tesseractCode;
}

class OnDeviceOcrProgress {
  const OnDeviceOcrProgress({
    required this.currentPage,
    required this.totalPages,
  });

  final int currentPage;
  final int totalPages;
}

class OnDeviceOcrResult {
  const OnDeviceOcrResult({
    required this.text,
    required this.pageCount,
    required this.language,
  });

  final String text;
  final int pageCount;
  final OnDeviceOcrLanguage language;
}

class OnDeviceOcrException implements Exception {
  const OnDeviceOcrException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Renders scanned PDF pages locally and recognizes them with Tesseract.
///
/// Pages are rendered and released sequentially. This keeps memory stable on
/// lower-end phones and avoids retaining any page image after it has been read.
class OnDeviceOcrService {
  static const int maxPagesPerDocument = 30;
  static const int _minimumRecognizedCharacters = 20;
  static const int _maximumLongEdge = 2048;

  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  static Future<OnDeviceOcrResult> extractPdfText({
    required File pdfFile,
    required OnDeviceOcrLanguage language,
    void Function(OnDeviceOcrProgress progress)? onProgress,
  }) async {
    if (!isSupported) {
      throw const OnDeviceOcrException(
        'On-device OCR is available only in the Android and iOS app.',
      );
    }
    if (!await pdfFile.exists()) {
      throw const OnDeviceOcrException('The selected PDF is no longer available.');
    }

    final document = await PdfDocument.openFile(pdfFile.path);
    final pageCount = document.pagesCount;
    if (pageCount <= 0) {
      document.close();
      throw const OnDeviceOcrException('This PDF does not contain any pages.');
    }
    if (pageCount > maxPagesPerDocument) {
      document.close();
      throw OnDeviceOcrException(
        'On-device OCR supports up to $maxPagesPerDocument pages per document. '
        'Please split this scanned PDF into smaller parts.',
      );
    }

    final temporaryDirectory = await getTemporaryDirectory();
    final jobDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}lumio_ocr_${DateTime.now().microsecondsSinceEpoch}',
    );
    await jobDirectory.create();

    final text = StringBuffer();
    try {
      for (var pageNumber = 1; pageNumber <= pageCount; pageNumber++) {
        onProgress?.call(
          OnDeviceOcrProgress(
            currentPage: pageNumber,
            totalPages: pageCount,
          ),
        );

        final page = await document.getPage(pageNumber);
        try {
          final longerEdge = math.max(page.width, page.height);
          final scale = math.min(2.0, _maximumLongEdge / longerEdge);
          final image = await page.render(
            width: math.max(1, (page.width * scale).round()).toDouble(),
            height: math.max(1, (page.height * scale).round()).toDouble(),
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
          );
          if (image == null) {
            throw OnDeviceOcrException(
              'Could not render page $pageNumber for OCR.',
            );
          }

          final imageFile = File(
            '${jobDirectory.path}${Platform.pathSeparator}page_$pageNumber.jpg',
          );
          await imageFile.writeAsBytes(image.bytes, flush: true);
          try {
            final pageText = await FlutterTesseractOcr.extractText(
              imageFile.path,
              language: language.tesseractCode,
              args: const {
                'psm': '3',
                'preserve_interword_spaces': '1',
              },
            );
            if (pageText.trim().isNotEmpty) {
              text
                ..writeln(pageText.trim())
                ..writeln();
            }
          } finally {
            if (await imageFile.exists()) {
              await imageFile.delete();
            }
          }
        } finally {
          page.close();
        }
      }
    } on OnDeviceOcrException {
      rethrow;
    } catch (_) {
      throw const OnDeviceOcrException(
        'On-device OCR could not read this PDF. Make sure the pages are clear and try again.',
      );
    } finally {
      document.close();
      if (await jobDirectory.exists()) {
        await jobDirectory.delete(recursive: true);
      }
    }

    final recognizedText = text.toString().trim();
    if (recognizedText.length < _minimumRecognizedCharacters) {
      throw const OnDeviceOcrException(
        'No readable text was found. Try a clearer scan or choose the correct document language.',
      );
    }

    return OnDeviceOcrResult(
      text: recognizedText,
      pageCount: pageCount,
      language: language,
    );
  }
}
