import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/errors/app_exceptions.dart';
import '../../models/ai_result_model.dart';
import '../../services/api_client.dart';
import '../cache/local_cache_service.dart';
import 'ai_key_store.dart';
import 'offline_ai_service.dart';
import '../../screen/disclaimer_screen.dart';

class AIGenerationService {
  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<Map<String, dynamic>> _checkFreeTrial() async {
    return ApiClient.get('/api/generate/trial-status');
  }

  Future<AIResult> generate({
    required String userId,
    required String pdfHash,
    required String extractedText,
    required List<String> selectedChapters,
    required String summaryType,
    required String difficulty,
    required int numMcqs,
    required String mode,
    required String type,
    required String title,
    required BuildContext context,
  }) async {
    final online = await _isOnline();
    final keys = await AIKeyStore.loadAllKeys(userId);
    final hasKeys = keys.values.any((v) => v != null && v!.isNotEmpty);

    final cacheKey = type == 'mcq'
        ? LocalCacheService.mcqCacheKey(
            userId: userId,
            pdfHash: pdfHash,
            chapters: selectedChapters,
            difficulty: difficulty,
            numMcqs: numMcqs,
          )
        : LocalCacheService.notesCacheKey(
            userId: userId,
            pdfHash: pdfHash,
            chapters: selectedChapters,
            summaryType: summaryType,
          );

    final localCached = type == 'mcq'
        ? await LocalCacheService.getMcq(cacheKey)
        : await LocalCacheService.getNotes(cacheKey);

    if (localCached != null) {
      return AIResult(
        data: localCached,
        provider: localCached['provider']?.toString() ?? 'local_cache',
        cached: true,
      );
    }

    if (!hasKeys) {
      final trialStatus = await _checkFreeTrial();
      final used = trialStatus['used'] == true;
      if (!used) {
        final result = await _callFreeGeneration(
          pdfHash: pdfHash,
          selectedChapters: selectedChapters,
          summaryType: summaryType,
          difficulty: difficulty,
          numMcqs: numMcqs,
          mode: mode,
          type: type,
          title: title,
        );
        await _saveLocal(cacheKey, result, type);
        return result;
      }

      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DisclaimerScreen(userId: userId)),
        );
      }
      throw AIException(type: AIErrorType.freeTrialExhausted);
    }

    if (online) {
      try {
        final result = await _callWithKeys(
          pdfHash: pdfHash,
          selectedChapters: selectedChapters,
          summaryType: summaryType,
          difficulty: difficulty,
          numMcqs: numMcqs,
          mode: mode,
          type: type,
          title: title,
          keys: keys,
        );
        await _saveLocal(cacheKey, result, type);
        return result;
      } on ApiException catch (e) {
        if (!e.message.contains('All providers exhausted')) rethrow;
      }
    }

    final accepted =
        await OfflineAIService.showAndAcceptDisclaimer(context, userId);
    if (!accepted) {
      throw AIException(type: AIErrorType.offlineUnavailable);
    }

    final offline = await OfflineAIService.generateOffline(
      extractedText: extractedText,
      numMcqs: numMcqs,
      difficulty: difficulty,
    );

    final result = AIResult(
      data: offline,
      provider: 'offline_gemma_2b',
      skipped: const [],
    );
    await _saveLocal(cacheKey, result, type);
    return result;
  }

  Future<void> _saveLocal(String cacheKey, AIResult result, String type) async {
    final payload = {
      ...result.data,
      'provider': result.provider,
    };
    if (type == 'mcq') {
      await LocalCacheService.saveMcq(cacheKey, payload);
    } else {
      await LocalCacheService.saveNotes(cacheKey, payload);
    }
  }

  Future<AIResult> _callFreeGeneration({
    required String pdfHash,
    required List<String> selectedChapters,
    required String summaryType,
    required String difficulty,
    required int numMcqs,
    required String mode,
    required String type,
    required String title,
  }) async {
    final res = await ApiClient.post('/api/generate/free', body: {
      'pdfHash': pdfHash,
      'selectedChapters': selectedChapters,
      'summaryType': summaryType,
      'difficulty': difficulty,
      'numMcqs': numMcqs,
      'mode': mode,
      'type': type,
      'title': title,
    });
    return AIResult.fromJson(res);
  }

  Future<AIResult> _callWithKeys({
    required String pdfHash,
    required List<String> selectedChapters,
    required String summaryType,
    required String difficulty,
    required int numMcqs,
    required String mode,
    required String type,
    required String title,
    required Map<String, String?> keys,
  }) async {
    final res = await ApiClient.post('/api/generate/with-keys', body: {
      'pdfHash': pdfHash,
      'selectedChapters': selectedChapters,
      'summaryType': summaryType,
      'difficulty': difficulty,
      'numMcqs': numMcqs,
      'mode': mode,
      'type': type,
      'title': title,
      'userKeys': {
        'gemini': keys['gemini'],
        'groq': keys['groq'],
        'cerebras': keys['cerebras'],
      },
    });
    return AIResult.fromJson(res);
  }
}
