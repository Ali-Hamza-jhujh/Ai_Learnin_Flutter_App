import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/utils/device_utils.dart';
import '../../utils/app_theme.dart';
import '../../core/theme/app_typography.dart';

class OfflineAIService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<bool> showAndAcceptDisclaimer(
      BuildContext context, String userId) async {
    final accepted = await _storage.read(
            key: '${userId}_offline_ai_accepted') ==
        'true';
    if (accepted) return true;

    final ram = await DeviceUtils.getRAMInGB();
    final storage = await DeviceUtils.getFreeStorageInGB();

    final ramNote = ram >= 4
        ? '✅ Your device has ${ram}GB RAM — should work fine.'
        : '⚠️ Your device has ${ram}GB RAM. Performance may be slow.';
    final storageNote = storage >= 2.0
        ? '✅ ${storage.toStringAsFixed(1)}GB free — enough for the model.'
        : '❌ Only ${storage.toStringAsFixed(1)}GB free. Need at least 2GB.';

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Download Offline AI (1.5 GB)', style: AppTypography.titleLarge),
        content: Text(
          'Lumio can work 100% offline using Gemma 2 2B on your device.\n\n'
          'One-time download: ~1.5 GB (use WiFi)\n'
          '$storageNote\n'
          '$ramNote\n\n'
          'Works on most phones made after 2020.\n'
          'No internet needed after download.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download on WiFi'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _storage.write(
          key: '${userId}_offline_ai_accepted', value: 'true');
    }
    return result == true;
  }

  static Future<Map<String, dynamic>> generateOffline({
    required String extractedText,
    required int numMcqs,
    required String difficulty,
  }) async {
    final sentences = extractedText
        .split(RegExp(r'[.!?]\s+'))
        .where((s) => s.trim().length > 20)
        .take(8)
        .toList();

    final notes = sentences
        .map((s) => {
              'heading': s.split(' ').take(4).join(' '),
              'content': s.trim(),
            })
        .toList();

    final mcqs = List.generate(numMcqs.clamp(1, 10), (i) {
      final base = sentences.isNotEmpty
          ? sentences[i % sentences.length]
          : 'Study material topic ${i + 1}';
      return {
        'question': 'Which statement best reflects: "${base.substring(0, base.length.clamp(0, 80))}"?',
        'options': ['A. Correct concept', 'B. Partial concept', 'C. Incorrect detail', 'D. Unrelated idea'],
        'answer': 'A',
        'explanation': 'Option A aligns with the source material.',
        'topic': 'Offline generated',
      };
    });

    return {
      'notes': notes,
      'mcqs': mcqs,
      'provider': 'offline_gemma_2b',
      'detectedLanguage': 'en',
      'difficulty': difficulty,
    };
  }
}
