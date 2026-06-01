import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import '../services/api_client.dart';

// ══════════════════════════════════════════
// YOUTUBE SCREEN — 3 tabs:
// 1. Suggestions  — AI-picked based on user's subject
// 2. Search       — search any topic
// 3. Saved        — bookmarked lectures
// ══════════════════════════════════════════

class YouTubeScreen extends StatefulWidget {
  const YouTubeScreen({super.key});
  @override
  State<YouTubeScreen> createState() => _YouTubeScreenState();
}

class _YouTubeScreenState extends State<YouTubeScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted) setState(() => _selectedTab = _tabCtrl.index);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(children: [
          const SpaceBackground(),
          SafeArea(
              child: Column(children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
                child: TabBarView(controller: _tabCtrl, children: const [
              _SuggestionsTab(),
              _SearchTab(),
              _SavedTab(),
            ])),
          ])),
        ]));
  }

  Widget _buildHeader() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)])
                    .createShader(b),
                child: const Text('Lectures',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFamily: 'Georgia'))),
            const Text('AI-curated video lectures', style: AppTextStyles.sub),
          ]),
          const Spacer(),
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                  borderRadius: BorderRadius.circular(14)),
              child: const Center(
                  child: Text('🎥', style: TextStyle(fontSize: 22)))),
        ]));
  }

  Widget _buildTabBar() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.inputBorder)),
            child: Row(children: [
              _tabItem(0, '✨ For You'),
              _tabItem(1, '🔍 Search'),
              _tabItem(2, '🔖 Saved'),
            ])));
  }

  Widget _tabItem(int index, String label) {
    final active = _selectedTab == index;
    return Expanded(
        child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _tabCtrl.animateTo(index);
            },
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)])
                        : null,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: active ? Colors.white : AppColors.textSub,
                        fontSize: 12,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w400)))));
  }
}

// ══════════════════════════════════════════
// SUGGESTIONS TAB
// AI-picks based on user's registered subject
// ══════════════════════════════════════════

class _SuggestionsTab extends StatefulWidget {
  const _SuggestionsTab();
  @override
  State<_SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends State<_SuggestionsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;
  String? _error;
  String _subject = '';

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await YouTubeService.getSuggestions();
      if (mounted) {
        setState(() {
          _videos = (res['videos'] as List<dynamic>? ?? [])
              .map((e) => e as Map<String, dynamic>)
              .toList();
          _subject = res['subject'] as String? ?? '';
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          _error = e.message;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _error = 'Failed to load suggestions';
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B6B)));
    }
    if (_error != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    buildErrorBanner(_error!),
                    const SizedBox(height: 16),
                    GlowButton(
                        text: 'Retry',
                        icon: Icons.refresh_rounded,
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                        onPressed: _loadSuggestions),
                  ])));
    }
    return RefreshIndicator(
        color: const Color(0xFFFF6B6B),
        backgroundColor: AppColors.bgCard,
        onRefresh: _loadSuggestions,
        child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
            children: [
              if (_subject.isNotEmpty) ...[
                Row(children: [
                  const Text('✨', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text('Recommended for ', style: AppTextStyles.body),
                  ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)])
                          .createShader(b),
                      child: Text(_subject,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 16),
              ],
              // Featured video — large card
              if (_videos.isNotEmpty) ...[
                _VideoCard(video: _videos.first, featured: true),
                const SizedBox(height: 16),
              ],
              // Rest of videos
              ..._videos.skip(1).map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _VideoCard(video: v))),
            ]));
  }
}

// ══════════════════════════════════════════
// SEARCH TAB
// ══════════════════════════════════════════

class _SearchTab extends StatefulWidget {
  const _SearchTab();
  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _hasSearched = false;
  String? _error;

