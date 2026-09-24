import "dart:async";
import "package:flutter/material.dart";
import "package:flutter/cupertino.dart";
import "../utils/app_theme.dart";
import "../models/dictionary_model.dart";
import "../services/dictionary_service.dart";
import "../services/api_service.dart";
import "dictionary_detail_screen.dart";

class CategoryItemsScreen extends StatefulWidget {
  final String category;
  const CategoryItemsScreen({super.key, required this.category});

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DictionaryItem> _items = [];
  List<String> _dbKeywords = []; // Keywords from DB items
  List<Map<String, dynamic>> _liveAutocomplete = []; // Live search suggestions
  bool _isLoading = true;
  bool _isFetchingApi = false;
  bool _isAdmin = false;
  String _activeLoadingTopic = "";
  String _searchQuery = "";
  Timer? _debounceTimer;

  // Fallback suggested topics per category (shown only if DB is empty)
  static const Map<String, List<String>> _fallbackTopics = {
    "Diseases":                ["Diabetes mellitus", "Hypertension", "Lung cancer", "Asthma", "Tuberculosis", "Alzheimer's disease", "Stroke", "Malaria", "Hepatitis B", "Pneumonia"],
    "Drugs":                   ["Metformin", "Aspirin", "Ibuprofen", "Paracetamol", "Amoxicillin", "Atorvastatin", "Lisinopril", "Albuterol", "Morphine", "Warfarin"],
    "Anatomy":                 ["Heart", "Brain", "Lungs", "Liver", "Kidney", "Femur", "Sciatic nerve", "Aorta", "Retina", "Pancreas"],
    "Physiology":              ["Cardiac cycle", "Homeostasis", "Action potential", "Cellular respiration", "Gas exchange", "Renal filtration", "Digestion"],
    "Biochemistry":            ["Glycolysis", "Krebs cycle", "DNA replication", "Hemoglobin", "ATP synthesis", "Lipid metabolism"],
    "Histology":               ["Epithelium", "Connective tissue", "Neuron", "Muscle tissue", "Cartilage", "Bone tissue"],
    "Pharmacology":            ["Mechanism of action", "Pharmacokinetics", "Agonist", "Antagonist", "Bioavailability", "Drug receptor"],
    "Lab Values":              ["HbA1c", "Complete blood count", "Blood glucose", "Lipid panel", "Serum creatinine", "Troponin"],
    "Clinical Concepts":       ["Differential diagnosis", "Sepsis", "Anaphylaxis", "Vital signs", "Glasgow Coma Scale"],
    "Procedures":              ["Electrocardiogram", "Chest X-ray", "Lumbar puncture", "Endoscopy", "Biopsy", "Intubation"],
    "Medical Terminologies":   ["Tachycardia", "Bradycardia", "Dyspnea", "Cyanosis", "Ischemia", "Hyperglycemia"],
    "Research Papers":         ["Clinical trials", "Meta-analysis", "Systematic review", "Oncology research"],
    "Medical Images":          ["Radiography", "CT scan", "MRI scan", "Ultrasonography", "Histopathology"],
    "Syndromes":               ["Down syndrome", "Cushing's syndrome", "Metabolic syndrome", "Polycystic ovary syndrome"],
    "Body Systems":            ["Cardiovascular system", "Nervous system", "Respiratory system", "Digestive system"],
    "Medical Classifications": ["ICD-10", "DSM-5", "TNM staging", "NYHA classification"],
  };

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    try {
      final profile = await ProfileService.getMyProfile();
      final user = profile["user"] as Map? ?? {};
      if (mounted) setState(() => _isAdmin = user["isAdmin"] == true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Fetch items from DB, extract unique keywords for chips
  Future<void> _fetchItems({String? query}) async {
    setState(() => _isLoading = true);
    try {
      final items = await DictionaryService.getByCategory(widget.category, query: query);
      if (mounted) {
        // Build keyword chip list from DB items
        final Set<String> kwSet = {};
        for (final item in items) {
          kwSet.add(item.title); // Always include title
          for (final kw in item.keywords) {
            if (kw.length > 2 && kw.length < 30) kwSet.add(kw);
          }
        }
        setState(() {
          _items = items;
          _dbKeywords = kwSet.take(30).toList()
            ..sort((a, b) => a.compareTo(b));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    setState(() {
      _searchQuery = query;
      _liveAutocomplete = [];
    });

    if (query.trim().isEmpty) {
      _fetchItems(); // Back to full list
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      // 1. Filter local DB
      final localFiltered = await DictionaryService.getByCategory(
          widget.category, query: query);
      if (!mounted) return;

      setState(() {
        _items = localFiltered;
        _isLoading = false;
      });

      // 2. If no local results, get autocomplete suggestions
      if (localFiltered.isEmpty && query.length > 2) {
        final suggestions = await DictionaryService.getAutocomplete(query);
        if (mounted) {
          setState(() {
            _liveAutocomplete = suggestions
                .where((s) =>
                    (s["category"] ?? "") == widget.category ||
                    (s["category"] ?? "").isEmpty)
                .take(6)
                .toList();
          });
        }
      }
    });
  }

  Future<void> _fetchTopicFromApi(String topicTitle) async {
    if (topicTitle.trim().isEmpty) return;
    setState(() {
      _isFetchingApi = true;
      _activeLoadingTopic = topicTitle;
      _liveAutocomplete = [];
    });
    FocusScope.of(context).unfocus();

    try {
      final result = await DictionaryService.smartSearch(topicTitle, categoryHint: widget.category);
      final DictionaryItem item = result["item"];
      if (mounted) {
        setState(() {
          _isFetchingApi = false;
          _activeLoadingTopic = "";
          _searchController.clear();
          _searchQuery = "";
        });
        _fetchItems(); // Refresh so new item appears in list
        Navigator.push(
            context, fadeSlideRoute(DictionaryDetailScreen(item: item)));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingApi = false;
          _activeLoadingTopic = "";
        });
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text("Search Error"),
            content: Text(
                "Could not fetch '$topicTitle' from medical APIs. Please try again."),
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
    final chips = _dbKeywords.isNotEmpty
        ? _dbKeywords
        : (_fallbackTopics[widget.category] ?? _fallbackTopics["Diseases"]!);

    return Scaffold(
      body: Stack(
        children: [
          const SpaceBackground(),
          SafeArea(
            child: Column(
              children: [
                // ── Top Bar ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                            Text(
                              widget.category,
                              style: AppTextStyles.heading
                                  .copyWith(fontSize: 22),
                            ),
                            Text(
                              _dbKeywords.isNotEmpty
                                  ? "${_items.length} entries in database"
                                  : "Local DB + live medical repository",
                              style: AppTextStyles.body.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (_items.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.cyan.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${_items.length}",
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.cyan),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Search Bar ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: "Search in ${widget.category}...",
                    placeholderStyle:
                        const TextStyle(color: AppColors.textMuted),
                    style: const TextStyle(color: AppColors.textWhite),
                    backgroundColor: AppColors.bgCard,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    borderRadius: BorderRadius.circular(16),
                    onChanged: _onSearchChanged,
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) _fetchTopicFromApi(val.trim());
                    },
                  ),
                ),

                // ── Keyword/Topic Chips from DB ────────────────────────────
                Container(
                  height: 46,
                  margin: const EdgeInsets.only(top: 2, bottom: 6),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: chips.length,
                    itemBuilder: (context, index) {
                      final topic = chips[index];
                      final isLoading = _activeLoadingTopic.toLowerCase() ==
                          topic.toLowerCase();
                      // Check if this keyword is already in DB
                      final isInDb = _items.any((item) =>
                          item.title.toLowerCase() == topic.toLowerCase() ||
                          item.keywords.any(
                              (kw) => kw.toLowerCase() == topic.toLowerCase()));
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          backgroundColor: isLoading
                              ? AppColors.violet
                              : isInDb
                                  ? AppColors.cyan.withOpacity(0.18)
                                  : AppColors.bgCard,
                          side: BorderSide(
                            color: isLoading
                                ? AppColors.violet
                                : isInDb
                                    ? AppColors.cyan
                                    : AppColors.inputBorder,
                            width: isInDb ? 1.2 : 1,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          avatar: isLoading
                              ? const CupertinoActivityIndicator(
                                  radius: 8, color: Colors.white)
                              : Icon(
                                  isInDb
                                      ? CupertinoIcons.checkmark_circle_fill
                                      : CupertinoIcons.sparkles,
                                  size: 12,
                                  color: isInDb
                                      ? AppColors.cyan
                                      : AppColors.textMuted),
                          label: Text(
                            topic,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isLoading
                                  ? Colors.white
                                  : isInDb
                                      ? AppColors.cyan
                                      : AppColors.textWhite,
                            ),
                          ),
                          onPressed: () => isInDb
                              ? _openExistingItem(topic)
                              : _fetchTopicFromApi(topic),
                        ),
                      );
                    },
                  ),
                ),

                // ── API Fetch Banner ───────────────────────────────────────
                if (_isFetchingApi)
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.violet.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.violet.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        const CupertinoActivityIndicator(radius: 9),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Fetching '$_activeLoadingTopic' from PubMed, Wikipedia, OpenFDA & Wikimedia...",
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.violet),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Live Autocomplete Suggestions (when no DB match) ────────
                if (_liveAutocomplete.isNotEmpty && !_isFetchingApi)
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: AppColors.cyan.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Fetch from Medical APIs:",
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.cyan,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _liveAutocomplete
                              .map((sug) => GestureDetector(
                                    onTap: () =>
                                        _fetchTopicFromApi(sug["title"] ?? ""),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.cyan.withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AppColors.cyan
                                                .withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              CupertinoIcons
                                                  .cloud_download_fill,
                                              size: 10,
                                              color: AppColors.cyan),
                                          const SizedBox(width: 4),
                                          Text(
                                            sug["title"] ?? "",
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.cyan,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),

                // ── Item List or Empty State ───────────────────────────────
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CupertinoActivityIndicator(radius: 12))
                      : _items.isEmpty
                          ? _buildEmptyState(_searchQuery, chips)
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return _buildItemCard(item);
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(DictionaryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: item.images.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  item.images[0].thumbnailUrl.isNotEmpty
                      ? item.images[0].thumbnailUrl
                      : item.images[0].url,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.doc_fill,
                      color: AppColors.violet, size: 22),
                ),
              )
            : Container(
                width: 60,
                height: 60,
                color: AppColors.bgCard,
                child: const Icon(CupertinoIcons.doc_fill,
                    color: AppColors.violet, size: 22),
              ),
        title: Text(
          item.title,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textWhite),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSub),
            ),
            if (item.keywords.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: item.keywords.take(4).map((kw) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(kw,
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.cyan, fontWeight: FontWeight.bold)),
                )).toList(),
              ),
            ],
          ],
        ),
        trailing: _isAdmin
            ? IconButton(
                icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent, size: 20),
                tooltip: "Admin: Delete",
                onPressed: () => _confirmDelete(item),
              )
            : const Icon(CupertinoIcons.chevron_right,
                color: AppColors.textMuted, size: 18),
        onTap: () =>
            Navigator.push(context, fadeSlideRoute(DictionaryDetailScreen(item: item))),
      ),
    );
  }

  Future<void> _confirmDelete(DictionaryItem item) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Delete Entry"),
        content: Text("Delete \"${item.title}\" from the dictionary?\nThis cannot be undone."),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Delete"),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await DictionaryService.deleteItem(item.id);
        if (mounted) {
          setState(() => _items.removeWhere((i) => i.id == item.id));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("\"${item.title}\" deleted"),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Delete failed: $e"),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _openExistingItem(String keyword) {
    final match = _items.firstWhere(
      (item) =>
          item.title.toLowerCase() == keyword.toLowerCase() ||
          item.keywords.any((kw) => kw.toLowerCase() == keyword.toLowerCase()),
      orElse: () => _items.first,
    );
    Navigator.push(
        context, fadeSlideRoute(DictionaryDetailScreen(item: match)));
  }

  Widget _buildEmptyState(String query, List<String> chips) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cyan.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.sparkles,
                size: 36, color: AppColors.cyan),
          ),
          const SizedBox(height: 16),
          Text(
            query.isEmpty
                ? "No entries yet in ${widget.category}.\nTap a topic below to fetch from Medical APIs & save to DB."
                : "No DB record for '$query'.\nTap below to fetch live from PubMed, Wikipedia & OpenFDA.",
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSub, height: 1.5),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: chips
                .map((topic) => ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bgCard,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(
                              color: AppColors.inputBorder),
                        ),
                      ),
                      icon: const Icon(CupertinoIcons.cloud_download,
                          size: 13, color: AppColors.cyan),
                      label: Text(
                        topic,
                        style: const TextStyle(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      onPressed: () => _fetchTopicFromApi(topic),
                    ))
                .toList(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
