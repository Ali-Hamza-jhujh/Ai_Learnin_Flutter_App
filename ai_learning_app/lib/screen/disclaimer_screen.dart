import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/lumio_theme.dart';

class DisclaimerScreen extends StatelessWidget {
  final String userId; // Keep for backwards compatibility
  const DisclaimerScreen({super.key, this.userId = ''});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      child: Stack(
        children: [
          const SpaceBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text('🎉', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text("You've tried Lumio AI!", style: AppTypography.displayMedium),
                  const SizedBox(height: 16),
                  const Text(
                    'Lumio is free to use, but AI generation costs real money. '
                    'Add your own free API keys for unlimited cloud quality, '
                    'or connect Health Connect to track vitals on this device.',
                    style: TextStyle(color: AppColors.textWhite, fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  
                  // Option A Card
                  _buildOptionCard(
                    context: context,
                    title: 'Option A: Cloud AI',
                    subtitle: 'Set Up Free API Keys',
                    glowColor: AppColors.success,
                    icon: CupertinoIcons.cloud,
                    route: '/settings/api-keys',
                  ),
                  const SizedBox(height: 16),

                  // Option B Card
                  _buildOptionCard(
                    context: context,
                    title: 'Option B: Health tracking',
                    subtitle: 'Health Connect permissions & alerts',
                    glowColor: AppColors.cyan,
                    icon: CupertinoIcons.heart_fill,
                    route: '/health',
                  ),
                  const Spacer(),

                  // Do Both
                  GlowButton(
                    text: 'Open Health dashboard ✨',
                    onPressed: () => Navigator.pushNamed(context, '/health'),
                  ),
                  const SizedBox(height: 12),
                  
                  Center(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Remind Me Later',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Color glowColor,
    required IconData icon,
    required String route,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: LumioDecorations.lumioCard(glowing: true).copyWith(
          border: Border.all(color: glowColor.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: glowColor, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: glowColor, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, color: glowColor, size: 24),
          ],
        ),
      ),
    );
  }
}
