import 'package:flutter/material.dart';
import '../core/theme/lumio_theme.dart';
import '../core/theme/app_typography.dart';
import '../utils/app_theme.dart';

class AIProviderBanner extends StatefulWidget {
  final String provider;
  final List<dynamic> skipped;
  final bool cached;

  const AIProviderBanner({
    super.key,
    required this.provider,
    this.skipped = const [],
    this.cached = false,
  });

  @override
  State<AIProviderBanner> createState() => _AIProviderBannerState();
}

class _AIProviderBannerState extends State<AIProviderBanner> {
  bool _expanded = false;

  Color get _color {
    if (widget.provider.contains('offline')) return LumioColors.offline;
    if (widget.provider.contains('free')) return AppColors.violet;
    if (widget.skipped.isNotEmpty) return AppColors.cyan;
    return AppColors.success;
  }

  String get _label {
    if (widget.cached) return '📦 Loaded from cache';
    if (widget.provider.contains('offline')) return '📴 Offline AI — Gemma 2B';
    if (widget.provider.contains('free')) return '🎁 Free trial generation';
    if (widget.skipped.isNotEmpty) {
      return '🔄 Switched provider — ${widget.provider.toUpperCase()}';
    }
    return '⚡ Generated with ${widget.provider.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: LumioDecorations.lumioCard(glowing: true).copyWith(
          border: Border.all(color: _color.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_label, style: AppTypography.labelLarge.copyWith(color: _color)),
            if (_expanded && widget.skipped.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...widget.skipped.map(
                (s) => Text(
                  '${s['provider']}: ${s['reason']}',
                  style: AppTypography.caption,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
