import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import '../services/api_client.dart';
import '../services/ai_generation_service.dart';
import 'ai_key_screens.dart';

// ══════════════════════════════════════════
// MCQ SCREEN — unchanged list view
// Only _GenerateMCQScreen gets the gate
// ══════════════════════════════════════════

class MCQScreen extends StatefulWidget {
  const MCQScreen({super.key});
  @override
  State<MCQScreen> createState() => _MCQScreenState();
}

class _MCQScreenState extends State<MCQScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _mcqs = [];
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
    _loadMCQs();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMCQs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await MCQService.getMyMCQs();
      final list = res['mcqs'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _mcqs = list.map((e) => e as Map<String, dynamic>).toList();
          _loading = false;
        });
        _fadeCtrl.forward(from: 0);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Failed to load MCQs';
        _loading = false;
      });
    }
  }

  Future<void> _deleteMCQ(String id) async {
    try {
      await MCQService.deleteMCQ(id);
      setState(() => _mcqs.removeWhere((m) => m['_id'] == id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            _snackBar('MCQ set deleted', AppColors.error));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const SpaceBackground(),
        SafeArea(child: Column(children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.violet))
                : _error != null
                    ? _buildError()
                    : _mcqs.isEmpty
                        ? _buildEmpty()
                        : _buildMCQList()),
        ])),
        Positioned(bottom: 24, right: 24, child: _buildFAB()),
      ]));
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShaderMask(
          shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
          child: const Text('MCQ Quiz',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
              color: Colors.white, fontFamily: 'Georgia'))),
        Text('${_mcqs.length} quiz set${_mcqs.length == 1 ? '' : 's'}',
          style: AppTextStyles.sub),
      ]),
      const Spacer(),
      IconButton(
        onPressed: _loadMCQs,
        icon: const Icon(Icons.refresh_rounded, color: AppColors.textSub)),
    ]));

  Widget _buildEmpty() => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF00C9A7).withOpacity(0.1),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFF00C9A7).withOpacity(0.2))),
        child: const Center(
            child: Text('❓', style: TextStyle(fontSize: 48)))),
      const SizedBox(height: 24),
      ShaderMask(
        shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
        child: const Text('No Quizzes Yet',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
            color: Colors.white, fontFamily: 'Georgia'))),
      const SizedBox(height: 8),
      const Text('Upload a PDF to generate AI-powered\nMCQ quizzes.',
        style: AppTextStyles.sub, textAlign: TextAlign.center),
      const SizedBox(height: 32),
      GlowButton(
        text: 'Generate Quiz',
        icon: Icons.add_rounded,
        gradient: const LinearGradient(
            colors: [Color(0xFF00C9A7), Color(0xFF007A64)]),
        onPressed: _openGenerateFlow),
    ])));

  Widget _buildError() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      buildErrorBanner(_error!),
      const SizedBox(height: 16),
      GlowButton(
          text: 'Retry',
          icon: Icons.refresh_rounded,
          onPressed: _loadMCQs),
    ])));

  Widget _buildMCQList() => FadeTransition(
    opacity: _fadeAnim,
    child: RefreshIndicator(
      color: AppColors.violet,
      backgroundColor: AppColors.bgCard,
      onRefresh: _loadMCQs,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
        itemCount: _mcqs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _mcqCard(_mcqs[i]))));

  Widget _mcqCard(Map<String, dynamic> mcq) {
    final title = mcq['title'] as String? ?? 'Untitled';
    final subject = mcq['subject'] as String? ?? '';
    final chapter = mcq['chapter'] as String? ?? '';
    final docType = mcq['documentType'] as String? ?? 'plain';
    final date = _formatDate(mcq['createdAt'] as String?);

    return Dismissible(
      key: Key(mcq['_id'] as String),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.delete_rounded, color: AppColors.error)),
      onDismissed: (_) => _deleteMCQ(mcq['_id'] as String),
      child: GestureDetector(
        onTap: () => _openTest(mcq['_id'] as String, title),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.inputBorder),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12, offset: const Offset(0, 4))]),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C9A7), Color(0xFF007A64)]),
                borderRadius: BorderRadius.circular(16)),
              child: Center(child: Text(
                docType == 'book' ? '📖' : '❓',
                style: const TextStyle(fontSize: 24)))),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                style: const TextStyle(color: AppColors.textWhite,
                  fontSize: 15, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              if (subject.isNotEmpty)
                Text(subject,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.cyan, fontSize: 12)),
              const SizedBox(height: 6),
              Row(children: [
                if (chapter.isNotEmpty)
                  _chip(
                    chapter.length > 20
                        ? '${chapter.substring(0, 20)}...'
                        : chapter,
                    const Color(0xFF00C9A7)),
                const Spacer(),
                Text(date,
                    style: AppTextStyles.label.copyWith(fontSize: 10)),
              ]),
            ])),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C9A7), Color(0xFF007A64)]),
                borderRadius: BorderRadius.circular(20)),
              child: const Text('Start',
                style: TextStyle(color: Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w700))),
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

  Widget _buildFAB() => GestureDetector(
    onTap: () {
      HapticFeedback.mediumImpact();
      _openGenerateFlow();
    },
    child: Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C9A7), Color(0xFF007A64)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: const Color(0xFF00C9A7).withOpacity(0.5),
          blurRadius: 20, offset: const Offset(0, 8))]),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28)));

  // ── Gate check before opening generate screen ──
  void _openGenerateFlow() async {
    // 1. Device check — MCQ generation is desktop only
    final isMobile = await _isMobileDevice();
    if (isMobile && mounted) {
      _showMobileBlocker();
      return;
    }

    // 2. Key / free-tier check
    final hasKey = await AIKeyStore.hasAnyKey();
    final freeUsed = await AIKeyStore.hasFreeGenerationBeenUsed();

    if (!hasKey && freeUsed && mounted) {
      // Free generation used and no key — show paywall
      Navigator.push(context, PageRouteBuilder(
        pageBuilder: (_, a, __) => FreeGenerationUsedScreen(
          onAddKey: () {
            Navigator.pop(context);
            _openKeyOnboarding();
          },
        ),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ));
      return;
    }

    if (!hasKey && !freeUsed && mounted) {
      // First time with no key — show onboarding with skip option
      final result = await Navigator.push<bool>(context,
        PageRouteBuilder<bool>(
          pageBuilder: (_, a, __) => APIKeyOnboardingScreen(
            onComplete: () => Navigator.pop(context, true)),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 350)));
      if (result != true) return;
    }

    // 3. Open generate screen
    if (!mounted) return;
    final result = await Navigator.push<bool>(context,
      PageRouteBuilder<bool>(
        pageBuilder: (_, a, __) => const _GenerateMCQScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child)),
        transitionDuration: const Duration(milliseconds: 350)));
    if (result == true) _loadMCQs();
  }

  void _openKeyOnboarding() async {
    await Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, a, __) => APIKeyOnboardingScreen(
        onComplete: () => Navigator.pop(context)),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 350)));
  }

  Future<bool> _isMobileDevice() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final d = await info.androidInfo;
        return !d.systemFeatures.contains('android.hardware.type.pc');
      }
      if (Platform.isIOS) {
        final d = await info.iosInfo;
        return d.model.toLowerCase().contains('iphone');
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void _showMobileBlocker() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🖥️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text('Desktop Only Feature',
              style: TextStyle(color: AppColors.textWhite,
                fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'AI generation is only available on laptops '
              'and desktops. Please open StudyAI on your computer.',
              style: AppTextStyles.sub,
              textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GlowButton(
              text: 'OK',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.pop(context)),
          ]))));
  }

  void _openTest(String id, String title) {
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, a, __) =>
          _TakeTestScreen(mcqId: id, title: title),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 300)));
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ══════════════════════════════════════════
// GENERATE MCQ SCREEN — unchanged UI
// Key gate is handled before navigation
// ══════════════════════════════════════════

