import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../services/ai_generation_service.dart';

// ══════════════════════════════════════════
// API KEYS SETTINGS SCREEN
// Matches the spec settings layout exactly.
// Shows status of each provider + offline AI.
// ══════════════════════════════════════════

class APIKeysSettingsScreen extends StatefulWidget {
  const APIKeysSettingsScreen({super.key});

  @override
  State<APIKeysSettingsScreen> createState() => _APIKeysSettingsScreenState();
}

class _APIKeysSettingsScreenState extends State<APIKeysSettingsScreen> {
  // Key values loaded from secure storage
  String? _geminiKey;
  String? _groqKey;
  String? _cerebrasKey;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final gemini   = await AIKeyStore.getGeminiKey();
    final groq     = await AIKeyStore.getGroqKey();
    final cerebras = await AIKeyStore.getCerebrasKey();
    if (mounted) setState(() {
      _geminiKey   = gemini;
      _groqKey     = groq;
      _cerebrasKey = cerebras;
      _loading     = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const SpaceBackground(),
        SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textSub, size: 20),
                onPressed: () => Navigator.pop(context)),
              const Expanded(child: Text('AI Providers',
                  style: TextStyle(color: AppColors.textWhite,
                      fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center)),
              const SizedBox(width: 44),
            ])),

          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(
                color: AppColors.violet))
            : RefreshIndicator(
                color: AppColors.violet,
                backgroundColor: AppColors.bgCard,
                onRefresh: _loadKeys,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                  children: [

                    // ── Cloud AI section ──────────────────
                    _sectionHeader('☁️', 'Cloud AI Providers'),
                    const SizedBox(height: 4),
                    const Text(
                      'All providers are free. Add as many as you want '
                      '— Lumio auto-switches when one hits its limit.',
                      style: AppTextStyles.sub),
                    const SizedBox(height: 16),

                    _ProviderTile(
                      name: 'Gemini (Google)',
                      emoji: '🌟',
                      badge: 'Primary · 1M tokens/day',
                      badgeColor: const Color(0xFF34EEB6),
                      getUrl: 'aistudio.google.com/app/apikey',
                      hintText: 'AIzaSy...',
                      currentKey: _geminiKey,
                      validator: AIGenerationService.validateGeminiKey,
                      onSaved: (k) async {
                        if (k == null) {
                          await AIKeyStore.deleteGeminiKey();
                        } else {
                          await AIKeyStore.saveGeminiKey(k);
                        }
                        await _loadKeys();
                      }),

                    const SizedBox(height: 12),

                    _ProviderTile(
                      name: 'Groq',
                      emoji: '⚡',
                      badge: 'Fallback 1 · 6K tokens/min',
                      badgeColor: AppColors.gold,
                      getUrl: 'console.groq.com/keys',
                      hintText: 'gsk_...',
                      currentKey: _groqKey,
                      validator: AIGenerationService.validateGroqKey,
                      onSaved: (k) async {
                        if (k == null) {
                          await AIKeyStore.deleteGroqKey();
                        } else {
                          await AIKeyStore.saveGroqKey(k);
                        }
                        await _loadKeys();
                      }),

                    const SizedBox(height: 12),

                    _ProviderTile(
                      name: 'Cerebras',
                      emoji: '🔵',
                      badge: 'Fallback 2 · 1M tokens/day',
                      badgeColor: const Color(0xFF48C6EF),
                      getUrl: 'cloud.cerebras.ai',
                      hintText: 'csk-...',
                      currentKey: _cerebrasKey,
                      validator: AIGenerationService.validateCerebrasKey,
                      onSaved: (k) async {
                        if (k == null) {
                          await AIKeyStore.deleteCerebrasKey();
                        } else {
                          await AIKeyStore.saveCerebrasKey(k);
                        }
                        await _loadKeys();
                      }),

                    const SizedBox(height: 8),

                    // Fallback order indicator
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.violet.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.violet.withOpacity(0.2))),
                      child: Row(children: [
                        const Icon(Icons.swap_horiz_rounded,
                            color: AppColors.violetLight, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Fallback order: Gemini → Groq → Cerebras',
                          style: AppTextStyles.body.copyWith(
                              fontSize: 12, color: AppColors.violetLight)),
                      ])),

                    const SizedBox(height: 28),

                    // ── Offline AI section ────────────────
                    _sectionHeader('📱', 'Offline AI (Gemma 7B)'),
                    const SizedBox(height: 16),
                    const _OfflineAITile(),

                    const SizedBox(height: 28),

                    // ── Security note ─────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.inputBorder)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        const Row(children: [
                          Icon(Icons.lock_outline_rounded,
                              color: AppColors.success, size: 16),
                          SizedBox(width: 8),
                          Text('Your keys are safe',
                            style: TextStyle(color: AppColors.textWhite,
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                          '• Stored only on this device (encrypted)\n'
                          '• Never sent to Lumio servers\n'
                          '• Sent directly to providers over HTTPS\n'
                          '• Never appear in logs or crash reports',
                          style: AppTextStyles.body.copyWith(fontSize: 12)),
                      ])),

                    const SizedBox(height: 16),

                    // Clear all keys
                    GestureDetector(
                      onTap: _confirmClearAll,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.error.withOpacity(0.25))),
                        child: Row(children: [
                          const Icon(Icons.delete_outline_rounded,
                              color: AppColors.error, size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('Clear All API Keys',
                              style: TextStyle(color: AppColors.error,
                                  fontSize: 14, fontWeight: FontWeight.w600))),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.error, size: 18),
                        ]))),
                  ]))),
        ])),
      ]));
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🗑️', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            const Text('Clear All Keys?',
                style: TextStyle(color: AppColors.textWhite,
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'This removes all saved API keys from this device. '
              'You will need to re-enter them to use cloud AI.',
              style: AppTextStyles.sub, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.inputBorder)),
                  child: const Text('Cancel',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSub,
                        fontWeight: FontWeight.w600))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  await AIKeyStore.clearAll();
                  await _loadKeys();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('All API keys cleared'),
                      backgroundColor: AppColors.error.withOpacity(0.9),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16)));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.error.withOpacity(0.3))),
                  child: const Text('Clear All',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.error,
                        fontWeight: FontWeight.w700))))),
            ]),
          ]))));
  }

  Widget _sectionHeader(String emoji, String title) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 18)),
    const SizedBox(width: 8),
    ShaderMask(
      shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
      child: Text(title, style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: Colors.white, fontFamily: 'Georgia'))),
  ]);
}

