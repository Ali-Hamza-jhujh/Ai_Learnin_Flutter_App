
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

// ══════════════════════════════════════════
// SKELETON LOADING WIDGETS
// Shimmer-style animated placeholders
// Used while data is loading on any screen
// ══════════════════════════════════════════

// ── Base shimmer animation ────────────────
class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end: Alignment(_anim.value + 1, 0),
          colors: const [
            Color(0xFF1A2048),
            Color(0xFF2E3A70),
            Color(0xFF1A2048),
          ],
        ).createShader(bounds),
        child: child!,
      ),
      child: widget.child,
    );
  }
}

// ── Skeleton box ──────────────────────────
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

// ── Skeleton line ─────────────────────────
class SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;

  const SkeletonLine({
    super.key,
    this.width,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// SCREEN-SPECIFIC SKELETONS
// ══════════════════════════════════════════

// ── Notes list skeleton ───────────────────
class NotesListSkeleton extends StatelessWidget {
  const NotesListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(children: [
          const SkeletonBox(width: 52, height: 52, radius: 16),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const SkeletonLine(height: 16),
            const SizedBox(height: 8),
            SkeletonLine(width: MediaQuery.of(context).size.width * 0.3, height: 12),
            const SizedBox(height: 8),
            Row(children: [
              const SkeletonBox(width: 80, height: 22, radius: 8),
              const SizedBox(width: 8),
              const SkeletonBox(width: 60, height: 22, radius: 8),
              const Spacer(),
              const SkeletonLine(width: 50, height: 10),
            ]),
          ])),
          const SizedBox(width: 8),
          const SkeletonBox(width: 20, height: 20, radius: 10),
        ])));
  }
}

// ── MCQ list skeleton ─────────────────────
class MCQListSkeleton extends StatelessWidget {
  const MCQListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(children: [
          const SkeletonBox(width: 52, height: 52, radius: 16),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const SkeletonLine(height: 16),
            const SizedBox(height: 8),
            SkeletonLine(width: MediaQuery.of(context).size.width * 0.25, height: 12),
            const SizedBox(height: 8),
            Row(children: [
              const SkeletonBox(width: 90, height: 22, radius: 8),
              const Spacer(),
              const SkeletonLine(width: 40, height: 10),
            ]),
          ])),
          const SizedBox(width: 8),
          const SkeletonBox(width: 56, height: 32, radius: 20),
        ])));
  }
}

// ── Chat list skeleton ────────────────────
class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(children: [
          const SkeletonBox(width: 48, height: 48, radius: 16),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const SkeletonLine(height: 15),
            const SizedBox(height: 8),
            Row(children: [
              SkeletonLine(
                width: MediaQuery.of(context).size.width * 0.2,
                height: 11),
              const SizedBox(width: 8),
              const SkeletonLine(width: 50, height: 11),
              const Spacer(),
              const SkeletonLine(width: 40, height: 10),
            ]),
          ])),
          const SizedBox(width: 8),
          const SkeletonBox(width: 18, height: 18, radius: 9),
        ])));
  }
}

// ── YouTube card skeleton ─────────────────
class YouTubeCardSkeleton extends StatelessWidget {
  const YouTubeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (i, __) => i == 0
          ? _featuredSkeleton(context)
          : _regularSkeleton(context),
    );
  }

  Widget _featuredSkeleton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(children: [
        const SkeletonBox(
          width: double.infinity, height: 180, radius: 0),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const SkeletonLine(height: 16),
            const SizedBox(height: 6),
            const SkeletonLine(height: 14),
            const SizedBox(height: 10),
            Row(children: [
              const SkeletonLine(width: 100, height: 12),
              const Spacer(),
              const SkeletonLine(width: 50, height: 12),
              const SizedBox(width: 12),
              const SkeletonBox(width: 22, height: 22, radius: 11),
            ]),
          ])),
      ]));
  }

  Widget _regularSkeleton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(children: [
        const SkeletonBox(width: 110, height: 72, radius: 12),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const SkeletonLine(height: 14),
          const SizedBox(height: 6),
          const SkeletonLine(height: 14),
          const SizedBox(height: 8),
          SkeletonLine(
            width: MediaQuery.of(context).size.width * 0.25,
            height: 11),
          const SizedBox(height: 6),
          Row(children: [
            const SkeletonLine(width: 50, height: 10),
            const Spacer(),
            const SkeletonBox(width: 18, height: 18, radius: 9),
          ]),
        ])),
      ]));
  }
}