class _GenerateMCQScreen extends StatefulWidget {
  const _GenerateMCQScreen();
  @override
  State<_GenerateMCQScreen> createState() => _GenerateMCQScreenState();
}

class _GenerateMCQScreenState extends State<_GenerateMCQScreen> {
  int _step = 0;
  File? _pdfFile;
  String _fileName = '';
  String _documentType = 'plain';
  List<String> _divisions = [];
  final _titleCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  String _mode = 'full';
  String? _selectedChapter;
  List<String> _selectedChapters = [];
  int _numQuestions = 10;
  String _difficulty = 'medium';
  bool _scanning = false;
  bool _generating = false;
  String? _error;
  String _status = 'Generating questions...';

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
    } catch (_) {
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
      final res = await MCQService.scanPDF(_pdfFile!);
      setState(() {
        _documentType = res['documentType'] as String? ?? 'plain';
        _divisions = (res['divisions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        _scanning = false;
        _step = 1;
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
    if (_mode == 'single' && _selectedChapter == null) {
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
    _cycleStatus();
    try {
      await MCQService.generateMCQ(
        pdfFile: _pdfFile!,
        title: _titleCtrl.text.trim(),
        mode: _mode,
        subject: _subjectCtrl.text.trim().isEmpty
            ? null
            : _subjectCtrl.text.trim(),
        chapter: _mode == 'single' ? _selectedChapter : null,
        chapters: _mode == 'multiple' ? _selectedChapters : null,
        numQuestions: _numQuestions,
        difficulty: _difficulty);
      if (mounted) setState(() {
        _step = 3;
        _generating = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() {
        _error = e.message;
        _step = 1;
        _generating = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Generation failed. Please try again.';
        _step = 1;
        _generating = false;
      });
    }
  }

  void _cycleStatus() {
    final msgs = [
      'Analyzing PDF content...',
      'Identifying key concepts...',
      'Crafting questions...',
      'Adding answer choices...',
      'Almost ready...',
    ];
    int i = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || !_generating) return false;
      setState(() => _status = msgs[i % msgs.length]);
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
        SafeArea(child: Column(children: [
          _buildTopBar(),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildStep())),
        ])),
      ]));
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
          color: AppColors.textSub, size: 20),
        onPressed: () => Navigator.pop(context, false)),
      const Spacer(),
      if (_step < 3)
        Row(children: List.generate(3, (i) {
          final active = i == (_step == 2 ? 1 : _step);
          final done = i < (_step == 2 ? 1 : _step);
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 28 : 8, height: 8,
              decoration: BoxDecoration(
                gradient: active || done
                    ? const LinearGradient(
                        colors: [Color(0xFF00C9A7), Color(0xFF007A64)])
                    : null,
                color: active || done ? null : AppColors.inputBorder,
                borderRadius: BorderRadius.circular(4))));
        })),
      const Spacer(),
      const SizedBox(width: 44),
    ]));

  Widget _buildStep() {
    switch (_step) {
      case 0: return _buildUploadStep();
      case 1: return _buildConfigStep();
      case 2: return _buildGeneratingStep();
      case 3: return _buildDoneStep();
      default: return _buildUploadStep();
    }
  }

  // ── Upload, Config, Generating, Done steps ──
  // Identical to original — no UI changes needed

  Widget _buildUploadStep() => Column(children: [
    const SizedBox(height: 40),
    Center(child: Container(
      width: 90, height: 90,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C9A7), Color(0xFF007A64)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(
          color: const Color(0xFF00C9A7).withOpacity(0.4),
          blurRadius: 24, offset: const Offset(0, 8))]),
      child: const Center(
          child: Text('❓', style: TextStyle(fontSize: 44))))),
    const SizedBox(height: 24),
    ShaderMask(
      shaderCallback: (b) => const LinearGradient(
        colors: [Color(0xFF00C9A7), Color(0xFF48C6EF)]).createShader(b),
      child: const Text('Generate Quiz',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
          color: Colors.white, fontFamily: 'Georgia'))),
    const SizedBox(height: 8),
    const Text('Upload your PDF to create AI-powered\nMCQ questions',
      style: AppTextStyles.sub, textAlign: TextAlign.center),
    const SizedBox(height: 40),
    if (_error != null) ...[buildErrorBanner(_error!), const SizedBox(height: 20)],
    GestureDetector(
      onTap: _scanning ? null : _pickPDF,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity, padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: _pdfFile != null
              ? const Color(0xFF00C9A7).withOpacity(0.06)
              : AppColors.inputBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _pdfFile != null
                ? const Color(0xFF00C9A7)
                : AppColors.inputBorder,
            width: _pdfFile != null ? 2 : 1.5)),
        child: _scanning
          ? Column(children: [
              CircularProgressIndicator(
                color: const Color(0xFF00C9A7).withOpacity(0.8)),
              const SizedBox(height: 16),
              const Text('Scanning document...',
                style: AppTextStyles.sub, textAlign: TextAlign.center),
            ])
          : _pdfFile != null
            ? Column(children: [
                const Text('📄', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text(_fileName,
                  style: const TextStyle(color: AppColors.textWhite,
                    fontSize: 15, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Tap to change',
                  style: AppTextStyles.body.copyWith(
                    color: const Color(0xFF00C9A7), fontSize: 12)),
              ])
            : const Column(children: [
                Text('📁', style: TextStyle(fontSize: 40)),
                SizedBox(height: 12),
                Text('Tap to select PDF',
                  style: TextStyle(color: AppColors.textWhite,
                    fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Text('Supports PDF files up to 100MB',
                  style: AppTextStyles.sub),
              ]))),
    const SizedBox(height: 24),
    if (_pdfFile != null && !_scanning)
      GlowButton(
        text: 'Continue',
        icon: Icons.arrow_forward_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF00C9A7), Color(0xFF007A64)]),
        onPressed: () => setState(() => _step = 1)),
    const SizedBox(height: 40),
  ]);

  Widget _buildConfigStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    const SizedBox(height: 24),
    ShaderMask(
      shaderCallback: (b) => const LinearGradient(
        colors: [Color(0xFF00C9A7), Color(0xFF48C6EF)]).createShader(b),
      child: const Text('Configure Quiz',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
          color: Colors.white, fontFamily: 'Georgia'))),
    const SizedBox(height: 4),
    Text(_divisions.isEmpty
        ? 'Full document quiz'
        : '${_divisions.length} sections detected',
      style: AppTextStyles.sub),
    const SizedBox(height: 28),
    if (_error != null) ...[
      buildErrorBanner(_error!),
      const SizedBox(height: 20)
    ],
    GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppTextField(
          label: 'Quiz Title',
          hint: 'e.g. Physics Chapter 1 Quiz',
          controller: _titleCtrl,
          prefixIcon: Icons.title_rounded),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Subject (optional)',
          hint: 'e.g. Physics, Mathematics',
          controller: _subjectCtrl,
          prefixIcon: Icons.book_outlined),
        const SizedBox(height: 20),
        const Text('NUMBER OF QUESTIONS', style: AppTextStyles.label),
        const SizedBox(height: 12),
        Row(children: [5, 10, 15, 20, 30].map((n) {
          final sel = _numQuestions == n;
          return Expanded(child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _numQuestions = n),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: sel ? const LinearGradient(
                    colors: [Color(0xFF00C9A7), Color(0xFF007A64)]) : null,
                  color: sel ? null : AppColors.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? Colors.transparent : AppColors.inputBorder)),
                child: Text('$n',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: sel ? Colors.white : AppColors.textSub,
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400))))));
        }).toList()),
        const SizedBox(height: 20),
        const Text('DIFFICULTY', style: AppTextStyles.label),
        const SizedBox(height: 12),
        Row(children: [
          _diffChip('easy', '😊 Easy', const Color(0xFF34EEB6)),
          const SizedBox(width: 8),
          _diffChip('medium', '🎯 Medium', AppColors.gold),
          const SizedBox(width: 8),
          _diffChip('hard', '🔥 Hard', AppColors.error),
        ]),
        if (_divisions.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('QUIZ MODE', style: AppTextStyles.label),
          const SizedBox(height: 10),
          Row(children: [
            _modeChip('full', '📚 Full'),
            const SizedBox(width: 8),
            _modeChip('single', '📖 Single'),
            const SizedBox(width: 8),
            _modeChip('multiple', '📑 Multi'),
          ]),
        ],
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
                        child: Text(d,
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedChapter = v)))),
        ],
        if (_mode == 'multiple' && _divisions.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('SELECT CHAPTERS', style: AppTextStyles.label),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
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
                    gradient: sel ? const LinearGradient(
                      colors: [Color(0xFF00C9A7), Color(0xFF007A64)]) : null,
                    color: sel ? null : AppColors.inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel
                          ? Colors.transparent
                          : AppColors.inputBorder)),
                  child: Text(d,
                    style: TextStyle(
                      color: sel ? Colors.white : AppColors.textSub,
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
      text: 'Generate $_numQuestions Questions',
      icon: Icons.auto_awesome_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFF00C9A7), Color(0xFF007A64)]),
      onPressed: _generate),
    const SizedBox(height: 40),
  ]);

  Widget _diffChip(String val, String label, Color color) {
    final sel = _difficulty == val;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _difficulty = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.2) : AppColors.inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? color : AppColors.inputBorder, width: 1.5)),
        child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: sel ? color : AppColors.textSub,
            fontSize: 12,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w400)))));
  }

  Widget _modeChip(String value, String label) {
    final sel = _mode == value;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() {
        _mode = value;
        _selectedChapter = null;
        _selectedChapters = [];
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: sel ? const LinearGradient(
            colors: [Color(0xFF00C9A7), Color(0xFF007A64)]) : null,
          color: sel ? null : AppColors.inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? Colors.transparent : AppColors.inputBorder)),
        child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: sel ? Colors.white : AppColors.textSub,
            fontSize: 12,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w400)))));
  }

  Widget _buildGeneratingStep() => SizedBox(
    height: MediaQuery.of(context).size.height * 0.75,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.85, end: 1.1),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOut,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00C9A7), Color(0xFF007A64)]),
            borderRadius: BorderRadius.circular(36),
            boxShadow: [BoxShadow(
              color: const Color(0xFF00C9A7).withOpacity(0.5),
              blurRadius: 40, offset: const Offset(0, 12))]),
          child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 52))))),
      const SizedBox(height: 32),
      ShaderMask(
        shaderCallback: (b) => const LinearGradient(
          colors: [Color(0xFF00C9A7), Color(0xFF48C6EF)]).createShader(b),
        child: const Text('Generating Quiz',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
            color: Colors.white, fontFamily: 'Georgia'))),
      const SizedBox(height: 12),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: Text(_status,
          key: ValueKey(_status),
          style: AppTextStyles.sub,
          textAlign: TextAlign.center)),
      const SizedBox(height: 32),
      const CircularProgressIndicator(
        color: Color(0xFF00C9A7), strokeWidth: 3),
      const SizedBox(height: 24),
      GlassCard(child: Row(children: [
        const Icon(Icons.info_outline_rounded,
          color: Color(0xFF00C9A7), size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'Generating $_numQuestions questions at $_difficulty difficulty.',
          style: AppTextStyles.body.copyWith(fontSize: 12))),
      ])),
    ]));

  Widget _buildDoneStep() => SizedBox(
    height: MediaQuery.of(context).size.height * 0.75,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 110, height: 110,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00C9A7), Color(0xFF007A64)]),
          borderRadius: BorderRadius.circular(36),
          boxShadow: [BoxShadow(
            color: const Color(0xFF00C9A7).withOpacity(0.5),
            blurRadius: 40, offset: const Offset(0, 12))]),
        child: const Center(
            child: Text('🎉', style: TextStyle(fontSize: 52)))),
      const SizedBox(height: 28),
      ShaderMask(
        shaderCallback: (b) => const LinearGradient(
          colors: [Color(0xFF00C9A7), Color(0xFF48C6EF)]).createShader(b),
        child: const Text('Quiz Ready!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
            color: Colors.white, fontFamily: 'Georgia'))),
      const SizedBox(height: 10),
      Text('"${_titleCtrl.text}"',
        style: AppTextStyles.sub.copyWith(color: AppColors.cyan),
        textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text('$_numQuestions questions · $_difficulty difficulty',
        style: AppTextStyles.body.copyWith(
          color: const Color(0xFF00C9A7), fontWeight: FontWeight.w600)),
      const SizedBox(height: 32),
      GlowButton(
        text: 'Take Quiz Now',
        icon: Icons.play_arrow_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF00C9A7), Color(0xFF007A64)]),
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

