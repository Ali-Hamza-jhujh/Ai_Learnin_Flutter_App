import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/lumio_theme.dart';

class AIConfigChoiceScreen extends StatelessWidget {
  const AIConfigChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: CupertinoNavigationBar(
        leading: const CupertinoNavigationBarBackButton(previousPageTitle: ''),
        backgroundColor: AppColors.bgCard.withValues(alpha: 0.8),
        middle: Text(
          'Setup AI Generation',
          style: AppTypography.titleLarge.copyWith(color: Colors.white, fontSize: 18),
        ),
      ),
      child: Stack(
        children: [
          const SpaceBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                ShaderMask(
                  shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
                  child: Text(
                    'Continue generating',
                    style: AppTypography.displayMedium.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Add a free cloud API key to keep generating notes and MCQs. Health tracking is separate and runs on-device.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: LumioDecorations.lumioCard(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Free API keys',
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Groq, Gemini, and Cerebras keys stay on this device.',
                        style: TextStyle(color: AppColors.textSub, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      GlowButton(
                        text: 'Configure API Keys',
                        icon: CupertinoIcons.arrow_right,
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/settings/api-keys');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: LumioDecorations.lumioCard(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Health Connect',
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Track steps, heart rate, sleep, and vitals. Morning, afternoon, and evening notifications.',
                        style: TextStyle(color: AppColors.textSub, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      GlowButton(
                        text: 'Open Health',
                        icon: CupertinoIcons.heart_fill,
                        gradient: const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFF9F1239)]),
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/health');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
