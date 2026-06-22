import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import '../services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ══════════════════════════════════════════
// GROQ KEY GATE WIDGET
//
// Wrap any AI-powered screen with this widget.
// It handles:
//  1. Device check  — shows disclaimer on phones
//  2. Key check     — if no key, shows onboarding
//  3. Free tier     — 1 free generation if no key
//  4. Permission    — 3-step consent before download
// ══════════════════════════════════════════

/// Wraps a child widget with the full Groq key gate.
/// Usage:
///   GroqKeyGate(child: _GenerateNotesScreen())
class GroqKeyGate extends StatefulWidget {
  final Widget child;
  final String featureName;        // e.g. "Notes Generation"
  final VoidCallback? onKeyReady;  // called when key is confirmed

  const GroqKeyGate({
    super.key,
    required this.child,
    this.featureName = 'AI Generation',
    this.onKeyReady,
  });

  @override
  State<GroqKeyGate> createState() => _GroqKeyGateState();
}

class _GroqKeyGateState extends State<GroqKeyGate> {
  _GateStatus _status = _GateStatus.checking;
  bool _isMobile = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // Step 1: Device check
    final mobile = await _detectMobile();
    if (!mounted) return;

    if (mobile) {
      setState(() { _status = _GateStatus.mobileBlocked; _isMobile = true; });
      return;
    }

    // Step 2: Key check
    final hasKey = await GroqKeyService.hasKey();
    if (!mounted) return;

    if (hasKey) {
      setState(() => _status = _GateStatus.ready);
      widget.onKeyReady?.call();
    } else {
      // Check free-tier usage
      final usedFree = await _FreeTierTracker.hasUsedFree();
      setState(() => _status = usedFree
          ? _GateStatus.noKey
          : _GateStatus.noKeyFreeAvailable);
    }
  }

  Future<bool> _detectMobile() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final d = await info.androidInfo;
        // Tablets typically have screen > 7 inches.
        // We use the system feature tag as the most reliable signal.
        return !d.systemFeatures.contains('android.hardware.type.pc');
      }
      if (Platform.isIOS) {
        final d = await info.iosInfo;
        // iPhone = "iPhone", iPad = "iPad"
        return d.model.toLowerCase().contains('iphone');
      }
      // Windows / macOS / Linux — always laptop/desktop
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _GateStatus.checking:
        return const _CheckingScreen();

      case _GateStatus.mobileBlocked:
        return _MobileDisclaimerScreen(featureName: widget.featureName);

      case _GateStatus.noKeyFreeAvailable:
        return _FreeTierScreen(
          featureName: widget.featureName,
          onSetupKey: () => setState(() => _status = _GateStatus.settingUpKey),
          onUseFree: () async {
            // Mark free tier as used, then show permission flow
            await _FreeTierTracker.markUsed();
            if (!mounted) return;
            setState(() => _status = _GateStatus.permissionFlow);
          },
        );

      case _GateStatus.noKey:
        return _NoKeyScreen(
          featureName: widget.featureName,
          onSetupKey: () => setState(() => _status = _GateStatus.settingUpKey),
        );

      case _GateStatus.settingUpKey:
        return _KeySetupScreen(
          featureName: widget.featureName,
          onSuccess: () {
            setState(() => _status = _GateStatus.permissionFlow);
            widget.onKeyReady?.call();
          },
          onBack: () => setState(() => _status = _GateStatus.noKey),
        );

      case _GateStatus.permissionFlow:
        return _PermissionFlowScreen(
          featureName: widget.featureName,
          onAccepted: () => setState(() => _status = _GateStatus.ready),
          onDeclined: () => setState(() => _status = _GateStatus.noKey),
        );

      case _GateStatus.ready:
        return widget.child;
    }
  }
}

enum _GateStatus {
  checking,
  mobileBlocked,
  noKeyFreeAvailable,
  noKey,
  settingUpKey,
  permissionFlow,
  ready,
}

