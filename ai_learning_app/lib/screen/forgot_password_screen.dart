import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Form, GlobalKey, FormState;
import '../services/api_service.dart';
import '../services/api_client.dart';
import '../utils/app_theme.dart';

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.forgotPassword(_emailCtrl.text.trim());
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
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
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: CupertinoNavigationBar(
        leading: const CupertinoNavigationBarBackButton(previousPageTitle: ''),
        backgroundColor: AppColors.bgCard.withOpacity(0.8),
      ),
      child: SafeArea(
        child: Stack(children: [
          const SpaceBackground(),
          FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: _sent ? _successPage() : _formPage(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _formPage() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reset Password', style: AppTextStyles.heading),
          const SizedBox(height: 4),
          const Text('Enter your email to receive a reset link.', style: AppTextStyles.sub),
          const SizedBox(height: 28),
          if (_error != null) ...[
            buildErrorBanner(_error!),
            const SizedBox(height: 20),
          ],
          Form(
            key: _formKey,
            child: AppTextField(
              label: 'Email',
              hint: 'your@email.com',
              controller: _emailCtrl,
              prefixIcon: CupertinoIcons.mail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onEditingComplete: _send,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              },
            ),
          ),
          const SizedBox(height: 28),
          GlowButton(
            text: 'Send Reset Link',
            icon: CupertinoIcons.arrow_right,
            isLoading: _loading,
            onPressed: _send,
          ),
        ],
      ),
    );
  }

  Widget _successPage() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.paperplane_fill, color: AppColors.success, size: 40),
          ),
          const SizedBox(height: 24),
          const Text('Email Sent!', style: AppTextStyles.heading),
          const SizedBox(height: 8),
          Text(
            'Check ${_emailCtrl.text} for a link to reset your password.',
            style: AppTextStyles.sub,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GlowButton(
            text: 'Back to Login',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
