import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/app_theme.dart';
import '../services/tts_service.dart';

class VoiceStudyScreen extends StatefulWidget {
  final String title;
  final String content;

  const VoiceStudyScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  State<VoiceStudyScreen> createState() => _VoiceStudyScreenState();
}

class _VoiceStudyScreenState extends State<VoiceStudyScreen> {
  final TtsService _ttsService = TtsService();
  late StreamSubscription _wordRangeSub;
  late StreamSubscription _stateSub;
  
  int _currentWordStart = -1;
  int _currentWordEnd = -1;
  TtsState _currentState = TtsState.stopped;
  double _speechRate = 0.5;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _ttsService.init();
    
    _wordRangeSub = _ttsService.onWordRange.listen((range) {
      if (!mounted) return;
      setState(() {
        if (range.isEmpty) {
          _currentWordStart = -1;
          _currentWordEnd = -1;
        } else {
          _currentWordStart = range['start'] as int;
          _currentWordEnd = range['end'] as int;
        }
      });
    });

    _stateSub = _ttsService.onStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _currentState = state);
    });
    
    await _ttsService.setRate(_speechRate);
  }

  @override
  void dispose() {
    _wordRangeSub.cancel();
    _stateSub.cancel();
    _ttsService.stop();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_currentState == TtsState.playing) {
      _ttsService.pause();
    } else if (_currentState == TtsState.paused) {
      _ttsService.speak(widget.content);
    } else {
      _ttsService.speak(widget.content);
    }
  }

  void _stop() {
    _ttsService.stop();
  }

  void _changeRate(double delta) {
    setState(() {
      _speechRate = (_speechRate + delta).clamp(0.1, 2.0);
    });
    _ttsService.setRate(_speechRate);
  }

  List<TextSpan> _buildHighlightedText() {
    final spans = <TextSpan>[];
    if (_currentWordStart == -1 || _currentWordEnd == -1 || _currentWordEnd > widget.content.length) {
      spans.add(TextSpan(text: widget.content, style: AppTextStyles.body.copyWith(fontSize: 18, color: AppColors.textWhite)));
      return spans;
    }

    // Highlight all text up to current position (already read)
    final readText = widget.content.substring(0, _currentWordEnd);
    // Current word being spoken
    final currentWord = widget.content.substring(_currentWordStart, _currentWordEnd);
    // Remaining text not yet read
    final remainingText = widget.content.substring(_currentWordEnd);

    // Text that has been read (highlighted in green)
    if (readText.isNotEmpty) {
      spans.add(TextSpan(
        text: readText,
        style: AppTextStyles.body.copyWith(
          fontSize: 18,
          color: AppColors.success,
          fontWeight: FontWeight.w500,
        ),
      ));
    }
    
    // Current word being spoken (highlighted in gold)
    spans.add(TextSpan(
      text: currentWord,
      style: AppTextStyles.body.copyWith(
        fontSize: 18,
        color: AppColors.gold,
        fontWeight: FontWeight.w700,
        backgroundColor: AppColors.gold.withValues(alpha: 0.2),
      ),
    ));

    // Remaining text (dimmed)
    if (remainingText.isNotEmpty) {
      spans.add(TextSpan(
        text: remainingText,
        style: AppTextStyles.body.copyWith(fontSize: 18, color: AppColors.textWhite.withValues(alpha: 0.4)),
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: AppColors.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Voice Study', style: AppTextStyles.heading.copyWith(fontSize: 20)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(widget.title, style: AppTextStyles.heading.copyWith(color: AppColors.violet), textAlign: TextAlign.center),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: RichText(
                text: TextSpan(children: _buildHighlightedText()),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Speed: ${_speechRate.toStringAsFixed(1)}x', style: AppTextStyles.label),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.minus_circle, color: AppColors.textSub),
                            onPressed: () => _changeRate(-0.1),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.plus_circle, color: AppColors.textSub),
                            onPressed: () => _changeRate(0.1),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.stop_fill, size: 36, color: AppColors.error),
                        onPressed: _stop,
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGrad,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: AppColors.violet.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8))
                            ]
                          ),
                          child: Icon(
                            _currentState == TtsState.playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
