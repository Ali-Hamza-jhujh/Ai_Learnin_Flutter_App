import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/lumio_theme.dart';
import '../core/constants/app_constants.dart';
import 'api_keys_screen.dart';

class DisclaimerScreen extends StatelessWidget {
  final String userId;

  const DisclaimerScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const SpaceBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🎉 You\'ve tried Lumio AI!',
                      style: AppTypography.displayMedium),
                  const SizedBox(height: 12),
                  Text(
                    'Lumio is free to use, but AI generation costs real money. '
                    'Add your own free API keys for unlimited cloud quality, '
                    'or download the offline model once.',
                    style: AppTypography.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  _OptionCard(
                    title: 'Add Free API Keys',
                    subtitle: 'Best Quality • Works on any phone',
                    glowColor: AppColors.success,
                    icon: Icons.cloud_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ApiKeysScreen(userId: userId),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _OptionCard(
                    title: 'Download Offline Model',
                    subtitle:
                        'No Internet Needed • ${AppConstants.offlineModelSizeGb}GB',
                    glowColor: AppColors.cyan,
                    icon: Icons.download_outlined,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  GlowButton(
                    text: 'Do Both (Recommended)',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ApiKeysScreen(userId: userId),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Remind Me Later',
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.textMuted)),
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
}

class _OptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color glowColor;
  final IconData icon;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.glowColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: LumioDecorations.lumioCard(glowing: true).copyWith(
          border: Border.all(color: glowColor.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: glowColor, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleMedium),
                  Text(subtitle, style: AppTypography.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
