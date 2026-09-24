import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/app_theme.dart';
import '../services/dictionary_service.dart';
import 'interactive_image_viewer_screen.dart';
import 'category_items_screen.dart';
import 'model_viewer_screen.dart';

class MedicalImagesGalleryScreen extends StatefulWidget {
  const MedicalImagesGalleryScreen({super.key});

  @override
  State<MedicalImagesGalleryScreen> createState() =>
      _MedicalImagesGalleryScreenState();
}

class _MedicalImagesGalleryScreenState extends State<MedicalImagesGalleryScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];
  int _selectedTab = 0; // 0 = All
  late TabController _tabController;

  // All images flat list for "All" tab
  List<GalleryImage> _allImages = [];

  // Category-specific images
  List<String> _tabNames = ['All'];
  Map<String, List<GalleryImage>> _categoryImages = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadGallery();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGallery() async {
    setState(() => _isLoading = true);
    try {
      final data = await DictionaryService.getImageGallery();
      final cats = (data['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final Map<String, List<GalleryImage>> catImages = {};
      final List<GalleryImage> allImgs = [];

      for (final cat in cats) {
        final name = cat['name'] as String? ?? 'Other';
        final rawImgs = (cat['images'] as List?)
                ?.map((m) =>
                    GalleryImage.fromMap(Map<String, dynamic>.from(m as Map)))
                .toList() ??
            [];
        if (rawImgs.isNotEmpty) {
          catImages[name] = rawImgs;
          allImgs.addAll(rawImgs);
        }
      }

      final tabNames = ['All', ...catImages.keys.toList()];
      final tabCount = tabNames.length;

      if (mounted) {
        _tabController.dispose();
        _tabController = TabController(length: tabCount, vsync: this);
        setState(() {
          _categories = cats;
          _categoryImages = catImages;
          _allImages = allImgs;
          _tabNames = tabNames;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('Error loading gallery: $e\n$stackTrace');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<GalleryImage> get _currentImages {
    if (_selectedTab == 0) return _allImages;
    final name = _tabNames[_selectedTab];
    return _categoryImages[name] ?? [];
  }

  void _openViewer(List<GalleryImage> images, int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => InteractiveImageViewerScreen(
          images: images,
          initialIndex: index,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
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
      'Syndromes': Color(0xFFF43F5E),
      'Body Systems': Color(0xFF0EA5E9),
      'Clinical Concepts': Color(0xFF6B7280),
    };
    return map[cat] ?? const Color(0xFF2563EB);
  }

  IconData _categoryIcon(String cat) {
    const map = {
      'Anatomy': CupertinoIcons.person_fill,
      'Diseases': CupertinoIcons.bandage_fill,
      'Histology': CupertinoIcons.eye_solid,
      'Drugs': CupertinoIcons.lab_flask_solid,
      'Physiology': CupertinoIcons.heart_fill,
      'Biochemistry': CupertinoIcons.waveform_path,
      'Pharmacology': CupertinoIcons.thermometer,
      'Procedures': CupertinoIcons.scissors,
      'Medical Images': CupertinoIcons.photo_fill,
      'Lab Values': CupertinoIcons.doc_plaintext,
      'Syndromes': CupertinoIcons.exclamationmark_triangle,
      'Body Systems': CupertinoIcons.circle_grid_hex_fill,
      'Clinical Concepts': CupertinoIcons.info_circle_fill,
    };
    return map[cat] ?? CupertinoIcons.photo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const SpaceBackground(),
          SafeArea(
            child: Column(
              children: [
                // ── Header ───────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.back,
                            color: AppColors.textWhite),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Medical Images',
                              style: TextStyle(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                fontFamily: 'Georgia',
                              ),
                            ),
                            Text(
                              _isLoading
                                  ? 'Loading gallery...'
                                  : '${_allImages.length} images across ${_categoryImages.length} subjects',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // 3D Model Button
                      IconButton(
                        icon: const Icon(CupertinoIcons.cube_box,
                            color: AppColors.cyan, size: 22),
                        tooltip: 'View 3D Model',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ModelViewerScreen(),
                            ),
                          );
                        },
                      ),
                      // Refresh
                      IconButton(
                        icon: const Icon(CupertinoIcons.refresh,
                            color: AppColors.textMuted, size: 20),
                        onPressed: _loadGallery,
                      ),
                    ],
                  ),
                ),

                // ── Tab bar ──────────────────────────────────────────────────
                if (!_isLoading && _tabNames.length > 1) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _tabNames.length,
                      itemBuilder: (_, i) {
                        final name = _tabNames[i];
                        final isSelected = _selectedTab == i;
                        final color =
                            i == 0 ? AppColors.violet : _categoryColor(name);
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTab = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withOpacity(0.18)
                                  : Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? color
                                    : Colors.white.withOpacity(0.15),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (i > 0) ...[
                                  Icon(_categoryIcon(name),
                                      size: 12,
                                      color:
                                          isSelected ? color : Colors.white38),
                                  const SizedBox(width: 5),
                                ] else ...[
                                  Icon(CupertinoIcons.square_grid_2x2_fill,
                                      size: 12,
                                      color:
                                          isSelected ? color : Colors.white38),
                                  const SizedBox(width: 5),
                                ],
                                Text(
                                  i == 0 ? 'All' : name,
                                  style: TextStyle(
                                    color: isSelected ? color : Colors.white60,
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (!_isLoading) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? color.withOpacity(0.25)
                                          : Colors.white10,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      i == 0
                                          ? '${_allImages.length}'
                                          : '${_categoryImages[name]?.length ?? 0}',
                                      style: TextStyle(
                                        color:
                                            isSelected ? color : Colors.white38,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // ── 3D Model Featured Banner ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ModelViewerScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.cyan.withOpacity(0.2),
                            AppColors.violet.withOpacity(0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cyan.withOpacity(0.5), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.cube_box_fill,
                              color: AppColors.cyan,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '3D Interactive Anatomical Model',
                                  style: TextStyle(
                                    color: AppColors.textWhite,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Explore complete body 3D skeleton (completebody.glb)',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            CupertinoIcons.chevron_right,
                            color: AppColors.textWhite,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Body ─────────────────────────────────────────────────────
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _allImages.isEmpty
                          ? _buildEmptyState()
                          : _buildGalleryGrid(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(radius: 14),
          const SizedBox(height: 16),
          Text(
            'Loading medical image gallery...',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cyan.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.photo_fill,
                size: 48, color: AppColors.cyan),
          ),
          const SizedBox(height: 20),
          const Text(
            'No images in library yet',
            style: TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Search for topics in any category to fetch medical images.\n'
            'Images will appear here grouped by subject.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),
          // Quick fetch chips for popular subjects
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              'Anatomy',
              'Diseases',
              'Histology',
              'Pharmacology',
              'Procedures'
            ]
                .map((cat) => GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        fadeSlideRoute(CategoryItemsScreen(category: cat)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _categoryColor(cat).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: _categoryColor(cat).withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_categoryIcon(cat),
                                size: 13, color: _categoryColor(cat)),
                            const SizedBox(width: 6),
                            Text(cat,
                                style: TextStyle(
                                    color: _categoryColor(cat),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid() {
    final images = _currentImages;
    final selectedName = _selectedTab == 0 ? 'All' : _tabNames[_selectedTab];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Category header (when not "All") ──────────────────────────────
        if (_selectedTab > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _categoryColor(selectedName).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_categoryIcon(selectedName),
                        size: 18, color: _categoryColor(selectedName)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(selectedName,
                            style: const TextStyle(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text('${images.length} images',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Masonry-style image grid ───────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, idx) => _buildImageCard(images, idx),
              childCount: images.length,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildImageCard(List<GalleryImage> images, int idx) {
    final img = images[idx];
    final color = _categoryColor(img.topicCategory);

    return GestureDetector(
      onTap: () => _openViewer(images, idx),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      img.thumbnailUrl.isNotEmpty ? img.thumbnailUrl : img.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF0F172A),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.photo,
                                color: color.withOpacity(0.4), size: 32),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                img.caption,
                                style: TextStyle(
                                    color: color.withOpacity(0.6),
                                    fontSize: 10),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: const Color(0xFF0F172A),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                              color: color,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                    ),
                    // Tap hint overlay
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(CupertinoIcons.fullscreen,
                            color: Colors.white70, size: 12),
                      ),
                    ),
                    // Category badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          img.topicCategory,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Caption
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                img.topicTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Text(
                img.caption,
                style: TextStyle(color: Colors.white38, fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
