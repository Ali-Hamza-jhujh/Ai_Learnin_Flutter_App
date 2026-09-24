import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import '../services/api_client.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  late AnimationController _entryCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Email/Password login ──────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.login(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      showCupertinoSuccess(context, 'Welcome back! 🚀');
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Google Sign-In ────────────────────
  Future<void> _googleLogin() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await _googleSignIn.signOut();

      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _googleLoading = false);
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        setState(() => _error = 'Google Sign-In failed. Please try again.');
        return;
      }

      final res = await AuthService.googleLogin(
        idToken: idToken,
        name: account.displayName ?? account.email.split('@')[0],
        email: account.email,
        profilePicture: account.photoUrl,
      );

      if (!mounted) return;

      // ── FIX: navigate based on needsProfile flag ──
      if (res['needsProfile'] == true) {
        // New Google user — send to RegisterScreen step 2
        // to collect subject, goal, education level
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RegisterScreen(
              googleName: account.displayName ?? '',
              googleEmail: account.email,
              googlePhotoUrl: account.photoUrl,
              startAtProfileStep: true,
            ),
          ),
        );
      } else {
        // Existing user — go to home
        showCupertinoSuccess(context, 'Welcome back, ${account.displayName}! 🚀');
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Google Sign-In failed. Please try again.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      child: Stack(children: [
        const SpaceBackground(),
        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(children: [
                  const SizedBox(height: 56),
                  _buildLogo(),
                  const SizedBox(height: 14),
                  ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.primaryGrad.createShader(b),
                      child: Text('StudyAI',
                          style: AppTextStyles.display
                              .copyWith(color: Colors.white))),
                  const SizedBox(height: 6),
                  const Text('AI-powered learning for every student',
                      style: AppTextStyles.sub, textAlign: TextAlign.center),
                  const SizedBox(height: 44),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sign In', style: AppTextStyles.heading),
                        const SizedBox(height: 4),
                        const Text('Continue your learning journey',
                            style: AppTextStyles.sub),
                        const SizedBox(height: 28),
                        GoogleButton(
                          text: 'Continue with Google',
                          isLoading: _googleLoading,
                          onPressed: _googleLogin,
                        ),
                        const SizedBox(height: 20),
                        buildDivider(),
                        const SizedBox(height: 20),
                        if (_error != null) ...[
                          buildErrorBanner(_error!),
                          const SizedBox(height: 20),
                        ],
                        Form(
                          key: _formKey,
                          child: Column(children: [
                            AppTextField(
                              label: 'Email',
                              hint: 'your@email.com',
                              controller: _emailCtrl,
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Email required';
                                }
                                if (!v.contains('@')) return 'Invalid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            AppTextField(
                              label: 'Password',
                              hint: 'Enter your password',
                              controller: _passCtrl,
                              prefixIcon: Icons.lock_outline_rounded,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                              onEditingComplete: _login,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password required';
                                }
                                if (v.length < 6) return 'Min 6 characters';
                                return null;
                              },
                            ),
                          ]),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(context,
                                fadeSlideRoute(const ForgotPasswordScreen())),
                            style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 8)),
                            child: const Text('Forgot password?',
                                style: AppTextStyles.link),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GlowButton(
                          text: 'Sign In',
                          icon: Icons.arrow_forward_rounded,
                          isLoading: _loading,
                          onPressed: _login,
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final guestUser = {
                              "_id": "offline_guest_id",
                              "name": "Guest Student",
                              "email": "guest@studyai.app",
                              "level": {
                                "level": 3,
                                "title": "Scholar Elite",
                                "progressPercent": 45,
                                "xpToNextLevel": 350
                              },
                              "xp": 820,
                              "streak": 5
                            };
                            await TokenManager.saveToken("offline_guest_token");
                            await TokenManager.saveUser(guestUser);
                            if (mounted) {
                              Navigator.pushReplacement(context, fadeSlideRoute(const HomeScreen()));
                            }
                          },
                          icon: const Icon(Icons.offline_bolt_rounded, color: AppColors.cyan, size: 18),
                          label: const Text(
                            'Enter Offline / Guest Mode',
                            style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: BorderSide(color: AppColors.cyan.withOpacity(0.4), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            backgroundColor: AppColors.cyan.withOpacity(0.05),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? ",
                          style: AppTextStyles.body),
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context, fadeSlideRoute(const RegisterScreen())),
                        child: Text('Sign Up',
                            style: AppTextStyles.link
                                .copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildLogo() => Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGrad,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: AppColors.violet.withOpacity(0.55),
                blurRadius: 30,
                offset: const Offset(0, 10))
          ],
        ),
        child: const Center(child: Text('📚', style: TextStyle(fontSize: 38))),
      );
}
