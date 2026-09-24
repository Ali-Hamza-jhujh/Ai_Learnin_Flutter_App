import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// A gallery image model passed into the viewer
class GalleryImage {
  final String url;
  final String thumbnailUrl;
  final String caption;
  final String topicTitle;
  final String topicCategory;
  final String creator;
  final String license;
  final String source;

  const GalleryImage({
    required this.url,
    required this.thumbnailUrl,
    required this.caption,
    required this.topicTitle,
    required this.topicCategory,
    this.creator = '',
    this.license = '',
    this.source = '',
  });

  factory GalleryImage.fromMap(Map<String, dynamic> m) => GalleryImage(
        url: m['url'] ?? '',
        thumbnailUrl: m['thumbnailUrl'] ?? m['url'] ?? '',
        caption: m['caption'] ?? 'Medical illustration',
        topicTitle: m['topicTitle'] ?? '',
        topicCategory: m['topicCategory'] ?? '',
        creator: m['creator'] ?? '',
        license: m['license'] ?? '',
        source: m['source'] ?? '',
      );
}

class InteractiveImageViewerScreen extends StatefulWidget {
  final List<GalleryImage> images;
  final int initialIndex;

  const InteractiveImageViewerScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<InteractiveImageViewerScreen> createState() =>
      _InteractiveImageViewerScreenState();
}