// ══════════════════════════════════════════
// FREE TIER TRACKER
// Tracks whether this user has used their 1 free generation.
// Stored locally — backend also enforces this server-side.
// ══════════════════════════════════════════

class _FreeTierTracker {
  static const String _key = 'free_tier_used';

  static Future<bool> hasUsedFree() async {
    final prefs = await _prefs();
    final userId = await TokenManager.getUserId() ?? 'guest';
    return prefs.getBool('${_key}_$userId') ?? false;
  }

  static Future<void> markUsed() async {
    final prefs = await _prefs();
    final userId = await TokenManager.getUserId() ?? 'guest';
    await prefs.setBool('${_key}_$userId', true);
  }

  static Future<dynamic> _prefs() async {
    // ignore: import_of_legacy_library_into_null_safe
    // We use shared_preferences via TokenManager's existing dependency
    final token = await TokenManager.getToken();
    // Re-use SharedPreferences from the existing package
    return _SharedPrefsCompat.instance;
  }
}

// Thin compat wrapper so we don't add a new import
class _SharedPrefsCompat {
  static final _SharedPrefsCompat instance = _SharedPrefsCompat._();
  _SharedPrefsCompat._();

  Future<bool> getBool(String key) async {
    // Delegates to TokenManager's SharedPreferences
    final prefs = await _getPrefs();
    return prefs.getBool(key) ?? false;
  }

  Future<void> setBool(String key, bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(key, value);
  }

 Future<dynamic> _getPrefs() async {
    return SharedPreferences.getInstance();
  }
}

// ══════════════════════════════════════════
// CHECKING SCREEN
// ══════════════════════════════════════════

class _CheckingScreen extends StatelessWidget {
  const _CheckingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const SpaceBackground(),
        const Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.violet),
            SizedBox(height: 20),
            Text('Checking setup...', style: AppTextStyles.sub),
          ],
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// MOBILE DISCLAIMER SCREEN
// Shown when user opens this feature on a phone/tablet.
// Cannot be dismissed — this is a hard block.
// ══════════════════════════════════════════

class _MobileDisclaimerScreen extends StatelessWidget {
  final String featureName;
  const _MobileDisclaimerScreen({required this.featureName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const SpaceBackground(),
        SafeArea(child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: AppColors.error.withOpacity(0.3))),
                child: const Center(
                  child: Text('🖥️', style: TextStyle(fontSize: 48)))),
              const SizedBox(height: 28),

              // Title
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]).createShader(b),
                child: Text('Desktop Only Feature',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                    color: Colors.white, fontFamily: 'Georgia'),
                  textAlign: TextAlign.center)),
              const SizedBox(height: 16),

              // Disclaimer card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.error.withOpacity(0.25))),
                child: Column(children: [
                  _row('⚠️', 'This feature is only available on laptops and desktop computers.'),
                  const SizedBox(height: 14),
                  _row('📱', 'Your current device has been detected as a mobile phone or tablet.'),
                  const SizedBox(height: 14),
                  _row('🔒', '$featureName requires a Groq API key and a desktop environment to run correctly.'),
                  const SizedBox(height: 14),
                  _row('💡', 'Please open the app on your laptop or PC to use this feature.'),
                ])),
              const SizedBox(height: 28),

              // Why?
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Why laptop only?',
                      style: TextStyle(color: AppColors.textWhite,
                        fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                      'AI generation is resource-intensive and works best with a stable '
                      'connection, larger screen, and desktop file system. Mobile support '
                      'is coming in a future update.',
                      style: AppTextStyles.sub),
                  ])),
              const SizedBox(height: 28),

              // Back button
              GlowButton(
                text: 'Go Back',
                icon: Icons.arrow_back_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                onPressed: () => Navigator.of(context).maybePop()),
            ],
          ),
        )),
      ]),
    );
  }

  Widget _row(String emoji, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: AppTextStyles.body.copyWith(fontSize: 13))),
    ]);
}

// ══════════════════════════════════════════
// FREE TIER SCREEN
// First-time user who hasn't set up a key yet.
// Offers 1 free trial OR key setup.
// ══════════════════════════════════════════

