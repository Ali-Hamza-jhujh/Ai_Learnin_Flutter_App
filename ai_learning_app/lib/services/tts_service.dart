import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused }

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();

  final _wordRangeController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onWordRange => _wordRangeController.stream;

  final _stateController = StreamController<TtsState>.broadcast();
  Stream<TtsState> get onStateChanged => _stateController.stream;

  final _completionController = StreamController<void>.broadcast();
  Stream<void> get onCompletion => _completionController.stream;

  TtsState _ttsState = TtsState.stopped;
  TtsState get ttsState => _ttsState;

  Future<void> init() async {
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.awaitSynthCompletion(true);

    _flutterTts.setProgressHandler(
        (String text, int startOffset, int endOffset, String word) {
      _wordRangeController.add({
        'text': text,
        'start': startOffset,
        'end': endOffset,
        'word': word,
      });
    });

    _flutterTts.setStartHandler(() {
      _ttsState = TtsState.playing;
      _stateController.add(_ttsState);
    });

    _flutterTts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
      _stateController.add(_ttsState);
      _completionController.add(null);
      _wordRangeController.add({}); // clear word range
    });

    _flutterTts.setCancelHandler(() {
      _ttsState = TtsState.stopped;
      _stateController.add(_ttsState);
      _wordRangeController.add({});
    });

    _flutterTts.setPauseHandler(() {
      _ttsState = TtsState.paused;
      _stateController.add(_ttsState);
    });

    _flutterTts.setContinueHandler(() {
      _ttsState = TtsState.playing;
      _stateController.add(_ttsState);
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _flutterTts.speak(text);
  }

  Future<void> pause() async {
    await _flutterTts.pause();
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  Future<void> setRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> setVolume(double volume) async {
    await _flutterTts.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> setLanguage(String language) async {
    await _flutterTts.setLanguage(language);
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch.clamp(0.5, 2.0));
  }
}
