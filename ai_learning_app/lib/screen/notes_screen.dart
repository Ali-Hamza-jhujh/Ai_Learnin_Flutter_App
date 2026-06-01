import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import '../services/api_client.dart';

// ══════════════════════════════════════════
// NOTES SCREEN — 3 states:
// 1. NotesList   — shows all saved notes
// 2. GenerateFlow — upload PDF → scan → configure → generate
// 3. NoteViewer  — read a single note
// ══════════════════════════════════════════

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;
  String? _error;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadNotes();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await NotesService.getMyNotes();
      final list = res['notes'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _notes = list.map((e) => e as Map<String, dynamic>).toList();
          _loading = false;
        });
        _fadeCtrl.forward(from: 0);
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
          _error = 'Failed to load notes';
          _loading = false;
        });
    }
  }

  Future<void> _deleteNote(String id) async {
    try {
      await NotesService.deleteNote(id);
      setState(() => _notes.removeWhere((n) => n['_id'] == id));
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(_snackBar('Note deleted', AppColors.error));
    } catch (_) {}
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
          Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.violet))
                  : _error != null
                      ? _buildError()
                      : _notes.isEmpty
                          ? _buildEmpty()
                          : _buildNotesList()),
        ])),
        // FAB — generate new notes
        Positioned(bottom: 24, right: 24, child: _buildFAB()),
      ]),
    );
  }

  Widget _buildHeader() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShaderMask(
                shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
                child: const Text('My Notes',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFamily: 'Georgia'))),
            Text(
                '${_notes.length} note${_notes.length == 1 ? '' : 's'} generated',
                style: AppTextStyles.sub),
          ]),
          const Spacer(),
          IconButton(
              onPressed: _loadNotes,
              icon:
                  const Icon(Icons.refresh_rounded, color: AppColors.textSub)),
        ]));
  }

  Widget _buildEmpty() {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(40),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                      color: AppColors.violet.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(32),
                      border:
                          Border.all(color: AppColors.violet.withOpacity(0.2))),
                  child: const Center(
                      child: Text('📚', style: TextStyle(fontSize: 48)))),
              const SizedBox(height: 24),
              ShaderMask(
                  shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
                  child: const Text('No Notes Yet',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Georgia'))),
              const SizedBox(height: 8),
              const Text(
                  'Upload a PDF to generate AI-powered\nstudy notes instantly.',
                  style: AppTextStyles.sub,
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              GlowButton(
                  text: 'Generate Notes',
                  icon: Icons.add_rounded,
                  onPressed: _openGenerateFlow),
            ])));
  }

  Widget _buildError() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      buildErrorBanner(_error!),
      const SizedBox(height: 16),
      GlowButton(
          text: 'Retry', icon: Icons.refresh_rounded, onPressed: _loadNotes),
    ]));
  }

  Widget _buildNotesList() {
    return FadeTransition(
        opacity: _fadeAnim,
        child: RefreshIndicator(
            color: AppColors.violet,
            backgroundColor: AppColors.bgCard,
            onRefresh: _loadNotes,
            child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
                itemCount: _notes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _noteCard(_notes[i]))));
  }

  Widget _noteCard(Map<String, dynamic> note) {
    final title = note['title'] as String? ?? 'Untitled';
    final subject = note['subject'] as String? ?? '';
    final mode = note['mode'] as String? ?? 'full';
    final chapters = (note['detectedChapters'] as List<dynamic>?)?.length ?? 0;
    final date = _formatDate(note['createdAt'] as String?);
    final docType = note['documentType'] as String? ?? 'plain';

    return Dismissible(
        key: Key(note['_id'] as String),
        direction: DismissDirection.endToStart,
        background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.delete_rounded, color: AppColors.error)),
        onDismissed: (_) => _deleteNote(note['_id'] as String),
        child: GestureDetector(
            onTap: () => _openNoteViewer(note['_id'] as String, title),
            child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.inputBorder),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]),
                child: Row(children: [
                  // Doc type icon
                  Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                          gradient: AppColors.primaryGrad,
                          borderRadius: BorderRadius.circular(16)),
                      child: Center(
                          child: Text(
                              docType == 'book'
                                  ? '📖'
                                  : docType == 'document'
                                      ? '📄'
                                      : '📝',
                              style: const TextStyle(fontSize: 24)))),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            style: const TextStyle(
                                color: AppColors.textWhite,
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        if (subject.isNotEmpty)
                          Text(subject,
                              style: AppTextStyles.body.copyWith(
                                  color: AppColors.cyan, fontSize: 12)),
                        const SizedBox(height: 6),
                        Row(children: [
                          _chip(_modeLabel(mode), AppColors.violet),
                          const SizedBox(width: 6),
                          if (chapters > 0)
                            _chip('$chapters chapters', AppColors.cyan),
                          const Spacer(),
                          Text(date,
                              style:
                                  AppTextStyles.label.copyWith(fontSize: 10)),
                        ]),
                      ])),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted),
                ]))));
  }

  Widget _chip(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)));

  Widget _buildFAB() {
    return GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _openGenerateFlow();
        },
        child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                gradient: AppColors.primaryGrad,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.violet.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ]),
            child:
                const Icon(Icons.add_rounded, color: Colors.white, size: 28)));
  }

  void _openGenerateFlow() async {
    // ✅ FIXED
    final result = await Navigator.push<bool>(
        context,
        PageRouteBuilder<bool>(
            pageBuilder: (_, animation, __) => const _GenerateNotesScreen(),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeOut)),
                    child: child)),
            transitionDuration: const Duration(milliseconds: 350)));
    if (result == true) _loadNotes();
  }

  void _openNoteViewer(String id, String title) {
    Navigator.push(
        context, fadeSlideRoute(_NoteViewerScreen(noteId: id, title: title)));
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'single':
        return 'Single Chapter';
      case 'multiple':
        return 'Multi Chapter';
      case 'full':
        return 'Full Document';
      default:
        return mode;
    }
  }
}

