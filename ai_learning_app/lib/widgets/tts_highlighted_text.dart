import 'dart:async';
import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../utils/app_theme.dart';

class TtsHighlightedText extends StatefulWidget {
  final String text;
  final TextStyle baseStyle;
  final TextStyle highlightStyle;
  final bool autoStart;
  final bool showControls;

  const TtsHighlightedText({
    super.key,
    required this.text,
    required this.baseStyle,
    required this.highlightStyle,
    this.autoStart = false,
    this.showControls = true,
  });

  @override
  State<TtsHighlightedText> createState() => _TtsHighlightedTextState();
}

class _TtsHighlightedTextState extends State<TtsHighlightedText> {
  final TtsService _ttsService = TtsService();
  StreamSubscription? _wordRangeSubscription;
  StreamSubscription? _stateSubscription;

  int _currentStart = -1;
  bool _isPlaying = false;
  bool _isPaused = false;
  double _speechRate = 0.5; // FlutterTTS rate: 0.5 is normal speed for most engines

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _sentenceKeys = {};

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _ttsService.init();

    _wordRangeSubscription = _ttsService.onWordRange.listen((range) {
      if (mounted) {
        setState(() {
          _currentStart = range['start'] as int? ?? -1;
        });
        _scrollToActiveSentence();
      }
    });

    _stateSubscription = _ttsService.onStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == TtsState.playing;
          _isPaused = state == TtsState.paused;
          if (!_isPlaying && !_isPaused) {
            _currentStart = -1;
          }
        });
      }
    });

    if (widget.autoStart) {
      _speak();
    }
  }

  @override
  void dispose() {
    _wordRangeSubscription?.cancel();
    _stateSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveSentence() {
    if (_currentStart == -1) return;
    final sentences = _splitIntoSentences(widget.text);
    int activeIdx = -1;

    int accumLength = 0;
    for (int i = 0; i < sentences.length; i++) {
      final sentenceStart = widget.text.indexOf(sentences[i], accumLength);
      if (sentenceStart == -1) continue;
      final sentenceEnd = sentenceStart + sentences[i].length;
      accumLength = sentenceEnd;

      if (_currentStart >= sentenceStart && _currentStart <= sentenceEnd) {
        activeIdx = i;
        break;
      }
    }

    if (activeIdx != -1 && _sentenceKeys.containsKey(activeIdx)) {
      final keyContext = _sentenceKeys[activeIdx]?.currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
      }
    }
  }

  Future<void> _speak([String? customText]) async {
    final textToSpeak = customText ?? widget.text;
    await _ttsService.setRate(_speechRate);
    await _ttsService.speak(textToSpeak);
  }

  Future<void> _pause() async {
    await _ttsService.pause();
  }

  Future<void> _stop() async {
    await _ttsService.stop();
  }

  Future<void> _setRate(double rate) async {
    setState(() => _speechRate = rate);
    await _ttsService.setRate(rate);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHighlightedText(),
        if (widget.showControls) ...[
          const SizedBox(height: 16),
          _buildAudioControlToolbar(),
        ],
      ],
    );
  }

  Widget _buildHighlightedText() {
    final sentences = _splitIntoSentences(widget.text);

    int accumPos = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(sentences.length, (index) {
        final sentence = sentences[index];
        final sentenceStart = widget.text.indexOf(sentence, accumPos);
        final sentenceEnd = sentenceStart == -1 ? 0 : sentenceStart + sentence.length;
        if (sentenceStart != -1) accumPos = sentenceEnd;

        _sentenceKeys.putIfAbsent(index, () => GlobalKey());

        final isSentenceActive = _currentStart >= sentenceStart &&
            _currentStart <= sentenceEnd &&
            _isPlaying;

        return GestureDetector(
          key: _sentenceKeys[index],
          onTap: () {
            final fromText = widget.text.substring(sentenceStart);
            _speak(fromText);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSentenceActive
                  ? AppColors.violet.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(
                  color: isSentenceActive
                      ? AppColors.violetLight
                      : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            child: _buildHighlightedSentence(sentence, sentenceStart),
          ),
        );
      }),
    );
  }

  Widget _buildHighlightedSentence(String sentence, int offset) {
    final words = sentence.split(RegExp(r'(\s+)'));

    int runningOffset = offset;
    return Wrap(
      spacing: 2,
      runSpacing: 4,
      children: words.map((word) {
        final wordStart = runningOffset;
        final wordEnd = wordStart + word.length;
        runningOffset = wordEnd;

        if (word.trim().isEmpty) {
          return Text(word, style: widget.baseStyle);
        }

        final isWordActive = _currentStart >= wordStart &&
            _currentStart <= wordEnd &&
            _isPlaying;

        if (isWordActive) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.violet,
                  AppColors.cyan,
                ],
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: AppColors.violet.withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              word,
              style: widget.highlightStyle.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        return Text(
          word,
          style: widget.baseStyle,
        );
      }).toList(),
    );
  }

  Widget _buildAudioControlToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Equalizer / Pulse Indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isPlaying
                      ? AppColors.violet.withValues(alpha: 0.2)
                      : AppColors.inputBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.record_voice_over : Icons.headset_rounded,
                  color: _isPlaying ? AppColors.violetLight : AppColors.textSub,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPlaying
                          ? 'Reading out loud…'
                          : _isPaused
                              ? 'Paused'
                              : 'Auditory Smart Reader',
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isPlaying
                          ? 'Tap any sentence to jump reading'
                          : 'Tap Play to start listening with line & word highlight',
                      style: const TextStyle(
                        color: AppColors.textSub,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Play / Pause Button
              GestureDetector(
                onTap: () {
                  if (_isPlaying) {
                    _pause();
                  } else if (_isPaused) {
                    _speak();
                  } else {
                    _speak();
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGrad,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.violet.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Stop Button
              if (_isPlaying || _isPaused)
                IconButton(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop_rounded,
                      color: AppColors.error, size: 22),
                  tooltip: 'Stop Reading',
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.inputBorder, height: 1),
          const SizedBox(height: 8),
          // Speed Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Speed:',
                style: TextStyle(
                    color: AppColors.textSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
              Row(
                children: [0.3, 0.5, 0.7, 1.0].map((rate) {
                  final label = rate == 0.3
                      ? '0.75x'
                      : rate == 0.5
                          ? '1.0x'
                          : rate == 0.7
                              ? '1.5x'
                              : '2.0x';
                  final isSelected = (_speechRate - rate).abs() < 0.05;
                  return GestureDetector(
                    onTap: () => _setRate(rate),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.violet
                            : AppColors.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.violetLight
                              : AppColors.inputBorder,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSub,
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _splitIntoSentences(String text) {
    final sentences = text.split(RegExp(r'(?<=[.!?:;\n])\s+'));
    return sentences.where((s) => s.trim().isNotEmpty).toList();
  }
}
