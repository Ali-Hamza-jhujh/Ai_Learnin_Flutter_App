import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AIKeyStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<void> saveKey(
      String userId, String provider, String key) async {
    if (key.trim().isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }
    await _storage.write(
        key: '${userId}_${provider}_key', value: key.trim());
  }

  static Future<String?> getKey(String userId, String provider) async {
    return _storage.read(key: '${userId}_${provider}_key');
  }

  static Future<Map<String, String?>> loadAllKeys(String userId) async {
    return {
      'gemini': await getKey(userId, 'gemini'),
      'groq': await getKey(userId, 'groq'),
      'cerebras': await getKey(userId, 'cerebras'),
    };
  }

  static Future<void> clearAllKeys(String userId) async {
    for (final provider in ['gemini', 'groq', 'cerebras']) {
      await _storage.delete(key: '${userId}_${provider}_key');
    }
    await _storage.delete(key: '${userId}_offline_ai_accepted');
  }

  static Future<bool> hasAnyKey(String userId) async {
    final keys = await loadAllKeys(userId);
    return keys.values.any((v) => v != null && v!.isNotEmpty);
  }
}