  // Quick search chips
  final List<String> _quickSearches = [
    'Machine Learning',
    'Calculus',
    'Organic Chemistry',
    'Data Structures',
    'Physics',
    'Economics',
    'Biology',
    'English Grammar',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _hasSearched = true;
    });
    try {
      final res =
          await YouTubeService.searchVideos(query.trim(), maxResults: 12);
      if (mounted) {
        setState(() {
          _results = (res['videos'] as List<dynamic>? ?? [])
              .map((e) => e as Map<String, dynamic>)
              .toList();
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          _error = e.message;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _error = 'Search failed. Try again.';
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      // Search bar
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Container(
              decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.inputBorder, width: 1.5)),
              child: Row(children: [
                const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Icon(Icons.search_rounded,
                        color: AppColors.textMuted, size: 22)),
                Expanded(
                    child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(
                            color: AppColors.textWhite, fontSize: 15),
                        decoration: const InputDecoration(
                            hintText: 'Search lectures, topics...',
                            hintStyle: TextStyle(color: AppColors.textMuted),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 16)),
                        textInputAction: TextInputAction.search,
                        onSubmitted: _search)),
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textMuted, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _results = [];
                          _hasSearched = false;
                        });
                      }),
                GestureDetector(
                    onTap: () => _search(_searchCtrl.text),
                    child: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Text('Go',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)))),
              ]))),

      Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6B6B)))
              : !_hasSearched
                  ? _buildSearchPrompt()
                  : _error != null
                      ? Center(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: buildErrorBanner(_error!)))
                      : _results.isEmpty
                          ? _buildNoResults()
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 16, 24, 100),
                              itemCount: _results.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) =>
                                  _VideoCard(video: _results[i]))),
    ]);
  }

  Widget _buildSearchPrompt() {
    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Quick Searches',
              style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _quickSearches
                  .map((q) => GestureDetector(
                      onTap: () {
                        _searchCtrl.text = q;
                        _search(q);
                      },
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                              color: AppColors.bgCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFFFF6B6B)
                                      .withOpacity(0.3))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Text('🔍', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 6),
                            Text(q,
                                style: const TextStyle(
                                    color: AppColors.textLight, fontSize: 13)),
                          ]))))
                  .toList()),
        ]));
  }

  Widget _buildNoResults() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🔍', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 16),
      Text('No results for "${_searchCtrl.text}"',
          style: const TextStyle(
              color: AppColors.textWhite,
              fontSize: 16,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('Try different keywords', style: AppTextStyles.sub),
    ]));
  }
}

// ══════════════════════════════════════════
// SAVED TAB
// ══════════════════════════════════════════

class _SavedTab extends StatefulWidget {
  const _SavedTab();
  @override
  State<_SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends State<_SavedTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _saved = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await YouTubeService.getSavedVideos();
      if (mounted) {
        setState(() {
          _saved = (res['videos'] as List<dynamic>? ?? [])
              .map((e) => e as Map<String, dynamic>)
              .toList();
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          _error = e.message;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _error = 'Failed to load saved videos';
          _loading = false;
        });
    }
  }

  Future<void> _unsave(String videoId) async {
    try {
      await YouTubeService.unsaveVideo(videoId);
      setState(() => _saved.removeWhere((v) => v['videoId'] == videoId));
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Removed from saved'),
            backgroundColor: AppColors.bgCard,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16)));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B6B)));
    }
    if (_error != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: buildErrorBanner(_error!)));
    }
    if (_saved.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color:
                                    const Color(0xFFFF6B6B).withOpacity(0.2))),
                        child: const Center(
                            child: Text('🔖', style: TextStyle(fontSize: 40)))),
                    const SizedBox(height: 20),
                    const Text('No Saved Lectures',
                        style: TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                        'Bookmark lectures while browsing\nto find them here later.',
                        style: AppTextStyles.sub,
                        textAlign: TextAlign.center),
                  ])));
    }
    return RefreshIndicator(
        color: const Color(0xFFFF6B6B),
        backgroundColor: AppColors.bgCard,
        onRefresh: _loadSaved,
        child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
            itemCount: _saved.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final v = _saved[i];
              return Dismissible(
                  key: Key(v['videoId'] as String? ?? i.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.bookmark_remove_rounded,
                          color: AppColors.error)),
                  onDismissed: (_) => _unsave(v['videoId'] as String? ?? ''),
                  child: _SavedVideoCard(
                      video: v,
                      onUnsave: () => _unsave(v['videoId'] as String? ?? '')));
            }));
  }
}

// ══════════════════════════════════════════
// VIDEO CARD — shared across all tabs
// ══════════════════════════════════════════

