import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
// import '../services/api_client.dart';
import 'login_screen.dart';
// Import other screens when built:
import 'notes_screen.dart';
import 'mcq_screen.dart';
import 'chat_tutor_screen.dart';
import 'exam_prediction_screen.dart';
import 'youtube_screen.dart';
import 'profile_screen.dart';

// ══════════════════════════════════════════
// HOME SCREEN — StudyAI Dashboard
// ══════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  bool _loading = true;

  late AnimationController _headerCtrl;
  late AnimationController _cardsCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _cardsFade;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _cardsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
            begin: const Offset(0, -0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));
    _cardsFade = CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOut);

    _loadData();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _cardsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final profile = await ProfileService.getMyProfile();
      final stats = await ProfileService.getStats();
      if (mounted) {
        setState(() {
          _profile = profile['user'] as Map<String, dynamic>?;
          _stats = stats;
          _loading = false;
        });
        _headerCtrl.forward();
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _cardsCtrl.forward();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _headerCtrl.forward();
      _cardsCtrl.forward();
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context, fadeSlideRoute(const LoginScreen()), (r) => false);
  }

  // ── Getters for profile data ──────────
  String get _name {
    final n = _profile?['name'] as String? ?? 'Student';
    return n.split(' ').first;
  }

  int get _xp => (_profile?['xp'] as num?)?.toInt() ?? 0;
  int get _streak => (_profile?['streak'] as num?)?.toInt() ?? 0;
  int get _level => (_profile?['level']?['level'] as num?)?.toInt() ?? 1;
  String get _levelTitle =>
      _profile?['level']?['title'] as String? ?? 'Beginner';
  int get _progressPercent =>
      (_profile?['level']?['progressPercent'] as num?)?.toInt() ?? 0;
  int get _notesCount =>
      (_stats?['stats']?['notesGenerated'] as num?)?.toInt() ?? 0;
  int get _testsCount =>
      (_stats?['stats']?['testsCompleted'] as num?)?.toInt() ?? 0;
  double get _avgScore =>
      (_stats?['stats']?['averageTestScore'] as num?)?.toDouble() ?? 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: Stack(children: [
        const SpaceBackground(),
        SafeArea(
          bottom: false,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.violet))
              : RefreshIndicator(
                  color: AppColors.violet,
                  backgroundColor: AppColors.bgCard,
                  onRefresh: _loadData,
                  child: CustomScrollView(slivers: [
                    SliverToBoxAdapter(
                        child: FadeTransition(
                            opacity: _headerFade,
                            child: SlideTransition(
                                position: _headerSlide,
                                child: _buildHeader()))),
                    SliverToBoxAdapter(
                        child: FadeTransition(
                            opacity: _cardsFade,
                            child: Column(children: [
                              _buildXPCard(),
                              _buildStatsRow(),
                              _buildDailyReward(),
                              _buildFeaturesGrid(),
                              _buildRecentActivity(),
                              const SizedBox(height: 100),
                            ]))),
                  ])),
        ),
        // Bottom nav
        Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
      ]),
    );
  }

  // ── HEADER ────────────────────────────
  Widget _buildHeader() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text(_greeting(),
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textMuted)),
                  const SizedBox(width: 6),
                  const Text('👋', style: TextStyle(fontSize: 16)),
                ]),
                const SizedBox(height: 4),
                ShaderMask(
                    shaderCallback: (b) =>
                        AppColors.primaryGrad.createShader(b),
                    child: Text(_name,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontFamily: 'Georgia'))),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          gradient: AppColors.primaryGrad,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('Lv.$_level · $_levelTitle',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700))),
                  const SizedBox(width: 8),
                  if (_streak > 0)
                    Row(children: [
                      const Text('🔥', style: TextStyle(fontSize: 14)),
                      Text(' $_streak day streak',
                          style: AppTextStyles.body.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w600)),
                    ]),
                ]),
              ])),
          // Avatar + notification
          Column(children: [
            GestureDetector(
             onTap: () => Navigator.push(context, fadeSlideRoute(const ProfileScreen())), // → ProfileScreen
                child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        gradient: AppColors.primaryGrad,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.violet.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6))
                        ]),
                    child: Center(
                        child: Text(
                            _name.isNotEmpty ? _name[0].toUpperCase() : 'S',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800))))),
            const SizedBox(height: 6),
            GestureDetector(
                onTap: _logout,
                child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.inputBorder)),
                    child: const Icon(Icons.logout_rounded,
                        color: AppColors.textMuted, size: 14))),
          ]),
        ]));
  }

  // ── XP PROGRESS CARD ─────────────────
  Widget _buildXPCard() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1A1060), Color(0xFF0D1535)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.violet.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.violet.withOpacity(0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8))
                ]),
            child: Column(children: [
              Row(children: [
                const Text('⚡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text('$_xp XP',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppColors.violet.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.violet.withOpacity(0.4))),
                    child: Text('Level $_level',
                        style: const TextStyle(
                            color: AppColors.violetLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 14),
              // Progress bar
              Stack(children: [
                Container(
                    height: 10,
                    decoration: BoxDecoration(
                        color: AppColors.inputBorder,
                        borderRadius: BorderRadius.circular(10))),
                FractionallySizedBox(
                    widthFactor: _progressPercent / 100,
                    child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                            gradient: AppColors.primaryGrad,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.violet.withOpacity(0.6),
                                  blurRadius: 8)
                            ]))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text('$_progressPercent% to Level ${_level + 1}',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.textMuted)),
                const Spacer(),
                Text('${_profile?['level']?['xpToNextLevel'] ?? 0} XP needed',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.textMuted)),
              ]),
            ])));
  }

  // ── STATS ROW ─────────────────────────
  Widget _buildStatsRow() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Row(children: [
          _statCard('📝', '$_notesCount', 'Notes', const Color(0xFF7B61FF)),
          const SizedBox(width: 12),
          _statCard('✅', '$_testsCount', 'Tests', const Color(0xFF00D4FF)),
          const SizedBox(width: 12),
          _statCard('📊', '${_avgScore.toStringAsFixed(0)}%', 'Avg Score',
              _avgScore >= 70 ? AppColors.success : AppColors.gold),
          const SizedBox(width: 12),
          _statCard('🔥', '$_streak', 'Streak', AppColors.gold),
        ]));
  }

  Widget _statCard(String emoji, String value, String label, Color accent) {
    return Expanded(
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accent.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                      color: accent.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]),
            child: Column(children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      color: accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label, style: AppTextStyles.label.copyWith(fontSize: 10)),
            ])));
  }

  // ── DAILY REWARD BANNER ───────────────
  Widget _buildDailyReward() {
    if (_streak == 0) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.gold.withOpacity(0.15),
                  AppColors.gold.withOpacity(0.05)
                ]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold.withOpacity(0.3))),
            child: Row(children: [
              const Text('🔥', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('$_streak Day Streak! Keep it up!',
                        style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Study today to maintain your streak',
                        style: AppTextStyles.body.copyWith(fontSize: 12)),
                  ])),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('+10 XP/day',
                      style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700))),
            ])));
  }

  // ── FEATURES GRID ─────────────────────
  Widget _buildFeaturesGrid() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ShaderMask(
                shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
                child: const Text('AI Features',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Georgia'))),
            const Spacer(),
            Text('All Tools', style: AppTextStyles.link.copyWith(fontSize: 13)),
          ]),
          const SizedBox(height: 16),
          // 2x2 grid
          Row(children: [
            _featureTile(
              icon: '📚',
              title: 'AI Notes',
              subtitle: 'Generate smart\nstudy notes',
              gradient: const [Color(0xFF7B61FF), Color(0xFF4A3FA0)],
              xpBadge: '+20 XP',
              onTap: () =>
                  Navigator.push(context, fadeSlideRoute(const NotesScreen())),
            ),
            const SizedBox(width: 14),
            _featureTile(
              icon: '❓',
              title: 'MCQ Quiz',
              subtitle: 'Test your\nknowledge',
              gradient: const [Color(0xFF00C9A7), Color(0xFF007A64)],
              xpBadge: '+35 XP',
              onTap: () => Navigator.push(
                  context, fadeSlideRoute(const MCQScreen())), // → MCQScreen
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _featureTile(
              icon: '🤖',
              title: 'AI Tutor',
              subtitle: 'Ask anything,\nlearn instantly',
              gradient: const [Color(0xFFFF6B6B), Color(0xFFB03A3A)],
              xpBadge: '+2 XP',
              onTap: () => Navigator.push(context, fadeSlideRoute(const ChatTutorScreen())), // → ChatTutorScreen
            ),
            const SizedBox(width: 14),
            _featureTile(
              icon: '🎥',
              title: 'Lectures',
              subtitle: 'YouTube video\nlectures',
              gradient: const [Color(0xFFFF9A3C), Color(0xFFB06420)],
              xpBadge: '+5 XP',
              onTap: () => Navigator.push(context,
                  fadeSlideRoute(const YouTubeScreen())), // → YouTubeScreen
            ),
          ]),
          const SizedBox(height: 14),
          // Full width ML card
          _fullWidthTile(
            icon: '📊',
            title: 'Exam Prediction',
            subtitle: 'AI predicts your score & finds weak topics',
            gradient: const [Color(0xFF48C6EF), Color(0xFF1A6A8A)],
            xpBadge: 'Smart Analysis',
           onTap: () => Navigator.push(context, fadeSlideRoute(const ExamPredictionScreen())), // → MLScreen
          ),
        ]));
  }

  Widget _featureTile({
    required String icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required String xpBadge,
    required VoidCallback onTap,
  }) {
    return Expanded(
        child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Container(
                height: 150,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                          color: gradient[0].withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8))
                    ]),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(icon, style: const TextStyle(fontSize: 28)),
                        const Spacer(),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(xpBadge,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700))),
                      ]),
                      const Spacer(),
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 11,
                              height: 1.4)),
                    ]))));
  }

  Widget _fullWidthTile({
    required String icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required String xpBadge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color: gradient[0].withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ]),
            child: Row(children: [
              Text(icon, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            height: 1.4)),
                  ])),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    Text(xpBadge,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 14),
                  ])),
            ])));
  }

  // ── RECENT ACTIVITY ───────────────────
  Widget _buildRecentActivity() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ShaderMask(
              shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
              child: const Text('Quick Actions',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Georgia'))),
          const SizedBox(height: 14),
          _quickAction(
              icon: Icons.upload_file_rounded,
              color: AppColors.violet,
              title: 'Upload PDF',
              subtitle: 'Generate notes or MCQs from any PDF',
              onTap: () {}),
          const SizedBox(height: 10),
          _quickAction(
              icon: Icons.leaderboard_rounded,
              color: AppColors.cyan,
              title: 'Leaderboard',
              subtitle: 'See where you rank among students',
              onTap: () {}),
          const SizedBox(height: 10),
          _quickAction(
              icon: Icons.trending_up_rounded,
              color: AppColors.success,
              title: 'My Progress',
              subtitle: 'View performance analytics',
              onTap: () {}),
        ]));
  }

  Widget _quickAction({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.2))),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: color, size: 22)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTextStyles.body.copyWith(fontSize: 12)),
                  ])),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 20),
            ])));
  }

  // ── BOTTOM NAV ────────────────────────
  Widget _buildBottomNav() {
    return Container(
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
            color: AppColors.bgCard.withOpacity(0.95),
            border: Border(
                top: BorderSide(
                    color: AppColors.violet.withOpacity(0.15), width: 1)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -8))
            ]),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _navItem(0, Icons.home_rounded, 'Home'),
          _navItem(1, Icons.description_outlined, 'Notes'),
          _navItem(2, Icons.quiz_outlined, 'MCQ'),
          _navItem(3, Icons.smart_toy_outlined, 'Tutor'),
          _navItem(4, Icons.person_outline_rounded, 'Profile'),
        ]));
  }

  Widget _navItem(int index, IconData icon, String label) {
    final active = _selectedIndex == index;
    return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedIndex = index);
          if (index == 1) {
            Navigator.push(context, fadeSlideRoute(const NotesScreen()));
          }
          if (index == 2) {
            Navigator.push(context, fadeSlideRoute(const MCQScreen()));
          }
          if (index == 3) {
            Navigator.push(context, fadeSlideRoute(const ChatTutorScreen()));
          }
          if (index == 4) {
  Navigator.push(context, fadeSlideRoute(const ProfileScreen()));
}
          // TODO: navigate to screens based on index
        },
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                gradient: active ? AppColors.primaryGrad : null,
                borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  color: active ? Colors.white : AppColors.textMuted, size: 22),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: active ? Colors.white : AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
            ])));
  }

  // ── Helpers ───────────────────────────
  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}