class _InteractiveImageViewerScreenState
    extends State<InteractiveImageViewerScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;

  // Per-page transform state
  final Map<int, _ImageTransform> _transforms = {};
  _ImageTransform get _current =>
      _transforms[_currentIndex] ??= _ImageTransform();

  // Rotation tracking
  double _startRotation = 0;

  // Tap highlight
  Offset? _tapPosition;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Caption glow
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  // Info panel
  bool _showInfo = false;
  bool _showOverlay = true; // top/bottom overlay visibility
  bool _isDoubleTapZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _pulseAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _glowAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _onTap(TapDownDetails details) {
    final pos = details.localPosition;
    setState(() => _tapPosition = pos);
    _pulseCtrl.forward(from: 0);
    _glowCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _tapPosition = null);
    });
  }

  void _onDoubleTap() {
    final t = _current;
    if (_isDoubleTapZoomed) {
      t.scale = 1.0;
      t.offset = Offset.zero;
    } else {
      t.scale = 2.5;
    }
    setState(() => _isDoubleTapZoomed = !_isDoubleTapZoomed);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _startRotation = _current.rotation;
    _current.prevScale = _current.scale;
    _current.prevOffset = _current.offset;
    _current.focalPoint = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      final t = _current;
      // Scale (pinch zoom)
      t.scale = (t.prevScale * d.scale).clamp(0.5, 8.0);
      // Rotation (2-finger)
      if (d.pointerCount >= 2) {
        t.rotation = _startRotation + d.rotation;
      }
      // Pan
      final delta = d.localFocalPoint - t.focalPoint;
      t.offset = t.prevOffset + delta;
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {}

  void _resetTransform() {
    setState(() {
      _transforms[_currentIndex] = _ImageTransform();
      _isDoubleTapZoomed = false;
    });
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
  }

  Color _categoryColor(String cat) {
    const map = {
      'Anatomy': Color(0xFF10B981),
      'Diseases': Color(0xFFEF4444),
      'Histology': Color(0xFFEC4899),
      'Drugs': Color(0xFF3B82F6),
      'Physiology': Color(0xFFF59E0B),
      'Biochemistry': Color(0xFF8B5CF6),
      'Pharmacology': Color(0xFF06B6D4),
      'Procedures': Color(0xFFF97316),
      'Medical Images': Color(0xFF84CC16),
      'Lab Values': Color(0xFF14B8A6),
    };
    return map[cat] ?? const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.images[_currentIndex];
    final catColor = _categoryColor(img.topicCategory);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Page View of images ──────────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() {
              _currentIndex = i;
              _isDoubleTapZoomed = false;
            }),
            itemBuilder: (ctx, pageIdx) {
              final pageImg = widget.images[pageIdx];
              final t = _transforms[pageIdx] ??= _ImageTransform();
              return GestureDetector(
                onTap: _toggleOverlay,
                onDoubleTap: _onDoubleTap,
                onTapDown: _onTap,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    children: [
                      // Transformed image
                      Center(
                        child: Transform(
                          transform: Matrix4.identity()
                            ..translate(t.offset.dx, t.offset.dy, 0.0)
                            ..rotateZ(t.rotation)
                            ..scale(t.scale, t.scale, 1.0),
                          alignment: Alignment.center,
                          child: Image.network(
                            pageImg.url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(CupertinoIcons.photo,
                                    color: Colors.white38, size: 64),
                                const SizedBox(height: 12),
                                Text(pageImg.caption,
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 13),
                                    textAlign: TextAlign.center),
                              ],
                            ),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                          : null,
                                      color: catColor,
                                      strokeWidth: 2,
                                    ),
                                    const SizedBox(height: 12),
                                    Text('Loading image...',
                                        style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Tap highlight pulse ring
                      if (_tapPosition != null && pageIdx == _currentIndex)
                        Positioned(
                          left: _tapPosition!.dx - 40,
                          top: _tapPosition!.dy - 40,
                          child: AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, __) {
                              final v = _pulseAnim.value;
                              return Opacity(
                                opacity: (1 - v).clamp(0.0, 1.0),
                                child: Container(
                                  width: 80 + 60 * v,
                                  height: 80 + 60 * v,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: catColor.withOpacity(0.9),
                                        width: 3 - v * 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            catColor.withOpacity(0.6 - v * 0.4),
                                        blurRadius: 20 + 30 * v,
                                        spreadRadius: 4 + 10 * v,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Top overlay: back + title + controls ─────────────────────────
          AnimatedOpacity(
            opacity: _showOverlay ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_showOverlay,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
                        child: Row(
                          children: [
                            // Back button
                            IconButton(
                              icon: const Icon(CupertinoIcons.back,
                                  color: Colors.white, size: 24),
                              onPressed: () => Navigator.pop(context),
                            ),
                            // Title + category
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedBuilder(
                                    animation: _glowAnim,
                                    builder: (_, child) {
                                      return Text(
                                        img.topicTitle,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          shadows: [
                                            Shadow(
                                              color: catColor.withOpacity(
                                                  _glowAnim.value * 0.9),
                                              blurRadius: 12 * _glowAnim.value,
                                            ),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: catColor.withOpacity(0.3),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color: catColor.withOpacity(0.6)),
                                        ),
                                        child: Text(
                                          img.topicCategory,
                                          style: TextStyle(
                                              color: catColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${_currentIndex + 1} / ${widget.images.length}',
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Reset button
                            IconButton(
                              tooltip: 'Reset zoom & rotation',
                              icon: const Icon(
                                  CupertinoIcons.arrow_counterclockwise,
                                  color: Colors.white70,
                                  size: 20),
                              onPressed: _resetTransform,
                            ),
                            // Info button
                            IconButton(
                              tooltip: 'Image info',
                              icon: Icon(
                                _showInfo
                                    ? CupertinoIcons.info_circle_fill
                                    : CupertinoIcons.info_circle,
                                color: _showInfo ? catColor : Colors.white70,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _showInfo = !_showInfo),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),

          // ── Bottom overlay: caption + navigation dots ─────────────────────
          AnimatedOpacity(
            opacity: _showOverlay ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_showOverlay,
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Navigation dots
                            if (widget.images.length > 1)
                              Center(
                                child: Wrap(
                                  spacing: 6,
                                  children: List.generate(
                                    math.min(widget.images.length, 12),
                                    (i) => GestureDetector(
                                      onTap: () {
                                        _pageController.animateToPage(i,
                                            duration: const Duration(
                                                milliseconds: 300),
                                            curve: Curves.easeInOut);
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 250),
                                        width: i == _currentIndex ? 20 : 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: i == _currentIndex
                                              ? catColor
                                              : Colors.white30,
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            // Caption with glow
                            AnimatedBuilder(
                              animation: _glowAnim,
                              builder: (_, __) {
                                return Text(
                                  img.caption,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.4,
                                    shadows: [
                                      Shadow(
                                        color: catColor
                                            .withOpacity(_glowAnim.value * 0.7),
                                        blurRadius: 8 * _glowAnim.value,
                                      ),
                                    ],
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            // Hint
                            Row(
                              children: [
                                Icon(CupertinoIcons.hand_draw,
                                    color: Colors.white30, size: 11),
                                const SizedBox(width: 4),
                                const Text(
                                  'Tap image to highlight • Pinch to zoom • 2-finger rotate',
                                  style: TextStyle(
                                      color: Colors.white30, fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Info panel (slide-up) ──────────────────────────────────────────
          if (_showInfo && _showOverlay)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827).withOpacity(0.97),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: catColor.withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                          color: catColor.withOpacity(0.2),
                          blurRadius: 24,
                          spreadRadius: 2),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(CupertinoIcons.photo_fill,
                              color: catColor, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Image Information',
                            style: TextStyle(
                                color: catColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _showInfo = false),
                            child: const Icon(CupertinoIcons.xmark_circle,
                                color: Colors.white38, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _infoRow('Topic', img.topicTitle, catColor),
                      _infoRow('Category', img.topicCategory, catColor),
                      _infoRow('Caption', img.caption, catColor),
                      if (img.creator.isNotEmpty)
                        _infoRow('Creator', img.creator, catColor),
                      if (img.license.isNotEmpty)
                        _infoRow('License', img.license, catColor),
                      if (img.source.isNotEmpty)
                        _infoRow('Source', img.source, catColor),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.hand_draw,
                                color: Colors.white38, size: 14),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tap anywhere on the image to highlight parts with a glow ring. '
                                'Pinch to zoom in on labeled areas. Two fingers rotate.',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Prev / Next arrow overlays ────────────────────────────────────
          if (widget.images.length > 1 && _showOverlay) ...[
            if (_currentIndex > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.chevron_left,
                          color: Colors.white70, size: 20),
                    ),
                  ),
                ),
              ),
            if (_currentIndex < widget.images.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.chevron_right,
                          color: Colors.white70, size: 20),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color accent) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                  color: accent.withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mutable per-page transform state
class _ImageTransform {
  double scale = 1.0;
  double prevScale = 1.0;
  double rotation = 0.0;
  Offset offset = Offset.zero;
  Offset prevOffset = Offset.zero;
  Offset focalPoint = Offset.zero;
}
