import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import '../utils/app_theme.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  int _focusMinutes = 25;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  Timer? _timer;

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          _timer?.cancel();
          setState(() => _isRunning = false);
          _showCompletionDialog();
        }
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _focusMinutes * 60;
    });
  }

  void _showCompletionDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Focus Session Complete!'),
        content: const Text('You earned +5 XP for completing your Pomodoro session.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              _resetTimer();
            },
            child: const Text('Awesome'),
          ),
        ],
      ),
    );
  }

  String get _timeString {
    int m = _remainingSeconds ~/ 60;
    int s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showSettingsSheet() {
    final times = [15, 25, 45, 60];
    int selectedIndex = times.indexOf(_focusMinutes);
    if (selectedIndex == -1) selectedIndex = 1;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: AppColors.bgCard,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('Save'),
                  onPressed: () {
                    _resetTimer();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                scrollController: FixedExtentScrollController(initialItem: selectedIndex),
                onSelectedItemChanged: (index) {
                  setState(() {
                    _focusMinutes = times[index];
                  });
                },
                children: times.map((t) => Center(child: Text('$t Minutes', style: const TextStyle(color: AppColors.textWhite)))).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: AppColors.bgCard,
        middle: Text('Focus Timer', style: TextStyle(color: AppColors.textWhite)),
      ),
      child: Stack(
        children: [
          const SpaceBackground(),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cyan, width: 4),
                      gradient: RadialGradient(
                        colors: [
                          AppColors.cyan.withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _timeString,
                        style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: AppColors.textWhite),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoButton(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(30),
                        onPressed: _resetTimer,
                        child: const Icon(CupertinoIcons.refresh, color: AppColors.textWhite),
                      ),
                      const SizedBox(width: 14),
                      CupertinoButton(
                        color: _isRunning ? AppColors.error : AppColors.cyan,
                        borderRadius: BorderRadius.circular(30),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        onPressed: _toggleTimer,
                        child: Text(
                          _isRunning ? 'PAUSE' : 'START',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 14),
                      CupertinoButton(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(30),
                        onPressed: _showSettingsSheet,
                        child: const Icon(CupertinoIcons.slider_horizontal_3, color: AppColors.textWhite),
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
