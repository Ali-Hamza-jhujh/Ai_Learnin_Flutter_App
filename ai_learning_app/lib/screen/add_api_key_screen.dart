import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/key_storage_service.dart';
import '../services/api_client.dart';
import '../utils/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/lumio_theme.dart';

class AddApiKeyScreen extends StatefulWidget {
  final bool showBoth;
  const AddApiKeyScreen({super.key, this.showBoth = false});

  @override
  State<AddApiKeyScreen> createState() => _AddApiKeyScreenState();
}

class _AddApiKeyScreenState extends State<AddApiKeyScreen> {
  final _groqCtrl = TextEditingController();
  final _geminiCtrl = TextEditingController();
  final _cerebrasCtrl = TextEditingController();

  bool _groqObscure = true;
  bool _geminiObscure = true;
  bool _cerebrasObscure = true;

  bool? _groqValid;
  bool? _geminiValid;
  bool? _cerebrasValid;

  bool _verifyingGroq = false;
  bool _verifyingGemini = false;
  bool _verifyingCerebras = false;

  bool _loadingTrial = true;
  bool _freeTrialAvailable = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
    _checkTrial();
  }

  Future<void> _loadKeys() async {
    final keys = await KeyStorageService.getAllKeys();
    setState(() {
      _groqCtrl.text = keys['groq'] ?? '';
      _geminiCtrl.text = keys['gemini'] ?? '';
      _cerebrasCtrl.text = keys['cerebras'] ?? '';
    });
  }

  Future<void> _checkTrial() async {
    try {
      final res = await ApiClient.get('/api/generate/trial-status');
      setState(() {
        _freeTrialAvailable = res['remaining'] != null && (res['remaining'] as num) > 0;
        _loadingTrial = false;
      });
    } catch (_) {
      setState(() => _loadingTrial = false);
    }
  }

  Future<bool> _testGroqKey(String key) async {
    try {
      final res = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $key",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "llama3-8b-8192",
          "messages": [{"role": "user", "content": "ping"}],
          "max_tokens": 1,
        }),
      );
      return res.statusCode != 401 && res.statusCode != 403;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _testGeminiKey(String key) async {
    try {
      final res = await http.post(
        Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$key"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [{"parts": [{"text": "ping"}]}]
        }),
      );
      return res.statusCode != 401 && res.statusCode != 403 && res.statusCode != 400;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _testCerebrasKey(String key) async {
    try {
      final res = await http.post(
        Uri.parse("https://api.cerebras.ai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $key",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "llama3.1-8b",
          "messages": [{"role": "user", "content": "ping"}],
          "max_tokens": 1,
        }),
      );
      return res.statusCode != 401 && res.statusCode != 403;
    } catch (_) {
      return false;
    }
  }

  Future<void> _verifyKey(String provider) async {
    if (provider == 'groq') {
      final key = _groqCtrl.text.trim();
      if (key.isEmpty) return;
      setState(() {
        _verifyingGroq = true;
        _groqValid = null;
      });
      final ok = await _testGroqKey(key);
      setState(() {
        _verifyingGroq = false;
        _groqValid = ok;
      });
    } else if (provider == 'gemini') {
      final key = _geminiCtrl.text.trim();
      if (key.isEmpty) return;
      setState(() {
        _verifyingGemini = true;
        _geminiValid = null;
      });
      final ok = await _testGeminiKey(key);
      setState(() {
        _verifyingGemini = false;
        _geminiValid = ok;
      });
    } else if (provider == 'cerebras') {
      final key = _cerebrasCtrl.text.trim();
      if (key.isEmpty) return;
      setState(() {
        _verifyingCerebras = true;
        _cerebrasValid = null;
      });
      final ok = await _testCerebrasKey(key);
      setState(() {
        _verifyingCerebras = false;
        _cerebrasValid = ok;
      });
    }
  }

  Future<void> _saveKey(String provider) async {
    final value = provider == 'groq'
        ? _groqCtrl.text
        : provider == 'gemini'
            ? _geminiCtrl.text
            : _cerebrasCtrl.text;

    if (value.trim().isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (c) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: const Text('Please enter a valid key first'),
          actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(c))],
        )
      );
      return;
    }

    if (provider == 'groq') {
      await KeyStorageService.saveGroqKey(value);
    } else if (provider == 'gemini') {
      await KeyStorageService.saveGeminiKey(value);
    } else if (provider == 'cerebras') {
      await KeyStorageService.saveCerebrasKey(value);
    }

    showCupertinoSuccess(context, 'Saved $provider key securely! ✅');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: CupertinoNavigationBar(
        leading: const CupertinoNavigationBarBackButton(previousPageTitle: ''),
        middle: Text('API Keys Settings', style: AppTypography.titleLarge.copyWith(color: Colors.white, fontSize: 18)),
        backgroundColor: AppColors.bgCard.withOpacity(0.8),
      ),
      child: Stack(
        children: [
          const SpaceBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                ShaderMask(
                  shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
                  child: Text(
                    "Add Your Free AI Keys",
                    style: AppTypography.displayMedium.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Free forever. No credit card needed.",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
                const SizedBox(height: 24),
                
                // GROQ
                _buildProviderSection(
                  name: 'Groq',
                  color: LumioColors.groq,
                  controller: _groqCtrl,
                  obscure: _groqObscure,
                  isValid: _groqValid,
                  verifying: _verifyingGroq,
                  instructions: "1. Go to console.groq.com/keys\n2. Sign up free (Google login works)\n3. Click \"Create API Key\"\n4. Paste it below",
                  url: "https://console.groq.com/keys",
                  onObscureToggle: () => setState(() => _groqObscure = !_groqObscure),
                  onVerify: () => _verifyKey('groq'),
                  onSave: () => _saveKey('groq'),
                ),

                // GEMINI
                _buildProviderSection(
                  name: 'Gemini',
                  color: LumioColors.gemini,
                  controller: _geminiCtrl,
                  obscure: _geminiObscure,
                  isValid: _geminiValid,
                  verifying: _verifyingGemini,
                  instructions: "1. Go to aistudio.google.com/app/apikey\n2. Sign in with Google\n3. Click \"Create API key\"\n4. Paste it below",
                  url: "https://aistudio.google.com/app/apikey",
                  onObscureToggle: () => setState(() => _geminiObscure = !_geminiObscure),
                  onVerify: () => _verifyKey('gemini'),
                  onSave: () => _saveKey('gemini'),
                ),

                // CEREBRAS
                _buildProviderSection(
                  name: 'Cerebras',
                  color: LumioColors.cerebras,
                  controller: _cerebrasCtrl,
                  obscure: _cerebrasObscure,
                  isValid: _cerebrasValid,
                  verifying: _verifyingCerebras,
                  instructions: "1. Go to cloud.cerebras.ai\n2. Sign up free\n3. Go to API Keys section\n4. Paste it below",
                  url: "https://cloud.cerebras.ai",
                  onObscureToggle: () => setState(() => _cerebrasObscure = !_cerebrasObscure),
                  onVerify: () => _verifyKey('cerebras'),
                  onSave: () => _saveKey('cerebras'),
                ),

                const SizedBox(height: 32),
                
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: LumioDecorations.lumioCard(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(CupertinoIcons.heart_fill, color: AppColors.error, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            'Health Connect',
                            style: AppTypography.titleMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Track steps, heart rate, sleep, and vitals on this device. Morning, afternoon, and evening notifications, plus alerts when a metric crosses your limit.',
                        style: TextStyle(color: AppColors.textWhite, fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pushNamed(context, '/health'),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.error.withOpacity(0.4)),
                          ),
                          child: const Text(
                            'Open health dashboard',
                            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                Center(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (_loadingTrial) return;
                      if (_freeTrialAvailable) {
                        Navigator.pop(context, true);
                      } else {
                        showCupertinoDialog(
                          context: context,
                          builder: (c) => CupertinoAlertDialog(
                            title: const Text('Limit Reached'),
                            content: const Text("You have used your 1 free generation. Add your free Groq key for unlimited access"),
                            actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(c))],
                          )
                        );
                      }
                    },
                    child: Text(
                      "Skip for now",
                      style: AppTextStyles.link.copyWith(
                        color: _freeTrialAvailable ? AppColors.cyan : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSection({
    required String name,
    required Color color,
    required TextEditingController controller,
    required bool obscure,
    required bool? isValid,
    required bool verifying,
    required String instructions,
    required String url,
    required VoidCallback onObscureToggle,
    required VoidCallback onVerify,
    required VoidCallback onSave,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: LumioDecorations.lumioCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: AppTypography.titleMedium.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: const Text(
                  "Free • No credit card",
                  style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(instructions, style: const TextStyle(color: AppColors.textWhite, fontSize: 13, height: 1.5)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: Text(
              "Get your key here ↗",
              style: AppTextStyles.link.copyWith(color: color, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          CupertinoTextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(color: AppColors.textWhite),
            placeholder: 'Paste $name API Key',
            placeholderStyle: const TextStyle(color: AppColors.textMuted),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.inputBorder),
            ),
            suffix: CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye, color: AppColors.textMuted),
              onPressed: onObscureToggle,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: color.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: verifying ? null : onVerify,
                    child: verifying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CupertinoActivityIndicator(radius: 8),
                          )
                        : Text("Verify", style: TextStyle(color: color)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: onSave,
                    child: const Text("Save", style: TextStyle(color: AppColors.textWhite)),
                  ),
                ),
              ),
            ],
          ),
          if (isValid != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isValid ? CupertinoIcons.check_mark_circled : CupertinoIcons.exclamationmark_circle,
                  color: isValid ? AppColors.success : AppColors.error,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  isValid ? "Key is valid and working! ✅" : "Key invalid, try again ✗",
                  style: TextStyle(
                    color: isValid ? AppColors.success : AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