// ── Profile skeleton ──────────────────────
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
      child: Column(children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: Column(children: [
            Row(children: [
              const SkeletonBox(width: 72, height: 72, radius: 24),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const SkeletonLine(height: 20),
                const SizedBox(height: 8),
                SkeletonLine(
                  width: MediaQuery.of(context).size.width * 0.4,
                  height: 13),
                const SizedBox(height: 8),
                const SkeletonBox(width: 120, height: 28, radius: 20),
              ])),
              const SkeletonBox(width: 38, height: 38, radius: 12),
            ]),
            const SizedBox(height: 20),
            const SkeletonLine(height: 8),
          ])),
        const SizedBox(height: 16),
        // XP cards row
        Row(children: [
          _xpCard(), const SizedBox(width: 12),
          _xpCard(), const SizedBox(width: 12),
          _xpCard(),
        ]),
        const SizedBox(height: 16),
        // Stats grid
        Row(children: [
          _statCard(), const SizedBox(width: 12), _statCard()]),
        const SizedBox(height: 12),
        Row(children: [
          _statCard(), const SizedBox(width: 12), _statCard()]),
        const SizedBox(height: 24),
        // Info card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: Column(children: [
            _infoRow(), const Divider(color: AppColors.inputBorder),
            _infoRow(), const Divider(color: AppColors.inputBorder),
            _infoRow(),
          ])),
      ]));
  }

  Widget _xpCard() => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.inputBorder),
    ),
    child: Column(children: [
      const SkeletonBox(width: 24, height: 24, radius: 12),
      const SizedBox(height: 8),
      const SkeletonLine(width: 40, height: 18),
      const SizedBox(height: 4),
      const SkeletonLine(width: 30, height: 10),
    ])));

  Widget _statCard() => Expanded(child: Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.inputBorder),
    ),
    child: Row(children: [
      const SkeletonBox(width: 44, height: 44, radius: 14),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const SkeletonLine(height: 20),
        const SizedBox(height: 6),
        const SkeletonLine(height: 10),
      ])),
    ])));

  Widget _infoRow() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      const SkeletonBox(width: 24, height: 24, radius: 12),
      const SizedBox(width: 12),
      const SkeletonLine(width: 60, height: 13),
      const Spacer(),
      const SkeletonLine(width: 100, height: 13),
    ]));
}

// ── Dashboard skeleton ────────────────────
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const SkeletonLine(width: 100, height: 13),
              const SizedBox(height: 8),
              const SkeletonLine(width: 150, height: 28),
              const SizedBox(height: 8),
              const SkeletonBox(width: 140, height: 28, radius: 20),
            ]),
            const Spacer(),
            const SkeletonBox(width: 52, height: 52, radius: 18),
          ])),
        const SizedBox(height: 20),
        // XP card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Column(children: [
              Row(children: [
                const SkeletonLine(width: 80, height: 22),
                const Spacer(),
                const SkeletonBox(width: 80, height: 32, radius: 20),
              ]),
              const SizedBox(height: 14),
              const SkeletonLine(height: 10),
              const SizedBox(height: 8),
              Row(children: [
                const SkeletonLine(width: 100, height: 10),
                const Spacer(),
                const SkeletonLine(width: 100, height: 10),
              ]),
            ]))),
        const SizedBox(height: 16),
        // Stats row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: List.generate(4, (i) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 3 ? 12 : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: const Column(children: [
                  SkeletonBox(width: 24, height: 24, radius: 12),
                  SizedBox(height: 6),
                  SkeletonLine(width: 30, height: 18),
                  SizedBox(height: 4),
                  SkeletonLine(width: 24, height: 10),
                ])))))),
      )]));
  }
}

// ══════════════════════════════════════════
// EMPTY STATE WIDGET
// Reusable empty state for all screens
// ══════════════════════════════════════════

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? buttonText;
  final IconData? buttonIcon;
  final VoidCallback? onButtonTap;
  final List<Color>? buttonGradient;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.buttonIcon,
    this.onButtonTap,
    this.buttonGradient,
  });

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: AppColors.violet.withOpacity(0.1),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppColors.violet.withOpacity(0.2))),
          child: Center(child: Text(emoji,
            style: const TextStyle(fontSize: 48)))),
        const SizedBox(height: 24),
        ShaderMask(
          shaderCallback: (b) =>
            AppColors.primaryGrad.createShader(b),
          child: Text(title,
            style: const TextStyle(fontSize: 22,
              fontWeight: FontWeight.w700, color: Colors.white,
              fontFamily: 'Georgia'),
            textAlign: TextAlign.center)),
        const SizedBox(height: 8),
        Text(subtitle,
          style: AppTextStyles.sub,
          textAlign: TextAlign.center),
        if (buttonText != null && onButtonTap != null) ...[
          const SizedBox(height: 32),
          GlowButton(
            text: buttonText!,
            icon: buttonIcon,
            gradient: buttonGradient != null
              ? LinearGradient(colors: buttonGradient!)
              : null,
            onPressed: onButtonTap!),
        ],
      ])));
  }
}

// ══════════════════════════════════════════
// ERROR STATE WIDGET
// ══════════════════════════════════════════

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        const Text('😕', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        buildErrorBanner(message),
        const SizedBox(height: 20),
        GlowButton(
          text: 'Try Again',
          icon: Icons.refresh_rounded,
          onPressed: onRetry),
      ])));
  }
}
