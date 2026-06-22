import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

// ══════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════

class MCQModel {
  final String question;
  final List<String> options;
  final String answer;
  final String explanation;

  const MCQModel({
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  factory MCQModel.fromJson(Map<String, dynamic> j) => MCQModel(
        question: j['question'] as String? ?? '',
        options: (j['options'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        answer: j['answer'] as String? ?? '',
        explanation: j['explanation'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'answer': answer,
        'explanation': explanation,
      };
}

class NoteModel {
  final String heading;
  final String content;

  const NoteModel({required this.heading, required this.content});

  factory NoteModel.fromJson(Map<String, dynamic> j) => NoteModel(
        heading: j['heading'] as String? ?? '',
        content: j['content'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'heading': heading, 'content': content};
}

class GenerationResult {
  final List<MCQModel> mcqs;
  final List<NoteModel> notes;
  final String provider;
  final List<String> skipped;
  final bool fromCache;
  final bool isFreeTrialUse;
  final bool showDisclaimer;
  final bool isOffline;
  final String? warning;

  const GenerationResult({
    required this.mcqs,
    required this.notes,
    required this.provider,
    this.skipped = const [],
    this.fromCache = false,
    this.isFreeTrialUse = false,
    this.showDisclaimer = false,
    this.isOffline = false,
    this.warning,
  });
}

enum AIErrorType {
  freeTrialExhausted,
  noKeys,
  noOfflineModel,
  allProvidersFailed,
  networkError,
}

class AIException implements Exception {
  final AIErrorType type;
  final String message;
  const AIException({required this.type, required this.message});
  @override
  String toString() => message;
}

// ══════════════════════════════════════════
// SECURE KEY STORAGE
// Keys NEVER touch SharedPreferences or backend DB.
// Stored only in Android Keystore / iOS Keychain.
// Per-user: scoped to userId so accounts never bleed.
// ══════════════════════════════════════════

class AIKeyStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _geminiPrefix    = 'ai_gemini_';
  static const _groqPrefix      = 'ai_groq_';
  static const _cerebrasPrefix  = 'ai_cerebras_';
  static const _onDeviceKey     = 'ai_ondevice_ok_';
  static const _freeUsedKey     = 'ai_free_used_';

  static Future<String> _uid() async =>
      await TokenManager.getUserId() ?? 'default';

  // ── Gemini ──────────────────────────────
  static Future<void>    saveGeminiKey(String k) async =>
      _storage.write(key: '$_geminiPrefix${await _uid()}', value: k.trim());
  static Future<String?> getGeminiKey() async =>
      _storage.read(key: '$_geminiPrefix${await _uid()}');
  static Future<void>    deleteGeminiKey() async =>
      _storage.delete(key: '$_geminiPrefix${await _uid()}');

  // ── Groq ────────────────────────────────
  static Future<void>    saveGroqKey(String k) async =>
      _storage.write(key: '$_groqPrefix${await _uid()}', value: k.trim());
  static Future<String?> getGroqKey() async =>
      _storage.read(key: '$_groqPrefix${await _uid()}');
  static Future<void>    deleteGroqKey() async =>
      _storage.delete(key: '$_groqPrefix${await _uid()}');

  // ── Cerebras ────────────────────────────
  static Future<void>    saveCerebrasKey(String k) async =>
      _storage.write(key: '$_cerebrasPrefix${await _uid()}', value: k.trim());
  static Future<String?> getCerebrasKey() async =>
      _storage.read(key: '$_cerebrasPrefix${await _uid()}');
  static Future<void>    deleteCerebrasKey() async =>
      _storage.delete(key: '$_cerebrasPrefix${await _uid()}');

  // ── On-device disclaimer accepted ───────
  static Future<bool> hasAcceptedOnDeviceDisclaimer() async {
    final v = await _storage.read(key: '$_onDeviceKey${await _uid()}');
    return v == 'true';
  }
  static Future<void> acceptOnDeviceDisclaimer() async =>
      _storage.write(key: '$_onDeviceKey${await _uid()}', value: 'true');

  // ── Free generation local mirror ────────
  static Future<bool> hasFreeGenerationBeenUsed() async {
    final v = await _storage.read(key: '$_freeUsedKey${await _uid()}');
    return v == 'true';
  }
  static Future<void> markFreeGenerationUsed() async =>
      _storage.write(key: '$_freeUsedKey${await _uid()}', value: 'true');

  // ── Load all keys as map (sent to backend) ──
  // Never logged, never stored on backend.
  static Future<Map<String, String?>> loadAllKeys() async => {
        'gemini':   await getGeminiKey(),
        'groq':     await getGroqKey(),
        'cerebras': await getCerebrasKey(),
      };

  static Future<bool> hasAnyKey() async {
    final k = await loadAllKeys();
    return k.values.any((v) => v != null && v.isNotEmpty);
  }

  // ── Clear all keys ───────────────────────
  static Future<void> clearAll() async {
    final uid = await _uid();
    await Future.wait([
      _storage.delete(key: '$_geminiPrefix$uid'),
      _storage.delete(key: '$_groqPrefix$uid'),
      _storage.delete(key: '$_cerebrasPrefix$uid'),
    ]);
  }
}

// ══════════════════════════════════════════
// CONNECTIVITY
// ══════════════════════════════════════════

Future<bool> isOnline() async {
  try {
    final r = await Connectivity().checkConnectivity();
    return r != ConnectivityResult.none;
  } catch (_) {
    return false;
  }
}

// ══════════════════════════════════════════
// AI GENERATION SERVICE
// Priority:
//   0. Lumio server key  (1 free trial)
//   1. User Gemini key   (primary)
//   2. User Groq key     (fast fallback)
//   3. User Cerebras key (volume fallback)
//   4. On-device Gemma   (offline)
// ══════════════════════════════════════════

class AIGenerationService {

  static Future<GenerationResult> generate({
    required String text,
    required int numMcqs,
    required String difficulty,
    String? chapterKey,
    required BuildContext context,
  }) async {
    final online = await isOnline();

    if (!online) {
      return _tryOffline(text, numMcqs, difficulty,
          reason: 'No internet connection');
    }

    try {
      final keys = await AIKeyStore.loadAllKeys();
      final result = await _callBackend(
          text: text, numMcqs: numMcqs, difficulty: difficulty, keys: keys);

      // Backend requested disclaimer display
      if (result.showDisclaimer && context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DisclaimerScreen()));
        });
      }

      return result;
    } on AIException catch (e) {
      if (e.type == AIErrorType.freeTrialExhausted) {
        await AIKeyStore.markFreeGenerationUsed();
        rethrow;
      }
      return _tryOffline(text, numMcqs, difficulty,
          reason: 'Cloud AI unavailable');
    } catch (_) {
      return _tryOffline(text, numMcqs, difficulty,
          reason: 'Cloud AI unavailable');
    }
  }

  static Future<GenerationResult> _callBackend({
    required String text,
    required int numMcqs,
    required String difficulty,
    required Map<String, String?> keys,
  }) async {
    final res = await ApiClient.post('/api/generate/free', body: {
      'text': text,
      'numMcqs': numMcqs,
      'difficulty': difficulty,
      // Keys go device → backend over HTTPS only. Never logged/stored.
      'keys': {
        'gemini':   keys['gemini']   ?? '',
        'groq':     keys['groq']     ?? '',
        'cerebras': keys['cerebras'] ?? '',
      },
    });

    if (res['error'] == 'free_trial_exhausted') {
      throw const AIException(
        type: AIErrorType.freeTrialExhausted,
        message: 'You have used your 1 free generation. '
            'Add a free API key for unlimited access.',
      );
    }
    if (res['error'] == 'all_providers_exhausted') {
      throw const AIException(
        type: AIErrorType.allProvidersFailed,
        message: 'All AI providers are busy right now. Using offline AI instead.',
      );
    }

    final mcqs = (res['mcqs'] as List<dynamic>? ?? [])
        .map((e) => MCQModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final notes = (res['notes'] as List<dynamic>? ?? [])
        .map((e) => NoteModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final skipped = (res['attempted'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return GenerationResult(
      mcqs: mcqs,
      notes: notes,
      provider: res['provider'] as String? ?? 'unknown',
      skipped: skipped,
      isFreeTrialUse: res['isFreeTrialUse'] as bool? ?? false,
      showDisclaimer: res['showDisclaimer'] as bool? ?? false,
    );
  }

  static Future<GenerationResult> _tryOffline(
    String text, int numMcqs, String difficulty, {required String reason}) async {
    // TODO: wire up flutter_gemma when model download is implemented:
    // final installed = await FlutterGemma.instance.isModelInstalled;
    // if (installed) { ... return GenerationResult(..., isOffline: true) }
    throw AIException(
      type: AIErrorType.noOfflineModel,
      message: '$reason. '
          'Connect to the internet or download the offline model in Settings.',
    );
  }

  // ── Key validation helpers ────────────────
  static Future<bool> validateGeminiKey(String key) async {
    try {
      final res = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/'
            'gemini-2.0-flash:generateContent?key=$key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': [{'parts': [{'text': 'Hi'}]}],
            'generationConfig': {'maxOutputTokens': 5}}),
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  static Future<bool> validateGroqKey(String key) async {
    if (!key.startsWith('gsk_')) return false;
    try {
      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
        body: jsonEncode({'model': 'llama-3.3-70b-versatile',
            'messages': [{'role': 'user', 'content': 'Hi'}], 'max_tokens': 5}),
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  static Future<bool> validateCerebrasKey(String key) async {
    try {
      final res = await http.post(
        Uri.parse('https://api.cerebras.ai/v1/chat/completions'),
        headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
        body: jsonEncode({'model': 'llama3.3-70b',
            'messages': [{'role': 'user', 'content': 'Hi'}], 'max_tokens': 5}),
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) { return false; }
  }
}

// ══════════════════════════════════════════
// AI PROVIDER BANNER
// Shows which provider was used — never an error
// for a successful automatic switch.
// ══════════════════════════════════════════

class AIProviderBanner extends StatelessWidget {
  final GenerationResult result;
  const AIProviderBanner({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.isOffline) {
      return _badge(icon: Icons.wifi_off_rounded,
          label: 'Offline AI — limited quality', color: Colors.orange);
    }
    if (result.skipped.isNotEmpty) {
      return Tooltip(
        message: 'Tried: ${result.skipped.join(", ")} — switched automatically',
        child: _badge(icon: Icons.swap_horiz_rounded,
            label: 'Used ${result.provider} (auto-switched)', color: Colors.blue),
      );
    }
    const icons = {'gemini': '🌟', 'groq': '⚡', 'cerebras': '🔵', 'server': '🆓'};
    return _badge(icon: Icons.cloud_done_rounded,
        label: '${icons[result.provider] ?? "🤖"} ${result.provider}',
        color: Colors.green);
  }

  Widget _badge({required IconData icon, required String label, required Color color}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color,
              fontWeight: FontWeight.w500)),
        ]));
}

// ══════════════════════════════════════════
// DISCLAIMER SCREEN
// Shown after free trial is used.
// Matches the spec layout exactly.
// ══════════════════════════════════════════

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050818),
      body: Stack(children: [
        Container(decoration: const BoxDecoration(
            gradient: RadialGradient(center: Alignment(0.7, -0.6),
                radius: 1.2,
                colors: [Color(0x267B61FF), Color(0xFF050818)]))),
        SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            const Text('🎉', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text("You've tried Lumio AI!",
                style: TextStyle(color: Colors.white, fontSize: 24,
                    fontWeight: FontWeight.w800, fontFamily: 'Georgia')),
            const SizedBox(height: 12),
            const Text(
              'You used your 1 free generation. Lumio is 100% free — '
              'AI just costs money to run, so we ask you to bring your '
              'own free API key. It takes 2 minutes and costs nothing.',
              style: TextStyle(color: Color(0xFF8892B0), fontSize: 15, height: 1.6)),
            const SizedBox(height: 32),

            // Option A
            _OptionCard(
              icon: '☁️',
              title: 'Option A — Cloud AI (Recommended)',
              badge: 'Free • Best Quality',
              badgeColor: const Color(0xFF34EEB6),
              description:
                  'Add a free API key from Google, Groq, or Cerebras. '
                  'Best quality. Works on any phone. Auto-switches if '
                  'one provider hits its limit.',
              buttonLabel: 'Set Up Free API Keys →',
              onTap: () { Navigator.pop(context);
                Navigator.pushNamed(context, '/settings/api-keys'); }),

            const SizedBox(height: 16),

            // Option B
            _OptionCard(
              icon: '📱',
              title: 'Option B — Offline AI',
              badge: 'No Internet Needed',
              badgeColor: const Color(0xFF48C6EF),
              description:
                  'Download Gemma 7B to your device. Works without internet. '
                  'No API keys needed.\n\n'
                  '⚠️ Requires 4 GB storage and 6 GB RAM. '
                  'May be slow on budget phones. '
                  'Best experience on laptop or desktop.',
              buttonLabel: 'Download Offline Model →',
              onTap: () { Navigator.pop(context);
                Navigator.pushNamed(context, '/settings/offline-ai'); }),

            const SizedBox(height: 20),

            // Do Both
            GestureDetector(
              onTap: () { Navigator.pop(context);
                Navigator.pushNamed(context, '/settings/setup-all'); },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF7B61FF), Color(0xFF00D4FF)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: const Color(0xFF7B61FF).withOpacity(0.4),
                      blurRadius: 20, offset: const Offset(0, 8))]),
                child: const Text('✨  Do Both — Recommended',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.w700)))),

            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Remind Me Later',
                      style: TextStyle(color: Color(0xFF4A5568), fontSize: 14)))),
            const SizedBox(height: 32),
          ]))),
      ]));
  }
}

class _OptionCard extends StatelessWidget {
  final String icon, title, badge, description, buttonLabel;
  final Color badgeColor;
  final VoidCallback onTap;

  const _OptionCard({required this.icon, required this.title,
      required this.badge, required this.badgeColor,
      required this.description, required this.buttonLabel,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: const Color(0xFF0D1225),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1E2A4A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: badgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Text(badge, style: TextStyle(fontSize: 11, color: badgeColor,
              fontWeight: FontWeight.w600))),
        const SizedBox(height: 12),
        Text(description, style: const TextStyle(color: Color(0xFF8892B0),
            fontSize: 13, height: 1.6)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity,
          child: OutlinedButton(onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: badgeColor,
              side: BorderSide(color: badgeColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12)),
            child: Text(buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.w600)))),
      ]));
  }
}