class _FreeTierScreen extends StatelessWidget {
  final String featureName;
  final VoidCallback onSetupKey;
  final VoidCallback onUseFree;

  const _FreeTierScreen({
    required this.featureName,
    required this.onSetupKey,
    required this.onUseFree,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const SpaceBackground(),
        SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 32),
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGrad,
                borderRadius: BorderRadius.circular(20)),
              child: const Text('FREE TRIAL AVAILABLE',
                style: TextStyle(color: Colors.white,
                  fontSize: 11, fontWeight: FontWeight.w800,
                  letterSpacing: 1.2))),
            const SizedBox(height: 20),

            ShaderMask(
              shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
              child: Text('Try $featureName Free',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                  color: Colors.white, fontFamily: 'Georgia'),
                textAlign: TextAlign.center)),
            const SizedBox(height: 12),
            const Text(
              'You have 1 free generation to try this feature.\n'
              'For unlimited access, add your own free Groq API key.',
              style: AppTextStyles.sub, textAlign: TextAlign.center),
            const SizedBox(height: 32),

            // Free trial card
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Row(children: [
                  Container(width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14)),
                    child: const Center(child: Text('🎁', style: TextStyle(fontSize: 22)))),
                  const SizedBox(width: 14),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1 Free Generation',
                        style: TextStyle(color: AppColors.textWhite,
                          fontSize: 15, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Uses our shared API key. No setup needed.',
                        style: AppTextStyles.sub),
                    ])),
                ]),
                const SizedBox(height: 16),
                const Divider(color: AppColors.inputBorder),
                const SizedBox(height: 14),
                _infoRow(Icons.warning_amber_rounded, AppColors.gold,
                  'Only 1 free generation per account. After that, you must add your own key.'),
                const SizedBox(height: 10),
                _infoRow(Icons.speed_rounded, AppColors.violet,
                  'Shared key may be slower during peak hours. Your own key is always faster.'),
              ])),
            const SizedBox(height: 24),

            // Use free button
            GlowButton(
              text: 'Use 1 Free Generation',
              icon: Icons.auto_awesome_rounded,
              onPressed: onUseFree),
            const SizedBox(height: 14),

            // Divider
            Row(children: [
              const Expanded(child: Divider(color: AppColors.inputBorder)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR', style: AppTextStyles.label)),
              const Expanded(child: Divider(color: AppColors.inputBorder)),
            ]),
            const SizedBox(height: 14),

            // Setup key button
            GlowButton(
              text: 'Set Up My Free Groq Key',
              icon: Icons.key_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
              onPressed: onSetupKey),
            const SizedBox(height: 12),
            const Text('Groq keys are free forever • No credit card needed',
              style: AppTextStyles.sub, textAlign: TextAlign.center),
            const SizedBox(height: 40),
          ]),
        )),
      ]),
    );
  }

  Widget _infoRow(IconData icon, Color color, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
        style: AppTextStyles.body.copyWith(fontSize: 12))),
    ]);
}

// ══════════════════════════════════════════
// NO KEY SCREEN
// User has already used free tier.
// Must add key to continue.
// ══════════════════════════════════════════

class _NoKeyScreen extends StatelessWidget {
  final String featureName;
  final VoidCallback onSetupKey;

