import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math' as math;

class AppColors {
  static const Color bg = Color(0xFFF3F4F6);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color violet = Color(0xFF1E40AF);
  static const Color violetGlow = Color(0x221E40AF);
  static const Color violetLight = Color(0xFF3B82F6);
  static const Color cyan = Color(0xFF2563EB);
  static const Color cyanGlow = Color(0x222563EB);
  static const Color gold = Color(0xFFF59E0B);
  static const Color textWhite = Color(0xFF0F172A);
  static const Color textSub = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color textLight = Color(0xFF64748B);
  static const Color inputBg = Color(0xFFF8FAFC);
  static const Color inputBorder = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFE2E8F0);

  static const LinearGradient primaryGrad = LinearGradient(
      colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);

  static const LinearGradient bgGrad = LinearGradient(
      colors: [Color(0xFFF3F4F6), Color(0xFFEFF6FF), Color(0xFFF3F4F6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);

  static const LinearGradient goldGrad = LinearGradient(
      colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);

  static const LinearGradient cardGradient = LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);
}

class AppTextStyles {
  static const TextStyle display = TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: AppColors.textWhite,
      fontFamily: 'Georgia',
      letterSpacing: -1,
      height: 1.15);

  static const TextStyle heading = TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: AppColors.textWhite,
      fontFamily: 'Georgia',
      letterSpacing: -0.5);

  static const TextStyle sub = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.textSub,
      height: 1.6);

  static const TextStyle body =
      TextStyle(fontSize: 14, color: AppColors.textSub, height: 1.5);

  static const TextStyle label = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textMuted,
      letterSpacing: 1.2);

  static const TextStyle btn = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: 0.3);

  static const TextStyle link = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.cyan);
}

// ── Glowing gradient button with press animation ──
class GlowButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final LinearGradient? gradient;

  const GlowButton(
      {super.key,
      required this.text,
      this.onPressed,
      this.isLoading = false,
      this.icon,
      this.gradient});

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 100),
        lowerBound: 0.96,
        upperBound: 1.0)
      ..value = 1.0;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grad = widget.gradient ?? AppColors.primaryGrad;
    return GestureDetector(
      onTapDown: (_) => _c.reverse(),
      onTapUp: (_) {
        _c.forward();
        if (!widget.isLoading) widget.onPressed?.call();
      },
      onTapCancel: () => _c.forward(),
      child: ScaleTransition(
          scale: _c,
          child: Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
                gradient: grad,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.violet.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8))
                ]),
            child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CupertinoActivityIndicator(
                            color: Colors.white, radius: 11))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8)
                        ],
                        Text(widget.text, style: AppTextStyles.btn),
                      ])),
          )),
    );
  }
}

// ── Google sign-in button ──
class GoogleButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  const GoogleButton(
      {super.key, required this.text, this.onPressed, this.isLoading = false});
  @override
  State<GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<GoogleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  bool _hover = false;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 100),
        lowerBound: 0.97,
        upperBound: 1.0)
      ..value = 1.0;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _c.reverse();
        setState(() => _hover = true);
      },
      onTapUp: (_) {
        _c.forward();
        setState(() => _hover = false);
        if (!widget.isLoading) widget.onPressed?.call();
      },
      onTapCancel: () {
        _c.forward();
        setState(() => _hover = false);
      },
      child: ScaleTransition(
          scale: _c,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
                color: _hover ? const Color(0xFF1A2340) : AppColors.inputBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: _hover
                        ? AppColors.violet.withValues(alpha: 0.5)
                        : AppColors.inputBorder,
                    width: 1.5)),
            child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CupertinoActivityIndicator(
                            color: AppColors.textSub, radius: 11))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        // Google G logo
                        Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4)),
                            child: const Center(
                                child: Text('G',
                                    style: TextStyle(
                                        color: Color(0xFF4285F4),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Georgia')))),
                        const SizedBox(width: 12),
                        Text(widget.text,
                            style: AppTextStyles.btn
                                .copyWith(color: AppColors.textWhite)),
                      ])),
          )),
    );
  }
}

