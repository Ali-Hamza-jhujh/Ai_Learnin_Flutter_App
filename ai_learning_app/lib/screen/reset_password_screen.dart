import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Form, GlobalKey, FormState;
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
    setState(() {
      _loading = true;
      _error = null;
    });
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
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: CupertinoNavigationBar(
        leading: const CupertinoNavigationBarBackButton(previousPageTitle: ''),
        backgroundColor: AppColors.bgCard.withValues(alpha: 0.8),
      ),
      child: SafeArea(
        child: Stack(children: [
          const SpaceBackground(),
          FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: _success ? _successPage() : _formPage(),
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
          const Text('Please enter your new password below.', style: AppTextStyles.sub),
          const SizedBox(height: 28),
          if (_error != null) ...[
            buildErrorBanner(_error!),
            const SizedBox(height: 20),
          ],
          Form(
            key: _formKey,
            child: Column(
              children: [
                AppTextField(
                  label: 'New Password',
                  hint: 'Enter new password',
                  controller: _passCtrl,
                  prefixIcon: CupertinoIcons.lock,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password required';
                    if (v.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                AppTextField(
                  label: 'Confirm Password',
                  hint: 'Confirm new password',
                  controller: _confirmCtrl,
                  prefixIcon: CupertinoIcons.lock_fill,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: _reset,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please confirm password';
                    if (v != _passCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          GlowButton(
            text: 'Update Password',
            icon: CupertinoIcons.check_mark,
            isLoading: _loading,
            onPressed: _reset,
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
              color: AppColors.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.check_mark_circled_solid, color: AppColors.success, size: 40),
          ),
          const SizedBox(height: 24),
          const Text('Password Updated!', style: AppTextStyles.heading),
          const SizedBox(height: 8),
          const Text(
            'Your password has been successfully reset. You can now sign in.',
            style: AppTextStyles.sub,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GlowButton(
            text: 'Go to Login',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                CupertinoPageRoute(builder: (_) => const LoginScreen()),
                (r) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
