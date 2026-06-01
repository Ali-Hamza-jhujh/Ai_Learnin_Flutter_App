import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/api_client.dart';
import 'login_screen.dart';
import '../utils/app_theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;
  const ResetPasswordScreen({super.key, required this.token});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _success = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  late AnimationController _entryCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.resetPassword(
        token: widget.token,
        newPassword: _passCtrl.text,
      );
      if (mounted) setState(() => _success = true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(children: [
            if (!_success)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF1A1A2E), size: 20),
                    onPressed: () => Navigator.pop(context)))),
            Expanded(child: SingleChildScrollView(
              child: _success ? _successPage() : _formPage())),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // FORM PAGE — HTML form state
  // ══════════════════════════════════════
  Widget _formPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 32, offset: const Offset(0, 8))
            ]),
          child: Column(children: [

            // ── Orange gradient header ──────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20))),
              child: Column(children: [
                const Text('🔐', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('StudyAI',
                  style: TextStyle(color: Colors.white, fontSize: 28,
                    fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('Reset Your Password',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85), fontSize: 14)),
              ])),

            // ── Body ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
              child: Form(key: _formKey, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [

                if (_error != null) ...[
                  _htmlErrorBox(_error!),
                  const SizedBox(height: 20),
                ],

                // New password field
                _htmlLabel('New Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure1,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 15),
                  decoration: _htmlInputDecoration(
                    hint: 'Enter new password',
                    suffix: IconButton(
                      icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility,
                          color: const Color(0xFFAAAAAA), size: 20),
                      onPressed: () => setState(() => _obscure1 = !_obscure1))),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password required';
                    if (v.length < 6) return 'Min 6 characters';
                    return null;
                  }),

                const SizedBox(height: 20),

                // Confirm password field
                _htmlLabel('Confirm New Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure2,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: _reset,
                  style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 15),
                  decoration: _htmlInputDecoration(
                    hint: 'Confirm new password',
                    suffix: IconButton(
                      icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility,
                          color: const Color(0xFFAAAAAA), size: 20),
                      onPressed: () => setState(() => _obscure2 = !_obscure2))),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please confirm password';
                    if (v != _passCtrl.text) return 'Passwords do not match';
                    return null;
                  }),

                const SizedBox(height: 28),

                // Reset button — orange gradient
                GestureDetector(
                  onTap: _loading ? null : _reset,
                  child: Container(
                    width: double.infinity, height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B6B).withOpacity(0.4),
                          blurRadius: 16, offset: const Offset(0, 4))
                      ]),
                    child: Center(child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                      : const Text('🔐  Reset Password',
                          style: TextStyle(color: Colors.white,
                            fontSize: 16, fontWeight: FontWeight.w700))))),
              ]))),

            _htmlFooter(),
          ]),
        ),
      )),
    );
  }

  // ══════════════════════════════════════
  // SUCCESS PAGE — matches HTML success state exactly
  // ══════════════════════════════════════
  Widget _successPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 32, offset: const Offset(0, 8))
            ]),
          child: Column(children: [

            // ── Purple/blue gradient header ─
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF48C6EF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20))),
              child: Column(children: [
                const Text('🎉', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 12),
                const Text('StudyAI',
                  style: TextStyle(color: Colors.white, fontSize: 28,
                    fontWeight: FontWeight.w700, letterSpacing: 1)),
              ])),

            // ── Body ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
              child: Column(children: [

                const Text('✅ Password Reset!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E))),
                const SizedBox(height: 12),
                const Text(
                  'Your password has been changed. You can now log in to StudyAI.',
                  style: TextStyle(color: Color(0xFF666666), fontSize: 15, height: 1.7),
                  textAlign: TextAlign.center),

                const SizedBox(height: 24),

                // ── Green success box — matches HTML exactly ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FFF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC6F6D5))),
                  child: Column(children: [
                    const Text('🚀', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    const Text('You are all set!',
                      style: TextStyle(color: Color(0xFF276749),
                        fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text(
                      'Open the StudyAI app and log in to start your learning journey.',
                      style: TextStyle(color: Color(0xFF276749), fontSize: 13),
                      textAlign: TextAlign.center),
                  ])),

                const SizedBox(height: 24),

                // Features row — matches HTML table
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _featureItem('🤖', 'AI Notes'),
                  _featureItem('❓', 'MCQs'),
                  _featureItem('🎥', 'Lectures'),
                  _featureItem('📊', 'Predictions'),
                ]),

                const SizedBox(height: 28),

                // Go to login button
                GestureDetector(
                  onTap: () => Navigator.pushAndRemoveUntil(
                    context,
                    fadeSlideRoute(const LoginScreen()),
                    (route) => false),
                  child: Container(
                    width: double.infinity, height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF48C6EF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.4),
                          blurRadius: 16, offset: const Offset(0, 4))
                      ]),
                    child: const Center(child: Text('Go to Login →',
                      style: TextStyle(color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.w700))))),
              ])),

            _htmlFooter(),
          ]),
        ),
      )),
    );
  }

  // ── Shared HTML-style helpers ─────────

  Widget _htmlLabel(String text) => Text(text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
      color: Color(0xFF444444), letterSpacing: 0.3));

  InputDecoration _htmlInputDecoration({required String hint, Widget? suffix}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8F9FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2)),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16));

  Widget _htmlErrorBox(String msg) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5F5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.4))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Color(0xFFC53030), size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(msg,
        style: const TextStyle(color: Color(0xFFC53030), fontSize: 13))),
    ]));

  Widget _featureItem(String emoji, String label) => Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 24)),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
  ]);

  Widget _htmlFooter() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF6C63FF), Color(0xFF48C6EF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20))),
    child: const Text(
      '📚 StudyAI · AI-powered learning for every student',
      style: TextStyle(color: Colors.white, fontSize: 13),
      textAlign: TextAlign.center));
}