  const _NoKeyScreen({required this.featureName, required this.onSetupKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const SpaceBackground(),
        SafeArea(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 90, height: 90,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.gold.withOpacity(0.3))),
                child: const Center(
                  child: Text('🔑', style: TextStyle(fontSize: 44)))),
              const SizedBox(height: 24),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFFFD93D), Color(0xFFFF9A3C)]).createShader(b),
                child: const Text('API Key Required',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                    color: Colors.white, fontFamily: 'Georgia'),
                  textAlign: TextAlign.center)),
              const SizedBox(height: 12),
              const Text(
                'Your free trial has been used.\n'
                'Add your free Groq API key for unlimited access.',
                style: AppTextStyles.sub, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _step('1', 'Visit console.groq.com'),
                  const SizedBox(height: 12),
                  _step('2', 'Sign up for free (no credit card)'),
                  const SizedBox(height: 12),
                  _step('3', 'Create an API key'),
                  const SizedBox(height: 12),
                  _step('4', 'Paste it below — get unlimited AI'),
                ])),
              const SizedBox(height: 28),
              GlowButton(
                text: 'Add My Groq API Key',
                icon: Icons.key_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD93D), Color(0xFFFF9A3C)]),
                onPressed: onSetupKey),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: const Text('Maybe later',
                  style: TextStyle(color: AppColors.textMuted,
                    fontSize: 14, decoration: TextDecoration.underline))),
            ],
          ),
        )),
      ]),
    );
  }

  Widget _step(String num, String text) => Row(children: [
    Container(width: 28, height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD93D), Color(0xFFFF9A3C)]),
        borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(num,
        style: const TextStyle(color: Colors.white,
          fontSize: 13, fontWeight: FontWeight.w800)))),
    const SizedBox(width: 12),
    Expanded(child: Text(text,
      style: const TextStyle(color: AppColors.textLight,
        fontSize: 13, fontWeight: FontWeight.w500))),
  ]);
}

// ══════════════════════════════════════════
// KEY SETUP SCREEN
// 3-step permission flow + key input
// ══════════════════════════════════════════

class _KeySetupScreen extends StatefulWidget {
  final String featureName;
  final VoidCallback onSuccess;
  final VoidCallback onBack;

  const _KeySetupScreen({
    required this.featureName,
    required this.onSuccess,
    required this.onBack,
  });

  @override
  State<_KeySetupScreen> createState() => _KeySetupScreenState();
}

