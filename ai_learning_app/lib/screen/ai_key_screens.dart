import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../services/ai_generation_service.dart';

// ══════════════════════════════════════════
// API KEY ONBOARDING SCREEN
// Shown when user has no keys at all
// ══════════════════════════════════════════

class APIKeyOnboardingScreen extends StatefulWidget {
  /// Called when user finishes setup or skips
  final VoidCallback onComplete;

  const APIKeyOnboardingScreen({super.key, required this.onComplete});

  @override
  State<APIKeyOnboardingScreen> createState() => _APIKeyOnboardingScreenState();
}

class _APIKeyOnboardingScreenState extends State<APIKeyOnboardingScreen>
    with TickerProviderStateMixin {
  final _groqCtrl = TextEditingController();
  final _geminiCtrl = TextEditingController();

  bool _groqVisible = false;
  bool _geminiVisible = false;
  bool _validatingGroq = false;
  bool _validatingGemini = false;
  bool _skipping = false;
  String? _groqError;
  String? _geminiError;
  String? _groqSuccess;
  String? _geminiSuccess;

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _groqCtrl.dispose();
    _geminiCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveGroq() async {
    final key = _groqCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _groqError = 'Please enter your Groq API key');
      return;
    }
    setState(() {
      _validatingGroq = true;
      _groqError = null;
      _groqSuccess = null;
    });
    final valid = await AIGenerationService.validateGroqKey(key);
    if (!mounted) return;
    if (valid) {
      await AIKeyStore.saveGroqKey(key);
      setState(() {
        _groqSuccess = '✅ Groq key saved! Unlimited generations unlocked.';
        _validatingGroq = false;
      });
    } else {
      setState(() {
        _groqError = 'Your API key seems invalid. Please check and re-enter';
        _validatingGroq = false;
      });
    }
  }

  Future<void> _saveGemini() async {
    final key = _geminiCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _geminiError = 'Please enter your Gemini API key');
      return;
    }
    setState(() {
      _validatingGemini = true;
      _geminiError = null;
      _geminiSuccess = null;
    });
    final valid = await AIGenerationService.validateGeminiKey(key);
    if (!mounted) return;
    if (valid) {
      await AIKeyStore.saveGeminiKey(key);
      setState(() {
        _geminiSuccess = '✅ Gemini key saved! Used as backup AI.';
        _validatingGemini = false;
      });
    } else {
      setState(() {
        _geminiError = 'Your API key seems invalid. Please check and re-enter';
        _validatingGemini = false;
      });
    }
  }

  Future<void> _skip() async {
    final freeUsed = await AIKeyStore.hasFreeGenerationBeenUsed();
    if (freeUsed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
            'You have used your 1 free generation. Add your free Groq key for unlimited access',
          ),
          backgroundColor: AppColors.error.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
      return;
    }
    setState(() => _skipping = true);
    widget.onComplete();
  }

  bool get _hasAnySaved =>
      _groqSuccess != null || _geminiSuccess != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const SpaceBackground(),
        SafeArea(
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGrad,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.violet.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: const Center(
                      child: Text('🔑', style: TextStyle(fontSize: 34))),
                ),
                const SizedBox(height: 16),
                ShaderMask(
                  shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
                  child: const Text(
                    'Unlock AI Generation',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'Georgia',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add your free API key for unlimited\nAI notes and MCQs',
                  style: AppTextStyles.sub,
                  textAlign: TextAlign.center,
                ),
              ]),
            ),

            const SizedBox(height: 20),

            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    gradient: AppColors.primaryGrad,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSub,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: '⚡ Groq (Recommended)'),
                    Tab(text: '✨ Gemini (Backup)'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _GroqTab(
                    ctrl: _groqCtrl,
                    visible: _groqVisible,
                    validating: _validatingGroq,
                    error: _groqError,
                    success: _groqSuccess,
                    onToggleVisible: () =>
                        setState(() => _groqVisible = !_groqVisible),
                    onSave: _saveGroq,
                  ),
                  _GeminiTab(
                    ctrl: _geminiCtrl,
                    visible: _geminiVisible,
                    validating: _validatingGemini,
                    error: _geminiError,
                    success: _geminiSuccess,
                    onToggleVisible: () =>
                        setState(() => _geminiVisible = !_geminiVisible),
                    onSave: _saveGemini,
                  ),
                ],
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(children: [
                if (_hasAnySaved)
                  GlowButton(
                    text: 'Done — Start Generating!',
                    icon: Icons.auto_awesome_rounded,
                    onPressed: widget.onComplete,
                  )
                else ...[
                  GlowButton(
                    text: 'Done',
                    icon: Icons.check_rounded,
                    onPressed: widget.onComplete,
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _skipping ? null : _skip,
                    child: Text(
                      'Skip — Use 1 Free Generation',
                      style: AppTextStyles.link.copyWith(
                        color: AppColors.textMuted,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Groq tab ──────────────────────────────
class _GroqTab extends StatelessWidget {
  final TextEditingController ctrl;
  final bool visible;
  final bool validating;
  final String? error;
  final String? success;
  final VoidCallback onToggleVisible;
  final VoidCallback onSave;

  const _GroqTab({
    required this.ctrl,
    required this.visible,
    required this.validating,
    required this.error,
    required this.success,
    required this.onToggleVisible,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Why Groq
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _row('⚡', 'Fastest AI available (Llama 3.1)'),
            const SizedBox(height: 8),
            _row('🆓', '14,400 free requests per day'),
            const SizedBox(height: 8),
            _row('💳', 'No credit card required'),
            const SizedBox(height: 8),
            _row('🔄', 'Resets every 24 hours'),
          ]),
        ),
        const SizedBox(height: 16),

        // Steps
        const Text('HOW TO GET YOUR FREE KEY', style: AppTextStyles.label),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _step('1', 'Go to', 'console.groq.com'),
            const SizedBox(height: 10),
            _step('2', 'Sign up free —', 'no credit card needed'),
            const SizedBox(height: 10),
            _step('3', 'Click "API Keys" →', '"Create API Key"'),
            const SizedBox(height: 10),
            _step('4', 'Copy and paste below', ''),
          ]),
        ),
        const SizedBox(height: 16),

        // Key input
        if (error != null) ...[
          buildErrorBanner(error!),
          const SizedBox(height: 12),
        ],
        if (success != null) ...[
          _successBanner(success!),
          const SizedBox(height: 12),
        ],

        Container(
          decoration: BoxDecoration(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: error != null
                  ? AppColors.error
                  : success != null
                      ? AppColors.success
                      : AppColors.inputBorder,
              width: 1.5,
            ),
          ),
          child: Row(children: [
            const SizedBox(width: 14),
            const Icon(Icons.key_rounded, color: AppColors.textMuted, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: ctrl,
                obscureText: !visible,
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: const InputDecoration(
                  hintText: 'gsk_xxxxxxxxxxxxxxxxxxxx',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppColors.textMuted,
                size: 18,
              ),
              onPressed: onToggleVisible,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        GlowButton(
          text: validating ? 'Validating...' : 'Save Groq Key',
          icon: validating ? Icons.hourglass_empty_rounded : Icons.save_rounded,
          isLoading: validating,
          onPressed: validating ? null : onSave,
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _row(String emoji, String text) => Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: AppTextStyles.body.copyWith(fontSize: 13))),
      ]);

  Widget _step(String num, String label, String value) => Row(children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGrad,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
              child: Text(num,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: AppTextStyles.body.copyWith(fontSize: 12)),
        if (value.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  color: AppColors.violet,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ]);
}

// ── Gemini tab ────────────────────────────
class _GeminiTab extends StatelessWidget {
  final TextEditingController ctrl;
  final bool visible;
  final bool validating;
  final String? error;
  final String? success;
  final VoidCallback onToggleVisible;
  final VoidCallback onSave;

  const _GeminiTab({
    required this.ctrl,
    required this.visible,
    required this.validating,
    required this.error,
    required this.success,
    required this.onToggleVisible,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _row('🔄', 'Used as automatic backup when Groq fails'),
            const SizedBox(height: 8),
            _row('🆓', 'Free tier available on Google AI Studio'),
            const SizedBox(height: 8),
            _row('💡', 'Optional but recommended for reliability'),
          ]),
        ),
        const SizedBox(height: 16),

        const Text('HOW TO GET YOUR FREE KEY', style: AppTextStyles.label),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _step('1', 'Go to', 'aistudio.google.com'),
            const SizedBox(height: 10),
            _step('2', 'Sign in with Google account', ''),
            const SizedBox(height: 10),
            _step('3', 'Click "Get API Key"', ''),
            const SizedBox(height: 10),
            _step('4', 'Copy and paste below', ''),
          ]),
        ),
        const SizedBox(height: 16),

        if (error != null) ...[
          buildErrorBanner(error!),
          const SizedBox(height: 12),
        ],
        if (success != null) ...[
          _successBanner(success!),
          const SizedBox(height: 12),
        ],

        Container(
          decoration: BoxDecoration(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: error != null
                  ? AppColors.error
                  : success != null
                      ? AppColors.success
                      : AppColors.inputBorder,
              width: 1.5,
            ),
          ),
          child: Row(children: [
            const SizedBox(width: 14),
            const Icon(Icons.key_rounded, color: AppColors.textMuted, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: ctrl,
                obscureText: !visible,
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: const InputDecoration(
                  hintText: 'AIzaSy...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppColors.textMuted,
                size: 18,
              ),
              onPressed: onToggleVisible,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        GlowButton(
          text: validating ? 'Validating...' : 'Save Gemini Key',
          icon: validating ? Icons.hourglass_empty_rounded : Icons.save_rounded,
          isLoading: validating,
          gradient: const LinearGradient(
            colors: [Color(0xFF4285F4), Color(0xFF34A853)],
          ),
          onPressed: validating ? null : onSave,
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _row(String emoji, String text) => Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: AppTextStyles.body.copyWith(fontSize: 13))),
      ]);

  Widget _step(String num, String label, String value) => Row(children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF4285F4), Color(0xFF34A853)]),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
              child: Text(num,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: AppTextStyles.body.copyWith(fontSize: 12)),
        if (value.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFF4285F4),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ]);
}