// ══════════════════════════════════════════
// TAKE TEST + RESULTS screens — unchanged
// Copy from original mcq_screen.dart as-is
// (omitted here to keep diff minimal)
// ══════════════════════════════════════════
// ══════════════════════════════════════════
// TAKE TEST SCREEN
// ══════════════════════════════════════════

class _TakeTestScreen extends StatefulWidget {
  final String mcqId;
  final String title;
  const _TakeTestScreen({required this.mcqId, required this.title});
  @override
  State<_TakeTestScreen> createState() => _TakeTestScreenState();
}

class _TakeTestScreenState extends State<_TakeTestScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _questions = [];
  bool _loading = true;
  String? _error;
  int _current = 0;
  Map<int, String> _answers = {};
  late Timer _timer;
  int _seconds = 0;
  late AnimationController _questionCtrl;
  late Animation<double> _questionFade;
  late Animation<Offset> _questionSlide;

  @override
  void initState() {
    super.initState();
    _questionCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _questionFade = CurvedAnimation(parent: _questionCtrl, curve: Curves.easeOut);
    _questionSlide = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _questionCtrl, curve: Curves.easeOut));
    _loadMCQ();
  }

  @override
  void dispose() {
    if (_timer.isActive) _timer.cancel();
    _questionCtrl.dispose();
    super.dispose();
  }

  List<String> _parseOptions(dynamic rawOptions) {
    if (rawOptions == null) return [];

    List<String> raw = [];
    if (rawOptions is List) {
      raw = rawOptions.map((e) => e.toString().trim()).toList();
    } else if (rawOptions is String) {
      raw = [rawOptions.trim()];
    }

    if (raw.length == 4 && raw.every((o) => o.isNotEmpty)) {
      final allClean = raw.every((o) {
        final withoutOwn = o.replaceFirst(RegExp(r'^[A-D][).]\s*'), '');
        return !RegExp(r'\s+[B-D][).]\s').hasMatch(withoutOwn);
      });
      if (allClean) return raw;
    }

    final joined = raw.join(' ');
    return _splitOptionsString(joined);
  }

  List<String> _splitOptionsString(String text) {
    final regex = RegExp(r'(?<!\w)([A-D])[).]\s*');
    final matches = regex.allMatches(text);

    if (matches.length < 2) {
      return [text];
    }

    final List<String> result = [];
    final positions = matches.map((m) => m.start).toList();

    for (int i = 0; i < positions.length; i++) {
      final start = positions[i];
      final end = i + 1 < positions.length ? positions[i + 1] : text.length;
      final part = text.substring(start, end).trim();
      if (part.isNotEmpty) result.add(part);
    }

    return result.where((o) => o.isNotEmpty).toList();
  }

  Future<void> _loadMCQ() async {
    try {
      final res = await MCQService.getMCQById(widget.mcqId);
      final mcq = res['mcq'] as Map<String, dynamic>;
      final rawQuestions = (mcq['questions'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>).toList();

      final normalised = rawQuestions.map((q) {
        final parsedOptions = _parseOptions(q['options']);
        return {...q, 'options': parsedOptions};
      }).toList();

      if (mounted) {
        setState(() {
          _questions = normalised;
          _loading = false;
        });
        _startTimer();
        _questionCtrl.forward();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to load quiz'; _loading = false; });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _timeDisplay {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _selectAnswer(String answer) {
    HapticFeedback.selectionClick();
    setState(() => _answers[_current] = answer);
  }

  void _nextQuestion() {
    if (_current < _questions.length - 1) {
      _questionCtrl.reverse().then((_) {
        setState(() => _current++);
        _questionCtrl.forward();
      });
    }
  }

  void _prevQuestion() {
    if (_current > 0) {
      _questionCtrl.reverse().then((_) {
        setState(() => _current--);
        _questionCtrl.forward();
      });
    }
  }

  Future<void> _submitTest() async {
    _timer.cancel();
    final answers = _answers.entries
        .map((e) => {'questionIndex': e.key, 'selectedAnswer': e.value})
        .toList();
    try {
      final res = await MCQService.submitTest(
        mcqId: widget.mcqId,
        answers: answers,
        timeTakenSeconds: _seconds);
      if (!mounted) return;
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, a, __) => _TestResultsScreen(
          result: res['result'] as Map<String, dynamic>,
          questions: _questions,
          answers: _answers,
          title: widget.title,
          timeTaken: _seconds),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400)));
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Error: ${e.message}', AppColors.error));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Failed to submit. Try again.', AppColors.error));
    }
  }

  void _confirmSubmit() {
    final answered = _answers.length;
    final total = _questions.length;
    final unanswered = total - answered;
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('📋', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 16),
          const Text('Submit Quiz?', style: TextStyle(
            color: AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (unanswered > 0)
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withOpacity(0.3))),
              child: Text(
                '$unanswered question${unanswered == 1 ? '' : 's'} unanswered',
                style: TextStyle(color: AppColors.gold, fontSize: 13,
                  fontWeight: FontWeight.w600),
                textAlign: TextAlign.center)),
          const SizedBox(height: 8),
          Text('$answered of $total answered', style: AppTextStyles.sub),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.inputBorder)),
                child: const Text('Cancel', textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSub,
                    fontWeight: FontWeight.w600))))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () { Navigator.pop(context); _submitTest(); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C9A7), Color(0xFF007A64)]),
                  borderRadius: BorderRadius.circular(14)),
                child: const Text('Submit', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700))))),
          ]),
        ]))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const SpaceBackground(),
        SafeArea(child: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C9A7)))
          : _error != null
            ? Center(child: buildErrorBanner(_error!))
            : _buildQuizContent()),
      ]));
  }

  Widget _buildQuizContent() {
    final q = _questions[_current];

    final options = (q['options'] as List<dynamic>)
        .map((e) => e.toString()).toList();

    final selected = _answers[_current];
    final progress = (_current + 1) / _questions.length;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textSub, size: 22),
            onPressed: () { _timer.cancel(); Navigator.pop(context); }),
          Expanded(child: Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.inputBorder,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF00C9A7)),
                minHeight: 6)),
            const SizedBox(height: 6),
            Text('${_current + 1} / ${_questions.length}', style: AppTextStyles.label),
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.inputBorder)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.timer_outlined, color: AppColors.textMuted, size: 14),
              const SizedBox(width: 4),
              Text(_timeDisplay, style: const TextStyle(
                color: AppColors.textWhite, fontSize: 13, fontWeight: FontWeight.w700)),
            ])),
        ])),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: List.generate(_questions.length, (i) {
            final ans = _answers[i];
            final isCurrent = i == _current;
            return GestureDetector(
              onTap: () {
                _questionCtrl.reverse().then((_) {
                  setState(() => _current = i);
                  _questionCtrl.forward();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 6),
                width: isCurrent ? 28 : 10, height: 10,
                decoration: BoxDecoration(
                  gradient: isCurrent ? const LinearGradient(
                    colors: [Color(0xFF00C9A7), Color(0xFF007A64)]) : null,
                  color: isCurrent ? null
                    : ans != null
                      ? const Color(0xFF00C9A7).withOpacity(0.5)
                      : AppColors.inputBorder,
                  borderRadius: BorderRadius.circular(5))));
          })))),

      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: FadeTransition(opacity: _questionFade,
          child: SlideTransition(position: _questionSlide,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1060), Color(0xFF0D1535)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00C9A7).withOpacity(0.2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C9A7).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                    child: Text('Q${_current + 1}',
                      style: const TextStyle(color: Color(0xFF00C9A7),
                        fontSize: 12, fontWeight: FontWeight.w700))),
                  const SizedBox(height: 12),
                  Text(q['question'] as String? ?? '',
                    style: const TextStyle(color: AppColors.textWhite,
                      fontSize: 16, fontWeight: FontWeight.w600, height: 1.5)),
                ])),

              const SizedBox(height: 20),

              ...options.asMap().entries.map((entry) {
                final idx = entry.key;
                final opt = entry.value;
                final labels = ['A', 'B', 'C', 'D', 'E'];
                final isSelected = selected == opt;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => _selectAnswer(opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: isSelected ? const LinearGradient(
                          colors: [Color(0xFF00C9A7), Color(0xFF007A64)]) : null,
                        color: isSelected ? null : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                            ? Colors.transparent : AppColors.inputBorder,
                          width: 1.5),
                        boxShadow: isSelected ? [BoxShadow(
                          color: const Color(0xFF00C9A7).withOpacity(0.3),
                          blurRadius: 12, offset: const Offset(0, 4))] : null),
                      child: Row(children: [
                        Container(width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: isSelected
                              ? Colors.white.withOpacity(0.2) : AppColors.inputBg,
                            borderRadius: BorderRadius.circular(10)),
                          child: Center(child: Text(
                            idx < labels.length ? labels[idx] : '?',
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textMuted,
                              fontSize: 13, fontWeight: FontWeight.w700)))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(opt,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textLight,
                            fontSize: 14, height: 1.4))),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 20),
                      ]))));
              }).toList(),

              const SizedBox(height: 20),
            ]))))),

      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Row(children: [
          if (_current > 0)
            GestureDetector(
              onTap: _prevQuestion,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.inputBorder)),
                child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textSub, size: 20))),
          if (_current > 0) const SizedBox(width: 12),
          Expanded(child: _current < _questions.length - 1
            ? GestureDetector(
                onTap: _nextQuestion,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C9A7), Color(0xFF007A64)]),
                    borderRadius: BorderRadius.circular(16)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                    Text('Next', style: TextStyle(color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.w700)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ])))
            : GestureDetector(
                onTap: _confirmSubmit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                      color: const Color(0xFFFF6B6B).withOpacity(0.4),
                      blurRadius: 16, offset: const Offset(0, 4))]),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                    Text('Submit Quiz', style: TextStyle(color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.w700)),
                    SizedBox(width: 8),
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  ])))),
        ])),
    ]);
  }
}