class _KeySetupScreenState extends State<_KeySetupScreen> {
  int _step = 0; // 0 = disclaimer1, 1 = disclaimer2, 2 = enter key
  final _keyCtrl = TextEditingController();
  bool _keyVisible = false;
  bool _validating = false;
  bool _consent1 = false;
  bool _consent2 = false;
  bool _consent3 = false;
  String? _error;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Please enter your Groq API key');
      return;
    }
    if (!key.startsWith('gsk_')) {
      setState(() => _error = 'Groq keys start with "gsk_". Please check your key.');
      return;
    }
    setState(() { _validating = true; _error = null; });
    final valid = await GroqKeyService.validateKey(key);
    if (!mounted) return;
    if (!valid) {
      setState(() {
        _error = 'Key validation failed. Please check and try again.';
        _validating = false;
      });
      return;
    }
    await GroqKeyService.saveKey(key);
    if (!mounted) return;
    setState(() => _validating = false);
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const SpaceBackground(),
        SafeArea(child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textSub, size: 20),
                onPressed: widget.onBack),
              const Spacer(),
              // Step indicator
              Row(children: List.generate(3, (i) {
                final done = i < _step;
                final active = i == _step;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: active ? 28 : 8, height: 8,
                    decoration: BoxDecoration(
                      gradient: active || done ? AppColors.primaryGrad : null,
                      color: active || done ? null : AppColors.inputBorder,
                      borderRadius: BorderRadius.circular(4))));
              })),
              const Spacer(),
              const SizedBox(width: 44),
            ])),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildStep())),
        ])),
      ]),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _buildStep0();
      case 1: return _buildStep1();
      case 2: return _buildStep2();
      default: return _buildStep0();
    }
  }

  // ── Step 0: Terms of Use Disclaimer ────
  Widget _buildStep0() {
    return Column(children: [
      const SizedBox(height: 32),
      _stepHeader('📋', 'Terms of Use', 'Step 1 of 3',
        'Please read and accept these terms before proceeding.'),
      const SizedBox(height: 24),
      GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _termsSection('🎯 What this feature does',
            'This feature uses your personal Groq API key to generate '
            'AI-powered study notes and MCQs from your PDF documents. '
            'All AI requests are processed through Groq\'s servers.'),
          const SizedBox(height: 16),
          _termsSection('🔑 Your API Key',
            'Your Groq API key is stored securely on your device and '
            'is sent only to Groq\'s official API endpoint. It is never '
            'shared with third parties or other users.'),
          const SizedBox(height: 16),
          _termsSection('📊 Usage & Limits',
            'Your Groq free tier includes 14,400 requests/day — '
            'effectively unlimited for normal study use. You are responsible '
            'for your own API usage and any associated costs.'),
          const SizedBox(height: 16),
          _termsSection('📄 Your Documents',
            'PDFs you upload are processed to extract text for AI generation. '
            'Extracted text is stored in our database to avoid re-processing '
            'the same document. You can delete your documents at any time.'),
        ])),
      const SizedBox(height: 20),
      // Consent checkbox
      _consentBox(
        value: _consent1,
        text: 'I have read and agree to the Terms of Use for this feature.',
        onChanged: (v) => setState(() => _consent1 = v ?? false)),
      const SizedBox(height: 24),
      GlowButton(
        text: 'Continue',
        icon: Icons.arrow_forward_rounded,
        onPressed: _consent1
          ? () => setState(() => _step = 1)
          : null),
      const SizedBox(height: 40),
    ]);
  }

  // ── Step 1: Data & Privacy Disclaimer ──
  Widget _buildStep1() {
    return Column(children: [
      const SizedBox(height: 32),
      _stepHeader('🔐', 'Data & Privacy', 'Step 2 of 3',
        'Understand how your data is handled.'),
      const SizedBox(height: 24),
      GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _termsSection('🗄️ What we store',
            'We store your generated notes and MCQs in our database so you '
            'can access them anytime without re-generating. PDF text is '
            'cached to avoid duplicate processing and save your API quota.'),
          const SizedBox(height: 16),
          _termsSection('🚫 What we do NOT store',
            'We do NOT store your original PDF files on our servers. '
            'Files are processed in memory and discarded immediately. '
            'Your Groq API key is encrypted at rest.'),
          const SizedBox(height: 16),
          _termsSection('👤 Your data is yours',
            'All generated content belongs to you. You can delete any '
            'note, MCQ, or PDF record at any time — deletion is permanent '
            'and removes all associated data from our database.'),
          const SizedBox(height: 16),
          _termsSection('🔒 Per-user isolation',
            'Your API key, notes, MCQs and PDF cache are strictly '
            'isolated to your account. No other user can access your data.'),
        ])),
      const SizedBox(height: 20),
      _consentBox(
        value: _consent2,
        text: 'I understand how my data is stored and processed.',
        onChanged: (v) => setState(() => _consent2 = v ?? false)),
      const SizedBox(height: 24),
      GlowButton(
        text: 'Continue',
        icon: Icons.arrow_forward_rounded,
        onPressed: _consent2
          ? () => setState(() => _step = 2)
          : null),
      const SizedBox(height: 40),
    ]);
  }

  // ── Step 2: Enter Key ─────────────────
  Widget _buildStep2() {
    return Column(children: [
      const SizedBox(height: 32),
      _stepHeader('🔑', 'Enter Your Key', 'Step 3 of 3',
        'Paste your free Groq API key to unlock unlimited AI.'),
      const SizedBox(height: 24),

      // How to get key
      GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Text('How to get your free key:',
            style: TextStyle(color: AppColors.textWhite,
              fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _keyStep('1', 'Go to', 'console.groq.com'),
          const SizedBox(height: 8),
          _keyStep('2', 'Sign up free —', 'no credit card needed'),
          const SizedBox(height: 8),
          _keyStep('3', 'Click "API Keys" →', '"Create API Key"'),
          const SizedBox(height: 8),
          _keyStep('4', 'Copy and paste it below', ''),
        ])),
      const SizedBox(height: 20),

      if (_error != null) ...[
        buildErrorBanner(_error!),
        const SizedBox(height: 16),
      ],

      // Key input
      Container(
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _error != null
              ? AppColors.error : AppColors.inputBorder,
            width: 1.5)),
        child: Row(children: [
          const SizedBox(width: 16),
          const Icon(Icons.key_rounded, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: _keyCtrl,
            obscureText: !_keyVisible,
            style: const TextStyle(
              color: AppColors.textWhite, fontSize: 13,
              fontFamily: 'monospace'),
            decoration: const InputDecoration(
              hintText: 'gsk_xxxxxxxxxxxxxxxxxxxx',
              hintStyle: TextStyle(color: AppColors.textMuted),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 16)),
            onChanged: (_) => setState(() => _error = null))),
          IconButton(
            icon: Icon(
              _keyVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: AppColors.textMuted, size: 18),
            onPressed: () => setState(() => _keyVisible = !_keyVisible)),
        ])),
      const SizedBox(height: 16),

      // Final consent
      _consentBox(
        value: _consent3,
        text: 'I confirm this is my own Groq API key and I accept all usage responsibilities.',
        onChanged: (v) => setState(() => _consent3 = v ?? false)),
      const SizedBox(height: 24),

      GlowButton(
        text: _validating ? 'Validating...' : 'Save Key & Unlock',
        icon: _validating ? Icons.hourglass_empty_rounded : Icons.lock_open_rounded,
        isLoading: _validating,
        onPressed: _consent3 && !_validating ? _saveKey : null),
      const SizedBox(height: 12),

      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withOpacity(0.2))),
        child: Row(children: [
          const Icon(Icons.check_circle_outline_rounded,
            color: AppColors.success, size: 16),
          const SizedBox(width: 8),
          const Expanded(child: Text(
            'Your key is stored locally on this device and sent only to Groq.',
            style: TextStyle(color: AppColors.success, fontSize: 11))),
        ])),
      const SizedBox(height: 40),
    ]);
  }

  Widget _stepHeader(String emoji, String title, String badge, String sub) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.violet.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20)),
        child: Text(badge,
          style: const TextStyle(color: AppColors.violetLight,
            fontSize: 11, fontWeight: FontWeight.w700))),
      const SizedBox(height: 16),
      Text(emoji, style: const TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      ShaderMask(
        shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
        child: Text(title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
            color: Colors.white, fontFamily: 'Georgia'))),
      const SizedBox(height: 8),
      Text(sub, style: AppTextStyles.sub, textAlign: TextAlign.center),
    ]);
  }

  Widget _termsSection(String heading, String body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(heading, style: const TextStyle(color: AppColors.textWhite,
        fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      Text(body, style: AppTextStyles.body.copyWith(fontSize: 12, height: 1.6)),
    ]);

  Widget _consentBox({
    required bool value,
    required String text,
    required ValueChanged<bool?> onChanged,
  }) => GestureDetector(
    onTap: () => onChanged(!value),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: value
          ? AppColors.violet.withOpacity(0.1) : AppColors.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? AppColors.violet : AppColors.inputBorder,
          width: 1.5)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 22, height: 22,
          decoration: BoxDecoration(
            gradient: value ? AppColors.primaryGrad : null,
            color: value ? null : AppColors.inputBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: value ? Colors.transparent : AppColors.inputBorder,
              width: 1.5)),
          child: value
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
            : null),
        const SizedBox(width: 12),
        Expanded(child: Text(text,
          style: TextStyle(
            color: value ? AppColors.textWhite : AppColors.textSub,
            fontSize: 13, height: 1.5))),
      ])));

  Widget _keyStep(String num, String label, String value) => Row(children: [
    Container(width: 22, height: 22,
      decoration: BoxDecoration(
        color: AppColors.violet.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6)),
      child: Center(child: Text(num,
        style: const TextStyle(color: AppColors.violetLight,
          fontSize: 11, fontWeight: FontWeight.w800)))),
    const SizedBox(width: 10),
    Text(label, style: AppTextStyles.body.copyWith(fontSize: 12)),
    if (value.isNotEmpty) ...[
      const SizedBox(width: 4),
      Text(value, style: TextStyle(
        color: AppColors.violet,
        fontSize: 12, fontWeight: FontWeight.w700)),
    ],
  ]);
}

