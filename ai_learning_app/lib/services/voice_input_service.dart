import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceInputService {
  static final VoiceInputService _instance = VoiceInputService._internal();
  factory VoiceInputService() => _instance;
  VoiceInputService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;

  final _textController = StreamController<String>.broadcast();
  Stream<String> get onText => _textController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get onStatus => _statusController.stream;

  bool get isListening => _speechToText.isListening;

  Future<bool> init() async {
    if (_isInitialized) return true;
    _isInitialized = await _speechToText.initialize(
      onStatus: (status) => _statusController.add(status),
      onError: (errorNotification) => _statusController.add('error: ${errorNotification.errorMsg}'),
    );
    return _isInitialized;
  }

  Future<void> startListening({String localeId = 'en_US'}) async {
    if (!_isInitialized) await init();
    if (!_isInitialized) return;

    await _speechToText.listen(
      onResult: (result) {
        _textController.add(result.recognizedWords);
      },
      localeId: localeId,
      cancelOnError: true,
      partialResults: true,
    );
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
  }
  
  Future<void> cancelListening() async {
    await _speechToText.cancel();
  }
}
