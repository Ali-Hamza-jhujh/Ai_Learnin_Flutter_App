import "package:flutter/material.dart";
import "package:flutter/cupertino.dart";
import "package:url_launcher/url_launcher.dart";
import "../utils/app_theme.dart";
import "../models/dictionary_model.dart";
import "../services/dictionary_service.dart";
import "category_items_screen.dart";

class DictionaryDetailScreen extends StatefulWidget {
  final DictionaryItem item;
  const DictionaryDetailScreen({super.key, required this.item});

  @override
  State<DictionaryDetailScreen> createState() => _DictionaryDetailScreenState();
}

class _DictionaryDetailScreenState extends State<DictionaryDetailScreen> {
  late DictionaryItem _item;
  bool _isBookmarked = false;
  bool _isLoading = true;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final item = await DictionaryService.getMedicalTopic(_item.slug);
      if (mounted) setState(() { _item = item; _isLoading = false; });
    } catch (e) {
      try {
        final details = await DictionaryService.getTopicDetails(_item.slug);
        if (mounted) setState(() {
          _item = details["item"];
          _isBookmarked = details["isBookmarked"] ?? false;
          _isLoading = false;
        });
      } catch (err) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleBookmark() async {
    try {
      final res = await DictionaryService.toggleBookmark(_item.id);
      if (mounted) {
        setState(() => _isBookmarked = res);
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(res ? "Bookmarked" : "Removed"),
            content: Text(res
                ? "'${_item.title}' saved to your medical hub."
                : "'${_item.title}' removed from bookmarks."),
            actions: [CupertinoDialogAction(child: const Text("OK"), onPressed: () => Navigator.pop(context))],
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
      }
    } catch (e) {
      debugPrint("URL launch error: $e");
    }
  }

  String _clean(String text) => text
      .replaceAll("&lt;", "<")
      .replaceAll("&gt;", ">")
      .replaceAll("&amp;", "&")
      .replaceAll("&quot;", '"')
      .replaceAll("&apos;", "'")
      .replaceAll("&#xa0;", " ")
      .replaceAll("&nbsp;", " ");

  // ═══════════════════════════════════════════════════════════════════
  // PAPER DETAIL MODAL
  // ═══════════════════════════════════════════════════════════════════
  void _showPaperDetail(DictionaryResearchPaper paper) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 5,
                decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(10)),
              )),
              const SizedBox(height: 20),

              // PMID Badge + close
              Row(
                children: [
                  _chip("📄 PMID: ${paper.pubmedId}", AppColors.cyan),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white54, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Title
              Text(_clean(paper.title),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4)),
              const SizedBox(height: 16),

              // Journal meta
              _infoBox(children: [
                _metaRow(CupertinoIcons.square_stack_3d_up_fill, paper.journal, AppColors.violet),
                const SizedBox(height: 6),
                _metaRow(CupertinoIcons.calendar, "Published: ${paper.pubDate}", Colors.white60),
                if (paper.volume.isNotEmpty || paper.issue.isNotEmpty || paper.pages.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _metaRow(CupertinoIcons.book, "Vol ${paper.volume}(${paper.issue}), pp ${paper.pages}", Colors.white54),
                ],
                if (paper.doi.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _metaRow(CupertinoIcons.link, "DOI: ${paper.doi}", Colors.white54),
                ],
              ]),
              const SizedBox(height: 18),

              // Authors
              _sectionLabel("Authors & Investigators", AppColors.cyan),
              const SizedBox(height: 6),
              Text(_clean(paper.authors),
                  style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4)),
              const SizedBox(height: 20),

              // Abstract
              _infoBox(children: [
                Row(children: const [
                  Icon(CupertinoIcons.doc_text_fill, color: AppColors.gold, size: 18),
                  SizedBox(width: 8),
                  Text("Full Scientific Abstract", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ]),
                const SizedBox(height: 14),
                Text(
                  _clean(paper.abstract).isNotEmpty ? _clean(paper.abstract)
                      : "Full study paper indexing and clinical trial metrics are available on the official PubMed database.",
                  style: const TextStyle(fontSize: 14, height: 1.65, color: Colors.white),
                ),
              ]),
              const SizedBox(height: 24),

              // Open on PubMed
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(CupertinoIcons.globe, color: Colors.white),
                  label: Text("Open on PubMed (PMID: ${paper.pubmedId})",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final url = paper.url.isNotEmpty
                        ? paper.url
                        : "https://pubmed.ncbi.nlm.nih.gov/${paper.pubmedId}/";
                    _launchUrl(url);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const SpaceBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.back, color: AppColors.textWhite),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(_item.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.heading.copyWith(fontSize: 19)),
                      ),
                      IconButton(
                        icon: Icon(
                          _isBookmarked ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                          color: _isBookmarked ? AppColors.gold : AppColors.textWhite,
                        ),
                        onPressed: _toggleBookmark,
                      ),
                    ],
                  ),
                ),

                // Category + views row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.violet, Color(0xFF6B4EE6)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(_item.category.toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                    ),
                    const SizedBox(width: 8),
                    if (_item.subcategory != null && _item.subcategory!.isNotEmpty)
                      _chip(_item.subcategory!, AppColors.textMuted),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: Row(children: [
                        const Icon(CupertinoIcons.eye, size: 12, color: AppColors.cyan),
                        const SizedBox(width: 4),
                        Text("${_item.viewCount} views",
                            style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Report body
                Expanded(
                  child: _isLoading
                      ? const Center(child: CupertinoActivityIndicator(radius: 12))
                      : _buildReport(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // FULL MEDICAL REPORT — all sections based on category + available data
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildReport() {
    final info = _item.clinicalInfo;
    final cat = _item.category;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [

        // ── 🖼️ Image Carousel ───────────────────────────────────────────
        if (_item.images.isNotEmpty) ...[
          _buildHeroImageCarousel(),
          const SizedBox(height: 16),
        ],

        // ── 📋 Executive Summary ─────────────────────────────────────────
        _gradientCard(
          title: "Executive Medical Summary",
          icon: CupertinoIcons.doc_plaintext,
          accent: AppColors.cyan,
          child: Text(
            _item.overview.definition.isNotEmpty
                ? _item.overview.definition
                : _item.description,
            style: const TextStyle(height: 1.65, fontSize: 14, color: AppColors.textWhite),
          ),
        ),
        const SizedBox(height: 14),

        // ── 🏷️ ICD Codes & Synonyms ──────────────────────────────────────
        if (_item.overview.icdCodes.isNotEmpty || _item.overview.synonyms.isNotEmpty) ...[
          _gradientCard(
            title: "Classifications & Aliases",
            icon: CupertinoIcons.tag,
            accent: AppColors.violet,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_item.overview.icdCodes.isNotEmpty) ...[
                  _sectionLabel("ICD-10-CM Codes", AppColors.cyan),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 6,
                      children: _item.overview.icdCodes.map((c) => _chip(c, AppColors.cyan)).toList()),
                  const SizedBox(height: 12),
                ],
                if (_item.overview.synonyms.isNotEmpty) ...[
                  _sectionLabel("Medical Synonyms", AppColors.textLight),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 6,
                      children: _item.overview.synonyms.map((s) => _chip(s, AppColors.textMuted)).toList()),
                ],
                if (_item.overview.classification.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _sectionLabel("Classification", AppColors.violet),
                  const SizedBox(height: 4),
                  Text(_item.overview.classification,
                      style: const TextStyle(fontSize: 13, color: AppColors.textWhite, height: 1.4)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ══════════════════════════════════════════════════════════════
        // DISEASE / SYNDROME sections
        // ══════════════════════════════════════════════════════════════
        if (cat == "Diseases" || cat == "Syndromes") ...[
          if (info.symptoms.isNotEmpty) ...[
            _bulletCard("Symptoms & Clinical Presentation", info.symptoms, CupertinoIcons.heart_slash, const Color(0xFFFF5252)),
            const SizedBox(height: 14),
          ],
          if (info.causes.isNotEmpty) ...[
            _bulletCard("Causes & Etiology", info.causes, CupertinoIcons.waveform, AppColors.gold),
            const SizedBox(height: 14),
          ],
          if (info.diagnosis.isNotEmpty) ...[
            _bulletCard("Diagnostic Workup & Testing", info.diagnosis, CupertinoIcons.search, AppColors.cyan),
            const SizedBox(height: 14),
          ],
          if (info.treatment.isNotEmpty) ...[
            _bulletCard("Treatment & Management", info.treatment, CupertinoIcons.bandage, const Color(0xFF00E676)),
            const SizedBox(height: 14),
          ],
          if (info.prevention.isNotEmpty) ...[
            _bulletCard("Prevention & Prophylaxis", info.prevention, CupertinoIcons.shield_fill, AppColors.cyan),
            const SizedBox(height: 14),
          ],
          if (info.complications.isNotEmpty) ...[
            _bulletCard("Complications & Prognosis", info.complications, CupertinoIcons.exclamationmark_triangle, AppColors.error),
            const SizedBox(height: 14),
          ],
        ],

        // ══════════════════════════════════════════════════════════════
        // DRUG sections
        // ══════════════════════════════════════════════════════════════
        if (cat == "Drugs" || cat == "Pharmacology") ...[
          if (info.drugClass.isNotEmpty) ...[
            _gradientCard(
              title: "Drug Class & Category",
              icon: CupertinoIcons.lab_flask_solid,
              accent: AppColors.cyan,
              child: Text(info.drugClass,
                  style: const TextStyle(fontSize: 14, color: AppColors.textWhite, height: 1.5)),
            ),
            const SizedBox(height: 14),
          ],
          if (info.brandNames.isNotEmpty) ...[
            _gradientCard(
              title: "Brand Names & Trade Names",
              icon: CupertinoIcons.tag_fill,
              accent: AppColors.cyan,
              child: Wrap(spacing: 8, runSpacing: 8,
                  children: info.brandNames.map((n) => _chip(n, AppColors.cyan)).toList()),
            ),
            const SizedBox(height: 14),
          ],
          if (info.uses.isNotEmpty) ...[
            _bulletCard("Approved Indications & Uses", info.uses, CupertinoIcons.checkmark_seal_fill, const Color(0xFF00E676)),
            const SizedBox(height: 14),
          ],
          if (info.causes.isNotEmpty) ...[
            _bulletCard("Mechanism of Action", info.causes, CupertinoIcons.waveform, AppColors.violet),
            const SizedBox(height: 14),
          ],
          if (info.functions.isNotEmpty) ...[
            _bulletCard("Pharmacokinetics (ADME)", info.functions, CupertinoIcons.chart_bar_fill, AppColors.gold),
            const SizedBox(height: 14),
          ],
          if (info.doseForms.isNotEmpty || info.strength.isNotEmpty) ...[
            _gradientCard(
              title: "Dosage Forms & Strengths",
              icon: CupertinoIcons.thermometer,
              accent: AppColors.violet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (info.doseForms.isNotEmpty) ...[
                    _sectionLabel("Available Forms", AppColors.violet),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 6,
                        children: info.doseForms.map((f) => _chip(f, AppColors.violet)).toList()),
                  ],
                  if (info.strength.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _sectionLabel("Strengths", AppColors.gold),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 6,
                        children: info.strength.map((s) => _chip(s, AppColors.gold)).toList()),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (info.sideEffects.isNotEmpty) ...[
            _bulletCard("Side Effects & Adverse Reactions", info.sideEffects, CupertinoIcons.bolt_horizontal_circle, AppColors.gold),
            const SizedBox(height: 14),
          ],
          if (info.warnings.isNotEmpty) ...[
            _bulletCard("Boxed Warnings ⚠️", info.warnings, CupertinoIcons.exclamationmark_shield, AppColors.error),
            const SizedBox(height: 14),
          ],
          if (info.contraindications.isNotEmpty) ...[
            _bulletCard("Contraindications", info.contraindications, CupertinoIcons.nosign, AppColors.error),
            const SizedBox(height: 14),
          ],
          if (info.interactions.isNotEmpty) ...[
            _bulletCard("Drug Interactions", info.interactions, CupertinoIcons.arrow_2_squarepath, AppColors.violet),
            const SizedBox(height: 14),
          ],
          if (info.symptoms.isNotEmpty) ...[
            _bulletCard("Overdose & Toxicity", info.symptoms, CupertinoIcons.exclamationmark_octagon_fill, AppColors.error),
            const SizedBox(height: 14),
          ],
        ],

        // ══════════════════════════════════════════════════════════════
        // ANATOMY / BODY SYSTEMS sections
        // ══════════════════════════════════════════════════════════════
        if (cat == "Anatomy" || cat == "Body Systems") ...[
          _gradientCard(
            title: "Anatomical Structure & Innervation",
            icon: CupertinoIcons.layers,
            accent: AppColors.cyan,
            child: Column(
              children: [
                if (info.origin.isNotEmpty) _detailRow("Origin", info.origin),
                if (info.insertion.isNotEmpty) _detailRow("Insertion", info.insertion),
                if (info.bloodSupply.isNotEmpty) _detailRow("Blood Supply", info.bloodSupply),
                if (info.nerveSupply.isNotEmpty) _detailRow("Innervation", info.nerveSupply),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (info.functions.isNotEmpty) ...[
            _bulletCard("Functions & Roles", info.functions, CupertinoIcons.arrow_right_circle_fill, const Color(0xFF00E676)),
            const SizedBox(height: 14),
          ],
          if (info.clinicalImportance.isNotEmpty) ...[
            _gradientCard(
              title: "Clinical Significance",
              icon: CupertinoIcons.info_circle_fill,
              accent: AppColors.gold,
              child: Text(info.clinicalImportance,
                  style: const TextStyle(fontSize: 13, color: AppColors.textWhite, height: 1.55)),
            ),
            const SizedBox(height: 14),
          ],
          if (info.symptoms.isNotEmpty) ...[
            _bulletCard("Associated Disorders", info.symptoms, CupertinoIcons.exclamationmark_triangle, AppColors.error),
            const SizedBox(height: 14),
          ],
        ],

        // ══════════════════════════════════════════════════════════════
        // PHYSIOLOGY sections
        // ══════════════════════════════════════════════════════════════
        if (cat == "Physiology") ...[
          if (info.functions.isNotEmpty) ...[
            _bulletCard("Physiological Functions & Mechanisms", info.functions, CupertinoIcons.heart_fill, AppColors.cyan),
            const SizedBox(height: 14),
          ],
          if (info.causes.isNotEmpty) ...[
            _bulletCard("Regulatory Mechanisms & Control", info.causes, CupertinoIcons.arrow_2_squarepath, AppColors.gold),
            const SizedBox(height: 14),
          ],
          if (info.treatment.isNotEmpty) ...[
            _bulletCard("Clinical Applications", info.treatment, CupertinoIcons.bandage, const Color(0xFF00E676)),
            const SizedBox(height: 14),
          ],
          if (info.complications.isNotEmpty) ...[
            _bulletCard("Physiological Disorders", info.complications, CupertinoIcons.exclamationmark_triangle, AppColors.error),
            const SizedBox(height: 14),
          ],
          if (info.clinicalImportance.isNotEmpty) ...[
            _gradientCard(
              title: "Clinical Importance",
              icon: CupertinoIcons.info_circle_fill,
              accent: AppColors.violet,
              child: Text(info.clinicalImportance,
                  style: const TextStyle(fontSize: 13, color: AppColors.textWhite, height: 1.55)),
            ),
            const SizedBox(height: 14),
          ],
        ],

        // ══════════════════════════════════════════════════════════════
        // BIOCHEMISTRY sections
        // ══════════════════════════════════════════════════════════════
        if (cat == "Biochemistry") ...[
          if (info.functions.isNotEmpty) ...[
            _bulletCard("Biochemical Functions & Reactions", info.functions, CupertinoIcons.waveform_path, AppColors.cyan),
            const SizedBox(height: 14),
          ],
          if (info.causes.isNotEmpty) ...[
            _bulletCard("Enzymes & Mechanisms", info.causes, CupertinoIcons.arrow_right_circle_fill, AppColors.violet),
            const SizedBox(height: 14),
          ],
          if (info.symptoms.isNotEmpty) ...[
            _bulletCard("Deficiency & Excess Disorders", info.symptoms, CupertinoIcons.exclamationmark_triangle, AppColors.error),
            const SizedBox(height: 14),
          ],
          if (info.treatment.isNotEmpty) ...[
            _bulletCard("Clinical Significance", info.treatment, CupertinoIcons.bandage, const Color(0xFF00E676)),
            const SizedBox(height: 14),
          ],
          if (info.normalRange.isNotEmpty) ...[
            _gradientCard(
              title: "Normal Levels & Reference Ranges",
              icon: CupertinoIcons.chart_bar,
              accent: AppColors.gold,
              child: Text(info.normalRange,
                  style: const TextStyle(fontSize: 13, color: AppColors.textWhite, height: 1.55)),
            ),
            const SizedBox(height: 14),
          ],
          if (info.clinicalImportance.isNotEmpty) ...[
            _gradientCard(
              title: "Molecular & Clinical Context",
              icon: CupertinoIcons.info_circle_fill,
              accent: AppColors.gold,
              child: Text(info.clinicalImportance,
                  style: const TextStyle(fontSize: 13, color: AppColors.textWhite, height: 1.55)),
            ),
            const SizedBox(height: 14),
          ],
        ],

        // ══════════════════════════════════════════════════════════════
        // HISTOLOGY sections
        // ══════════════════════════════════════════════════════════════
        if (cat == "Histology") ...[
          if (info.functions.isNotEmpty) ...[
            _bulletCard("Functions & Characteristics", info.functions, CupertinoIcons.eye_solid, AppColors.cyan),
            const SizedBox(height: 14),
          ],
          if (info.causes.isNotEmpty) ...[
            _bulletCard("Cellular Structure & Composition", info.causes, CupertinoIcons.circle_grid_hex, AppColors.violet),
            const SizedBox(height: 14),
          ],
          if (info.treatment.isNotEmpty) ...[
            _bulletCard("Staining & Microscopy", info.treatment, CupertinoIcons.photo_fill, AppColors.gold),
            const SizedBox(height: 14),
          ],
          if (info.symptoms.isNotEmpty) ...[
            _bulletCard("Histopathological Changes", info.symptoms, CupertinoIcons.exclamationmark_triangle, AppColors.error),
            const SizedBox(height: 14),
          ],
          if (info.clinicalImportance.isNotEmpty) ...[
            _gradientCard(
              title: "Clinical Significance",
              icon: CupertinoIcons.info_circle_fill,
              accent: AppColors.gold,
              child: Text(info.clinicalImportance,
                  style: const TextStyle(fontSize: 13, color: AppColors.textWhite, height: 1.55)),
            ),
            const SizedBox(height: 14),
          ],
        ],

        // ══════════════════════════════════════════════════════════════
        // LAB VALUES sections
        // ══════════════════════════════════════════════════════════════
        if (cat == "Lab Values") ...[
          if (info.normalRange.isNotEmpty) ...[
            _gradientCard(
              title: "Normal Reference Range",
              icon: CupertinoIcons.chart_bar_square,
              accent: const Color(0xFF00E676),
              child: Text(info.normalRange,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF00E676), height: 1.4)),
            ),
            const SizedBox(height: 14),
          ],
          if (info.clinicalSignificance.isNotEmpty) ...[
            _gradientCard(
              title: "Clinical Significance & Interpretation",
              icon: CupertinoIcons.info_circle_fill,
              accent: AppColors.cyan,
              child: Text(info.clinicalSignificance,
                  style: const TextStyle(fontSize: 13, color: AppColors.textWhite, height: 1.6)),
            ),
            const SizedBox(height: 14),
          ],
          if (info.highValues.isNotEmpty) ...[
            _bulletCard("Elevated Values — Causes & Significance", info.highValues, CupertinoIcons.arrow_up_circle_fill, AppColors.error),
            const SizedBox(height: 14),
          ],
          if (info.lowValues.isNotEmpty) ...[
            _bulletCard("Low Values — Causes & Significance", info.lowValues, CupertinoIcons.arrow_down_circle_fill, AppColors.gold),
            const SizedBox(height: 14),
          ],
          if (info.causes.isNotEmpty) ...[
            _bulletCard("Associated Conditions", info.causes, CupertinoIcons.waveform, AppColors.violet),
            const SizedBox(height: 14),
          ],
          if (info.treatment.isNotEmpty) ...[
            _bulletCard("Management & Correction", info.treatment, CupertinoIcons.bandage, AppColors.cyan),
            const SizedBox(height: 14),
          ],
        ],

        // ══════════════════════════════════════════════════════════════
        // PROCEDURES sections
        // ══════════════════════════════════════════════════════════════
        if (cat == "Procedures") ...[
          if (info.uses.isNotEmpty) ...[
            _bulletCard("Indications & Purposes", info.uses, CupertinoIcons.checkmark_seal_fill, const Color(0xFF00E676)),
            const SizedBox(height: 14),
          ],
          if (info.functions.isNotEmpty) ...[
            _bulletCard("Preparation & Equipment", info.functions, CupertinoIcons.wrench_fill, AppColors.gold),
            const SizedBox(height: 14),
          ],
          if (info.treatment.isNotEmpty) ...[
            _bulletCard("Technique & Steps", info.treatment, CupertinoIcons.scissors, AppColors.cyan),
            const SizedBox(height: 14),
          ],
          if (info.complications.isNotEmpty) ...[
            _bulletCard("Complications & Risks", info.complications, CupertinoIcons.exclamationmark_triangle, AppColors.error),
            const SizedBox(height: 14),
          ],
          if (info.clinicalImportance.isNotEmpty) ...[
            _gradientCard(
              title: "Clinical Significance & Outcomes",
              icon: CupertinoIcons.info_circle_fill,
              accent: AppColors.violet,
              child: Text(info.clinicalImportance,
                  style: const TextStyle(fontSize: 13, color: AppColors.textWhite, height: 1.55)),
            ),
            const SizedBox(height: 14),
          ],
        ],

        // ══════════════════════════════════════════════════════════════
        // CLINICAL CONCEPTS sections
        // ══════════════════════════════════════════════════════════════
        if (cat == "Clinical Concepts") ...[
          if (info.functions.isNotEmpty) ...[
            _bulletCard("Core Concept & Principles", info.functions, CupertinoIcons.lightbulb_fill, AppColors.cyan),
            const SizedBox(height: 14),
          ],
          if (info.symptoms.isNotEmpty) ...[
            _bulletCard("Clinical Features & Findings", info.symptoms, CupertinoIcons.heart_slash, const Color(0xFFFF5252)),
            const SizedBox(height: 14),
          ],
          if (info.causes.isNotEmpty) ...[
            _bulletCard("Causes & Mechanisms", info.causes, CupertinoIcons.waveform, AppColors.gold),
            const SizedBox(height: 14),
          ],
          if (info.treatment.isNotEmpty) ...[
            _bulletCard("Clinical Management", info.treatment, CupertinoIcons.bandage, const Color(0xFF00E676)),
            const SizedBox(height: 14),
          ],
          if (info.clinicalImportance.isNotEmpty) ...[
            _gradientCard(
              title: "Clinical Importance & Applications",
              icon: CupertinoIcons.info_circle_fill,
              accent: AppColors.violet,
              child: Text(info.clinicalImportance,
                  style: const TextStyle(fontSize: 13, color: AppColors.textWhite, height: 1.55)),
            ),
            const SizedBox(height: 14),
          ],
        ],

        // ══════════════════════════════════════════════════════════════
        // MEDICAL IMAGES / RESEARCH PAPERS / MEDICAL TERMINOLOGIES / fallback
        // ══════════════════════════════════════════════════════════════
        if (cat == "Medical Images" || cat == "Research Papers" || cat == "Medical Terminologies" ||
            (!["Diseases","Syndromes","Drugs","Pharmacology","Anatomy","Body Systems",
               "Physiology","Biochemistry","Histology","Lab Values","Procedures","Clinical Concepts"].contains(cat))) ...[
          if (info.functions.isNotEmpty) ...[
            _bulletCard("Key Information", info.functions, CupertinoIcons.info_circle_fill, AppColors.cyan),
            const SizedBox(height: 14),
          ],
          if (info.causes.isNotEmpty) ...[
            _bulletCard("Details & Context", info.causes, CupertinoIcons.waveform, AppColors.gold),
            const SizedBox(height: 14),
          ],
          if (info.symptoms.isNotEmpty) ...[
            _bulletCard("Features & Characteristics", info.symptoms, CupertinoIcons.heart_slash, const Color(0xFFFF5252)),
            const SizedBox(height: 14),
          ],
          if (info.treatment.isNotEmpty) ...[
            _bulletCard("Applications & Uses", info.treatment, CupertinoIcons.checkmark_circle_fill, const Color(0xFF00E676)),
            const SizedBox(height: 14),
          ],
          if (info.complications.isNotEmpty) ...[
            _bulletCard("Limitations & Risks", info.complications, CupertinoIcons.exclamationmark_triangle, AppColors.error),
            const SizedBox(height: 14),
          ],
          if (info.clinicalImportance.isNotEmpty) ...[
            _gradientCard(
              title: "Clinical Context & Significance",
              icon: CupertinoIcons.doc_plaintext,
              accent: AppColors.violet,
              child: Text(info.clinicalImportance,
                  style: const TextStyle(fontSize: 13, color: AppColors.textWhite, height: 1.55)),
            ),
            const SizedBox(height: 14),
          ],
        ],

        // ── 🗂️ Additional Diagrams Gallery (images 2+) ───────────────────
        if (_item.images.length > 1) ...[
          _buildGallery(),
          const SizedBox(height: 14),
        ],

        // ── 🔗 Related Topics ────────────────────────────────────────────
        if (_item.relatedTopics.isNotEmpty) ...[
          _gradientCard(
            title: "Related Topics",
            icon: CupertinoIcons.arrow_right_arrow_left_circle_fill,
            accent: AppColors.violet,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _item.relatedTopics.map((topic) => GestureDetector(
                onTap: () {
                  final cat = _item.category;
                  Navigator.push(context, fadeSlideRoute(
                    CategoryItemsScreen(category: cat),
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.violet.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.arrow_right, size: 11, color: AppColors.violet),
                      const SizedBox(width: 6),
                      Text(topic, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.violet)),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── 📚 PubMed Research Papers ────────────────────────────────────
        if (_item.researchPapers.isNotEmpty) ...[
          _buildPubMedSection(),
          const SizedBox(height: 14),
        ],

        // ── 🔗 Official References ───────────────────────────────────────
        if (_item.references.isNotEmpty) ...[
          _buildReferencesSection(),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Image Carousel
  // ══════════════════════════════════════════════════════════════════
  Widget _buildHeroImageCarousel() {
    final images = _item.images;
    final safeIndex = _currentImageIndex < images.length ? _currentImageIndex : 0;
    final current = images[safeIndex];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 240,
                child: PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _currentImageIndex = i),
                  itemBuilder: (context, index) {
                    final img = images[index];
                    return GestureDetector(
                      onTap: () => _showFullscreenImage(img),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        child: Image.network(
                          img.mediumUrl.isNotEmpty ? img.mediumUrl : img.url,
                          width: double.infinity,
                          height: 240,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.bgCard,
                            child: const Center(
                                child: Icon(CupertinoIcons.photo, color: AppColors.textMuted, size: 40)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (images.length > 1) ...[
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(CupertinoIcons.photo, size: 12, color: AppColors.cyan),
                      const SizedBox(width: 4),
                      Text("${safeIndex + 1} / ${images.length}",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ]),
                  ),
                ),
                Positioned(
                  bottom: 8, left: 0, right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(images.length, (idx) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: safeIndex == idx ? 16 : 6, height: 6,
                      decoration: BoxDecoration(
                        color: safeIndex == idx ? AppColors.cyan : Colors.white38,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    )),
                  ),
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(CupertinoIcons.info_circle_fill, size: 16, color: AppColors.cyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(current.caption,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textWhite),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.zoom_in, size: 14, color: AppColors.textMuted),
            ]),
          ),
          if (current.source.isNotEmpty || current.creator.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                "© ${current.creator.isNotEmpty ? current.creator : 'Wikimedia'} • ${current.license.isNotEmpty ? current.license : 'CC BY-SA'} • ${current.source.isNotEmpty ? current.source : 'Wikimedia Commons'}",
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  void _showFullscreenImage(DictionaryImage img) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.95),
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5, maxScale: 4.0,
                child: Image.network(img.url.isNotEmpty ? img.url : img.mediumUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(CupertinoIcons.photo, color: Colors.white54, size: 60)),
              ),
            ),
            Positioned(
              top: 40, right: 16,
              child: IconButton(
                icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 24, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24)),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(img.caption,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  if (img.creator.isNotEmpty || img.license.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        "${img.source.isNotEmpty ? img.source : 'Wikimedia'} • ${img.creator.isNotEmpty ? img.creator : 'Medical'} • ${img.license.isNotEmpty ? img.license : 'CC BY-SA'}",
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGallery() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(CupertinoIcons.photo, color: AppColors.cyan, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text("Clinical Diagrams & Visuals",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textWhite))),
          ]),
          const SizedBox(height: 14),
          ..._item.images.skip(1).map((img) => GestureDetector(
                onTap: () => _showFullscreenImage(img),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.inputBorder)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(
                          img.mediumUrl.isNotEmpty ? img.mediumUrl : img.url,
                          width: double.infinity, height: 200, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120, color: AppColors.bg,
                            child: const Center(child: Icon(CupertinoIcons.photo, color: AppColors.textMuted, size: 30)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(img.caption,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textWhite)),
                          if (img.source.isNotEmpty)
                            Text("Source: ${img.source} — ${img.license.isNotEmpty ? img.license : 'CC BY-SA'}",
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ]),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPubMedSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(CupertinoIcons.book_fill, color: AppColors.cyan, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text("PubMed Research Papers",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textWhite))),
          ]),
          const SizedBox(height: 4),
          Text("${_item.researchPapers.length} indexed article${_item.researchPapers.length > 1 ? 's' : ''}",
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 14),
          ..._item.researchPapers.map((paper) => Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showPaperDetail(paper),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.inputBorder.withOpacity(0.5)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Text(paper.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textWhite, height: 1.3)),
                        ),
                        const SizedBox(width: 8),
                        const Icon(CupertinoIcons.chevron_right_circle_fill, color: AppColors.cyan, size: 18),
                      ]),
                      const SizedBox(height: 6),
                      Text("Authors: ${paper.authors}",
                          style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(
                          child: Text("${paper.journal} • ${paper.pubDate}",
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: AppColors.cyan.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text("PMID: ${paper.pubmedId}",
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.cyan)),
                        ),
                      ]),
                      if (paper.abstract.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          paper.abstract.length > 150
                              ? "${paper.abstract.substring(0, 150)}..."
                              : paper.abstract,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSub, height: 1.4),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(children: const [
                        Icon(CupertinoIcons.doc_text, size: 11, color: AppColors.textMuted),
                        SizedBox(width: 4),
                        Text("Tap to read full abstract & details",
                            style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                      ]),
                    ]),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildReferencesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(CupertinoIcons.link, color: AppColors.violet, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text("Official Medical References",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textWhite))),
          ]),
          const SizedBox(height: 14),
          ..._item.references.map((ref) => Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () { if (ref.url.isNotEmpty) _launchUrl(ref.url); },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.inputBorder.withOpacity(0.5))),
                    child: Row(children: [
                      Icon(
                        ref.type == "government" ? CupertinoIcons.building_2_fill : CupertinoIcons.globe,
                        color: ref.type == "government" ? AppColors.gold : AppColors.cyan,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(ref.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textWhite)),
                        Text(ref.source, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                      ])),
                      const Icon(CupertinoIcons.arrow_up_right, size: 14, color: AppColors.cyan),
                    ]),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Shared UI helpers
  // ══════════════════════════════════════════════════════════════════
  Widget _gradientCard({required String title, required IconData icon, required Color accent, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textWhite))),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _bulletCard(String title, List<String> items, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textWhite))),
        ]),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("• ", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            Expanded(child: Text(item, style: const TextStyle(height: 1.5, color: AppColors.textWhite, fontSize: 13))),
          ]),
        )),
      ]),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.cyan, fontSize: 13)),
        ),
        Expanded(child: Text(value, style: const TextStyle(color: AppColors.textWhite, fontSize: 13))),
      ]),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13));
  }

  Widget _infoBox({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _metaRow(IconData icon, String text, Color color) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color))),
    ]);
  }
}