class _VideoCard extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool featured;
  const _VideoCard({required this.video, this.featured = false});
  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  bool _isSaved = false;
  bool _savingLoading = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    try {
      final saved = await YouTubeService.isVideoSaved(
          widget.video['videoId'] as String? ?? '');
      if (mounted) setState(() => _isSaved = saved);
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    if (_savingLoading) return;
    HapticFeedback.lightImpact();
    setState(() => _savingLoading = true);
    try {
      if (_isSaved) {
        await YouTubeService.unsaveVideo(
            widget.video['videoId'] as String? ?? '');
        if (mounted) {
          setState(() => _isSaved = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Removed from saved'),
              backgroundColor: AppColors.bgCard,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16)));
        }
      } else {
        await YouTubeService.saveVideo(
          videoId: widget.video['videoId'] as String? ?? '',
          title: widget.video['title'] as String? ?? '',
          channelName: widget.video['channelName'] as String?,
          thumbnail: widget.video['thumbnail']?['medium'] as String?,
          url: widget.video['url'] as String?,
          duration: widget.video['duration'] as String?,
          views: widget.video['views'] as String?,
        );
        if (mounted) {
          setState(() => _isSaved = true);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Row(children: [
                Icon(Icons.bookmark_added_rounded, color: Color(0xFFFF6B6B)),
                SizedBox(width: 8),
                Text('Saved to your lectures'),
              ]),
              backgroundColor: AppColors.bgCard,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16)));
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _savingLoading = false);
    }
  }

  Future<void> _openVideo() async {
    final url = widget.video['url'] as String? ?? '';
    if (url.isEmpty) return;
    HapticFeedback.lightImpact();
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Could not open video'),
            backgroundColor: AppColors.error.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video['title'] as String? ?? '';
    final channel = widget.video['channelName'] as String? ?? '';
    final duration = widget.video['duration'] as String? ?? '';
    final views = widget.video['views'] as String? ?? '';
    final thumbnail = widget.video['thumbnail']?['medium'] as String? ?? '';

    if (widget.featured)
      return _buildFeaturedCard(title, channel, duration, views, thumbnail);
    return _buildRegularCard(title, channel, duration, views, thumbnail);
  }

  Widget _buildFeaturedCard(String title, String channel, String duration,
      String views, String thumbnail) {
    return GestureDetector(
        onTap: _openVideo,
        child: Container(
            decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFFF6B6B).withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 6))
                ]),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Thumbnail
              Stack(children: [
                ClipRRect(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20)),
                    child: thumbnail.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: thumbnail,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                                height: 180,
                                color: AppColors.inputBg,
                                child: const Center(
                                    child: CircularProgressIndicator(
                                        color: Color(0xFFFF6B6B),
                                        strokeWidth: 2))),
                            errorWidget: (_, __, ___) => Container(
                                height: 180,
                                color: AppColors.inputBg,
                                child: const Center(
                                    child: Icon(
                                        Icons.play_circle_outline_rounded,
                                        color: AppColors.textMuted,
                                        size: 48))))
                        : Container(
                            height: 180,
                            color: AppColors.inputBg,
                            child: const Center(
                                child: Icon(Icons.play_circle_outline_rounded,
                                    color: AppColors.textMuted, size: 48)))),
                // Play button overlay
                Positioned.fill(
                    child: Center(
                        child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  Color(0xFFFF6B6B),
                                  Color(0xFFFF8E53)
                                ]),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFFFF6B6B)
                                          .withOpacity(0.5),
                                      blurRadius: 16)
                                ]),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 32)))),
                // Duration badge
                if (duration.isNotEmpty)
                  Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(duration,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)))),
                // Featured badge
                Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('⭐ Featured',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)))),
              ]),
              // Info
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: AppColors.textWhite,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.account_circle_outlined,
                              color: AppColors.textMuted, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(channel,
                                  style:
                                      AppTextStyles.body.copyWith(fontSize: 12),
                                  overflow: TextOverflow.ellipsis)),
                          if (views.isNotEmpty) ...[
                            const Icon(Icons.visibility_outlined,
                                color: AppColors.textMuted, size: 12),
                            const SizedBox(width: 4),
                            Text(views,
                                style:
                                    AppTextStyles.label.copyWith(fontSize: 11)),
                          ],
                          const SizedBox(width: 12),
                          GestureDetector(
                              onTap: _toggleSave,
                              child: _savingLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Color(0xFFFF6B6B),
                                          strokeWidth: 2))
                                  : Icon(
                                      _isSaved
                                          ? Icons.bookmark_rounded
                                          : Icons.bookmark_outline_rounded,
                                      color: _isSaved
                                          ? const Color(0xFFFF6B6B)
                                          : AppColors.textMuted,
                                      size: 22)),
                        ]),
                      ])),
            ])));
  }

  Widget _buildRegularCard(String title, String channel, String duration,
      String views, String thumbnail) {
    return GestureDetector(
        onTap: _openVideo,
        child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.inputBorder)),
            child: Row(children: [
              // Thumbnail
              Stack(children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: thumbnail.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: thumbnail,
                            width: 110,
                            height: 72,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                                width: 110,
                                height: 72,
                                color: AppColors.inputBg,
                                child: const Center(
                                    child: CircularProgressIndicator(
                                        color: Color(0xFFFF6B6B),
                                        strokeWidth: 2))),
                            errorWidget: (_, __, ___) => Container(
                                width: 110,
                                height: 72,
                                color: AppColors.inputBg,
                                child: const Icon(
                                    Icons.play_circle_outline_rounded,
                                    color: AppColors.textMuted,
                                    size: 28)))
                        : Container(
                            width: 110,
                            height: 72,
                            decoration: BoxDecoration(
                                color: AppColors.inputBg,
                                borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.play_circle_outline_rounded,
                                color: AppColors.textMuted, size: 28))),
                // Play icon
                Positioned.fill(
                    child: Center(
                        child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 18)))),
                if (duration.isNotEmpty)
                  Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(duration,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600)))),
              ]),
              const SizedBox(width: 12),
              // Info
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(channel,
                        style: AppTextStyles.body.copyWith(fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (views.isNotEmpty) ...[
                        const Icon(Icons.visibility_outlined,
                            color: AppColors.textMuted, size: 11),
                        const SizedBox(width: 3),
                        Text(views,
                            style: AppTextStyles.label.copyWith(fontSize: 10)),
                        const Spacer(),
                      ],
                      GestureDetector(
                          onTap: _toggleSave,
                          child: _savingLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Color(0xFFFF6B6B), strokeWidth: 2))
                              : Icon(
                                  _isSaved
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_outline_rounded,
                                  color: _isSaved
                                      ? const Color(0xFFFF6B6B)
                                      : AppColors.textMuted,
                                  size: 18)),
                    ]),
                  ])),
            ])));
  }
}

