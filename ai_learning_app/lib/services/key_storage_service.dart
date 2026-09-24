import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<void> saveGroqKey(String key) async {
    await _storage.write(key: 'lumio_groq_key', value: key.trim());
  }

  static Future<void> saveGeminiKey(String key) async {
    await _storage.write(key: 'lumio_gemini_key', value: key.trim());
  }

  static Future<void> saveCerebrasKey(String key) async {
    await _storage.write(key: 'lumio_cerebras_key', value: key.trim());
  }

  static Future<String?> getGroqKey() async {
    return await _storage.read(key: 'lumio_groq_key');
  }

  static Future<String?> getGeminiKey() async {
    return await _storage.read(key: 'lumio_gemini_key');
  }

  static Future<String?> getCerebrasKey() async {
    return await _storage.read(key: 'lumio_cerebras_key');
  }

  static Future<Map<String, String?>> getAllKeys() async {
    return {
      'groq': await getGroqKey(),
      'gemini': await getGeminiKey(),
      'cerebras': await getCerebrasKey(),
    };
  }

  static Future<bool> hasAnyKey() async {
    final keys = await getAllKeys();
    return keys.values.any((v) => v != null && v.isNotEmpty);
  }

  static Future<void> clearAllKeys() async {
    await _storage.delete(key: 'lumio_groq_key');
    await _storage.delete(key: 'lumio_gemini_key');
    await _storage.delete(key: 'lumio_cerebras_key');
  }
}
