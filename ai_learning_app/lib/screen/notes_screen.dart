import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
// Removed conflicting import; using pdfx's PdfDocument
import 'package:pdf/pdf.dart' as pdf_lib;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import '../services/api_client.dart';
import 'smart_reader_screen.dart';
import '../widgets/share_to_group_dialog.dart';

// ══════════════════════════════════════════
// NOTES SCREEN — 2 states:
// 1. NotesList  — shows all AI-generated notes
// 2. NoteViewer — read a single AI note
// + Document Reader — open & view any document
// ══════════════════════════════════════════

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _notes = [];
  bool _loading = false;
  String? _error;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.value = 1.0;
    _loadNotes();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    try {
      final res = await NotesService.getMyNotes().timeout(const Duration(seconds: 4));
      final list = res['notes'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _notes = list.map((e) => e as Map<String, dynamic>).toList();
          _loading = false;
        });
        _fadeCtrl.forward(from: 0);
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.isApiLimitError) {
          Navigator.pushNamed(context, '/settings/api-keys').then((keySaved) {
            if (keySaved == true && mounted) _loadNotes();
          });
        } else {
          setState(() {
            _error = e.message;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load notes';
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteNote(String id) async {
    try {
      await NotesService.deleteNote(id);
      setState(() => _notes.removeWhere((n) => n['_id'] == id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(_snackBar('Note deleted', AppColors.error));
      }
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
        Positioned(bottom: 24, right: 24, child: _buildFAB()),
      ]),
    );
  }

  Widget _buildHeader() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ShaderMask(
                  shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
                  child: const Text('Smart AI Reader',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'Georgia'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              Text(
                  'Auditory Doc & Study Studio',
                  style: AppTextStyles.sub.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openDocumentReader,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                  gradient: AppColors.primaryGrad,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.violet.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.headset_rounded, color: Colors.white, size: 15),
                  SizedBox(width: 4),
                  Text('Upload & Listen',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          IconButton(
              padding: const EdgeInsets.only(left: 4),
              constraints: const BoxConstraints(),
              onPressed: _loadNotes,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSub, size: 20)),
        ]));
  }

  Widget _buildEmpty() {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(32),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                      color: AppColors.violet.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                          color: AppColors.violet.withValues(alpha: 0.25))),
                  child: const Center(
                      child: Icon(Icons.record_voice_over_rounded,
                          color: AppColors.violetLight, size: 46))),
              const SizedBox(height: 24),
              ShaderMask(
                  shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
                  child: const Text('Auditory Doc Reader',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Georgia'))),
              const SizedBox(height: 10),
              const Text(
                  'Upload any document (PDF, TXT, MD, Code) or open saved study notes to read out loud with real-time sentence & glowing word highlighting.',
                  style: AppTextStyles.sub,
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),
              GlowButton(
                  text: 'Upload Document to Listen',
                  icon: Icons.folder_open_rounded,
                  onPressed: _openDocumentReader),
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
            child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                itemCount: _notes.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) return _buildHeroUploadBanner();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _noteCard(_notes[i - 1]),
                  );
                })));
  }

  Widget _buildHeroUploadBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.violet.withValues(alpha: 0.25),
            AppColors.bgCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.violet.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGrad,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.record_voice_over_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auditory Document Reader',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Listen to any document with glowing word highlights',
                      style: AppTextStyles.sub.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Open any PDF, Text, Markdown, or Code file to read & listen with dynamic speed control and line highlighting.',
            style: TextStyle(color: AppColors.textLight, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openDocumentReader,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Open File to Read & Listen',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noteCard(Map<String, dynamic> note) {
    final title = note['title'] as String? ?? 'Untitled';
    final subject = note['subject'] as String? ?? '';
    final mode = note['mode'] as String? ?? 'full';
    final chapters = (note['detectedChapters'] as List<dynamic>?)?.length ?? 0;
    final date = _formatDate(note['createdAt'] as String?);
    final docType = note['documentType'] as String? ?? 'plain';

    return GestureDetector(
        onTap: () => _openNoteViewer(note['_id'] as String, title),
        onLongPress: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Note'),
              content:
                  const Text('Are you sure you want to delete this note?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true) _deleteNote(note['_id'] as String);
        },
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
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.cyan, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Flexible(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _chip(_modeLabel(mode), AppColors.violet),
                            if (chapters > 0)
                              _chip('$chapters chapters', AppColors.cyan),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(date,
                          style: AppTextStyles.label.copyWith(fontSize: 10)),
                    ]),
                  ])),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
            ])));
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
          _openDocumentReader();
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
            child: const Icon(Icons.folder_open_rounded,
                color: Colors.white, size: 28)));
  }

  void _openDocumentReader() async {
    await Navigator.push(
        context,
        PageRouteBuilder(
            pageBuilder: (_, animation, __) => const SmartReaderScreen(),
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
  }

  void _openNoteViewer(String id, String title) {
    Navigator.push(
        context, fadeSlideRoute(NoteViewerScreen(noteId: id, title: title)));
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
// DOCUMENT READER SCREEN
// Supports: PDF (pdfx, lazy-paged, pinch-zoom), TXT, Markdown,
// source code (Dart, JS, Python, Java, etc.), JSON, YAML,
// HTML, XML, CSV, log files — handles any file size smoothly.
// ══════════════════════════════════════════

enum _DocType { pdf, text, unknown }

class DocumentReaderScreen extends StatefulWidget {
  final String? initialFilePath;
  final bool startAuditory;
  const DocumentReaderScreen({super.key, this.initialFilePath, this.startAuditory = true});
  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen>
    with TickerProviderStateMixin {
  // State
  File? _file;
  String _fileName = '';
  _DocType _docType = _DocType.unknown;
  bool _loading = false;
  String? _error;

  // PDF
  PdfControllerPinch? _pdfController;
  int _pdfPage = 1;
  int _pdfTotalPages = 0;

  // Text
  String _textContent = '';
  final ScrollController _textScroll = ScrollController();

  // Toolbar auto-hide
  bool _toolbarVisible = true;
  Timer? _toolbarTimer;
  late AnimationController _toolbarCtrl;
  late Animation<double> _toolbarAnim;

  // Search
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Auditory Reader
  bool _isAuditoryMode = true;

  static const _textExtensions = {
    'txt', 'md', 'markdown', 'log', 'csv',
    'dart', 'js', 'ts', 'jsx', 'tsx',
    'json', 'yaml', 'yml', 'toml',
    'py', 'java', 'kt', 'swift', 'c', 'cpp', 'h', 'hpp',
    'html', 'htm', 'css', 'scss', 'xml',
    'sh', 'bash', 'sql', 'rb', 'go', 'rs',
  };

  static const _codeExtensions = {
    'dart', 'js', 'ts', 'jsx', 'tsx',
    'json', 'yaml', 'yml', 'toml',
    'py', 'java', 'kt', 'swift', 'c', 'cpp', 'h', 'hpp',
    'html', 'htm', 'css', 'scss', 'xml',
    'sh', 'bash', 'sql', 'rb', 'go', 'rs', 'md', 'markdown',
  };

  @override
  void initState() {
    super.initState();
    _isAuditoryMode = widget.startAuditory;
    _toolbarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _toolbarAnim = CurvedAnimation(parent: _toolbarCtrl, curve: Curves.easeOut);
    _toolbarCtrl.value = 1.0;
    _resetToolbarTimer();

    if (widget.initialFilePath != null) {
      _loadFile(File(widget.initialFilePath!));
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    _textScroll.dispose();
    _toolbarTimer?.cancel();
    _toolbarCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── File loading ──────────────────────

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          ..._textExtensions,
        ],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;
      await _loadFile(File(path));
    } catch (e) {
      setState(() => _error = 'Could not open file: $e');
    }
  }

  Future<void> _loadFile(File file) async {
    final name = file.path.replaceAll('\\', '/').split('/').last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';

    setState(() {
      _loading = true;
      _error = null;
      _file = file;
      _fileName = name;
      _textContent = '';
      _searchQuery = '';
      _searchCtrl.clear();
      _searchOpen = false;
    });

    _pdfController?.dispose();
    _pdfController = null;

    if (ext == 'pdf') {
      await _loadPDF(file);
    } else if (_textExtensions.contains(ext) || ext.isEmpty) {
      await _loadTextFile(file);
    } else {
      setState(() {
        _error = 'Unsupported file type: .$ext';
        _loading = false;
        _docType = _DocType.unknown;
      });
    }
  }

  Future<void> _loadPDF(File file) async {
    try {
      final controller = PdfControllerPinch(
        document: PdfDocument.openFile(file.path),
      );
      controller.addListener(() {
        if (mounted) {
          setState(() {
            _pdfPage = controller.page;
            _pdfTotalPages = controller.pagesCount ?? 0;
          });
        }
      });
      if (mounted) {
        setState(() {
          _pdfController = controller;
          _docType = _DocType.pdf;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to open PDF: $e';
          _loading = false;
          _docType = _DocType.unknown;
        });
      }
    }
  }

  Future<void> _loadTextFile(File file) async {
    try {
      final size = await file.length();
      String content;
      const maxBytes = 5 * 1024 * 1024; // 5 MB cap
      if (size > maxBytes) {
        final raf = await file.open();
        final bytes = await raf.read(maxBytes);
        await raf.close();
        content = String.fromCharCodes(bytes);
        content +=
            '\n\n─────────────────────────────────────────\n'
            '⚠️  Preview truncated at 5 MB for performance.\n'
            '    Use "Share" to open in your system viewer for full content.\n'
            '─────────────────────────────────────────';
      } else {
        content = await file.readAsString();
      }
      if (mounted) {
        setState(() {
          _textContent = content;
          _docType = _DocType.text;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to read file: $e';
          _loading = false;
          _docType = _DocType.unknown;
        });
      }
    }
  }

  // ── Toolbar auto-hide ─────────────────

  void _toggleToolbar() {
    setState(() => _toolbarVisible = !_toolbarVisible);
    if (_toolbarVisible) {
      _toolbarCtrl.forward();
      _resetToolbarTimer();
    } else {
      _toolbarTimer?.cancel();
      _toolbarCtrl.reverse();
    }
  }

  void _keepToolbar() {
    if (!_toolbarVisible) {
      setState(() => _toolbarVisible = true);
      _toolbarCtrl.forward();
    }
    _resetToolbarTimer();
  }

  void _resetToolbarTimer() {
    _toolbarTimer?.cancel();
    if (!_searchOpen && !_isAuditoryMode) {
      _toolbarTimer = Timer(const Duration(seconds: 8), () {
        if (mounted && _toolbarVisible && !_searchOpen && !_isAuditoryMode) {
          setState(() => _toolbarVisible = false);
          _toolbarCtrl.reverse();
        }
      });
    }
  }

  // ── Share ─────────────────────────────

  Future<void> _shareFile() async {
    if (_file == null) return;
    await Share.shareXFiles([XFile(_file!.path)], text: _fileName);
  }

  void _openInSmartReader() {
    if (_file == null && _textContent.isEmpty) return;
    Navigator.push(
      context,
      fadeSlideRoute(SmartReaderScreen(
        initialFilePath: _file?.path,
        initialText: _docType == _DocType.text ? _textContent : null,
        title: _fileName,
        autoPlay: true,
      )),
    );
  }

  // ── Build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const SpaceBackground(),
        SafeArea(
          child: Column(
            children: [
              FadeTransition(
                opacity: _toolbarAnim,
                child: _buildTopBar(),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
        if (_docType == _DocType.pdf && _pdfTotalPages > 0 && !_isAuditoryMode)
          Positioned(
            bottom: 76,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _toolbarAnim,
              child: _buildPageIndicator(),
            ),
          ),
        if (_file != null && !_loading && _error == null)
          Positioned(
            bottom: 20,
            left: 24,
            right: 24,
            child: FadeTransition(
              opacity: _toolbarAnim,
              child: Center(
                child: GestureDetector(
                  onTap: _openInSmartReader,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGrad,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.violet.withOpacity(0.5),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Listen Aloud (Smart Reader)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildBody() {
    if (_file == null && !_loading) return _buildLanding();
    if (_loading) return _buildLoadingView();
    if (_error != null) return _buildErrorView();
    switch (_docType) {
      case _DocType.pdf:
        return _buildPDFView();
      case _DocType.text:
        return _buildTextView();
      case _DocType.unknown:
        return _buildErrorView();
    }
  }

  // ── Landing ───────────────────────────

  Widget _buildLanding() {
    return Column(children: [
      _buildTopBar(),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                        gradient: AppColors.primaryGrad,
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.violet.withOpacity(0.45),
                              blurRadius: 40,
                              offset: const Offset(0, 16))
                        ]),
                    child: const Center(
                        child: Text('📖', style: TextStyle(fontSize: 58))),
                  ),
                  const SizedBox(height: 32),
                  ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.primaryGrad.createShader(b),
                      child: const Text('Document Reader',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontFamily: 'Georgia'))),
                  const SizedBox(height: 12),
                  const Text(
                      'Open and read any document — PDFs, text files,\n'
                      'code, markdown, CSV, JSON, XML, and more.',
                      style: AppTextStyles.sub,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      'PDF', 'TXT', 'MD', 'JSON', 'YAML',
                      'Dart', 'JS', 'Python', 'Java', 'CSV', 'HTML', 'XML',
                      'C/C++', 'SQL', 'Go', 'Rust',
                    ]
                        .map((f) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: AppColors.violet.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          AppColors.violet.withOpacity(0.3))),
                              child: Text(f,
                                  style: const TextStyle(
                                      color: AppColors.violetLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 40),
                  GlowButton(
                      text: 'Choose File',
                      icon: Icons.folder_open_rounded,
                      onPressed: _pickFile),
                ]),
          ),
        ),
      ),
    ]);
  }

  // ── Loading ───────────────────────────

  Widget _buildLoadingView() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1.1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                    gradient: AppColors.primaryGrad,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.violet.withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 10))
                    ]),
                child: const Center(
                    child: Text('📄', style: TextStyle(fontSize: 44))))),
        const SizedBox(height: 28),
        const CircularProgressIndicator(
            color: AppColors.violet, strokeWidth: 3),
        const SizedBox(height: 20),
        Text('Opening $_fileName…',
            style: AppTextStyles.sub, textAlign: TextAlign.center),
      ]),
    );
  }

  // ── Error ─────────────────────────────

  Widget _buildErrorView() {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  buildErrorBanner(_error ?? 'Unknown error'),
                  const SizedBox(height: 24),
                  GlowButton(
                      text: 'Choose Another File',
                      icon: Icons.folder_open_rounded,
                      onPressed: _pickFile),
                ])));
  }

  // ── PDF View ──────────────────────────

  Widget _buildPDFView() {
    return GestureDetector(
      onTap: _toggleToolbar,
      child: PdfViewPinch(
        controller: _pdfController!,
        onPageChanged: (page) {
          setState(() => _pdfPage = page);
          _keepToolbar();
        },
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(
            loaderSwitchDuration: Duration(milliseconds: 300),
          ),
          documentLoaderBuilder: (_) => const Center(
              child: CircularProgressIndicator(color: AppColors.violet)),
          pageLoaderBuilder: (_) => const SizedBox.shrink(),
          errorBuilder: (_, e) =>
              Center(child: buildErrorBanner('Render error: $e')),
        ),
      ),
    );
  }

  // ── Text View ─────────────────────────

  Widget _buildTextView() {
    final ext = _fileName.contains('.')
        ? _fileName.split('.').last.toLowerCase()
        : 'txt';
    final isCode = _codeExtensions.contains(ext);

    final topPad = kToolbarHeight + MediaQuery.of(context).padding.top + 8;

    return GestureDetector(
      onTap: _toggleToolbar,
      child: Scrollbar(
        controller: _textScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _textScroll,
          padding:
              EdgeInsets.fromLTRB(16, topPad, 16, 80),
          child: _searchQuery.isNotEmpty
              ? SelectableText.rich(
                  _buildHighlightedText(_textContent, _searchQuery),
                  style: _textStyle(isCode),
                )
              : SelectableText(
                  _textContent,
                  style: _textStyle(isCode),
                ),
        ),
      ),
    );
  }

  TextStyle _textStyle(bool isCode) => TextStyle(
        fontFamily: isCode ? 'monospace' : null,
        fontSize: isCode ? 13 : 15,
        color: isCode ? const Color(0xFFD4D4D4) : AppColors.textLight,
        height: isCode ? 1.55 : 1.75,
        letterSpacing: isCode ? 0.3 : null,
      );

  TextSpan _buildHighlightedText(String text, String query) {
    if (query.isEmpty) return TextSpan(text: text);
    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lower.indexOf(lowerQ, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
          text: text.substring(idx, idx + query.length),
          style: const TextStyle(
              backgroundColor: Color(0xFFFFD700),
              color: Colors.black,
              fontWeight: FontWeight.w700)));
      start = idx + query.length;
    }
    return TextSpan(children: spans);
  }

  // ── Top Bar ───────────────────────────

  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bg.withOpacity(0.98),
            AppColors.bg.withOpacity(0.0),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textSub, size: 20),
                  onPressed: () => Navigator.pop(context)),
              Expanded(
                  child: _file == null
                      ? ShaderMask(
                          shaderCallback: (b) =>
                              AppColors.primaryGrad.createShader(b),
                          child: const Text('Document Reader',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              Text(_fileName,
                                  style: const TextStyle(
                                      color: AppColors.textWhite,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis),
                              if (_docType == _DocType.pdf &&
                                  _pdfTotalPages > 0)
                                Text('Page $_pdfPage of $_pdfTotalPages',
                                    style: AppTextStyles.label
                                        .copyWith(fontSize: 10)),
                            ])),
              if (_file != null)
                IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.violet.withOpacity(0.22),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.violetLight.withOpacity(0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.record_voice_over_rounded,
                        color: AppColors.violetLight,
                        size: 18,
                      ),
                    ),
                    tooltip: 'Listen Aloud with Smart Reader',
                    onPressed: _openInSmartReader),
              if (_file != null && _docType == _DocType.text)
                IconButton(
                    icon: Icon(
                        _searchOpen
                            ? Icons.search_off_rounded
                            : Icons.search_rounded,
                        color: _searchOpen
                            ? AppColors.violet
                            : AppColors.textSub,
                        size: 20),
                    tooltip: 'Search in document',
                    onPressed: () {
                      setState(() {
                        _searchOpen = !_searchOpen;
                        if (!_searchOpen) {
                          _searchQuery = '';
                          _searchCtrl.clear();
                        }
                      });
                      if (_searchOpen) {
                        _toolbarTimer?.cancel();
                      } else {
                        _resetToolbarTimer();
                      }
                    }),
              if (_file != null)
                IconButton(
                    icon: const Icon(Icons.folder_open_rounded,
                        color: AppColors.textSub, size: 20),
                    tooltip: 'Open Another File',
                    onPressed: _pickFile),
              if (_file != null)
                IconButton(
                    icon: const Icon(Icons.share_outlined,
                        color: AppColors.textSub, size: 20),
                    tooltip: 'Share File',
                    onPressed: _shareFile),
            ]),
          ),
          // Search bar
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                    color: AppColors.inputBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.violet.withOpacity(0.4))),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style:
                      const TextStyle(color: AppColors.textWhite, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search in document…',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textMuted, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: AppColors.textMuted, size: 16),
                            onPressed: () {
                              setState(() => _searchQuery = '');
                              _searchCtrl.clear();
                            })
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Page indicator ────────────────────

  Widget _buildPageIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.bgCard.withOpacity(0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.inputBorder),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: _pdfPage > 1
                ? () => _pdfController?.jumpToPage(_pdfPage - 1)
                : null,
            child: Icon(Icons.chevron_left_rounded,
                color: _pdfPage > 1 ? AppColors.textSub : AppColors.textMuted,
                size: 22),
          ),
          const SizedBox(width: 10),
          Text('$_pdfPage / $_pdfTotalPages',
              style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _pdfPage < _pdfTotalPages
                ? () => _pdfController?.jumpToPage(_pdfPage + 1)
                : null,
            child: Icon(Icons.chevron_right_rounded,
                color: _pdfPage < _pdfTotalPages
                    ? AppColors.textSub
                    : AppColors.textMuted,
                size: 22),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// NOTE VIEWER SCREEN
// Displays full AI-generated note content chapter by chapter
// ══════════════════════════════════════════

class NoteViewerScreen extends StatefulWidget {
  final String noteId;
  final String title;
  final bool fromGroup;
  const NoteViewerScreen(
      {required this.noteId, required this.title, this.fromGroup = false});
  @override
  State<NoteViewerScreen> createState() => _NoteViewerScreenState();
}

class _NoteViewerScreenState extends State<NoteViewerScreen> {
  Map<String, dynamic>? _note;
  bool _loading = true;
  String? _error;
  int _selectedChapter = 0;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  void _openVoiceStudy() {
    if (_chapters.isEmpty || _selectedChapter >= _chapters.length) return;
    final text = _chapters[_selectedChapter]['notes']?.toString() ??
        _chapters[_selectedChapter]['content']?.toString() ??
        '';
    if (text.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SmartReaderScreen(
          title: widget.title,
          initialText: text.replaceAll(RegExp(r'[*#_`~]'), ''),
        ),
      ),
    );
  }

  Future<void> _downloadPDF() async {
    if (_note == null) return;
    final title = _note!['title']?.toString() ?? widget.title;
    final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    try {
      final pdfDoc = pw.Document();
      final processedChapters = _prepareChapters();
      pdfDoc.addPage(pw.MultiPage(
        pageFormat: pdf_lib.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Generated by Lumio AI Study Companion',
              style: pw.TextStyle(
                  fontSize: 10,
                  color: pdf_lib.PdfColors.grey700,
                  fontStyle: pw.FontStyle.italic)),
          pw.SizedBox(height: 24),
          ...processedChapters.expand((c) => [
                if (c['name'].toString().isNotEmpty) ...[
                  pw.Text(c['name'].toString(),
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                ],
                if (c['content'].toString().isNotEmpty)
                  pw.Paragraph(text: c['content'].toString()),
                pw.SizedBox(height: 16),
              ]),
        ],
      ));
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final f = File('${downloadsDir.path}/$sanitizedTitle.pdf');
        await f.writeAsBytes(await pdfDoc.save());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('PDF saved: $sanitizedTitle.pdf'),
              backgroundColor: AppColors.success));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e'),
                backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _sharePDF() async {
    if (_note == null) return;
    final title = _note!['title']?.toString() ?? widget.title;
    final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    try {
      final pdfDoc = pw.Document();
      final processedChapters = _prepareChapters();
      pdfDoc.addPage(pw.MultiPage(
        pageFormat: pdf_lib.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Generated by Lumio AI Study Companion',
              style: pw.TextStyle(
                  fontSize: 10,
                  color: pdf_lib.PdfColors.grey700,
                  fontStyle: pw.FontStyle.italic)),
          pw.SizedBox(height: 24),
          ...processedChapters.expand((c) => [
                if (c['name'].toString().isNotEmpty) ...[
                  pw.Text(c['name'].toString(),
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                ],
                if (c['content'].toString().isNotEmpty)
                  pw.Paragraph(text: c['content'].toString()),
                pw.SizedBox(height: 16),
              ]),
        ],
      ));
      final tempDir = await getTemporaryDirectory();
      final f = File('${tempDir.path}/$sanitizedTitle.pdf');
      await f.writeAsBytes(await pdfDoc.save());
      await Share.shareXFiles([XFile(f.path)], text: 'Study Notes: $title');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Share failed: $e'),
                backgroundColor: AppColors.error));
      }
    }
  }

  List<Map<String, String>> _prepareChapters() {
    return _chapters.map((c) {
      final chName =
          c['chapterName']?.toString() ?? c['heading']?.toString() ?? '';
      final content = c['notes']?.toString() ?? c['content']?.toString() ?? '';
      final clean = content
          .replaceAll(RegExp(r'#{1,6}\s'), '')
          .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1')
          .replaceAll(RegExp(r'\*([^*]+)\*'), r'\1')
          .replaceAll(RegExp(r'`([^`]+)`'), r'\1')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
      return {'name': chName, 'content': clean};
    }).toList();
  }

  Future<void> _loadNote() async {
    setState(() => _loading = true);
    try {
      final res = await NotesService.getNoteById(widget.noteId);
      if (mounted) {
        setState(() {
          _note = res['note'] as Map<String, dynamic>?;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load note';
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text(
            'Are you sure you want to delete this note? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        await NotesService.deleteNote(widget.noteId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Note deleted successfully')));
        }
      } on ApiException catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete: ${e.message}')));
        }
      } catch (_) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Failed to delete')));
        }
      }
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
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      icon: const Icon(Icons.record_voice_over_rounded,
                          color: AppColors.cyan, size: 21),
                      tooltip: 'Read Aloud',
                      onPressed: _loading ? null : _openVoiceStudy),
                  IconButton(
                      icon: const Icon(Icons.file_download_outlined,
                          color: AppColors.textSub, size: 21),
                      tooltip: 'Download PDF',
                      onPressed: _loading ? null : _downloadPDF),
                  IconButton(
                      icon: const Icon(Icons.share_outlined,
                          color: AppColors.textSub, size: 20),
                      tooltip: 'Share PDF',
                      onPressed: _loading ? null : _sharePDF),
                  if (!widget.fromGroup)
                    IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.textSub, size: 20),
                        tooltip: 'Delete Note',
                        onPressed: _loading ? null : _deleteNote),
                  IconButton(
                      tooltip: 'Share to Study Group',
                      icon: const Icon(Icons.groups_outlined,
                          color: AppColors.textSub, size: 20),
                      onPressed: () async {
                        final shared = await showDialog<bool>(
                          context: context,
                          builder: (context) => ShareToGroupDialog(
                            contentId: widget.noteId,
                            isNote: true,
                          ),
                        );
                        if (shared == true && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Note shared with the group!'),
                                backgroundColor: AppColors.success),
                          );
                        }
                      }),
                ])),
            Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.violet))
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
    if (_selectedChapter >= _chapters.length) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => setState(() => _selectedChapter = 0));
    }

    final uniqueNames = _uniqueChapterNames();

    return Column(children: [
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
                          child: Text(uniqueNames[i],
                              style: TextStyle(
                                  color:
                                      sel ? Colors.white : AppColors.textSub,
                                  fontSize: 12,
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.w400),
                              overflow: TextOverflow.ellipsis)));
                })),
      Expanded(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              Color(0xFF1A1060),
                              Color(0xFF0D1535)
                            ]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.violet.withOpacity(0.3))),
                        child: Row(children: [
                          const Text('📖', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  _selectedChapter < uniqueNames.length
                                      ? uniqueNames[_selectedChapter]
                                      : '',
                                  style: const TextStyle(
                                      color: AppColors.textWhite,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700))),
                        ])),
                    const SizedBox(height: 20),
                    _buildFormattedNotes(
                        _chapters[_selectedChapter]['notes']?.toString() ?? ''),
                    const SizedBox(height: 40),
                  ]))),
    ]);
  }

  List<String> _uniqueChapterNames() {
    final names = <String>[];
    final counts = <String, int>{};
    for (final chapter in _chapters) {
      final name =
          chapter['chapterName']?.toString() ?? 'Chapter ${names.length + 1}';
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final used = <String, int>{};
    for (final chapter in _chapters) {
      final name =
          chapter['chapterName']?.toString() ?? 'Chapter ${names.length + 1}';
      if (counts[name]! > 1) {
        used[name] = (used[name] ?? 0) + 1;
        names.add('$name (${used[name]})');
      } else {
        names.add(name);
      }
    }
    return names;
  }

  Widget _buildFormattedNotes(String text) {
    final lines = text.split('\n');
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) return const SizedBox(height: 8);

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
                              color: AppColors.violet,
                              shape: BoxShape.circle)),
                      Expanded(
                          child: Text(trimmed.substring(2),
                              style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 14,
                                  height: 1.6))),
                    ]));
          }
          if (trimmed.startsWith('**') && trimmed.endsWith('**')) {
            return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(trimmed.replaceAll('**', ''),
                    style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)));
          }
          return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(trimmed,
                  style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 14,
                      height: 1.7)));
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