// ══════════════════════════════════════════
// TEST RESULTS SCREEN
// ══════════════════════════════════════════

class _TestResultsScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final List<Map<String, dynamic>> questions;
  final Map<int, String> answers;
  final String title;
  final int timeTaken;

  const _TestResultsScreen({
    required this.result,
    required this.questions,
    required this.answers,
    required this.title,
    required this.timeTaken,
  });

  int get _score => (result['scorePercent'] as num?)?.toInt() ?? 0;
  int get _correct => (result['correctAnswers'] as num?)?.toInt() ?? 0;
  int get _wrong => (result['wrongAnswers'] as num?)?.toInt() ?? 0;
  int get _skipped => (result['skippedAnswers'] as num?)?.toInt() ?? 0;
  int get _total => (result['totalQuestions'] as num?)?.toInt() ?? 0;
  String get _prediction => result['prediction'] as String? ?? '';

  Color get _scoreColor {
    if (_score >= 80) return AppColors.success;
    if (_score >= 60) return AppColors.gold;
    return AppColors.error;
  }

  String get _scoreEmoji {
    if (_score >= 85) return '🏆';
    if (_score >= 70) return '🎯';
    if (_score >= 50) return '📚';
    return '💪';
  }

  String get _timeTakenDisplay {
    final m = timeTaken ~/ 60;
    final s = timeTaken % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const SpaceBackground(),
        SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 20),
            Center(child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 160, height: 160,
                child: CircularProgressIndicator(
                  value: _score / 100, strokeWidth: 10,
                  backgroundColor: AppColors.inputBorder,
                  valueColor: AlwaysStoppedAnimation(_scoreColor))),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_scoreEmoji, style: const TextStyle(fontSize: 36)),
                Text('$_score%', style: TextStyle(
                  color: _scoreColor, fontSize: 32, fontWeight: FontWeight.w800)),
                Text(
                  _score >= 80 ? 'Excellent!'
                    : _score >= 60 ? 'Good Job!'
                    : _score >= 40 ? 'Keep Going!' : 'Try Again!',
                  style: AppTextStyles.body.copyWith(
                    color: _scoreColor, fontWeight: FontWeight.w600)),
              ]),
            ])),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(
              color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(children: [
              _statBox('✅', '$_correct', 'Correct', AppColors.success),
              const SizedBox(width: 10),
              _statBox('❌', '$_wrong', 'Wrong', AppColors.error),
              const SizedBox(width: 10),
              _statBox('⏭️', '$_skipped', 'Skipped', AppColors.gold),
              const SizedBox(width: 10),
              _statBox('⏱️', _timeTakenDisplay, 'Time', AppColors.cyan),
            ]),
            const SizedBox(height: 20),
            if (_prediction.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _scoreColor.withOpacity(0.15),
                    _scoreColor.withOpacity(0.05)]),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _scoreColor.withOpacity(0.3))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_scoreEmoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_prediction,
                    style: TextStyle(color: AppColors.textLight,
                      fontSize: 14, height: 1.6))),
                ])),
            const SizedBox(height: 20),
            GlassCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Answer Review', style: TextStyle(
                color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ...questions.asMap().entries.map((entry) {
                final i = entry.key;
                final q = entry.value;
                final userAns = answers[i];
                final correct = q['correctAnswer'] as String? ?? '';
                final isCorrect = userAns == correct;
                final skipped = userAns == null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: skipped
                      ? AppColors.gold.withOpacity(0.06)
                      : isCorrect
                        ? AppColors.success.withOpacity(0.06)
                        : AppColors.error.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: skipped ? AppColors.gold.withOpacity(0.2)
                        : isCorrect
                          ? AppColors.success.withOpacity(0.2)
                          : AppColors.error.withOpacity(0.2))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(skipped ? '⏭️' : isCorrect ? '✅' : '❌',
                        style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.inputBg,
                          borderRadius: BorderRadius.circular(6)),
                        child: Text('Q${i + 1}', style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11,
                          fontWeight: FontWeight.w600))),
                    ]),
                    const SizedBox(height: 8),
                    Text(q['question'] as String? ?? '',
                      style: const TextStyle(color: AppColors.textWhite,
                        fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    if (!skipped && !isCorrect) ...[
                      Text('Your answer: $userAns',
                        style: const TextStyle(color: AppColors.error, fontSize: 12)),
                      const SizedBox(height: 4),
                    ],
                    Text('Correct: $correct',
                      style: const TextStyle(color: AppColors.success,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                    if (q['explanation'] != null &&
                        (q['explanation'] as String).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(q['explanation'] as String,
                        style: AppTextStyles.body.copyWith(fontSize: 12),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ]));
              }).toList(),
            ])),
            const SizedBox(height: 24),
            GlowButton(text: 'Back to Quizzes', icon: Icons.arrow_back_rounded,
              onPressed: () => Navigator.pop(context)),
            const SizedBox(height: 40),
          ]))),
      ]));
  }

  Widget _statBox(String emoji, String value, String label, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(
          color: color, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.label.copyWith(fontSize: 9)),
      ])));
  }
}
// _TakeTestScreen and _TestResultsScreen
// are IDENTICAL to original — no changes needed.
// Keep them from your existing mcq_screen.dart.

SnackBar _snackBar(String msg, Color color) => SnackBar(
  content: Text(msg, style: const TextStyle(color: Colors.white)),
  backgroundColor: color.withOpacity(0.9),
  behavior: SnackBarBehavior.floating,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  margin: const EdgeInsets.all(16));