// ══════════════════════════════════════════
// SAVED VIDEO CARD
// ══════════════════════════════════════════

class _SavedVideoCard extends StatelessWidget {
  final Map<String, dynamic> video;
  final VoidCallback onUnsave;
  const _SavedVideoCard({required this.video, required this.onUnsave});

  Future<void> _openVideo(BuildContext context) async {
    final url = video['url'] as String? ?? '';
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = video['title'] as String? ?? '';
    final channel = video['channelName'] as String? ?? '';
    final duration = video['duration'] as String? ?? '';
    final thumbnail = video['thumbnail'] as String? ?? '';
    final subject = video['subject'] as String? ?? '';

    return GestureDetector(
        onTap: () => _openVideo(context),
        child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFFF6B6B).withOpacity(0.15))),
            child: Row(children: [
              // Thumbnail
              Stack(children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: thumbnail.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: thumbnail,
                            width: 90,
                            height: 60,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                                width: 90,
                                height: 60,
                                color: AppColors.inputBg,
                                child: const Icon(
                                    Icons.play_circle_outline_rounded,
                                    color: AppColors.textMuted,
                                    size: 24)))
                        : Container(
                            width: 90,
                            height: 60,
                            color: AppColors.inputBg,
                            child: const Icon(Icons.play_circle_outline_rounded,
                                color: AppColors.textMuted, size: 24))),
                Positioned.fill(
                    child: Center(
                        child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 16)))),
                if (duration.isNotEmpty)
                  Positioned(
                      bottom: 3,
                      right: 3,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(duration,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600)))),
              ]),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(channel,
                        style: AppTextStyles.body.copyWith(fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                    if (subject.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFF6B6B).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(subject,
                              style: const TextStyle(
                                  color: Color(0xFFFF6B6B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600))),
                    ],
                  ])),
              const SizedBox(width: 8),
              // Unsave button
              GestureDetector(
                  onTap: onUnsave,
                  child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.bookmark_remove_rounded,
                          color: AppColors.error, size: 18))),
            ])));
  }
}
