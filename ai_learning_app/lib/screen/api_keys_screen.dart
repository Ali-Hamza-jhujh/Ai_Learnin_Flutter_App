import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/lumio_theme.dart';
import '../services/ai/ai_key_store.dart';

class ApiKeysScreen extends StatefulWidget {
  final String userId;

  const ApiKeysScreen({super.key, required this.userId});

  @override
  State<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends State<ApiKeysScreen> {
  final _geminiCtrl = TextEditingController();
  final _groqCtrl = TextEditingController();
  final _cerebrasCtrl = TextEditingController();
  bool _loading = true;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final keys = await AIKeyStore.loadAllKeys(widget.userId);
    if (!mounted) return;
    setState(() {
      _geminiCtrl.text = keys['gemini'] ?? '';
      _groqCtrl.text = keys['groq'] ?? '';
      _cerebrasCtrl.text = keys['cerebras'] ?? '';
      _loading = false;
    });
  }

  Future<void> _saveProvider(String provider, String value) async {
    if (value.trim().isEmpty) return;
    await AIKeyStore.saveKey(widget.userId, provider, value.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      successSnackBar('$provider key saved securely'),
    );
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Clear all keys?'),
        content: const Text('This removes all provider keys from secure storage.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true) return;
    await AIKeyStore.clearAllKeys(widget.userId);
    await _loadKeys();
  }

  @override
  void dispose() {
    _geminiCtrl.dispose();
    _groqCtrl.dispose();
    _cerebrasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('API Keys', style: AppTypography.titleLarge),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.violet))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _providerCard(
                  name: 'Gemini (Google)',
                  color: LumioColors.gemini,
                  controller: _geminiCtrl,
                  helpUrl: 'https://aistudio.google.com',
                  onSave: () => _saveProvider('gemini', _geminiCtrl.text),
                ),
                _providerCard(
                  name: 'Groq',
                  color: LumioColors.groq,
                  controller: _groqCtrl,
                  helpUrl: 'https://console.groq.com',
                  onSave: () => _saveProvider('groq', _groqCtrl.text),
                ),
                _providerCard(
                  name: 'Cerebras',
                  color: LumioColors.cerebras,
                  controller: _cerebrasCtrl,
                  helpUrl: 'https://cloud.cerebras.ai',
                  onSave: () => _saveProvider('cerebras', _cerebrasCtrl.text),
                ),
                const SizedBox(height: 24),
                GlowButton(text: 'Clear All Keys', onPressed: _clearAll),
              ],
            ),
    );
  }

  Widget _providerCard({
    required String name,
    required Color color,
    required TextEditingController controller,
    required String helpUrl,
    required VoidCallback onSave,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: LumioDecorations.lumioCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key_rounded, color: color),
              const SizedBox(width: 8),
              Text(name, style: AppTypography.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            obscureText: _obscure,
            style: const TextStyle(color: AppColors.textWhite),
            decoration: InputDecoration(
              hintText: 'Paste API key',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => launchUrl(Uri.parse(helpUrl)),
                child: const Text('How to get key'),
              ),
              const Spacer(),
              TextButton(onPressed: onSave, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}