// ══════════════════════════════════════════
// GENERATE NOTES SCREEN
// Step 1: Upload PDF
// Step 2: Scan → select chapters
// Step 3: Configure title/subject/mode
// Step 4: Generate → loading → done
// ══════════════════════════════════════════

class _GenerateNotesScreen extends StatefulWidget {
  const _GenerateNotesScreen();
  @override
  State<_GenerateNotesScreen> createState() => _GenerateNotesScreenState();
}

class _GenerateNotesScreenState extends State<_GenerateNotesScreen> {
  int _step = 0; // 0=upload, 1=configure, 2=generating, 3=done

  // File
  File? _pdfFile;
  String _fileName = '';

  // Scan results
  String _documentType = 'plain';
  List<String> _divisions = [];

  // Config
  final _titleCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  String _mode = 'full';
  String? _selectedChapter;
  List<String> _selectedChapters = [];

  bool _scanning = false;
  bool _generating = false;
  String? _error;
  String _generatingStatus = 'Analyzing your PDF...';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPDF() async {
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;

      setState(() {
        _pdfFile = File(path);
        _fileName = result.files.first.name;
        _error = null;
      });

      await _scanPDF();
    } catch (e) {
      setState(() => _error = 'Could not pick file. Please try again.');
    }
  }

  Future<void> _scanPDF() async {
    if (_pdfFile == null) return;
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final res = await NotesService.scanPDF(_pdfFile!);
      setState(() {
        _documentType = res['documentType'] as String? ?? 'plain';
        _divisions = (res['divisions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        _scanning = false;
        _step = 1;
        // Auto-set title from filename
        if (_titleCtrl.text.isEmpty) {
          _titleCtrl.text = _fileName.replaceAll('.pdf', '');
        }
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _scanning = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to scan PDF';
        _scanning = false;
      });
    }
  }

  Future<void> _generate() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a title');
      return;
    }
    if (_mode == 'single' &&
        (_selectedChapter == null || _selectedChapter!.isEmpty)) {
      setState(() => _error = 'Please select a chapter');
      return;
    }
    if (_mode == 'multiple' && _selectedChapters.isEmpty) {
      setState(() => _error = 'Please select at least one chapter');
      return;
    }

    setState(() {
      _step = 2;
      _generating = true;
      _error = null;
    });

    // Cycle status messages while generating
    _cycleStatus();

    try {
      await NotesService.generateNotes(
        pdfFile: _pdfFile!,
        title: _titleCtrl.text.trim(),
        mode: _mode,
        subject:
            _subjectCtrl.text.trim().isEmpty ? null : _subjectCtrl.text.trim(),
        chapter: _mode == 'single' ? _selectedChapter : null,
        chapters: _mode == 'multiple' ? _selectedChapters : null,
      );
      if (mounted)
        setState(() {
          _step = 3;
          _generating = false;
        });
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          _error = e.message;
          _step = 1;
          _generating = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _error = 'Generation failed. Please try again.';
          _step = 1;
          _generating = false;
        });
    }
  }

  void _cycleStatus() {
    final messages = [
      'Analyzing your PDF...',
      'Extracting key concepts...',
      'Organizing information...',
      'Writing study notes...',
      'Almost done...',
    ];
    int i = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || !_generating) return false;
      setState(() => _generatingStatus = messages[i % messages.length]);
      i++;
      return _generating;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(children: [
          const SpaceBackground(),
          SafeArea(
              child: Column(children: [
            _buildTopBar(),
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildCurrentStep())),
          ])),
        ]));
  }

  Widget _buildTopBar() {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textSub, size: 20),
              onPressed: () => Navigator.pop(context, false)),
          const Spacer(),
          if (_step < 3)
            Row(
                children: List.generate(3, (i) {
              final active = i == (_step == 2 ? 1 : _step);
              final done = i < (_step == 2 ? 1 : _step);
              return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: active ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                          gradient:
                              active || done ? AppColors.primaryGrad : null,
                          color: active || done ? null : AppColors.inputBorder,
                          borderRadius: BorderRadius.circular(4))));
            })),
          const Spacer(),
          const SizedBox(width: 44),
        ]));
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildUploadStep();
      case 1:
        return _buildConfigStep();
      case 2:
        return _buildGeneratingStep();
      case 3:
        return _buildDoneStep();
      default:
        return _buildUploadStep();
    }
  }

  // ── STEP 0: Upload ────────────────────
  Widget _buildUploadStep() {
    return Column(children: [
      const SizedBox(height: 40),
      Center(
          child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                  color: AppColors.violet.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.violet.withOpacity(0.3))),
              child: const Center(
                  child: Text('📤', style: TextStyle(fontSize: 44))))),
      const SizedBox(height: 24),
      ShaderMask(
          shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
          child: const Text('Upload PDF',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFamily: 'Georgia'))),
      const SizedBox(height: 8),
      const Text(
          'Upload your textbook or notes PDF\nto generate AI study notes',
          style: AppTextStyles.sub,
          textAlign: TextAlign.center),
      const SizedBox(height: 40),

      if (_error != null) ...[
        buildErrorBanner(_error!),
        const SizedBox(height: 20)
      ],

      // Drop zone
      GestureDetector(
          onTap: _scanning ? null : _pickPDF,
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                  color: _pdfFile != null
                      ? AppColors.violet.withOpacity(0.08)
                      : AppColors.inputBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: _pdfFile != null
                          ? AppColors.violet
                          : AppColors.inputBorder,
                      width: _pdfFile != null ? 2 : 1.5,
                      style: BorderStyle.solid)),
              child: _scanning
                  ? Column(children: [
                      const CircularProgressIndicator(color: AppColors.violet),
                      const SizedBox(height: 16),
                      const Text('Scanning document...',
                          style: AppTextStyles.sub,
                          textAlign: TextAlign.center),
                    ])
                  : _pdfFile != null
                      ? Column(children: [
                          const Text('📄', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text(_fileName,
                              style: const TextStyle(
                                  color: AppColors.textWhite,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text('Tap to change file',
                              style: AppTextStyles.body.copyWith(
                                  color: AppColors.violet, fontSize: 12)),
                        ])
                      : Column(children: [
                          const Text('📁', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          const Text('Tap to select PDF',
                              style: TextStyle(
                                  color: AppColors.textWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          const Text('Supports PDF files up to 100MB',
                              style: AppTextStyles.sub),
                        ]))),

      const SizedBox(height: 24),
      if (_pdfFile != null && !_scanning)
        GlowButton(
            text: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => setState(() => _step = 1)),
      const SizedBox(height: 40),
    ]);
  }

  // ── STEP 1: Configure ─────────────────
  Widget _buildConfigStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      Row(children: [
        ShaderMask(
            shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
            child: const Text('Configure Notes',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Georgia'))),
        const Spacer(),
        // Document type badge
        _docTypeBadge(),
      ]),
      const SizedBox(height: 4),
      Text(
          _divisions.isEmpty
              ? 'Plain document — full notes will be generated'
              : '${_divisions.length} ${_documentType == 'book' ? 'chapters' : 'sections'} detected',
          style: AppTextStyles.sub),
      const SizedBox(height: 28),
      if (_error != null) ...[
        buildErrorBanner(_error!),
        const SizedBox(height: 20)
      ],
      GlassCard(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AppTextField(
                label: 'Notes Title',
                hint: 'e.g. Physics Chapter 1 Notes',
                controller: _titleCtrl,
                prefixIcon: Icons.title_rounded),

            const SizedBox(height: 16),

            AppTextField(
                label: 'Subject (optional)',
                hint: 'e.g. Physics, Mathematics',
                controller: _subjectCtrl,
                prefixIcon: Icons.book_outlined),

            // Mode selector — only show if chapters exist
            if (_divisions.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('GENERATE MODE', style: AppTextStyles.label),
              const SizedBox(height: 10),
              Row(children: [
                _modeChip('full', '📚 Full Doc'),
                const SizedBox(width: 8),
                _modeChip('single', '📖 Single'),
                const SizedBox(width: 8),
                _modeChip('multiple', '📑 Multiple'),
              ]),
            ],

            // Single chapter selector
            if (_mode == 'single' && _divisions.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('SELECT CHAPTER', style: AppTextStyles.label),
              const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: AppColors.inputBorder, width: 1.5)),
                  child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                          value: _selectedChapter,
                          hint: const Text('Select chapter',
                              style: TextStyle(color: AppColors.textMuted)),
                          dropdownColor: AppColors.bgCard,
                          style: const TextStyle(color: AppColors.textWhite),
                          isExpanded: true,
                          items: _divisions
                              .map((d) => DropdownMenuItem(
                                  value: d,
                                  child:
                                      Text(d, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedChapter = v)))),
            ],

            // Multiple chapters selector
            if (_mode == 'multiple' && _divisions.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('SELECT CHAPTERS', style: AppTextStyles.label),
              const SizedBox(height: 10),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _divisions.map((d) {
                    final sel = _selectedChapters.contains(d);
                    return GestureDetector(
                        onTap: () => setState(() {
                              if (sel)
                                _selectedChapters.remove(d);
                              else
                                _selectedChapters.add(d);
                            }),
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                                gradient: sel ? AppColors.primaryGrad : null,
                                color: sel ? null : AppColors.inputBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: sel
                                        ? Colors.transparent
                                        : AppColors.inputBorder)),
                            child: Text(d,
                                style: TextStyle(
                                    color:
                                        sel ? Colors.white : AppColors.textSub,
                                    fontSize: 12,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.w400),
                                overflow: TextOverflow.ellipsis)));
                  }).toList()),
            ],
          ])),
      const SizedBox(height: 24),
      GlowButton(
          text: 'Generate Notes',
          icon: Icons.auto_awesome_rounded,
          onPressed: _generate),
      const SizedBox(height: 40),
    ]);
  }

  // ── STEP 2: Generating ────────────────
  Widget _buildGeneratingStep() {
    return SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Pulsing animation
          TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.1),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeInOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                      gradient: AppColors.primaryGrad,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.violet.withOpacity(0.5),
                            blurRadius: 40,
                            offset: const Offset(0, 12))
                      ]),
                  child: const Center(
                      child: Text('🤖', style: TextStyle(fontSize: 52))))),
          const SizedBox(height: 32),
          ShaderMask(
              shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
              child: const Text('Generating Notes',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'Georgia'))),
          const SizedBox(height: 12),
          AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(_generatingStatus,
                  key: ValueKey(_generatingStatus),
                  style: AppTextStyles.sub,
                  textAlign: TextAlign.center)),
          const SizedBox(height: 32),
          const CircularProgressIndicator(
              color: AppColors.violet, strokeWidth: 3),
          const SizedBox(height: 24),
          GlassCard(
              child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.violetLight, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text('This may take 1-3 minutes depending on PDF size.',
                    style: AppTextStyles.body.copyWith(fontSize: 12))),
          ])),
        ]));
  }

  // ── STEP 3: Done ──────────────────────
  Widget _buildDoneStep() {
    return SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                  gradient: AppColors.primaryGrad,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.violet.withOpacity(0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 12))
                  ]),
              child: const Center(
                  child: Text('🎉', style: TextStyle(fontSize: 52)))),
          const SizedBox(height: 28),
          ShaderMask(
              shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
              child: const Text('Notes Generated!',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'Georgia'))),
          const SizedBox(height: 10),
          Text('"${_titleCtrl.text}"',
              style: AppTextStyles.sub.copyWith(color: AppColors.cyan),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          GlowButton(
              text: 'View Notes',
              icon: Icons.visibility_rounded,
              onPressed: () => Navigator.pop(context, true)),
          const SizedBox(height: 14),
          TextButton(
              onPressed: () => setState(() {
                    _step = 0;
                    _pdfFile = null;
                    _fileName = '';
                    _titleCtrl.clear();
                    _subjectCtrl.clear();
                    _divisions = [];
                    _selectedChapter = null;
                    _selectedChapters = [];
                    _mode = 'full';
                  }),
              child: const Text('Generate Another', style: AppTextStyles.link)),
        ]));
  }

  Widget _docTypeBadge() {
    final label = _documentType == 'book'
        ? '📖 Book'
        : _documentType == 'document'
            ? '📄 Document'
            : '📝 Plain';
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: AppColors.violet.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.violet.withOpacity(0.3))),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.violetLight,
                fontSize: 12,
                fontWeight: FontWeight.w600)));
  }

  Widget _modeChip(String value, String label) {
    final sel = _mode == value;
    return Expanded(
        child: GestureDetector(
            onTap: () => setState(() {
                  _mode = value;
                  _selectedChapter = null;
                  _selectedChapters = [];
                }),
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    gradient: sel ? AppColors.primaryGrad : null,
                    color: sel ? null : AppColors.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            sel ? Colors.transparent : AppColors.inputBorder)),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: sel ? Colors.white : AppColors.textSub,
                        fontSize: 12,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.w400)))));
  }
}