// ── Input field ──
class AppTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final IconData prefixIcon;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final VoidCallback? onEditingComplete;

  const AppTextField(
      {super.key,
      required this.label,
      required this.hint,
      required this.controller,
      required this.prefixIcon,
      this.isPassword = false,
      this.keyboardType = TextInputType.text,
      this.validator,
      this.textInputAction = TextInputAction.next,
      this.onEditingComplete});

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label.toUpperCase(), style: AppTextStyles.label),
      const SizedBox(height: 8),
      Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: FormField<String>(
            validator: widget.validator,
            initialValue: widget.controller.text,
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CupertinoTextField(
                    controller: widget.controller,
                    obscureText: widget.isPassword && _obscure,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    onEditingComplete: widget.onEditingComplete,
                    style: const TextStyle(color: AppColors.textWhite, fontSize: 15),
                    placeholder: widget.hint,
                    placeholderStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                    prefix: Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: Icon(widget.prefixIcon,
                          color: _focused ? AppColors.violet : AppColors.textMuted, size: 20),
                    ),
                    suffix: widget.isPassword
                        ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: Icon(
                                _obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                                color: AppColors.textMuted,
                                size: 20),
                            onPressed: () => setState(() => _obscure = !_obscure))
                        : null,
                    decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: state.hasError
                                ? AppColors.error
                                : (_focused ? AppColors.violet : AppColors.inputBorder),
                            width: _focused || state.hasError ? 2 : 1.5)),
                    onChanged: (val) => state.didChange(val),
                  ),
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 6),
                      child: Text(state.errorText ?? '',
                          style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    )
                ],
              );
            },
          )),
    ]);
  }
}

// ── Deep space background with animated particles ──
class SpaceBackground extends StatefulWidget {
  const SpaceBackground({super.key});
  @override
  State<SpaceBackground> createState() => _SpaceBackgroundState();
}

class _SpaceBackgroundState extends State<SpaceBackground>
    with TickerProviderStateMixin {
  late AnimationController _nebulaCtrl;
  late AnimationController _starCtrl;

  @override
  void initState() {
    super.initState();
    _nebulaCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat(reverse: true);
    _starCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _nebulaCtrl.dispose();
    _starCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: Listenable.merge([_nebulaCtrl, _starCtrl]),
        builder: (_, __) => CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _SpacePainter(_nebulaCtrl.value, _starCtrl.value)));
  }
}

class _SpacePainter extends CustomPainter {
  final double nebula;
  final double star;
  _SpacePainter(this.nebula, this.star);

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
              colors: [Color(0xFFF3F4F6), Color(0xFFEFF6FF), Color(0xFFF9FAFB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Nebula glow top-right
    final nebulaPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);
    nebulaPaint.color = Color.fromRGBO(30, 64, 175, 0.05 + nebula * 0.03);
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.12), 200, nebulaPaint);

    // Nebula glow bottom-left
    nebulaPaint.color = Color.fromRGBO(59, 130, 246, 0.04 + (1 - nebula) * 0.03);
    canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.8), 160, nebulaPaint);

    // Stars (rendered as soft light-blue ambient dots)
    final rand = math.Random(42);
    for (int i = 0; i < 60; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final r = rand.nextDouble() * 1.5 + 0.5;
      final phase = rand.nextDouble() * math.pi * 2;
      final opacity = 0.15 + math.sin(star * math.pi * 2 + phase).abs() * 0.3;
      canvas.drawCircle(Offset(x, y), r,
          Paint()..color = Color.fromRGBO(100, 116, 139, opacity));
    }

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0x06000000)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 80) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 80) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Diagonal accent line
    final accentPaint = Paint()
      ..color = AppColors.violet.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(size.width * 0.6, 0),
        Offset(size.width, size.height * 0.5), accentPaint);
    canvas.drawLine(Offset(0, size.height * 0.3),
        Offset(size.width * 0.4, size.height), accentPaint);
  }

  @override
  bool shouldRepaint(_SpacePainter old) =>
      old.nebula != nebula || old.star != star;
}

// ── Glass card container ──
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const GlassCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: padding ?? const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 40,
                  offset: const Offset(0, 20))
            ]),
        child: child);
  }
}

// ── Error banner ──
Widget buildErrorBanner(String msg) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
      const SizedBox(width: 10),
      Expanded(
          child: Text(msg,
              style: AppTextStyles.body.copyWith(color: AppColors.error))),
    ]));

// ── Or divider ──
Widget buildDivider() => const Row(children: [
      Expanded(child: Divider(color: AppColors.divider)),
      Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text('OR', style: AppTextStyles.label)),
      Expanded(child: Divider(color: AppColors.divider)),
    ]);

// ── Page transition ──
PageRouteBuilder fadeSlideRoute(Widget screen) => PageRouteBuilder(
    pageBuilder: (_, a, __) => screen,
    transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
                    .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child)),
    transitionDuration: const Duration(milliseconds: 350));

// ── Success snackbar (Replaced with Cupertino Dialog helper) ──
void showCupertinoSuccess(BuildContext context, String msg) {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.check_mark_circled_solid, color: AppColors.success),
          SizedBox(width: 8),
          Text('Success'),
        ],
      ),
      content: Text(msg),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          child: const Text('OK'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}
