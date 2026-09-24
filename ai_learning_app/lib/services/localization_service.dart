import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  String _currentLocale = 'en';
  Map<String, String> _localizedStrings = {};

  String get currentLocale => _currentLocale;
  bool get isRTL => ['ur', 'ar'].contains(_currentLocale);

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'ur', 'name': 'اردو (Urdu)'},
    {'code': 'ar', 'name': 'العربية (Arabic)'},
    {'code': 'es', 'name': 'Español (Spanish)'},
    {'code': 'hi', 'name': 'हिन्दी (Hindi)'},
    {'code': 'zh', 'name': '中文 (Chinese)'},
    {'code': 'fr', 'name': 'Français (French)'},
    {'code': 'pt', 'name': 'Português (Portuguese)'},
    {'code': 'de', 'name': 'Deutsch (German)'},
    {'code': 'ja', 'name': '日本語 (Japanese)'},
    {'code': 'ko', 'name': '한국어 (Korean)'},
    {'code': 'tr', 'name': 'Türkçe (Turkish)'},
    {'code': 'ru', 'name': 'Русский (Russian)'},
    {'code': 'id', 'name': 'Bahasa Indonesia'},
    {'code': 'vi', 'name': 'Tiếng Việt (Vietnamese)'},
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLocale = prefs.getString('app_locale') ?? 'en';
    await _loadTranslationFile();
    notifyListeners();
  }

  Future<void> _loadTranslationFile() async {
    try {
      final jsonString = await rootBundle.loadString('assets/i18n/$_currentLocale.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      _localizedStrings = jsonMap.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      debugPrint('Error loading translation file assets/i18n/$_currentLocale.json: $e');
      _localizedStrings = {};
    }
  }

  Future<void> changeLanguage(String code) async {
    _currentLocale = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', code);
    await _loadTranslationFile();
    notifyListeners();
  }

  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
}
