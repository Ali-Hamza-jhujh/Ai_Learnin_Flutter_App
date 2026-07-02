import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class LumioShimmer extends StatefulWidget {
  final double height;
  final double width;
  final BorderRadius borderRadius;

  const LumioShimmer({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<LumioShimmer> createState() => _LumioShimmerState();
}

class _LumioShimmerState extends State<LumioShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1 + _controller.value * 2, 0),
              end: Alignment(1 + _controller.value * 2, 0),
              colors: const [
                AppColors.bgCard,
                AppColors.bgSurface,
                AppColors.bgCard,
              ],
            ),
          ),
        );
      },
    );
  }
}
