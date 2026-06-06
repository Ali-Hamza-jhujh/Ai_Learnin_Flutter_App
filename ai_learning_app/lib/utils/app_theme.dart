import 'package:flutter/material.dart';
import 'dart:math' as math;

class AppColors {
  static const Color bg = Color(0xFF050818);
  static const Color bgCard = Color(0xFF0D1225);
  static const Color bgSurface = Color(0xFF111827);
  static const Color violet = Color(0xFF7B61FF);
  static const Color violetGlow = Color(0x447B61FF);
  static const Color violetLight = Color(0xFF9B7FFF);
  static const Color cyan = Color(0xFF00D4FF);
  static const Color cyanGlow = Color(0x3300D4FF);
  static const Color gold = Color(0xFFFFB547);
  static const Color textWhite = Color(0xFFEEF2FF);
  static const Color textSub = Color(0xFF8892B0);
  static const Color textMuted = Color(0xFF4A5568);
  static const Color success = Color(0xFF34EEB6);
  static const Color error = Color(0xFFFF5C8D);
  static const Color textLight = Color(0xFFCCD6F6);
  static const Color inputBg = Color(0xFF0F1629);
  static const Color inputBorder = Color(0xFF1E2A4A);
  static const Color divider = Color(0xFF1A2340);

  static const LinearGradient primaryGrad = LinearGradient(
      colors: [Color(0xFF7B61FF), Color(0xFF00D4FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);

  static const LinearGradient bgGrad = LinearGradient(
      colors: [Color(0xFF050818), Color(0xFF0A0F2E), Color(0xFF050818)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);

  static const LinearGradient goldGrad = LinearGradient(
      colors: [Color(0xFFFFB547), Color(0xFFFF6B9D)],
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
                      color: AppColors.violet.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8))
                ]),
            child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
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
                        ? AppColors.violet.withOpacity(0.5)
                        : AppColors.inputBorder,
                    width: 1.5)),
            child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: AppColors.textSub, strokeWidth: 2.5))
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
          child: TextFormField(
            controller: widget.controller,
            obscureText: widget.isPassword && _obscure,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onEditingComplete: widget.onEditingComplete,
            validator: widget.validator,
            style: const TextStyle(color: AppColors.textWhite, fontSize: 15),
            decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle:
                    const TextStyle(color: AppColors.textMuted, fontSize: 14),
                filled: true,
                fillColor: AppColors.inputBg,
                prefixIcon: Icon(widget.prefixIcon,
                    color: _focused ? AppColors.violet : AppColors.textMuted,
                    size: 20),
                suffixIcon: widget.isPassword
                    ? IconButton(
                        icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textMuted,
                            size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure))
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.inputBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                        color: AppColors.inputBorder, width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: AppColors.violet, width: 2)),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: AppColors.error, width: 1.5)),
                focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: AppColors.error, width: 2)),
                errorStyle:
                    const TextStyle(color: AppColors.error, fontSize: 12),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 18)),
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
              colors: [Color(0xFF050818), Color(0xFF0A0F2E), Color(0xFF06091A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Nebula glow top-right
    final nebulaPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);
    nebulaPaint.color = Color.fromRGBO(123, 97, 255, 0.08 + nebula * 0.06);
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.12), 200, nebulaPaint);

    // Nebula glow bottom-left
    nebulaPaint.color = Color.fromRGBO(0, 212, 255, 0.06 + (1 - nebula) * 0.05);
    canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.8), 160, nebulaPaint);

    // Stars
    final rand = math.Random(42);
    for (int i = 0; i < 60; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final r = rand.nextDouble() * 1.5 + 0.5;
      final phase = rand.nextDouble() * math.pi * 2;
      final opacity = 0.2 + math.sin(star * math.pi * 2 + phase).abs() * 0.5;
      canvas.drawCircle(Offset(x, y), r,
          Paint()..color = Color.fromRGBO(238, 242, 255, opacity));
    }

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0x08FFFFFF)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 80)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    for (double y = 0; y < size.height; y += 80)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

    // Diagonal accent line
    final accentPaint = Paint()
      ..color = AppColors.violet.withOpacity(0.06)
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
                  color: Colors.black.withOpacity(0.3),
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
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withOpacity(0.3))),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
      const SizedBox(width: 10),
      Expanded(
          child: Text(msg,
              style: AppTextStyles.body.copyWith(color: AppColors.error))),
    ]));

// ── Or divider ──
Widget buildDivider() => Row(children: [
      Expanded(child: Divider(color: AppColors.divider)),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
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

// ── Success snackbar ──
SnackBar successSnackBar(String msg) => SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle_rounded, color: AppColors.success),
      const SizedBox(width: 10),
      Text(msg, style: AppTextStyles.body.copyWith(color: Colors.white)),
    ]),
    backgroundColor: AppColors.bgCard,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    margin: const EdgeInsets.all(16));
class StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.violet.withOpacity(0.07);
 
    // Large soft orbs
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.15), 180, paint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.75), 140, paint);
 
    // Small dots
    final dotPaint = Paint()..color = AppColors.violetLight.withOpacity(0.2);
    final positions = [
      Offset(size.width * 0.2, size.height * 0.1),
      Offset(size.width * 0.75, size.height * 0.35),
      Offset(size.width * 0.5, size.height * 0.85),
      Offset(size.width * 0.9, size.height * 0.6),
      Offset(size.width * 0.15, size.height * 0.5),
    ];
    for (final pos in positions) {
      canvas.drawCircle(pos, 3, dotPaint);
    }
 
    // Grid lines (subtle)
    final linePaint = Paint()
      ..color = AppColors.violet.withOpacity(0.04)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }
 
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
 