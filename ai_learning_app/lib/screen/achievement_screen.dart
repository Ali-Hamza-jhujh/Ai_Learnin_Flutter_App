import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/achievement_service.dart';
import '../utils/app_theme.dart';

class AchievementScreen extends StatefulWidget {
  const AchievementScreen({super.key});

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await AchievementService.getMyAchievements();
      if (mounted) {
        setState(() {
          _stats = res['data'];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load achievements';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: AppColors.bg,
        middle: Text('Achievements', style: TextStyle(color: AppColors.textWhite)),
      ),
      child: Stack(
        children: [
          const SpaceBackground(),
          SafeArea(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final achievements = (_stats?['achievements'] as List<dynamic>?) ?? [];
    final unlockedCount = _stats?['unlockedCount'] ?? 0;
    final totalCount = _stats?['totalCount'] ?? 0;
    final xp = _stats?['xp'] ?? 0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
                  child: const Text('Your Trophy Room',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'Georgia')),
                ),
                const SizedBox(height: 8),
                Text('$unlockedCount / $totalCount Unlocked • $xp XP',
                    style: AppTextStyles.sub),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final ach = achievements[index];
                return _buildAchievementCard(ach);
              },
              childCount: achievements.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementCard(Map<String, dynamic> ach) {
    final bool isUnlocked = ach['isUnlocked'] == true;
    final String title = ach['title'] ?? '';
    final String description = ach['description'] ?? '';
    final int xpReward = ach['xpReward'] ?? 0;
    final String icon = ach['icon'] ?? '🏆';

    return Container(
      decoration: BoxDecoration(
        color: isUnlocked ? AppColors.bgCard : AppColors.inputBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked ? AppColors.violet.withOpacity(0.5) : AppColors.inputBorder,
          width: isUnlocked ? 2 : 1,
        ),
        boxShadow: isUnlocked
            ? [BoxShadow(color: AppColors.violet.withOpacity(0.2), blurRadius: 10)]
            : [],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: TextStyle(fontSize: 40, color: isUnlocked ? Colors.white : Colors.grey)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isUnlocked ? AppColors.textWhite : AppColors.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isUnlocked ? AppColors.textLight : AppColors.textMuted.withOpacity(0.5),
                  fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isUnlocked ? AppColors.violet.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '+$xpReward XP',
              style: TextStyle(
                  color: isUnlocked ? AppColors.violetLight : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