// ══════════════════════════════════════════
// PROVIDER TILE
// Shows status, masked key, edit/remove buttons
// ══════════════════════════════════════════

class _ProviderTile extends StatefulWidget {
  final String name;
  final String emoji;
  final String badge;
  final Color badgeColor;
  final String getUrl;
  final String hintText;
  final String? currentKey;
  final Future<bool> Function(String) validator;
  final Future<void> Function(String?) onSaved;

  const _ProviderTile({
    required this.name,
    required this.emoji,
    required this.badge,
    required this.badgeColor,
    required this.getUrl,
    required this.hintText,
    required this.currentKey,
    required this.validator,
    required this.onSaved,
  });

  @override
  State<_ProviderTile> createState() => _ProviderTileState();
}

class _ProviderTileState extends State<_ProviderTile> {
  bool _editing  = false;
  bool _saving   = false;
  bool _visible  = false;
  String? _error;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _ctrl.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Please enter a key');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final valid = await widget.validator(key);
    if (!mounted) return;
    if (!valid) {
      setState(() {
        _error = 'Your API key seems invalid. Please check and re-enter';
        _saving = false;
      });
      return;
    }
    await widget.onSaved(key);
    if (mounted) setState(() { _editing = false; _saving = false; _ctrl.clear(); });
  }

  Future<void> _remove() async {
    await widget.onSaved(null);
    if (mounted) setState(() { _editing = false; _ctrl.clear(); _error = null; });
  }

  bool get _hasKey =>
      widget.currentKey != null && widget.currentKey!.isNotEmpty;

  String get _maskedKey {
    final k = widget.currentKey ?? '';
    if (k.length <= 8) return '●' * k.length;
    return '${k.substring(0, 6)}${'●' * 10}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasKey
              ? widget.badgeColor.withOpacity(0.3)
              : AppColors.inputBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Row 1: name + status
        Row(children: [
          Text(widget.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.name, style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: widget.badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6)),
              child: Text(widget.badge, style: TextStyle(
                  fontSize: 10, color: widget.badgeColor,
                  fontWeight: FontWeight.w600))),
          ])),
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _hasKey
                  ? AppColors.success.withOpacity(0.12)
                  : AppColors.inputBg,
              borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                decoration: BoxDecoration(
                  color: _hasKey ? AppColors.success : AppColors.textMuted,
                  shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(_hasKey ? 'Active' : 'Not set',
                style: TextStyle(
                  fontSize: 11,
                  color: _hasKey ? AppColors.success : AppColors.textMuted,
                  fontWeight: FontWeight.w600)),
            ])),
        ]),

        // Masked key display (when set, not editing)
        if (_hasKey && !_editing) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.inputBorder)),
              child: Text(_maskedKey,
                style: const TextStyle(
                  color: AppColors.textSub,
                  fontSize: 13,
                  fontFamily: 'monospace')))),
            const SizedBox(width: 8),
            // Edit button
            GestureDetector(
              onTap: () {
                _ctrl.text = widget.currentKey ?? '';
                setState(() => _editing = true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.violet.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.violet.withOpacity(0.3))),
                child: const Text('Edit',
                  style: TextStyle(
                    color: AppColors.violetLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)))),
            const SizedBox(width: 6),
            // Remove button
            GestureDetector(
              onTap: _remove,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.error.withOpacity(0.25))),
                child: const Text('Remove',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)))),
          ]),
        ],

        // Edit / Add form
        if (_editing || !_hasKey) ...[
          const SizedBox(height: 12),
          if (_error != null) ...[
            buildErrorBanner(_error!),
            const SizedBox(height: 8),
          ],
          Container(
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _error != null
                    ? AppColors.error : AppColors.inputBorder,
                width: 1.5)),
            child: Row(children: [
              const SizedBox(width: 12),
              const Icon(Icons.key_rounded,
                  color: AppColors.textMuted, size: 16),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: _ctrl,
                obscureText: !_visible,
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 12,
                  fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14)),
                onChanged: (_) => setState(() => _error = null))),
              IconButton(
                icon: Icon(
                  _visible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.textMuted, size: 16),
                onPressed: () => setState(() => _visible = !_visible)),
            ])),
          const SizedBox(height: 10),
          Row(children: [
            if (_editing) ...[
              Expanded(child: GestureDetector(
                onTap: () => setState(() {
                  _editing = false; _ctrl.clear(); _error = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.inputBorder)),
                  child: const Text('Cancel',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSub,
                        fontSize: 13, fontWeight: FontWeight.w600))))),
              const SizedBox(width: 8),
            ],
            Expanded(child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGrad,
                  borderRadius: BorderRadius.circular(10)),
                child: _saving
                  ? const Center(child: SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)))
                  : Text(_hasKey ? 'Update Key' : 'Save Key',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700))))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.open_in_new_rounded,
                color: AppColors.textMuted, size: 12),
            const SizedBox(width: 4),
            Text('Get free key at ${widget.getUrl}',
              style: AppTextStyles.label.copyWith(fontSize: 10)),
          ]),
        ],
      ]));
  }
}