Widget _successBanner(String msg) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded,
            color: AppColors.success, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.success))),
      ]),
    );

// ══════════════════════════════════════════
// ON-DEVICE DISCLAIMER DIALOG
// Show before enabling flutter_gemma
// ══════════════════════════════════════════

Future<bool> showOnDeviceDisclaimerDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: AppColors.bgCard,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('⚠️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 16),
          const Text(
            'On-Device AI Warning',
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.gold.withOpacity(0.3)),
            ),
            child: const Text(
              'On-device AI requires significant device resources.\n\n'
              'This feature works best on:\n'
              '  • Laptops and desktops running Flutter\n'
              '  • High-performance phones (8GB RAM or more)\n'
              '  • Devices with at least 4GB free storage\n\n'
              'On low-end devices this may cause:\n'
              '  • Slow performance\n'
              '  • App crashes\n'
              '  • Battery drain\n\n'
              'Do you want to continue?',
              style: TextStyle(
                  color: AppColors.textLight, fontSize: 13, height: 1.6),
            ),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.inputBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: const Text(
                    'Cancel',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSub,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.gold.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'Enable Anyway',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
  return result ?? false;
}

// ══════════════════════════════════════════
// FREE GENERATION USED PAYWALL
// Shown after 1 free generation is consumed
// ══════════════════════════════════════════

