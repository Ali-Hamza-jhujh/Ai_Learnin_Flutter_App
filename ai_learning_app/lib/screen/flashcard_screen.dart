import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/lumio_theme.dart';

class FlashcardSchedule {
  final int interval;
  final double easeFactor;

  FlashcardSchedule({required this.interval, required this.easeFactor});
}

class SpacedRepetition {
  static FlashcardSchedule calculateNext({
    required bool gotItRight,
    required double easeFactor,
    required int interval,
  }) {
    if (!gotItRight) {
      return FlashcardSchedule(
        interval: 1,
        easeFactor: max(1.3, easeFactor - 0.2),
      );
    }

    final newInterval = interval == 0
        ? 1
        : interval == 1
            ? 3
            : (interval * easeFactor).round();
    final newEase = min(easeFactor + 0.1, 2.5);
    return FlashcardSchedule(interval: newInterval, easeFactor: newEase);
  }
}

class FlashcardScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cards;

  const FlashcardScreen({super.key, required this.cards});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  int _index = 0;
  bool _showBack = false;

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('Flashcards', style: AppTypography.titleLarge),
        ),
        body: Center(
          child: Text('No flashcards yet. Generate notes first.',
              style: AppTypography.bodyLarge),
        ),
      );
    }

    final card = widget.cards[_index];
    final front = card['front']?.toString() ?? '';
    final back = card['back']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Flashcards', style: AppTypography.titleLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('${_index + 1} / ${widget.cards.length}',
                style: AppTypography.caption),
            const SizedBox(height: 20),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showBack = !_showBack),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: LumioDecorations.lumioCard(glowing: true),
                  child: Center(
                    child: Text(
                      _showBack ? back : front,
                      textAlign: TextAlign.center,
                      style: AppTypography.titleMedium,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GlowButton(
                    text: 'Review again',
                    gradient: const LinearGradient(
                      colors: [AppColors.error, Color(0xFFB03A3A)],
                    ),
                    onPressed: _next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlowButton(
                    text: 'Got it',
                    onPressed: _next,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _next() {
    setState(() {
      _showBack = false;
      _index = (_index + 1) % widget.cards.length;
    });
  }
}
