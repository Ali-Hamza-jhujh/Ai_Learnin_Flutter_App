import "dart:async";
import "package:flutter/material.dart";
import "package:flutter/cupertino.dart";
import "../utils/app_theme.dart";
import "../models/dictionary_model.dart";
import "../services/dictionary_service.dart";
import "dictionary_detail_screen.dart";
import "category_items_screen.dart";
import "medical_images_gallery_screen.dart";
import "human_anatomy_explorer_screen.dart";

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;
  bool _isLoadingStats = true;
  bool _isLoadingCategories = true;
  Timer? _debounceTimer;

  List<DictionaryItem> _trending = [];
  List<DictionaryItem> _popular = [];
  List<DictionaryItem> _recent = [];
  List<DictionaryItem> _bookmarks = [];
  List<Map<String, dynamic>> _categories = [];

  // ── local icon + color map for visual richness ───────────────────────────
  static const Map<String, Map<String, dynamic>> _catMeta = {
    "Diseases": {
      "icon": CupertinoIcons.bandage_fill,
      "color": Color(0xFFEF4444)
    },
    "Drugs": {
      "icon": CupertinoIcons.lab_flask_solid,
      "color": Color(0xFF3B82F6)
    },
    "Anatomy": {"icon": CupertinoIcons.person_fill, "color": Color(0xFF10B981)},
    "Physiology": {
      "icon": CupertinoIcons.heart_fill,
      "color": Color(0xFFF59E0B)
    },
    "Biochemistry": {
      "icon": CupertinoIcons.waveform_path,
      "color": Color(0xFF8B5CF6)
    },
    "Histology": {"icon": CupertinoIcons.eye_solid, "color": Color(0xFFEC4899)},
    "Pharmacology": {
      "icon": CupertinoIcons.thermometer,
      "color": Color(0xFF06B6D4)
    },
    "Lab Values": {
      "icon": CupertinoIcons.doc_plaintext,
      "color": Color(0xFF14B8A6)
    },
    "Clinical Concepts": {
      "icon": CupertinoIcons.info_circle_fill,
      "color": Color(0xFF6B7280)
    },
    "Procedures": {"icon": CupertinoIcons.scissors, "color": Color(0xFFF97316)},
    "Research Papers": {
      "icon": CupertinoIcons.book_fill,
      "color": Color(0xFF6366F1)
    },
    "Medical Images": {
      "icon": CupertinoIcons.photo_fill,
      "color": Color(0xFF84CC16)
    },
    "Syndromes": {
      "icon": CupertinoIcons.exclamationmark_triangle,
      "color": Color(0xFFF43F5E)
    },
    "Body Systems": {
      "icon": CupertinoIcons.circle_grid_hex_fill,
      "color": Color(0xFF0EA5E9)
    },
    "Medical Terminologies": {
      "icon": CupertinoIcons.textformat_abc,
      "color": Color(0xFF7C3AED)
    },
    "Medical Classifications": {
      "icon": CupertinoIcons.list_number,
      "color": Color(0xFF059669)
    },
  };

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadStatsAndBookmarks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final cats = await DictionaryService.getMedicalCategories();
      if (mounted) {
        setState(() {
          if (cats.isNotEmpty) {
            _categories = cats;
          } else {
            _categories = _catMeta.keys
                .map((name) => {"name": name, "count": 0, "topItems": []})
                .toList();
          }
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      // Fallback: use static list from _catMeta keys
      if (mounted) {
        setState(() {
          _categories = _catMeta.keys
              .map((name) => {"name": name, "count": 0, "topItems": []})
              .toList();
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _loadStatsAndBookmarks() async {
    setState(() => _isLoadingStats = true);
    try {
      final stats = await DictionaryService.getStats();
      final bookmarks = await DictionaryService.getBookmarks();
      if (mounted) {
        setState(() {
          _trending = stats["trending"] ?? [];
          _popular = stats["popular"] ?? [];
          _recent = stats["recentlyAdded"] ?? [];
          _bookmarks = bookmarks;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final suggestions = await DictionaryService.getAutocomplete(query);
      if (mounted) setState(() => _suggestions = suggestions);
    });
  }

  Future<void> _submitSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();
    try {
      final result = await DictionaryService.search(query);
      final DictionaryItem item = result["item"];
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchController.clear();
          _suggestions = [];
        });
        Navigator.push(
            context, fadeSlideRoute(DictionaryDetailScreen(item: item)));
        _loadStatsAndBookmarks();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text("Search Error"),
            content: Text(
                "Could not find '$query' in local database. Try the category search for live API results."),
            actions: [
              CupertinoDialogAction(
                  child: const Text("OK"),
                  onPressed: () => Navigator.pop(context))
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const SpaceBackground(),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Header ──────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(CupertinoIcons.back,
                                  color: AppColors.textWhite),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Text("Knowledge Hub",
                                style: AppTextStyles.label),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text("Medical Dictionary",
                            style:
                                AppTextStyles.display.copyWith(fontSize: 30)),
                        const SizedBox(height: 4),
                        Text(
                          "Self-growing medical intelligence — live APIs + local DB",
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textLight),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Search Bar ───────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          children: [
                            CupertinoSearchTextField(
                              controller: _searchController,
                              placeholder: "Search diseases, drugs, anatomy...",
                              placeholderStyle:
                                  const TextStyle(color: AppColors.textMuted),
                              style:
                                  const TextStyle(color: AppColors.textWhite),
                              backgroundColor: AppColors.bgCard,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              borderRadius: BorderRadius.circular(16),
                              onChanged: _onSearchChanged,
                              onSubmitted: _submitSearch,
                            ),
                            if (_isSearching)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CupertinoActivityIndicator(radius: 12),
                              ),
                          ],
                        ),
                        if (_suggestions.isNotEmpty)
                          Positioned(
                            top: 50,
                            left: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  )
                                ],
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount: _suggestions.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(
                                        height: 1, color: AppColors.divider),
                                itemBuilder: (context, index) {
                                  final sug = _suggestions[index];
                                  return ListTile(
                                    title: Text(sug["title"] ?? "",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textWhite)),
                                    subtitle: Text(sug["category"] ?? "",
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textLight)),
                                    trailing: const Icon(
                                        CupertinoIcons.arrow_up_left,
                                        size: 16,
                                        color: AppColors.textMuted),
                                    onTap: () {
                                      _searchController.text = sug["title"];
                                      _submitSearch(sug["title"]);
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Section Title ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.square_grid_2x2_fill,
                            color: AppColors.cyan, size: 16),
                        const SizedBox(width: 8),
                        Text("Browse Categories",
                            style:
                                AppTextStyles.heading.copyWith(fontSize: 18)),
                        const Spacer(),
                        if (!_isLoadingCategories)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "${_categories.length} categories",
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.cyan,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Interactive 3D Anatomy Explorer Card ──────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context,
                            fadeSlideRoute(const HumanAnatomyExplorerScreen()));
                      },
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [AppColors.cyan, AppColors.violet],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.cyan.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -20,
                              bottom: -20,
                              child: Icon(
                                CupertinoIcons.person_crop_circle_fill,
                                size: 140,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Interactive 3D Anatomy",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Explore the full human body, tap to learn",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
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
                ),

                // ── Category Grid ─────────────────────────────────────────────
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: _isLoadingCategories
                      ? SliverToBoxAdapter(
                          child: SizedBox(
                            height: 200,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.95,
                              ),
                              itemCount: 6,
                              itemBuilder: (_, __) =>
                                  _buildCategorySkeletonCard(),
                            ),
                          ),
                        )
                      : SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.95,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final cat = _categories[index];
                              final name = cat["name"] as String? ?? "Unknown";
                              final count = cat["count"] as int? ?? 0;
                              final meta = _catMeta[name] ??
                                  {
                                    "icon": CupertinoIcons.circle,
                                    "color": AppColors.violet,
                                  };
                              return _buildCategoryCard(name, count, meta);
                            },
                            childCount: _categories.length,
                          ),
                        ),
                ),

                // ── Stats & Bookmarks ─────────────────────────────────────────
                if (_isLoadingStats)
                  const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CupertinoActivityIndicator(radius: 12),
                      ),
                    ),
                  )
                else ...[
                  if (_bookmarks.isNotEmpty)
                    SliverToBoxAdapter(
                        child: _buildSection("📚 My Bookmarks", _bookmarks)),
                  if (_trending.isNotEmpty)
                    SliverToBoxAdapter(
                        child: _buildSection("🔥 Trending Topics", _trending)),
                  if (_popular.isNotEmpty)
                    SliverToBoxAdapter(
                        child: _buildSection("⭐ Most Searched", _popular)),
                  if (_recent.isNotEmpty)
                    SliverToBoxAdapter(
                        child: _buildSection("🆕 Recently Added", _recent)),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String name, int count, Map<String, dynamic> meta) {
    final Color color = meta["color"] as Color;
    final IconData icon = meta["icon"] as IconData;
    return GestureDetector(
      onTap: () {
        if (name == 'Medical Images') {
          Navigator.push(
              context, fadeSlideRoute(const MedicalImagesGalleryScreen()));
        } else {
          Navigator.push(
              context, fadeSlideRoute(CategoryItemsScreen(category: name)));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (count > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        count > 99 ? "99+" : "$count",
                        style: const TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySkeletonCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Center(
        child: CupertinoActivityIndicator(radius: 8),
      ),
    );
  }

  Widget _buildSection(String title, List<DictionaryItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child:
              Text(title, style: AppTextStyles.heading.copyWith(fontSize: 20)),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, right: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(context,
                      fadeSlideRoute(DictionaryDetailScreen(item: item)));
                },
                child: Container(
                  width: 220,
                  margin: const EdgeInsets.only(right: 12, bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.violet.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.category,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.violet),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textWhite,
                                fontSize: 14),
                          ),
                        ],
                      ),
                      Text(
                        "${item.viewCount} views",
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
