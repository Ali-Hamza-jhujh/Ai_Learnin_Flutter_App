import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import '../services/api_client.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  // ── Optional params for Google sign-up flow ──
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
  final _formKey = GlobalKey<FormState>();
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

  // Track if this is a Google-only registration
  // (no password needed — profile step only)
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
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _stepFade = CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _entryCtrl.forward();
    });
    _stepCtrl.value = 1.0;

    // ── FIX: if coming from Google flow, pre-fill and skip to step 2 ──
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

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    _stepCtrl.reverse().then((_) {
      setState(() => _step = 1);
      _stepCtrl.forward();
    });
  }

  // ── Regular email registration ────────
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isGoogleFlow) {
        // ── Google flow: update profile via ProfileService ──
        await ProfileService.updateProfile(
          name: _nameCtrl.text.trim(),
          educationLevel: _eduLevel,
          subject: _subjectCtrl.text.trim(),
          goal: _goalCtrl.text.trim(),
          profilePicture: widget.googlePhotoUrl,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            successSnackBar('Profile complete! Welcome to StudyAI 🚀'));
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        // ── Normal registration ──
        await AuthService.register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          educationLevel: _eduLevel,
          subject: _subjectCtrl.text.trim(),
          goal: _goalCtrl.text.trim(),
        );
        if (!mounted) return;
        _showSuccess();
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Google Sign-Up (from register screen) ────────────────
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
        // New Google user — go to step 2 to collect profile info
        _isGoogleFlow = true;
        _nameCtrl.text = account.displayName ?? '';
        _emailCtrl.text = account.email;
        _stepCtrl.reverse().then((_) {
          setState(() => _step = 1);
          _stepCtrl.forward();
        });
        ScaffoldMessenger.of(context).showSnackBar(
            successSnackBar('Google connected! Complete your study profile.'));
      } else {
        // Existing user — go to home directly
        ScaffoldMessenger.of(context).showSnackBar(
            successSnackBar('Welcome back, ${account.displayName}! 🚀'));
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Google Sign-Up failed. Please try again.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGrad,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.violet.withOpacity(0.5),
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
                      color: AppColors.violet.withOpacity(0.1),
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const SpaceBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // ── Top bar ──
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: AppColors.textSub, size: 20),
                          onPressed: () {
                            if (_step == 1 && !_isGoogleFlow) {
                              // Normal flow: go back to step 1
                              _stepCtrl.reverse().then((_) {
                                setState(() => _step = 0);
                                _stepCtrl.forward();
                              });
                            } else if (_step == 1 && _isGoogleFlow) {
                              // Google flow on step 2: go back to login
                              Navigator.pop(context);
                            } else {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        const Spacer(),
                        // Hide step dots if Google flow (only 1 step)
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
                                    gradient: active || done
                                        ? AppColors.primaryGrad
                                        : null,
                                    color: active || done
                                        ? null
                                        : AppColors.inputBorder,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              );
                            }),
                          ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            _isGoogleFlow ? 'Profile' : '${_step + 1} of 2',
                            style: AppTextStyles.label,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FadeTransition(
                        opacity: _stepFade,
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            _buildLogoSmall(),
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
                                  ? 'Tell us about your studies'
                                  : _step == 0
                                      ? 'Join the future of learning'
                                      : 'Personalize your AI tutor',
                              style: AppTextStyles.sub,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            GlassCard(
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_error != null) ...[
                                      buildErrorBanner(_error!),
                                      const SizedBox(height: 20),
                                    ],

                                    // ── STEP 1: Account details ──
                                    if (_step == 0 && !_isGoogleFlow) ...[
                                      GoogleButton(
                                        text: 'Sign up with Google',
                                        isLoading: _googleLoading,
                                        onPressed: _googleSignUp,
                                      ),
                                      const SizedBox(height: 20),
                                      buildDivider(),
                                      const SizedBox(height: 20),
                                      AppTextField(
                                        label: 'Full Name',
                                        hint: 'e.g. Ali Hassan',
                                        controller: _nameCtrl,
                                        prefixIcon:
                                            Icons.person_outline_rounded,
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Name required'
                                            : null,
                                      ),
                                      const SizedBox(height: 16),
                                      AppTextField(
                                        label: 'Email',
                                        hint: 'your@email.com',
                                        controller: _emailCtrl,
                                        prefixIcon: Icons.email_outlined,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (v) {
                                          if (v == null || v.isEmpty)
                                            return 'Email required';
                                          if (!v.contains('@'))
                                            return 'Invalid email';
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
                                          if (v == null || v.isEmpty)
                                            return 'Password required';
                                          if (v.length < 6)
                                            return 'Min 6 characters';
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
                                    ],

                                    // ── STEP 2: Study profile
                                    // (both normal & Google flows) ──
                                    if (_step == 1 || _isGoogleFlow) ...[
                                      // Show Google banner if Google flow
                                      if (_isGoogleFlow) ...[
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4285F4)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: const Color(0xFF4285F4)
                                                    .withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Text('🔗',
                                                  style:
                                                      TextStyle(fontSize: 20)),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _nameCtrl.text.isNotEmpty
                                                          ? _nameCtrl.text
                                                          : 'Google Account',
                                                      style: const TextStyle(
                                                          color: AppColors
                                                              .textWhite,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 13),
                                                    ),
                                                    Text(
                                                      _emailCtrl.text,
                                                      style: AppTextStyles.label
                                                          .copyWith(
                                                              fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                      ],

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
                                              duration: const Duration(
                                                  milliseconds: 220),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10),
                                              decoration: BoxDecoration(
                                                gradient: sel
                                                    ? AppColors.primaryGrad
                                                    : null,
                                                color: sel
                                                    ? null
                                                    : AppColors.inputBg,
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
                                                            color: AppColors
                                                                .violet
                                                                .withOpacity(
                                                                    0.35),
                                                            blurRadius: 12)
                                                      ]
                                                    : null,
                                              ),
                                              child: Text(
                                                _eduLabels[lv]!,
                                                style: AppTextStyles.body
                                                    .copyWith(
                                                        color: sel
                                                            ? Colors.white
                                                            : AppColors.textSub,
                                                        fontWeight: sel
                                                            ? FontWeight.w700
                                                            : FontWeight.w400),
                                              ),
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
                                        validator: (v) => v == null || v.isEmpty
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
                                        children: _goalSuggestions.entries
                                            .map((e) => GestureDetector(
                                                  onTap: () {
                                                    _goalCtrl.text = e.key;
                                                    setState(() {});
                                                  },
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                        milliseconds: 200),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12,
                                                        vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: _goalCtrl.text ==
                                                              e.key
                                                          ? AppColors.violet
                                                              .withOpacity(0.2)
                                                          : AppColors.inputBg,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      border: Border.all(
                                                          color: _goalCtrl
                                                                      .text ==
                                                                  e.key
                                                              ? AppColors.violet
                                                              : AppColors
                                                                  .inputBorder),
                                                    ),
                                                    child: Text(
                                                      '${e.value} ${e.key}',
                                                      style: AppTextStyles.body
                                                          .copyWith(
                                                              color: _goalCtrl
                                                                          .text ==
                                                                      e.key
                                                                  ? AppColors
                                                                      .violet
                                                                  : AppColors
                                                                      .textSub,
                                                              fontWeight: _goalCtrl
                                                                          .text ==
                                                                      e.key
                                                                  ? FontWeight
                                                                      .w600
                                                                  : FontWeight
                                                                      .w400),
                                                    ),
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                      const SizedBox(height: 12),
                                      AppTextField(
                                        label: 'Or describe your goal',
                                        hint: 'What do you want to achieve?',
                                        controller: _goalCtrl,
                                        prefixIcon: Icons.flag_outlined,
                                        textInputAction: TextInputAction.done,
                                        onEditingComplete: _register,
                                        validator: (v) => v == null || v.isEmpty
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
                                        onPressed: _register,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
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
                                        style: AppTextStyles.link.copyWith(
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 40),
                          ],
                        ),
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

  Widget _buildLogoSmall() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGrad,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: AppColors.violet.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: const Center(child: Text('📚', style: TextStyle(fontSize: 28))),
      );
}