// ══════════════════════════════════════════
// PERMISSION FLOW SCREEN
// 3-step consent shown before first use
// (even for free tier users)
// ══════════════════════════════════════════

class _PermissionFlowScreen extends StatefulWidget {
  final String featureName;
  final VoidCallback onAccepted;
  final VoidCallback onDeclined;

  const _PermissionFlowScreen({
    required this.featureName,
    required this.onAccepted,
    required this.onDeclined,
  });

  @override
  State<_PermissionFlowScreen> createState() => _PermissionFlowScreenState();
}

class _PermissionFlowScreenState extends State<_PermissionFlowScreen> {
  int _step = 0;

  final List<_PermStep> _steps = const [
    _PermStep(
      emoji: '📄',
      title: 'PDF Processing',
      body: 'Your PDF will be uploaded and its text extracted for AI processing. '
            'The original file is NOT stored on our servers — only the extracted '
            'text content and your generated notes/MCQs are saved.',
      actionLabel: 'I understand — Continue',
    ),
    _PermStep(
      emoji: '🤖',
      title: 'AI Generation',
      body: 'Your document content will be sent to Groq\'s AI servers for processing. '
            'By continuing, you confirm you have the right to process this document '
            'and agree that AI-generated content may not be 100% accurate.',
      actionLabel: 'Agreed — Continue',
    ),
    _PermStep(
      emoji: '✅',
      title: 'Ready to Generate',
      body: 'Everything is set up. Your AI-powered generation is about to begin. '
            'Results will be saved to your personal library and only visible to you.',
      actionLabel: 'Start Generation',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final s = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const SpaceBackground(),
        SafeArea(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Progress dots
              Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: i == _step ? 24 : 8, height: 8,
                    decoration: BoxDecoration(
                      gradient: i <= _step ? AppColors.primaryGrad : null,
                      color: i <= _step ? null : AppColors.inputBorder,
                      borderRadius: BorderRadius.circular(4)))))),
              const SizedBox(height: 32),

              // Icon
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(_step),
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGrad,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(
                      color: AppColors.violet.withOpacity(0.4),
                      blurRadius: 24, offset: const Offset(0, 8))]),
                  child: Center(child: Text(s.emoji,
                    style: const TextStyle(fontSize: 44))))),
              const SizedBox(height: 24),

              // Title
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: ShaderMask(
                  key: ValueKey('t$_step'),
                  shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
                  child: Text(s.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                      color: Colors.white, fontFamily: 'Georgia')))),
              const SizedBox(height: 16),

              // Body card
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: GlassCard(
                  key: ValueKey('b$_step'),
                  padding: const EdgeInsets.all(20),
                  child: Text(s.body,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14, height: 1.7),
                    textAlign: TextAlign.center))),
              const SizedBox(height: 28),

              // Action button
              GlowButton(
                text: s.actionLabel,
                icon: isLast
                  ? Icons.auto_awesome_rounded
                  : Icons.arrow_forward_rounded,
                gradient: isLast
                  ? const LinearGradient(
                      colors: [AppColors.success, Color(0xFF00876A)])
                  : AppColors.primaryGrad,
                onPressed: () {
                  if (isLast) {
                    widget.onAccepted();
                  } else {
                    setState(() => _step++);
                  }
                }),
              const SizedBox(height: 14),

              // Decline link
              GestureDetector(
                onTap: widget.onDeclined,
                child: const Text('Cancel and go back',
                  style: TextStyle(color: AppColors.textMuted,
                    fontSize: 13,
                    decoration: TextDecoration.underline))),
            ],
          ),
        )),
      ]),
    );
  }
}

class _PermStep {
  final String emoji;
  final String title;
  final String body;
  final String actionLabel;
  const _PermStep({
    required this.emoji,
    required this.title,
    required this.body,
    required this.actionLabel,
  });
}