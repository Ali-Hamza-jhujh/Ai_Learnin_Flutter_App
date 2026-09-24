import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import '../services/api_client.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String? googleName;
  final String? googleEmail;
  final String? googlePhotoUrl;
  final bool startAtProfileStep;

  const RegisterScreen({
    super.key,
    this.googleName,
    this.googleEmail,
    this.googlePhotoUrl,
    this.startAtProfileStep = false,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  // Separate form keys for each step
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();

  String _eduLevel = 'undergraduate';
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;
  int _step = 0;
  bool _isGoogleFlow = false;

  late AnimationController _entryCtrl;
  late AnimationController _stepCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _stepFade;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  final List<String> _eduLevels = [
    'school',
    'undergraduate',
    'postgraduate',
    'other'
  ];
  final Map<String, String> _eduLabels = {
    'school': '🏫 School',
    'undergraduate': '🎓 Undergraduate',
    'postgraduate': '📚 Postgraduate',
    'other': '✨ Other',
  };
  final Map<String, String> _goalSuggestions = {
    'Pass finals': '🎯',
    'Get distinction': '🏆',
    'Ace entrance exam': '🚀',
    'Improve grades': '📈',
  };

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _stepCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _stepFade = CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOut);
    _stepCtrl.value = 1.0;

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _entryCtrl.forward();
    });

    // Coming in from Google login → jump straight to profile step
    if (widget.startAtProfileStep) {
      _isGoogleFlow = true;
      _step = 1;
      if (widget.googleName != null) _nameCtrl.text = widget.googleName!;
      if (widget.googleEmail != null) _emailCtrl.text = widget.googleEmail!;
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _stepCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _subjectCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  // ── Step 1 → Step 2 (email flow only) ────────────────────
  void _nextStep() {
    if (!_step1FormKey.currentState!.validate()) return;
    _animateToStep(1);
  }

  void _animateToStep(int s) {
    _stepCtrl.reverse().then((_) {
      setState(() => _step = s);
      _stepCtrl.forward();
    });
  }

  // ── Final submit ─────────────────────────────────────────
  Future<void> _submit() async {
    if (!_step2FormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isGoogleFlow) {
        // Google user: just update profile fields
        await ProfileService.updateProfile(
          name: _nameCtrl.text.trim(),
          educationLevel: _eduLevel,
          subject: _subjectCtrl.text.trim(),
          goal: _goalCtrl.text.trim(),
          profilePicture: widget.googlePhotoUrl,
        );
        if (!mounted) return;
        showCupertinoSuccess(context, 'Profile complete! Welcome 🚀');
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        // Email user: full registration
        await AuthService.register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          educationLevel: _eduLevel,
          subject: _subjectCtrl.text.trim(),
          goal: _goalCtrl.text.trim(),
        );
        if (!mounted) return;
        _showVerifyDialog();
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Google sign-up (from step 1) ─────────────────────────
  Future<void> _googleSignUp() async {
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
        setState(() => _error = 'Google Sign-Up failed. Please try again.');
        return;
      }

      final res = await AuthService.googleLogin(
        idToken: idToken,
        name: account.displayName ?? account.email.split('@')[0],
        email: account.email,
        profilePicture: account.photoUrl,
      );

      if (!mounted) return;

      if (res['needsProfile'] == true) {
        // New Google user → fill name/email and go to profile step
        _isGoogleFlow = true;
        _nameCtrl.text = account.displayName ?? '';
        _emailCtrl.text = account.email;
        _animateToStep(1);
        showCupertinoSuccess(context, 'Google connected! Complete your profile.');
      } else {
        // Returning Google user → go home
        showCupertinoSuccess(context, 'Welcome back, ${account.displayName}! 🚀');
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Google Sign-Up failed. Please try again.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _showVerifyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGrad,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.violet.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10))
                  ],
                ),
                child: const Icon(Icons.mark_email_read_outlined,
                    color: Colors.white, size: 40)),
            const SizedBox(height: 24),
            const Text("You're almost in! 🎉",
                style: AppTextStyles.heading, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text(
                'Check your email to verify your account and start your AI-powered learning journey.',
                style: AppTextStyles.sub,
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_emailCtrl.text.trim(),
                    style: AppTextStyles.body.copyWith(
                        color: AppColors.cyan, fontWeight: FontWeight.w600))),
            const SizedBox(height: 28),
            GlowButton(
              text: 'Go to Login',
              icon: Icons.arrow_forward_rounded,
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                    context, fadeSlideRoute(const LoginScreen()));
              },
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      child: Stack(children: [
        const SpaceBackground(),
        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(children: [
              // ── Top bar ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textSub, size: 20),
                    onPressed: () {
                      if (_step == 1 && !_isGoogleFlow) {
                        _animateToStep(0);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  const Spacer(),
                  if (!_isGoogleFlow)
                    Row(
                        children: List.generate(2, (i) {
                      final active = i == _step;
                      final done = i < _step;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                          width: active ? 32 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            gradient:
                                active || done ? AppColors.primaryGrad : null,
                            color:
                                active || done ? null : AppColors.inputBorder,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      );
                    })),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(_isGoogleFlow ? 'Profile' : '${_step + 1} of 2',
                        style: AppTextStyles.label),
                  ),
                ]),
              ),

              // ── Body ──────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FadeTransition(
                    opacity: _stepFade,
                    child: Column(children: [
                      const SizedBox(height: 20),
                      _buildLogo(),
                      const SizedBox(height: 16),
                      ShaderMask(
                        shaderCallback: (b) =>
                            AppColors.primaryGrad.createShader(b),
                        child: Text(
                          _isGoogleFlow
                              ? 'Complete Profile'
                              : _step == 0
                                  ? 'Create Account'
                                  : 'Study Profile',
                          style: AppTextStyles.heading
                              .copyWith(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isGoogleFlow
                            ? 'Personalise your AI tutor'
                            : _step == 0
                                ? 'Join the future of learning'
                                : 'Tell us about your studies',
                        style: AppTextStyles.sub,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      if (_error != null) ...[
                        buildErrorBanner(_error!),
                        const SizedBox(height: 16),
                      ],

                      // ── Step 1: Account ────────────────────
                      if (_step == 0 && !_isGoogleFlow)
                        GlassCard(
                            child: Form(
                          key: _step1FormKey,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GoogleButton(
                                    text: 'Sign up with Google',
                                    isLoading: _googleLoading,
                                    onPressed: _googleSignUp),
                                const SizedBox(height: 20),
                                buildDivider(),
                                const SizedBox(height: 20),
                                AppTextField(
                                  label: 'Full Name',
                                  hint: 'e.g. Ali Hassan',
                                  controller: _nameCtrl,
                                  prefixIcon: CupertinoIcons.person,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Name required'
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                AppTextField(
                                  label: 'Email',
                                  hint: 'your@email.com',
                                  controller: _emailCtrl,
                                  prefixIcon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Email required';
                                    }
                                    if (!v.contains('@')) {
                                      return 'Invalid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                AppTextField(
                                  label: 'Password',
                                  hint: 'At least 6 characters',
                                  controller: _passCtrl,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  isPassword: true,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Password required';
                                    }
                                    if (v.length < 6) return 'Min 6 characters';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                AppTextField(
                                  label: 'Confirm Password',
                                  hint: 'Re-enter your password',
                                  controller: _confirmCtrl,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  isPassword: true,
                                  textInputAction: TextInputAction.done,
                                  onEditingComplete: _nextStep,
                                  validator: (v) => v != _passCtrl.text
                                      ? 'Passwords do not match'
                                      : null,
                                ),
                                const SizedBox(height: 28),
                                GlowButton(
                                  text: 'Continue',
                                  icon: Icons.arrow_forward_rounded,
                                  onPressed: _nextStep,
                                ),
                              ]),
                        )),

                      // ── Step 2: Study profile ──────────────
                      // Used by BOTH email flow (step==1) and Google flow
                      if (_step == 1 || _isGoogleFlow)
                        GlassCard(
                            child: Form(
                          key: _step2FormKey,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Google banner (read-only, no editable fields)
                                if (_isGoogleFlow) _googleBanner(),

                                if (_isGoogleFlow) const SizedBox(height: 20),

                                // Education level
                                const Text('Education Level',
                                    style: AppTextStyles.label),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _eduLevels.map((lv) {
                                    final sel = _eduLevel == lv;
                                    return GestureDetector(
                                      onTap: () =>
                                          setState(() => _eduLevel = lv),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          gradient: sel
                                              ? AppColors.primaryGrad
                                              : null,
                                          color: sel ? null : AppColors.inputBg,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: sel
                                                  ? Colors.transparent
                                                  : AppColors.inputBorder,
                                              width: 1.5),
                                          boxShadow: sel
                                              ? [
                                                  BoxShadow(
                                                      color: AppColors.violet
                                                          .withValues(
                                                              alpha: 0.35),
                                                      blurRadius: 12)
                                                ]
                                              : null,
                                        ),
                                        child: Text(_eduLabels[lv]!,
                                            style: AppTextStyles.body.copyWith(
                                              color: sel
                                                  ? Colors.white
                                                  : AppColors.textSub,
                                              fontWeight: sel
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                            )),
                                      ),
                                    );
                                  }).toList(),
                                ),

                                const SizedBox(height: 24),
                                AppTextField(
                                  label: 'Main Subject',
                                  hint: 'e.g. Computer Science, Biology',
                                  controller: _subjectCtrl,
                                  prefixIcon: Icons.auto_stories_outlined,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Subject required'
                                          : null,
                                ),

                                const SizedBox(height: 20),
                                const Text('Study Goal',
                                    style: AppTextStyles.label),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _goalSuggestions.entries.map((e) {
                                    final sel = _goalCtrl.text == e.key;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() => _goalCtrl.text = e.key);
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: sel
                                              ? AppColors.violet
                                                  .withValues(alpha: 0.2)
                                              : AppColors.inputBg,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: sel
                                                  ? AppColors.violet
                                                  : AppColors.inputBorder),
                                        ),
                                        child: Text('${e.value} ${e.key}',
                                            style: AppTextStyles.body.copyWith(
                                              color: sel
                                                  ? AppColors.violet
                                                  : AppColors.textSub,
                                              fontWeight: sel
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            )),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                                AppTextField(
                                  label: 'Or describe your goal',
                                  hint: 'What do you want to achieve?',
                                  controller: _goalCtrl,
                                  prefixIcon: Icons.flag_outlined,
                                  textInputAction: TextInputAction.done,
                                  onEditingComplete: _submit,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Goal required'
                                          : null,
                                ),

                                const SizedBox(height: 28),
                                GlowButton(
                                  text: _isGoogleFlow
                                      ? 'Complete Setup'
                                      : 'Create Account',
                                  icon: _isGoogleFlow
                                      ? Icons.check_circle_rounded
                                      : Icons.rocket_launch_rounded,
                                  isLoading: _loading,
                                  onPressed: _submit,
                                ),
                              ]),
                        )),

                      const SizedBox(height: 24),
                      if (!_isGoogleFlow)
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Already have an account? ',
                                  style: AppTextStyles.body),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Text('Sign In',
                                    style: AppTextStyles.link
                                        .copyWith(fontWeight: FontWeight.w700)),
                              ),
                            ]),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _googleBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF4285F4).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        // Google G icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
              child: Text('G',
                  style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      fontFamily: 'Georgia'))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Google Account',
              style: const TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(_emailCtrl.text,
                style: AppTextStyles.label.copyWith(fontSize: 12)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4285F4).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('Google',
              style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _buildLogo() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGrad,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: AppColors.violet.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: const Center(child: Text('📚', style: TextStyle(fontSize: 28))),
      );
}
