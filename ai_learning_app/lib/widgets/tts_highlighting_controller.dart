import 'dart:async';
import 'package:flutter/material.dart';
import '../services/tts_service.dart';

class TtsHighlightingController extends ChangeNotifier {
  final TtsService _ttsService = TtsService();
  StreamSubscription? _wordRangeSubscription;
  
  int _currentStart = -1;
  int _currentEnd = -1;
  bool _isPlaying = false;
  String _activeMessageId = '';

  int get currentStart => _currentStart;
  int get currentEnd => _currentEnd;
  bool get isPlaying => _isPlaying;
  String get activeMessageId => _activeMessageId;

  TtsHighlightingController() {
    _ttsService.init();
    
    _wordRangeSubscription = _ttsService.onWordRange.listen((range) {
      _currentStart = range['start'] as int? ?? -1;
      _currentEnd = range['end'] as int? ?? -1;
      notifyListeners();
    });
  }

  Future<void> speak(String text, String messageId) async {
    // Always stop current playback first
    await _ttsService.stop();
    
    // Reset all state and set new active message
    _activeMessageId = messageId;
    _currentStart = -1;
    _currentEnd = -1;
    _isPlaying = true; // Set playing state immediately
    
    notifyListeners();
    
    // Start new playback
    await _ttsService.speak(text);
  }

  Future<void> stop() async {
    await _ttsService.stop();
    _activeMessageId = '';
    _isPlaying = false;
    _currentStart = -1;
    _currentEnd = -1;
    notifyListeners();
  }

  bool isMessageActive(String messageId) {
    return _isPlaying && _activeMessageId == messageId;
  }

  @override
  void dispose() {
    _wordRangeSubscription?.cancel();
    super.dispose();
  }
}