class FreeGenerationUsedScreen extends StatelessWidget {
  final VoidCallback onAddKey;

  const FreeGenerationUsedScreen({super.key, required this.onAddKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const SpaceBackground(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(32),
                    border:
                        Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: const Center(
                      child: Text('🔓', style: TextStyle(fontSize: 48))),
                ),
                const SizedBox(height: 24),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFFFFD93D), Color(0xFFFF9A3C)],
                  ).createShader(b),
                  child: const Text(
                    'Free Generation Used',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'Georgia',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You have used your 1 free generation.\n'
                  'Add your free Groq key for unlimited access.',
                  style: AppTextStyles.sub,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(children: [
                    _featureRow('⚡', 'Groq is 100% free forever'),
                    const SizedBox(height: 10),
                    _featureRow('🔑', 'No credit card required'),
                    const SizedBox(height: 10),
                    _featureRow('♾️', '14,400 requests per day'),
                    const SizedBox(height: 10),
                    _featureRow('🤖',
                        'Best AI quality (Llama 3.1)'),
                  ]),
                ),
                const SizedBox(height: 28),

                GlowButton(
                  text: 'Add My Free Groq Key',
                  icon: Icons.key_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD93D), Color(0xFFFF9A3C)],
                  ),
                  onPressed: onAddKey,
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Text(
                    'Maybe later',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _featureRow(String emoji, String text) => Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: AppTextStyles.body
                    .copyWith(fontSize: 13))),
      ]);
}