import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/lumio_theme.dart';
import '../services/localization_service.dart';
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
        easeFactor: math.max(1.3, easeFactor - 0.2),
      );
    }

    final newInterval = interval == 0
        ? 1
        : interval == 1
            ? 3
            : (interval * easeFactor).round();
    final newEase = math.min(easeFactor + 0.1, 2.5);
    return FlashcardSchedule(interval: newInterval, easeFactor: newEase);
  }
}

class FlashcardScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cards;

  const FlashcardScreen({super.key, required this.cards});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _showBack = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _effectiveCards {
    if (widget.cards.isNotEmpty) return widget.cards;
    return const [
      {
        'front': 'What is Spaced Repetition (SRS)?',
        'back': 'A learning technique that increases intervals between reviews of previously learned material to exploit the psychological spacing effect.',
        'easeFactor': 2.5,
        'interval': 1,
      },
      {
        'front': 'What is Active Recall?',
        'back': 'Testing yourself during study to stimulate memory retrieval, leading to stronger neural connections than passive reading.',
        'easeFactor': 2.5,
        'interval': 1,
      },
      {
        'front': 'How to optimize AI Study Notes?',
        'back': 'Select specific chapters & summary depth (Quick, Normal, Deep) to generate structured Markdown study guides.',
        'easeFactor': 2.5,
        'interval': 1,
      },
    ];
  }

  void _rateCard(String rating) {
    final cards = _effectiveCards;
    final card = cards[_index];
    final double ease = (card['easeFactor'] as double?) ?? 2.5;
    final int currentInterval = (card['interval'] as int?) ?? 1;

    bool gotItRight = rating != 'hard';
    final schedule = SpacedRepetition.calculateNext(
      gotItRight: gotItRight,
      easeFactor: rating == 'easy' ? ease + 0.15 : ease,
      interval: currentInterval,
    );

    _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          rating == 'hard'
              ? 'Card scheduled for review tomorrow (1d)'
              : rating == 'medium'
                  ? 'Card scheduled in 3 days'
                  : 'Mastered! Scheduled in ${schedule.interval} days',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    // Reset card flip and proceed to next index
    if (_showBack) {
      _flipController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _showBack = false;
            _index = (_index + 1) % cards.length;
          });
        }
      });
    } else {
      if (mounted) {
        setState(() {
          _index = (_index + 1) % cards.length;
        });
      }
    }
  }


  void _toggleFlip() {
    if (_showBack) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _showBack = !_showBack;
    });
  }

  Widget _buildRateButton({
    required String label,
    required String subLabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subLabel,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = _effectiveCards;
    final card = cards[_index];
    final front = card['front']?.toString() ?? '';
    final back = card['back']?.toString() ?? '';
    final loc = LocalizationService();
    final isRtl = loc.isRTL;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ScaffoldMessenger(
        child: CupertinoPageScaffold(
          backgroundColor: AppColors.bg,
          navigationBar: CupertinoNavigationBar(
            leading: const CupertinoNavigationBarBackButton(previousPageTitle: ''),
            backgroundColor: AppColors.bgCard.withOpacity(0.8),
            middle: Text(loc.translate('flashcards'),
                style: AppTypography.titleLarge.copyWith(fontSize: 18, color: AppColors.textWhite)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Card ${_index + 1} of ${cards.length}',
                          style: AppTypography.caption),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.violet.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                        ),
                        child: Text('SRS Active',
                            style: TextStyle(color: AppColors.cyan, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // 3D Flip Card Container
                  Expanded(
                    child: GestureDetector(
                      onTap: _toggleFlip,
                      child: AnimatedBuilder(
                        animation: _flipAnimation,
                        builder: (context, child) {
                          final angle = _flipAnimation.value * math.pi;
                          final isBack = angle >= math.pi / 2;
  
                          return Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001) // perspective
                              ..rotateY(angle),
                            alignment: Alignment.center,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isBack 
                                      ? [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)]
                                      : [const Color(0xFFFFFFFF), const Color(0xFFF1F5F9)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: isBack 
                                      ? AppColors.cyan.withOpacity(0.5) 
                                      : AppColors.violet.withOpacity(0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isBack 
                                        ? AppColors.cyan.withOpacity(0.08) 
                                        : AppColors.violet.withOpacity(0.08),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Transform(
                                // Keep the text correctly oriented after 180 deg rotation
                                transform: isBack 
                                    ? (Matrix4.identity()..rotateY(math.pi)) 
                                    : Matrix4.identity(),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: (isBack ? AppColors.cyan : AppColors.violet).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isBack ? 'ANSWER' : 'QUESTION',
                                        style: TextStyle(
                                          color: isBack ? AppColors.cyan : AppColors.violet,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    Text(
                                      isBack ? back : front,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.titleLarge.copyWith(
                                        color: AppColors.textWhite,
                                        height: 1.5,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.flip_camera_android_rounded, 
                                            color: AppColors.textMuted.withOpacity(0.6), size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Tap card to ${isBack ? "see question" : "view answer"}',
                                          style: TextStyle(
                                            color: AppColors.textMuted.withOpacity(0.6), 
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Rating buttons
                  Text(loc.translate('rateDifficulty'),
                      style: TextStyle(color: AppColors.textMuted.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildRateButton(
                        label: '🔴 Hard',
                        subLabel: '(1d)',
                        color: AppColors.error,
                        onTap: () => _rateCard('hard'),
                      ),
                      const SizedBox(width: 10),
                      _buildRateButton(
                        label: '🟡 Good',
                        subLabel: '(3d)',
                        color: AppColors.gold,
                        onTap: () => _rateCard('medium'),
                      ),
                      const SizedBox(width: 10),
                      _buildRateButton(
                        label: '🟢 Easy',
                        subLabel: '(7d)',
                        color: AppColors.success,
                        onTap: () => _rateCard('easy'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
