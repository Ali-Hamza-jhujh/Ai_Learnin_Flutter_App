
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screen/login_screen.dart';
import 'screen/home_screen.dart';
import 'screen/onboarding_screen.dart';
import 'services/api_client.dart';
import 'utils/app_theme.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
await NotificationService.init();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const StudyApp());
}

class StudyApp extends StatelessWidget {
  const StudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.violet,
          secondary: AppColors.cyan,
          surface: AppColors.bgCard,
        ),
        useMaterial3: true,
        fontFamily: 'Georgia',
      ),
      home: const SplashRouter(),
    );
  }
}

// ══════════════════════════════════════════
// SPLASH ROUTER
// ══════════════════════════════════════════

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter>
    with SingleTickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoFade = CurvedAnimation(
      parent: _logoCtrl,
      curve: Curves.easeOut,
    );
    _logoCtrl.forward();
    _route();
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    super.dispose();
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;

    if (!onboardingDone) {
      _go(const OnboardingScreen());
      return;
    }

    final loggedIn = await TokenManager.isLoggedIn();
    if (loggedIn) {
      _go(const HomeScreen());
    } else {
      _go(const LoginScreen());
    }
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => screen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Star background
          CustomPaint(
            painter: StarPainter(),
            size: MediaQuery.of(context).size,
          ),
          // Content
          Center(
            child: AnimatedBuilder(
              animation: _logoCtrl,
              builder: (_, __) {
                return FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo box
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGrad,
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.violet.withOpacity(0.6),
                                blurRadius: 50,
                                spreadRadius: 5,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '📚',
                              style: TextStyle(fontSize: 56),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // App name
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppColors.primaryGrad.createShader(bounds),
                          child: const Text(
                            'StudyAI',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFamily: 'Georgia',
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'AI-powered learning',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 60),
                        // Loading dots
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LoadingDot(delay: 0),
                            _LoadingDot(delay: 200),
                            _LoadingDot(delay: 400),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated loading dot ──────────────────
class _LoadingDot extends StatefulWidget {
  final int delay;
  const _LoadingDot({required this.delay});

  @override
  State<_LoadingDot> createState() => _LoadingDotState();
}

class _LoadingDotState extends State<_LoadingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.violet.withOpacity(_anim.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.violet.withOpacity(_anim.value * 0.5),
                blurRadius: 8,
              ),
            ],
          ),
        );
      },
    );
  }
}
