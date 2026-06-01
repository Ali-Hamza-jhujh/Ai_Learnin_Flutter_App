import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import '../services/api_client.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
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
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.forgotPassword(_emailCtrl.text.trim());
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      // Timeout still means email was sent — backend sends in background
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timeout')) {
        if (mounted) setState(() => _sent = true);
      } else {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
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
            // ── Back button ──────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF1A1A2E), size: 20),
                  onPressed: () => Navigator.pop(context)))),

            Expanded(child: SingleChildScrollView(
              child: _sent ? _successPage() : _formPage())),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // FORM PAGE — matches HTML form state
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
                blurRadius: 32,
                offset: const Offset(0, 8))
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
                  style: TextStyle(
                    color: Colors.white, fontSize: 28,
                    fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('Password Reset Request',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85), fontSize: 14)),
              ])),

            // ── Body ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Error banner
                if (_error != null) ...[
                  _htmlErrorBox(_error!),
                  const SizedBox(height: 20),
                ],

                const Text('Email Address',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: Color(0xFF444444), letterSpacing: 0.3)),
                const SizedBox(height: 8),

                Form(key: _formKey, child: TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: _send,
                  style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'your@email.com',
                    hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
                    prefixIcon: const Icon(Icons.email_outlined,
                        color: Color(0xFFAAAAAA), size: 20),
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16)),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email required';
                    if (!v.contains('@')) return 'Invalid email';
                    return null;
                  })),

                const SizedBox(height: 28),

                // Send button — orange gradient matching header
                GestureDetector(
                  onTap: _loading ? null : _send,
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
                      : const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Send Reset Link',
                            style: TextStyle(color: Colors.white,
                              fontSize: 16, fontWeight: FontWeight.w700)),
                        ])))),
              ])),

            // ── Footer ─────────────────────
            _htmlFooter(),
          ]),
        ),
      )),
    );
  }

  // ══════════════════════════════════════
  // SUCCESS PAGE — matches HTML success state
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
                const Text('📬', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('StudyAI',
                  style: TextStyle(color: Colors.white, fontSize: 28,
                    fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('Email Sent Successfully',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85), fontSize: 14)),
              ])),

            // ── Body ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
              child: Column(children: [

                const Text('Check your email! 📧',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E))),
                const SizedBox(height: 12),
                Text(
                  'We sent a password reset link to',
                  style: TextStyle(color: const Color(0xFF666666), fontSize: 15, height: 1.7)),
                const SizedBox(height: 6),
                // Email chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3))),
                  child: Text(_emailCtrl.text.trim(),
                    style: const TextStyle(
                      color: Color(0xFF6C63FF), fontWeight: FontWeight.w600,
                      fontSize: 14))),
                const SizedBox(height: 24),

                // ── Warning box — red left border ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: const BorderSide(color: Color(0xFFFF6B6B), width: 4),
                      top: BorderSide(color: const Color(0xFFFF6B6B).withOpacity(0.15)),
                      right: BorderSide(color: const Color(0xFFFF6B6B).withOpacity(0.15)),
                      bottom: BorderSide(color: const Color(0xFFFF6B6B).withOpacity(0.15)))),
                  child: const Text(
                    '⚠️ This link expires in 1 hour. Request a new one if it expires.',
                    style: TextStyle(color: Color(0xFFC53030), fontSize: 13, height: 1.6))),

                const SizedBox(height: 16),

                // ── Info box — purple left border ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: const BorderSide(color: Color(0xFF6C63FF), width: 4),
                      top: BorderSide(color: const Color(0xFF6C63FF).withOpacity(0.1)),
                      right: BorderSide(color: const Color(0xFF6C63FF).withOpacity(0.1)),
                      bottom: BorderSide(color: const Color(0xFF6C63FF).withOpacity(0.1)))),
                  child: const Text(
                    '🔒 If you did not request a password reset, your account is safe. No changes have been made.',
                    style: TextStyle(color: Color(0xFF666666), fontSize: 13, height: 1.6))),

                const SizedBox(height: 28),

                // Back to login button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
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
                    child: const Center(child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Back to Login',
                          style: TextStyle(color: Colors.white,
                            fontSize: 16, fontWeight: FontWeight.w700)),
                      ])))),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: () => setState(() {
                    _sent = false;
                    _emailCtrl.clear();
                  }),
                  child: const Text('Try a different email',
                    style: TextStyle(color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.w600, fontSize: 14))),
              ])),

            _htmlFooter(),
          ]),
        ),
      )),
    );
  }

  // ── HTML-style error box ──────────────
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

  // ── HTML-style footer ─────────────────
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