// ══════════════════════════════════════════
// NOTE VIEWER SCREEN
// Displays full note content chapter by chapter
// ══════════════════════════════════════════

class _NoteViewerScreen extends StatefulWidget {
  final String noteId;
  final String title;
  const _NoteViewerScreen({required this.noteId, required this.title});
  @override
  State<_NoteViewerScreen> createState() => _NoteViewerScreenState();
}

class _NoteViewerScreenState extends State<_NoteViewerScreen> {
  Map<String, dynamic>? _note;
  bool _loading = true;
  String? _error;
  int _selectedChapter = 0;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    setState(() => _loading = true);
    try {
      final res = await NotesService.getNoteById(widget.noteId);
      if (mounted)
        setState(() {
          _note = res['note'] as Map<String, dynamic>?;
          _loading = false;
        });
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          _error = e.message;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _error = 'Failed to load note';
          _loading = false;
        });
    }
  }

  List<Map<String, dynamic>> get _chapters {
    final list = _note?['chapters'] as List<dynamic>? ?? [];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(children: [
          const SpaceBackground(),
          SafeArea(
              child: Column(children: [
            // Header
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textSub, size: 20),
                      onPressed: () => Navigator.pop(context)),
                  Expanded(
                      child: Text(widget.title,
                          style: const TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis)),
                  IconButton(
                      icon: const Icon(Icons.share_outlined,
                          color: AppColors.textSub, size: 20),
                      onPressed: () {}),
                ])),
            Expanded(
                child: _loading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.violet))
                    : _error != null
                        ? Center(child: buildErrorBanner(_error!))
                        : _buildContent()),
          ])),
        ]));
  }

  Widget _buildContent() {
    if (_chapters.isEmpty) {
      return const Center(
          child: Text('No content available', style: AppTextStyles.sub));
    }

    return Column(children: [
      // Chapter tabs (if multiple)
      if (_chapters.length > 1)
        SizedBox(
            height: 48,
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _chapters.length,
                itemBuilder: (_, i) {
                  final sel = i == _selectedChapter;
                  final name = _chapters[i]['chapterName'] as String? ??
                      'Chapter ${i + 1}';
                  return GestureDetector(
                      onTap: () => setState(() => _selectedChapter = i),
                      child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                              gradient: sel ? AppColors.primaryGrad : null,
                              color: sel ? null : AppColors.bgCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: sel
                                      ? Colors.transparent
                                      : AppColors.inputBorder)),
                          child: Text(name,
                              style: TextStyle(
                                  color: sel ? Colors.white : AppColors.textSub,
                                  fontSize: 12,
                                  fontWeight:
                                      sel ? FontWeight.w700 : FontWeight.w400),
                              overflow: TextOverflow.ellipsis)));
                })),

      // Note content
      Expanded(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chapter title
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFF1A1060), Color(0xFF0D1535)]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.violet.withOpacity(0.3))),
                        child: Row(children: [
                          const Text('📖', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  _chapters[_selectedChapter]['chapterName']
                                          as String? ??
                                      'Notes',
                                  style: const TextStyle(
                                      color: AppColors.textWhite,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700))),
                        ])),

                    const SizedBox(height: 20),

                    // Notes text — formatted with markdown-like rendering
                    _buildFormattedNotes(
                        _chapters[_selectedChapter]['notes'] as String? ?? ''),

                    const SizedBox(height: 40),
                  ]))),
    ]);
  }

  Widget _buildFormattedNotes(String text) {
    // Split into paragraphs and render nicely
    final lines = text.split('\n');
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) return const SizedBox(height: 8);

          // Heading line (starts with # or ##)
          if (trimmed.startsWith('## ')) {
            return Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Text(trimmed.substring(3),
                    style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)));
          }
          if (trimmed.startsWith('# ')) {
            return Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 8),
                child: ShaderMask(
                    shaderCallback: (b) =>
                        AppColors.primaryGrad.createShader(b),
                    child: Text(trimmed.substring(2),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800))));
          }

          // Bullet point
          if (trimmed.startsWith('- ') || trimmed.startsWith('• ')) {
            return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          margin: const EdgeInsets.only(top: 6, right: 10),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: AppColors.violet, shape: BoxShape.circle)),
                      Expanded(
                          child: Text(trimmed.substring(2),
                              style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 14,
                                  height: 1.6))),
                    ]));
          }

          // Bold line (starts with **)
          if (trimmed.startsWith('**') && trimmed.endsWith('**')) {
            return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(trimmed.replaceAll('**', ''),
                    style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)));
          }

          // Regular paragraph
          return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(trimmed,
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 14, height: 1.7)));
        }).toList());
  }
}

// ── Snackbar helper ───────────────────────
SnackBar _snackBar(String msg, Color color) => SnackBar(
    content: Text(msg, style: const TextStyle(color: Colors.white)),
    backgroundColor: color.withOpacity(0.9),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.all(16));
