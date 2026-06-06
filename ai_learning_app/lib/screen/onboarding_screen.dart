import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  final List<_OnboardPage> _pages = const [
    _OnboardPage(
      emoji: '📚',
      gradientColors: [Color(0xFF7B61FF), Color(0xFF4A3FA0)],
      glowColor: Color(0xFF7B61FF),
      title: 'Study Smarter\nwith AI',
      subtitle: 'Upload any PDF and get instant AI-generated study notes, summaries, and key concepts — in seconds.',
      features: ['📄 Upload any PDF', '🤖 AI summarizes for you', '📝 Organized chapters'],
    ),
    _OnboardPage(
      emoji: '❓',
      gradientColors: [Color(0xFF00C9A7), Color(0xFF007A64)],
      glowColor: Color(0xFF00C9A7),
      title: 'Test Your\nKnowledge',
      subtitle: 'Generate AI-powered MCQ quizzes from your notes. Choose difficulty, get instant feedback.',
      features: ['🎯 Custom difficulty', '⚡ Instant results', '📊 Performance tracking'],
    ),
    _OnboardPage(
      emoji: '🤖',
      gradientColors: [Color(0xFFFF6B6B), Color(0xFFB03A3A)],
      glowColor: Color(0xFFFF6B6B),
      title: 'Your Personal\nAI Tutor',
      subtitle: 'Chat with your AI tutor 24/7. Ask anything, get step-by-step explanations in real time.',
      features: ['💬 Ask anything', '📡 Streaming replies', '📎 Attach your PDF'],
    ),
    _OnboardPage(
      emoji: '🏆',
      gradientColors: [Color(0xFFFFB547), Color(0xFFFF6B9D)],
      glowColor: Color(0xFFFFB547),
      title: 'Track Progress\n& Compete',
      subtitle: 'Earn XP, maintain streaks, predict exam scores with AI, and climb the leaderboard.',
      features: ['⚡ Earn XP & level up', '🔥 Daily streaks', '📈 Exam prediction'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -12, end: 12).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_currentPage < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic);
    } else {
      _finish();
    }
  }

  void _skip() {
    HapticFeedback.selectionClick();
    _finish();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const LoginScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 600)));
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        // ── Animated background ──────────
        _buildBackground(page),

        SafeArea(child: Column(children: [
          // ── Skip button ──────────────
          if (!isLast)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, top: 8),
                child: TextButton(
                  onPressed: _skip,
                  child: const Text('Skip',
                    style: TextStyle(color: AppColors.textMuted,
                      fontSize: 14, fontWeight: FontWeight.w600)))))
          else
            const SizedBox(height: 48),

          // ── Pages ────────────────────
          Expanded(child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (_, i) => _buildPage(_pages[i]))),

          // ── Bottom controls ───────────
          _buildControls(page, isLast),
          const SizedBox(height: 16),
        ])),
      ]));
  }

  Widget _buildBackground(_OnboardPage page) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.6, -0.6),
          radius: 1.2,
          colors: [
            page.glowColor.withOpacity(0.15),
            AppColors.bg,
          ])),
      // ── FIX: CustomPaint with StarPainter class ──
      child: CustomPaint(
        painter: StarPainter()));
  }

  Widget _buildPage(_OnboardPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        // ── Floating emoji ───────────────
        AnimatedBuilder(
          animation: _floatAnim,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, _floatAnim.value),
            child: child),
          child: Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: page.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [BoxShadow(
                color: page.glowColor.withOpacity(0.5),
                blurRadius: 40, spreadRadius: 8,
                offset: const Offset(0, 16))]),
            child: Center(child: Text(page.emoji,
              style: const TextStyle(fontSize: 64))))),

        const SizedBox(height: 48),

        // ── Title ────────────────────────
        ShaderMask(
          shaderCallback: (b) => LinearGradient(
            colors: [Colors.white, page.glowColor.withOpacity(0.85)])
              .createShader(b),
          child: Text(page.title,
            style: const TextStyle(
              fontSize: 36, fontWeight: FontWeight.w900,
              color: Colors.white, fontFamily: 'Georgia', height: 1.15),
            textAlign: TextAlign.center)),

        const SizedBox(height: 16),

        // ── Subtitle ─────────────────────
        Text(page.subtitle,
          style: AppTextStyles.sub.copyWith(fontSize: 15, height: 1.7),
          textAlign: TextAlign.center),

        const SizedBox(height: 32),

        // ── Feature pills ─────────────────
        Wrap(
          spacing: 10, runSpacing: 10,
          alignment: WrapAlignment.center,
          children: page.features.map((f) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: page.glowColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: page.glowColor.withOpacity(0.3))),
            child: Text(f, style: TextStyle(
              color: page.glowColor, fontSize: 13,
              fontWeight: FontWeight.w600)))).toList()),
      ]));
  }

  Widget _buildControls(_OnboardPage page, bool isLast) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(children: [
        // ── Page dots ─────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pages.length, (i) {
            final active = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 32 : 8,
              height: 8,
              decoration: BoxDecoration(
                gradient: active ? LinearGradient(
                  colors: page.gradientColors) : null,
                color: active ? null
                  : AppColors.textMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4)));
          })),

        const SizedBox(height: 28),

        // ── CTA button ────────────────────
        GestureDetector(
          onTap: _next,
          child: Container(
            width: double.infinity, height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: page.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                color: page.glowColor.withOpacity(0.45),
                blurRadius: 24, offset: const Offset(0, 10))]),
            child: Center(child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
              Text(isLast ? 'Get Started 🚀' : 'Continue',
                style: const TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w800)),
              if (!isLast) ...[
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 22),
              ],
            ])))),

        if (isLast) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _skip,
            child: const Text('Already have an account? Sign In',
              style: AppTextStyles.link)),
        ],
      ]));
  }
}

// ── Data model ────────────────────────────
class _OnboardPage {
  final String emoji;
  final List<Color> gradientColors;
  final Color glowColor;
  final String title;
  final String subtitle;
  final List<String> features;

  const _OnboardPage({
    required this.emoji,
    required this.gradientColors,
    required this.glowColor,
    required this.title,
    required this.subtitle,
    required this.features,
  });
}