// ══════════════════════════════════════════
// OFFLINE AI TILE
// Shows download status and device check
// ══════════════════════════════════════════

class _OfflineAITile extends StatefulWidget {
  const _OfflineAITile();
  @override
  State<_OfflineAITile> createState() => _OfflineAITileState();
}

class _OfflineAITileState extends State<_OfflineAITile> {
  // TODO: replace with actual FlutterGemma.instance.isModelInstalled check
  final bool _installed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Row(children: [
          const Text('📱', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Gemma 7B (On-Device)',
              style: TextStyle(color: AppColors.textWhite,
                  fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(_installed ? '✅ Installed' : '⬇️ Not downloaded',
              style: TextStyle(
                fontSize: 12,
                color: _installed ? AppColors.success : AppColors.textMuted,
                fontWeight: FontWeight.w600)),
          ])),
        ]),

        const SizedBox(height: 14),

        // Requirements
        _reqRow('💾', 'Required:  4.0 GB storage'),
        const SizedBox(height: 6),
        _reqRow('🧠', 'Required:  6 GB RAM'),
        const SizedBox(height: 6),
        _reqRow('💡', 'Best on:  desktop / laptop or 8GB+ RAM phones'),

        const SizedBox(height: 14),

        if (!_installed) ...[
          GlowButton(
            text: 'Download Offline Model — 4 GB',
            icon: Icons.download_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFF48C6EF), Color(0xFF6F86D6)]),
            onPressed: () => _showDownloadDialog(context)),
          const SizedBox(height: 8),
          const Text('⚠️  Download only on WiFi. Uses ~4 GB of data.',
            style: TextStyle(color: AppColors.gold,
                fontSize: 11)),
        ] else ...[
          GlowButton(
            text: 'Remove Offline Model',
            icon: Icons.delete_outline_rounded,
            gradient: LinearGradient(colors: [
              AppColors.error, AppColors.error.withOpacity(0.7)]),
            onPressed: () {}),
        ],
      ]));
  }

  Widget _reqRow(String emoji, String text) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 14)),
    const SizedBox(width: 8),
    Text(text, style: AppTextStyles.body.copyWith(fontSize: 12)),
  ]);

  void _showDownloadDialog(BuildContext context) async {
    // Show on-device disclaimer first
    final accepted = await showOnDeviceDisclaimerDialog(context);
    if (!accepted) return;
    await AIKeyStore.acceptOnDeviceDisclaimer();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            'Offline model download coming soon. Connect to WiFi and try again.'),
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16)));
    }
  }
}

// ══════════════════════════════════════════
// ON-DEVICE DISCLAIMER DIALOG
// Reused from ai_key_screens.dart
// ══════════════════════════════════════════

Future<bool> showOnDeviceDisclaimerDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('⚠️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 16),
          const Text('On-Device AI Warning',
            style: TextStyle(color: AppColors.textWhite,
                fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.gold.withOpacity(0.3))),
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
              style: TextStyle(color: AppColors.textLight,
                  fontSize: 13, height: 1.6))),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.inputBorder)),
                child: const Text('Cancel',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSub,
                      fontWeight: FontWeight.w600))))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context, true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.gold.withOpacity(0.4))),
                child: const Text('Enable Anyway',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.gold,
                      fontWeight: FontWeight.w700))))),
          ]),
        ]))));
  return result ?? false;
}