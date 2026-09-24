import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/tts_service.dart';
import '../services/pdf_extractor_service.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';

// ══════════════════════════════════════════════════════
// SMART AUDITORY READER SCREEN
//  • Real Document Presentation: Opens original PDF (pinch-zoom, covers, layout)
//  • Auditory reading with live glowing word and spoken sentence HUD
//  • Synchronized page turns: as audio speaks, PDF turns pages automatically
//  • Ignores initial image/cover pages (starts reading from actual body text)
//  • Mini-player docked when scrolling down into the document
//  • Background reading with lock-screen notification card & popup
//  • Complete audio controls: Play/Pause, Stop, Prev/Next, Speed, Vol, Pitch
// ══════════════════════════════════════════════════════

class SmartReaderScreen extends StatefulWidget {
  final String? initialFilePath;
  final String? initialText;
  final String? title;
  final bool autoPlay;

  const SmartReaderScreen({
    super.key,
    this.initialFilePath,
    this.initialText,
    this.title,
    this.autoPlay = true,
  });

  @override
  State<SmartReaderScreen> createState() => _SmartReaderScreenState();
}

class _SmartReaderScreenState extends State<SmartReaderScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── TTS ────────────────────────────────────────────────
  final TtsService _tts = TtsService();
  StreamSubscription? _wordSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _completionSub;

  int _currentLineIndex = 0;
  // ValueNotifier for word highlight — avoids full setState on every word tick
  final ValueNotifier<int> _wordStartNotifier = ValueNotifier<int>(-1);
  // ignore: unused_field — used internally by timer guards & stream handlers
  int _currentWordStart = -1;
  TtsState _ttsState = TtsState.stopped;
  bool _userStopped = false;

  // Utterance tracking & sync fallback
  int _activeSpeechSession = 0;
  DateTime _lastSpeakStartTime = DateTime.now();
  Timer? _wordSyncTimer;

  // Pending text for sync — set before speak(), consumed on TtsState.playing
  String _pendingSpeakText = '';
  int _pendingSpeakSession = 0;

  // ── Original PDF Document Viewing (Syncfusion) ──────────
  PdfViewerController? _sfPdfController;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  HighlightAnnotation? _activeBookLineAnnotation;
  HighlightAnnotation? _activeBookWordAnnotation;
  bool _isPdf = false;
  bool _pdfControllerReady = false;
  String? _pdfFilePath; // Path for SfPdfViewer.file()
  bool _showOriginalPdf = true; // Toggle: Book (PDF) vs Doc (text) view — defaults to true for PDF books
  /// Set true when user taps play before lines have finished loading;
  /// cleared and honoured as soon as background extraction completes.
  bool _pendingPlay = false;

  // ── Loading animation ──────────────────────────────────
  late AnimationController _loadingBounceCtrl;
  late AnimationController _loadingGlowCtrl;

  // ── Controls ───────────────────────────────────────────
  double _speed = 0.5; // flutter_tts: 0.5 = 1.0x
  double _volume = 1.0;
  double _pitch = 1.0;
  bool _controlsExpanded = false;
  bool _isDarkPaper = false; // Paper mode (white page matching screenshot)

  // ── Document & Lines ───────────────────────────────────
  String _fileName = 'Document';
  List<SpokenLine> _lines = [];
  int _totalPages = 1;
  bool _loading = false;
  String _loadingMessage = 'Loading document…';
  String? _error;

  // ── Scroll & Keys (for text-only mode) ─────────────────
  final ScrollController _scrollCtrl = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  bool _userScrolledAway = false;

  // ── Animations ─────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _panelCtrl;
  late Animation<double> _panelAnim;

  static const _textExtensions = {
    'txt', 'md', 'markdown', 'log', 'csv',
    'dart', 'js', 'ts', 'jsx', 'tsx',
    'json', 'yaml', 'yml', 'toml',
    'py', 'java', 'kt', 'swift', 'c', 'cpp', 'h', 'hpp',
    'html', 'htm', 'css', 'scss', 'xml',
    'sh', 'bash', 'sql', 'rb', 'go', 'rs',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _panelAnim = CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOut);

    // Loading animation controllers
    _loadingBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _loadingGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _initTts();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialFilePath != null) {
        _loadFile(File(widget.initialFilePath!), autoSpeak: widget.autoPlay);
      } else if (widget.initialText != null && widget.initialText!.isNotEmpty) {
        _loadRawText(widget.initialText!, widget.title ?? 'Document', autoSpeak: widget.autoPlay);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.cancelPlaybackNotification();
    _clearBookHighlights();
    _sfPdfController?.dispose();
    _wordSyncTimer?.cancel();
    _wordSub?.cancel();
    _stateSub?.cancel();
    _completionSub?.cancel();
    _tts.stop();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    _panelCtrl.dispose();
    _loadingBounceCtrl.dispose();
    _loadingGlowCtrl.dispose();
    _wordStartNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep lock-screen notification updated when device sleeps or screen locks
    if (_ttsState == TtsState.playing &&
        _lines.isNotEmpty &&
        _currentLineIndex < _lines.length) {
      NotificationService.showPlaybackNotification(
        title: _fileName,
        currentLine: _lines[_currentLineIndex].text,
        isPlaying: true,
        currentLineIndex: _currentLineIndex,
        totalLines: _lines.length,
      );
    }
  }

  // ── TTS Engine ─────────────────────────────────────────

  Future<void> _initTts() async {
    await _tts.init();
    await _tts.setRate(_speed);
    await _tts.setVolume(_volume);
    await _tts.setPitch(_pitch);

    // Track active word inside currently spoken line
    _wordSub = _tts.onWordRange.listen((range) {
      if (!mounted) return;
      if (range.isEmpty) return;
      final start = range['start'] as int? ?? -1;
      if (start >= 0) {
        // Native engine progress event arrived! Cancel synthetic timer and use engine position
        _wordSyncTimer?.cancel();
        // Use ValueNotifier — no setState, no full rebuild
        _currentWordStart = start;
        _wordStartNotifier.value = start;
        if (_lines.isNotEmpty && _currentLineIndex < _lines.length) {
          _updateBookWordHighlight(_lines[_currentLineIndex], start);
        }
      }
    });

    _stateSub = _tts.onStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _ttsState = state);
      if (state == TtsState.playing) {
        if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
        // Start word sync timer ONLY when TTS engine actually begins speaking.
        // This ensures word highlight is in sync with audio, not ahead of it.
        if (_pendingSpeakText.isNotEmpty && _pendingSpeakSession == _activeSpeechSession) {
          _startWordSyncTimer(_pendingSpeakText, _pendingSpeakSession);
          _pendingSpeakText = '';
        }
      } else {
        _wordSyncTimer?.cancel();
        _currentWordStart = -1;
        _wordStartNotifier.value = -1;
        _pulseCtrl.stop();
        _pulseCtrl.value = 0.9;
      }
    });

    // Advance to next line when current line completes
    _completionSub = _tts.onCompletion.listen((_) {
      if (!mounted) return;
      // Guard: Ignore stale completion events fired by Android when cancelling a previous utterance
      final elapsed = DateTime.now().difference(_lastSpeakStartTime).inMilliseconds;
      if (elapsed < 320) {
        return;
      }
      if (!_userStopped && _ttsState != TtsState.paused) {
        _advanceToNextLine();
      }
    });
  }

  /// Highlights the spoken SENTENCE directly on the original PDF book using exact line bounds.
  /// Zero searchText calls — zero main-thread blocking, zero ANR, instant 60fps rendering.
  void _updateBookSentenceHighlight(SpokenLine line) {
    if (!_isPdf || _sfPdfController == null || !_pdfControllerReady) return;

    _clearBookHighlights();

    if (line.lineBounds.isNotEmpty) {
      try {
        final textLines = line.lineBounds
            .map((b) => PdfTextLine(b, line.text, line.pageNumber))
            .toList();
        final hl = HighlightAnnotation(textBoundsCollection: textLines);
        hl.color = const Color(0xFFFFD600); // Warm luminous gold wash over spoken sentence
        hl.opacity = 0.32;
        _activeBookLineAnnotation = hl;
        _sfPdfController!.addAnnotation(hl);
      } catch (e) {
        debugPrint('Error adding book line annotation: $e');
      }
    }

    // Automatically jump/scroll PDF page if page changed
    if (line.pageNumber >= 1 && line.pageNumber <= _totalPages) {
      if (_sfPdfController!.pageNumber != line.pageNumber) {
        _sfPdfController!.jumpToPage(line.pageNumber);
      }
    }
  }

  /// Highlights the exact spoken WORD directly on the PDF book page in real-time.
  void _updateBookWordHighlight(SpokenLine line, int wordStartOffset) {
    if (!_isPdf || _sfPdfController == null || !_pdfControllerReady || !_showOriginalPdf) return;
    if (line.words.isEmpty || wordStartOffset < 0) return;

    SpokenWord? targetWord;
    for (final w in line.words) {
      if (wordStartOffset >= w.startOffset && wordStartOffset <= w.endOffset) {
        targetWord = w;
        break;
      }
    }
    targetWord ??= (line.words.isNotEmpty ? line.words.first : null);
    if (targetWord == null) return;

    try {
      if (_activeBookWordAnnotation != null) {
        _sfPdfController!.removeAnnotation(_activeBookWordAnnotation!);
        _activeBookWordAnnotation = null;
      }

      final wordLine = PdfTextLine(targetWord.bounds, targetWord.text, line.pageNumber);
      final wordHl = HighlightAnnotation(textBoundsCollection: [wordLine]);
      wordHl.color = const Color(0xFF7B61FF); // Vibrant purple active-word highlight on book
      wordHl.opacity = 0.65;
      _activeBookWordAnnotation = wordHl;
      _sfPdfController!.addAnnotation(wordHl);
    } catch (e) {
      debugPrint('Error updating book word annotation: $e');
    }
  }

  void _clearBookHighlights() {
    try {
      if (_activeBookWordAnnotation != null) {
        _sfPdfController?.removeAnnotation(_activeBookWordAnnotation!);
        _activeBookWordAnnotation = null;
      }
      if (_activeBookLineAnnotation != null) {
        _sfPdfController?.removeAnnotation(_activeBookLineAnnotation!);
        _activeBookLineAnnotation = null;
      }
    } catch (_) {}
  }

  /// Timer-based word sync — advances word highlight in lockstep with spoken audio.
  void _startWordSyncTimer(String text, int session) {
    _wordSyncTimer?.cancel();
    final wordMatches = RegExp(r'\S+').allMatches(text).toList();
    if (wordMatches.isEmpty) return;

    int currentIdx = 0;
    // Highlight first word immediately on both Doc view and PDF Book view
    if (mounted && _activeSpeechSession == session) {
      final start = wordMatches[0].start;
      _currentWordStart = start;
      _wordStartNotifier.value = start;
      if (_lines.isNotEmpty && _currentLineIndex < _lines.length) {
        _updateBookWordHighlight(_lines[_currentLineIndex], start);
      }
    }

    final double speedFactor = (_speed <= 0 ? 0.5 : _speed) * 2.0;
    // ~340ms per average English word at 1.0x rate (matches natural spoken cadence)
    final baseWordMs = (340 / speedFactor).clamp(110.0, 520.0);

    void scheduleNext() {
      if (!mounted || _activeSpeechSession != session || _ttsState != TtsState.playing) return;
      if (currentIdx >= wordMatches.length - 1) return;

      final currentWord = wordMatches[currentIdx].group(0) ?? '';
      final wordLenFactor = (currentWord.length / 4.6).clamp(0.60, 1.40);
      final wordDelayMs = (baseWordMs * wordLenFactor).toInt();

      _wordSyncTimer = Timer(Duration(milliseconds: wordDelayMs), () {
        if (!mounted || _activeSpeechSession != session || _ttsState != TtsState.playing) return;
        currentIdx++;
        if (currentIdx < wordMatches.length) {
          final start = wordMatches[currentIdx].start;
          _currentWordStart = start;
          _wordStartNotifier.value = start;
          if (_lines.isNotEmpty && _currentLineIndex < _lines.length) {
            _updateBookWordHighlight(_lines[_currentLineIndex], start);
          }
          scheduleNext();
        }
      });
    }

    scheduleNext();
  }

  void _speakCurrentLine() {
    if (_lines.isEmpty) return;
    if (_currentLineIndex < 0) _currentLineIndex = 0;
    if (_currentLineIndex >= _lines.length) {
      _stop();
      return;
    }

    _userStopped = false;
    final line = _lines[_currentLineIndex];
    final textToSpeak = line.text.trim();

    if (textToSpeak.isEmpty) {
      _advanceToNextLine();
      return;
    }

    final session = ++_activeSpeechSession;
    _lastSpeakStartTime = DateTime.now();

    _tts.setRate(_speed);
    _tts.setVolume(_volume);
    _tts.setPitch(_pitch);

    // Cancel any running timer and reset word highlight
    _wordSyncTimer?.cancel();
    _currentWordStart = -1;
    _wordStartNotifier.value = -1;

    // Store text+session so the sync timer starts ONLY when TTS actually begins.
    // (TtsState.playing fires in _stateSub). Prevents highlighting before voice starts.
    _pendingSpeakText = textToSpeak;
    _pendingSpeakSession = session;

    _tts.speak(textToSpeak);

    // Highlight the line and word directly ON THE ORIGINAL BOOK PAGE
    if (_isPdf && _sfPdfController != null && _pdfControllerReady && _showOriginalPdf) {
      _updateBookSentenceHighlight(line);
      if (line.words.isNotEmpty) {
        _updateBookWordHighlight(line, line.words.first.startOffset);
      }
    }

    // Keep active spoken sentence smoothly centered in view for the user
    _scrollToActiveLine();

    // Lock-screen & Background Media Card Notification
    NotificationService.showPlaybackNotification(
      title: _fileName,
      currentLine: textToSpeak,
      isPlaying: true,
      currentLineIndex: _currentLineIndex,
      totalLines: _lines.length,
    );
  }

  void _advanceToNextLine() {
    _wordSyncTimer?.cancel();
    if (_currentLineIndex + 1 < _lines.length) {
      setState(() {
        _currentLineIndex++;
        _userScrolledAway = false;
      });
      _speakCurrentLine();
    } else {
      _stop();
      NotificationService.cancelPlaybackNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Finished reading document 🎉'),
            backgroundColor: AppColors.violet,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _prevLine() {
    HapticFeedback.selectionClick();
    if (_currentLineIndex > 0) {
      _wordSyncTimer?.cancel();
      _activeSpeechSession++;
      setState(() {
        _currentLineIndex--;
        _userScrolledAway = false;
      });
      _speakCurrentLine();
    }
  }

  void _nextLine() {
    HapticFeedback.selectionClick();
    if (_currentLineIndex + 1 < _lines.length) {
      _wordSyncTimer?.cancel();
      _activeSpeechSession++;
      setState(() {
        _currentLineIndex++;
        _userScrolledAway = false;
      });
      _speakCurrentLine();
    }
  }

  void _togglePlayPause() {
    HapticFeedback.mediumImpact();
    if (_ttsState == TtsState.playing) {
      // Pause — keep current line index so resume continues from same line
      _wordSyncTimer?.cancel();
      _tts.pause();
      NotificationService.showPlaybackNotification(
        title: _fileName,
        currentLine: (_lines.isNotEmpty && _currentLineIndex < _lines.length)
            ? _lines[_currentLineIndex].text
            : '',
        isPlaying: false,
        currentLineIndex: _currentLineIndex,
        totalLines: _lines.length,
      );
    } else if (_ttsState == TtsState.paused) {
      // Resume
      _userStopped = false;
      _speakCurrentLine();
    } else {
      // Start fresh from current line
      _userStopped = false;
      _speakCurrentLine();
    }
  }

  void _stop() {
    HapticFeedback.lightImpact();
    _userStopped = true;
    _wordSyncTimer?.cancel();
    _activeSpeechSession++;
    _tts.stop();
    // Clear PDF highlight and reset word position
    _clearBookHighlights();
    NotificationService.cancelPlaybackNotification();
    _currentWordStart = -1;
    _wordStartNotifier.value = -1;
    // Stop = reset to very beginning of document
    setState(() {
      _currentLineIndex = 0;
      _userScrolledAway = false;
    });
  }

  // ── Audio Settings ─────────────────────────────────────

  Future<void> _applySpeed(double val) async {
    setState(() => _speed = val);
    await _tts.setRate(val);
  }

  Future<void> _applyVolume(double val) async {
    setState(() => _volume = val);
    await _tts.setVolume(val);
  }

  Future<void> _applyPitch(double val) async {
    setState(() => _pitch = val);
    await _tts.setPitch(val);
  }

  void _cycleSpeed() {
    HapticFeedback.selectionClick();
    final presets = [0.35, 0.5, 0.65, 0.8, 1.0];
    int nextIdx = 0;
    for (int i = 0; i < presets.length; i++) {
      if ((_speed - presets[i]).abs() < 0.05) {
        nextIdx = (i + 1) % presets.length;
        break;
      }
    }
    _applySpeed(presets[nextIdx]);
  }

  String _speedLabel(double rate) {
    if (rate <= 0.3) return '0.5x';
    if (rate <= 0.42) return '0.75x';
    if (rate <= 0.55) return '1.0x';
    if (rate <= 0.7) return '1.25x';
    if (rate <= 0.85) return '1.5x';
    return '2.0x';
  }

  // ── Auto-Scroll on Page (text-only mode) ─────────────────

  void _scrollToActiveLine({bool force = false}) {
    if (_userScrolledAway && !force) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _lineKeys[_currentLineIndex];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          alignment: 0.28,
        );
      }
    });
  }

  // ── File & Text Loading ────────────────────────────────

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', ..._textExtensions],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;
      await _loadFile(File(path), autoSpeak: true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open file: $e');
    }
  }

  Future<void> _loadFile(File file, {bool autoSpeak = true}) async {
    final name = file.path.replaceAll('\\', '/').split('/').last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'txt';
    final isPdf = (ext == 'pdf');

    // Dispose previous PDF controller before creating new one
    _clearBookHighlights();
    _sfPdfController?.dispose();
    _sfPdfController = null;
    _pdfControllerReady = false;
    _pdfFilePath = null;

    setState(() {
      _loading = false; // Don't block UI — show PDF immediately
      _error = null;
      _fileName = name;
      _isPdf = isPdf;
      _showOriginalPdf = isPdf;
      _currentLineIndex = 0;
      _lines = [];
      _lineKeys.clear();
    });

    try {
      if (isPdf) {
        // ── Step 1: Show PDF instantly — create controller and set file path
        final controller = PdfViewerController();

        if (mounted) {
          setState(() {
            _sfPdfController = controller;
            _pdfFilePath = file.path;
            _pdfControllerReady = false; // set true once SfPdfViewer fires onDocumentLoaded
          });
        }

        // ── Step 2: Extract text for TTS in the background (non-blocking)
        // The PDF is already visible to the user at this point.
        PdfExtractorService.extractDocument(
          file,
          onStatus: (msg) {
            if (mounted) setState(() => _loadingMessage = msg);
          },
        ).then((extracted) {
          if (!mounted) return;
          setState(() {
            _lines = _normalizeLines(extracted.lines);
            _totalPages = extracted.totalPages > 0 ? extracted.totalPages : 1;
            _loadingMessage = '';
          });
          // Start reading if user tapped play while lines were loading,
          // or if autoSpeak was requested on document open.
          final shouldPlay = _pendingPlay || autoSpeak;
          if (shouldPlay) setState(() => _pendingPlay = false);
          if (shouldPlay && _lines.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 350), () {
              if (mounted && _lines.isNotEmpty && _ttsState != TtsState.playing) {
                _speakCurrentLine();
              }
            });
          }
        }).catchError((e) {
          // Text extraction failed — PDF is still visible, just no TTS
          debugPrint('Text extraction failed: $e');
          if (mounted) setState(() => _loadingMessage = '');
        });

        return; // PDF is displayed; text loads in background
      } else {
        // Plain text file — must load synchronously (no visual to show first)
        setState(() => _loading = true);
        final size = await file.length();
        String content;
        const maxBytes = 4 * 1024 * 1024;
        if (size > maxBytes) {
          final raf = await file.open();
          final bytes = await raf.read(maxBytes);
          await raf.close();
          content = String.fromCharCodes(bytes);
        } else {
          content = await file.readAsString();
        }

        final lines = PdfExtractorService.splitIntoRuleLines(content);
        if (mounted) {
          setState(() {
            _lines = _normalizeLines(lines);
            _totalPages = 1;
            _loading = false;
          });
        }
      }

      // Auto-start speaking immediately on document open
      if (autoSpeak && _lines.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _lines.isNotEmpty && _ttsState != TtsState.playing) {
              _speakCurrentLine();
            }
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to open document:\n$e';
          _loading = false;
        });
      }
    }
  }

  List<SpokenLine> _normalizeLines(List<SpokenLine> raw) {
    return List.generate(
      raw.length,
      (i) => SpokenLine(
        index: i,
        text: raw[i].text,
        pageNumber: raw[i].pageNumber,
        isHeading: raw[i].isHeading,
        lineBounds: raw[i].lineBounds,
        words: raw[i].words,
      ),
    );
  }

  void _loadRawText(String text, String name, {bool autoSpeak = true}) {
    _tts.stop();
    _clearBookHighlights();
    _sfPdfController?.dispose();
    _sfPdfController = null;
    _pdfControllerReady = false;
    _pdfFilePath = null;

    final lines = PdfExtractorService.splitIntoRuleLines(text);
    setState(() {
      _fileName = name;
      _isPdf = false;
      _lines = _normalizeLines(lines);
      _totalPages = 1;
      _currentLineIndex = 0;
      _loading = false;
      _error = null;
      _lineKeys.clear();
    });

    if (autoSpeak && lines.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && _lines.isNotEmpty && _ttsState != TtsState.playing) {
            _speakCurrentLine();
          }
        });
      });
    }
  }

  // ── Build Screen ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkPaper ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _loading
                      ? _buildLoadingView()
                      : _error != null && _lines.isEmpty && !_isPdf
                          ? _buildErrorView()
                          : (_isPdf && _pdfFilePath != null)
                              ? _buildPdfDocumentArea()
                              : _lines.isNotEmpty
                                  ? _buildTextDocumentView()
                                  : _buildLanding(),
                ),
              ],
            ),
          ),
          // Audio Player Controls Bar — shown once a document is loaded
          if ((_lines.isNotEmpty || (_isPdf && _pdfFilePath != null)) && !_loading)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildAudioPlayerBar(),
            ),
        ],
      ),
    );
  }

  /// Wraps PDF view and doc view in an IndexedStack so both stay alive in the
  /// widget tree — switching between them is instant (no reload, no lag).
  Widget _buildPdfDocumentArea() {
    // 0 = Book (PDF), 1 = Doc (text)
    final idx = _showOriginalPdf ? 0 : 1;
    return IndexedStack(
      index: idx,
      children: [
        _buildPdfView(),
        _lines.isNotEmpty ? _buildTextDocumentView() : const SizedBox.shrink(),
      ],
    );
  }

  // ── App Bar ────────────────────────────────────────────

  Widget _buildAppBar() {
    final activeLine = (_lines.isNotEmpty && _currentLineIndex < _lines.length)
        ? _lines[_currentLineIndex]
        : null;
    final pageNum = activeLine?.pageNumber ?? 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _isDarkPaper ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _isDarkPaper ? Colors.white70 : Colors.black87,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _fileName,
                  style: TextStyle(
                    color: _isDarkPaper ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_lines.isNotEmpty)
                  Text(
                    'Page $pageNum of $_totalPages · Line ${_currentLineIndex + 1}/${_lines.length}',
                    style: TextStyle(
                      color: _isDarkPaper ? Colors.white54 : const Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          // Switch View Mode: Book (PDF) ↔ Doc (text karaoke)
          if (_isPdf && _pdfFilePath != null && _lines.isNotEmpty)
            IconButton(
              icon: Icon(
                _showOriginalPdf ? Icons.auto_stories_rounded : Icons.picture_as_pdf_rounded,
                color: _isDarkPaper ? Colors.white70 : const Color(0xFF6366F1),
                size: 22,
              ),
              tooltip: _showOriginalPdf ? 'Switch to Doc View' : 'Switch to Book View',
              onPressed: () {
                setState(() => _showOriginalPdf = !_showOriginalPdf);
                if (_showOriginalPdf) {
                  if (_lines.isNotEmpty && _currentLineIndex < _lines.length) {
                    final line = _lines[_currentLineIndex];
                    if (_sfPdfController != null && _pdfControllerReady) {
                      _sfPdfController!.jumpToPage(line.pageNumber);
                      _updateBookSentenceHighlight(line);
                      if (_currentWordStart >= 0) {
                        _updateBookWordHighlight(line, _currentWordStart);
                      }
                    }
                  }
                } else {
                  _scrollToActiveLine(force: true);
                }
              },
            ),
          // Theme Paper Toggle
          IconButton(
            icon: Icon(
              _isDarkPaper ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _isDarkPaper ? Colors.amber : const Color(0xFF475569),
              size: 20,
            ),
            tooltip: _isDarkPaper ? 'Switch to White Paper' : 'Switch to Dark Paper',
            onPressed: () => setState(() => _isDarkPaper = !_isDarkPaper),
          ),
          // Open Document
          IconButton(
            icon: Icon(
              Icons.folder_open_rounded,
              color: _isDarkPaper ? Colors.white70 : const Color(0xFF475569),
              size: 22,
            ),
            tooltip: 'Open Another Document',
            onPressed: _pickFile,
          ),
        ],
      ),
    );
  }

  // ── Real PDF View (Original Document) ─────────────────

  Widget _buildPdfView() {
    final isTtsLoading = _lines.isEmpty && _loadingMessage.isNotEmpty;

    return Stack(
      children: [
        // Original PDF rendered with high-fidelity, pinch zoom, text selection
        if (_pdfFilePath != null)
          SfPdfViewer.file(
            File(_pdfFilePath!),
            key: _pdfViewerKey,
            controller: _sfPdfController,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            canShowPaginationDialog: true,
            pageSpacing: 8,
            // Current sentence: vivid yellow highlight (visible on light PDF pages)
            currentSearchTextHighlightColor: const Color(0xFFFFD600).withValues(alpha: 0.60),
            // Other occurrences: fully transparent — only the current sentence lit
            otherSearchTextHighlightColor: const Color(0x00000000),
            onDocumentLoaded: (PdfDocumentLoadedDetails details) {
              if (mounted) {
                setState(() {
                  _pdfControllerReady = true;
                  if (_sfPdfController?.pageCount != null && _sfPdfController!.pageCount > 0) {
                    _totalPages = _sfPdfController!.pageCount;
                  }
                });
                if (_lines.isNotEmpty && _currentLineIndex < _lines.length) {
                  _updateBookSentenceHighlight(_lines[_currentLineIndex]);
                }
              }
            },
            onPageChanged: (PdfPageChangedDetails details) {
              if (mounted) setState(() {});
            },
            onTap: (PdfGestureDetails details) {
              if (_lines.isEmpty) {
                setState(() => _pendingPlay = true);
                HapticFeedback.lightImpact();
                return;
              }
              final tappedPage = details.pageNumber;
              final pageLines = _lines.where((l) => l.pageNumber == tappedPage).toList();
              if (pageLines.isNotEmpty) {
                final double clickY = details.pagePosition.dy.clamp(0.0, 800.0);
                final double fraction = (clickY / 800.0).clamp(0.0, 0.99);
                final int lineOffset = (fraction * pageLines.length).floor().clamp(0, pageLines.length - 1);
                final targetLine = pageLines[lineOffset];
                _wordSyncTimer?.cancel();
                _activeSpeechSession++;
                setState(() => _currentLineIndex = targetLine.index);
                _speakCurrentLine();
                return;
              }
              _togglePlayPause();
            },
            onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
              final sel = details.selectedText?.trim();
              if (sel != null && sel.isNotEmpty && _lines.isNotEmpty) {
                final matchIdx = _lines.indexWhere((l) => l.text.toLowerCase().contains(sel.toLowerCase()));
                if (matchIdx != -1) {
                  _wordSyncTimer?.cancel();
                  _activeSpeechSession++;
                  setState(() => _currentLineIndex = matchIdx);
                  _speakCurrentLine();
                }
              }
            },
            onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
              if (mounted) {
                setState(() {
                  if (_lines.isEmpty) _error = 'Failed to load PDF: ${details.description}';
                });
              }
            },
          ),



        // ── Background TTS preparation status badge ────────
        if (isTtsLoading)
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _isDarkPaper
                      ? const Color(0xFF1E293B).withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _loadingMessage.isNotEmpty ? _loadingMessage : 'Preparing audio…',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isDarkPaper ? Colors.white70 : const Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }



  // ── Text Document View (for non-PDF files) ─────────────

  Widget _buildTextDocumentView() {
    // Group lines by pageNumber
    final Map<int, List<SpokenLine>> linesByPage = {};
    for (final line in _lines) {
      linesByPage.putIfAbsent(line.pageNumber, () => []).add(line);
    }
    final pageNumbers = linesByPage.keys.toList()..sort();

    return NotificationListener<UserScrollNotification>(
      onNotification: (notif) {
        if (notif.direction != ScrollDirection.idle) {
          if (!_userScrolledAway) {
            setState(() => _userScrolledAway = true);
          }
        }
        return false;
      },
      child: Scrollbar(
        controller: _scrollCtrl,
        thumbVisibility: true,
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
          itemCount: pageNumbers.length,
          itemBuilder: (context, idx) {
            final page = pageNumbers[idx];
            final pageLines = linesByPage[page] ?? [];
            return _buildPaperSheet(page, pageLines);
          },
        ),
      ),
    );
  }

  Widget _buildPaperSheet(int pageNumber, List<SpokenLine> pageLines) {
    final isWhite = !_isDarkPaper;
    final paperBg = isWhite ? Colors.white : const Color(0xFF1E293B);
    final borderColor = isWhite ? const Color(0xFFE2E8F0) : const Color(0xFF334155);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: paperBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isWhite ? 0.08 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pageNumber == 1) ...[
            Text(
              _cleanDocTitle(_fileName),
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isWhite ? const Color(0xFF0F172A) : Colors.white,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),
            Divider(color: borderColor, height: 1, thickness: 1),
            const SizedBox(height: 18),
          ],

          // Page Lines
          ...pageLines.map((line) => _buildLineOnPage(line)),

          // Page Footer
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Page $pageNumber of $_totalPages',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isWhite ? const Color(0xFF94A3B8) : Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cleanDocTitle(String raw) {
    var title = raw.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    return title.replaceAll('_', ' ');
  }

  // ── Line Rendered Directly on the Document Page (text-only) ───

  Widget _buildLineOnPage(SpokenLine line) {
    _lineKeys.putIfAbsent(line.index, () => GlobalKey());
    final isLineActive = (line.index == _currentLineIndex);

    return GestureDetector(
      key: _lineKeys[line.index],
      onTap: () {
        HapticFeedback.selectionClick();
        _wordSyncTimer?.cancel();
        _activeSpeechSession++;
        setState(() {
          _currentLineIndex = line.index;
          _userScrolledAway = false;
        });
        _speakCurrentLine();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: EdgeInsets.only(
          bottom: line.isHeading ? 10 : 4,
          top: line.isHeading ? 10 : 0,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isLineActive ? 8 : 4,
          vertical: isLineActive ? 5 : 2,
        ),
        decoration: BoxDecoration(
          color: isLineActive
              ? (_isDarkPaper
                  ? AppColors.violet.withValues(alpha: 0.22)
                  : const Color(0xFF7B61FF).withValues(alpha: 0.14))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isLineActive
              ? const Border(left: BorderSide(color: AppColors.violet, width: 3.5))
              : null,
        ),
        // ValueListenableBuilder ensures only this line rebuilds on word change
        child: isLineActive
            ? ValueListenableBuilder<int>(
                valueListenable: _wordStartNotifier,
                builder: (context, wordStart, _) {
                  final isWhite = !_isDarkPaper;
                  return _buildLineWordsOnPage(
                      line, _ttsState == TtsState.playing, wordStart, isWhite);
                },
              )
            : _buildLineWordsOnPage(line, false, -1, !_isDarkPaper),
      ),
    );
  }

  Widget _buildLineWordsOnPage(
      SpokenLine line, bool isSpeakingActive, int wordStart, bool isWhite) {
    final matches = RegExp(r'(\S+)|(\s+)').allMatches(line.text).toList();

    return Wrap(
      spacing: 0,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: matches.map((m) {
        final token = m.group(0) ?? '';
        final start = m.start;
        final end = m.end;

        if (token.trim().isEmpty) {
          return Text(
            token,
            style: TextStyle(
              fontSize: line.isHeading ? 17 : 14.5,
              height: line.isHeading ? 1.4 : 1.55,
            ),
          );
        }

        final isWordGlowing =
            isSpeakingActive && wordStart >= 0 && start <= wordStart && end > wordStart;

        if (isWordGlowing) {
          return Container(
            margin: const EdgeInsets.only(right: 1),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFF00D4FF)]),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B61FF).withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              token,
              style: TextStyle(
                color: Colors.white,
                fontSize: line.isHeading ? 17 : 14.5,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          );
        }

        final alreadySpoken = isSpeakingActive && wordStart > 0 && end <= wordStart;

        Color textColor;
        if (line.isHeading) {
          textColor = isWhite ? const Color(0xFF0F172A) : Colors.white;
        } else if (alreadySpoken) {
          textColor = isWhite ? const Color(0xFF94A3B8) : Colors.white38;
        } else if (isSpeakingActive) {
          textColor = isWhite ? const Color(0xFF0F172A) : Colors.white;
        } else {
          textColor = isWhite ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
        }

        return Text(
          token,
          style: TextStyle(
            fontSize: line.isHeading ? 17 : 14.5,
            fontWeight: line.isHeading
                ? FontWeight.w800
                : (isSpeakingActive ? FontWeight.w600 : FontWeight.w400),
            color: textColor,
            height: line.isHeading ? 1.4 : 1.55,
          ),
        );
      }).toList(),
    );
  }

  // ── Floating Audio Controls Bar ─────────────────────────

  Widget _buildAudioPlayerBar() {
    final currentLineText = (_lines.isNotEmpty && _currentLineIndex < _lines.length)
        ? _lines[_currentLineIndex].text
        : '';
    final progress = _lines.isEmpty
        ? 0.0
        : ((_currentLineIndex + 1) / _lines.length).clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: const Border(
          top: BorderSide(color: AppColors.inputBorder, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar across top edge
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.inputBorder.withValues(alpha: 0.4),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7B61FF)),
                ),
              ),
            ),


            if (!_controlsExpanded) ...[
              // ── COMPACT MINI-PLAYER ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                child: Row(
                  children: [
                    if (_ttsState == TtsState.playing)
                      _buildBouncingWaveform()
                    else
                      Icon(
                        _ttsState == TtsState.paused
                            ? Icons.pause_circle_outline_rounded
                            : Icons.headset_rounded,
                        color: _ttsState == TtsState.paused
                            ? AppColors.violetLight
                            : AppColors.textMuted,
                        size: 20,
                      ),
                    const SizedBox(width: 10),

                    // Active Line Snippet & Progress
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _controlsExpanded = true;
                            _userScrolledAway = false;
                          });
                          _panelCtrl.forward();
                          if (!_isPdf) _scrollToActiveLine(force: true);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentLineText.isNotEmpty
                                  ? currentLineText
                                  : 'Document ready to read',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Line ${_currentLineIndex + 1}/${_lines.length} · ${_speedLabel(_speed)}',
                              style: TextStyle(
                                color: AppColors.textSub.withValues(alpha: 0.8),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Jump back to active line (text-only mode)
                    if (!_isPdf && _userScrolledAway)
                      IconButton(
                        icon: const Icon(
                          Icons.my_location_rounded,
                          color: Color(0xFF00D4FF),
                          size: 20,
                        ),
                        tooltip: 'Jump to currently spoken line',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() => _userScrolledAway = false);
                          _scrollToActiveLine(force: true);
                        },
                      ),

                    // Previous Line
                    IconButton(
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: AppColors.textSub,
                        size: 24,
                      ),
                      tooltip: 'Previous Line',
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      constraints: const BoxConstraints(),
                      onPressed: _prevLine,
                    ),

                    const SizedBox(width: 2),

                    // Mini Center Play / Pause button
                    // Shows spinner while lines are still being extracted in background
                    GestureDetector(
                      onTap: () {
                        if (_lines.isEmpty) {
                          // Lines still loading — queue play for when they arrive
                          setState(() => _pendingPlay = true);
                          HapticFeedback.lightImpact();
                        } else {
                          _togglePlayPause();
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGrad,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.violet.withValues(alpha: 0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _lines.isEmpty
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            : Icon(
                                _ttsState == TtsState.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                      ),
                    ),

                    const SizedBox(width: 2),

                    // Next Line
                    IconButton(
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: AppColors.textSub,
                        size: 24,
                      ),
                      tooltip: 'Next Line',
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      constraints: const BoxConstraints(),
                      onPressed: _nextLine,
                    ),

                    // Expand Full Controls Button
                    IconButton(
                      icon: const Icon(
                        Icons.tune_rounded,
                        color: AppColors.textSub,
                        size: 20,
                      ),
                      tooltip: 'Speed & Pitch controls',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() => _controlsExpanded = true);
                        _panelCtrl.forward();
                      },
                    ),
                  ],
                ),
              ),
            ] else ...[
              // ── EXPANDED CONTROLS BAR ─────────────────────────────
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  setState(() => _controlsExpanded = false);
                  _panelCtrl.reverse();
                },
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Status & Waveform Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(
                      _ttsState == TtsState.playing
                          ? Icons.record_voice_over_rounded
                          : (_ttsState == TtsState.paused
                              ? Icons.pause_circle_outline_rounded
                              : Icons.headset_rounded),
                      color: _ttsState == TtsState.playing
                          ? AppColors.violetLight
                          : AppColors.textMuted,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _ttsState == TtsState.playing
                            ? 'Reading: $currentLineText'
                            : (_ttsState == TtsState.paused ? 'Paused' : 'Ready to read'),
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_ttsState == TtsState.playing) _buildBouncingWaveform(),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Full Playback Controls Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Focus active line button (text-only mode)
                    if (!_isPdf && _userScrolledAway)
                      _iconBtn(
                        icon: Icons.my_location_rounded,
                        size: 24,
                        color: const Color(0xFF00D4FF),
                        tooltip: 'Focus Active Line',
                        onTap: () {
                          setState(() => _userScrolledAway = false);
                          _scrollToActiveLine(force: true);
                        },
                      ),

                    // Previous Line
                    _iconBtn(
                      icon: Icons.skip_previous_rounded,
                      size: 28,
                      color: AppColors.textSub,
                      tooltip: 'Previous Line',
                      onTap: _prevLine,
                    ),

                    // Stop Button
                    _iconBtn(
                      icon: Icons.stop_rounded,
                      size: 28,
                      color: AppColors.error,
                      tooltip: 'Stop',
                      onTap: _stop,
                    ),

                    // Big Center Play / Pause Button
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGrad,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.violet.withValues(alpha: 0.55),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          _ttsState == TtsState.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),

                    // Next Line
                    _iconBtn(
                      icon: Icons.skip_next_rounded,
                      size: 28,
                      color: AppColors.textSub,
                      tooltip: 'Next Line',
                      onTap: _nextLine,
                    ),

                    // Speed Quick Cycle Button
                    InkWell(
                      onTap: _cycleSpeed,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.violet.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.violet.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _speedLabel(_speed),
                          style: const TextStyle(
                            color: AppColors.violetLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),

                    // Collapse Button
                    _iconBtn(
                      icon: Icons.keyboard_arrow_down_rounded,
                      size: 26,
                      color: AppColors.violetLight,
                      tooltip: 'Collapse to Mini Player',
                      onTap: () {
                        setState(() => _controlsExpanded = false);
                        _panelCtrl.reverse();
                      },
                    ),
                  ],
                ),
              ),

              // Expandable sliders for Speed, Volume, Pitch
              ClipRect(
                child: SizeTransition(
                  sizeFactor: _panelAnim,
                  child: _buildSliderPanel(),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBouncingWaveform() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final v = _pulseCtrl.value;
        final bars = [0.35, 0.9, 0.6, 1.0, 0.75];
        return SizedBox(
          width: 24,
          height: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: bars.asMap().entries.map((e) {
              final phase = (e.key / bars.length);
              final scale = 0.25 +
                  0.75 *
                      ((v + phase) % 1.0 < 0.5
                          ? (v + phase) % 1.0 * 2
                          : (1 - ((v + phase) % 1.0)) * 2);
              return Container(
                width: 2.5,
                height: 16 * scale,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B61FF), Color(0xFF00D4FF)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSliderPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Column(
        children: [
          const Divider(color: AppColors.inputBorder, height: 1),
          const SizedBox(height: 10),

          _buildSliderRow(
            icon: Icons.speed_rounded,
            label: 'Speed',
            value: _speed,
            min: 0.25,
            max: 1.0,
            displayValue: _speedLabel(_speed),
            color: const Color(0xFF7B61FF),
            onChanged: _applySpeed,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _presetChip('0.5x', 0.25),
              _presetChip('0.75x', 0.38),
              _presetChip('1.0x', 0.5),
              _presetChip('1.25x', 0.63),
              _presetChip('1.5x', 0.75),
              _presetChip('2.0x', 1.0),
            ],
          ),
          const SizedBox(height: 10),

          _buildSliderRow(
            icon: _volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            label: 'Volume',
            value: _volume,
            min: 0.0,
            max: 1.0,
            displayValue: '${(_volume * 100).round()}%',
            color: const Color(0xFF00C9A7),
            onChanged: _applyVolume,
          ),
          const SizedBox(height: 10),

          _buildSliderRow(
            icon: Icons.music_note_rounded,
            label: 'Pitch',
            value: _pitch,
            min: 0.5,
            max: 2.0,
            displayValue: _pitch.toStringAsFixed(1),
            color: const Color(0xFFFF6B6B),
            onChanged: _applyPitch,
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, double val) {
    final isSelected = (_speed - val).abs() < 0.06;
    return GestureDetector(
      onTap: () => _applySpeed(val),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.violet : AppColors.inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.violetLight : AppColors.inputBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textSub,
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSub,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.15),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            displayValue,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required double size,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, color: color, size: size),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }

  // ── Landing & Loading States ───────────────────────────

  Widget _buildLanding() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGrad,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.violet.withValues(alpha: 0.45),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: Text('📖', style: TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 20),
            ShaderMask(
              shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
              child: const Text(
                'Document Smart Reader',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFamily: 'Georgia',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Open any document and listen with live line & word highlights directly on the page.',
              style: AppTextStyles.sub,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GlowButton(
              text: 'Open Document',
              icon: Icons.folder_open_rounded,
              onPressed: _pickFile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    final isDark = _isDarkPaper;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.white54 : const Color(0xFF64748B);

    return Container(
      color: bgColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing document icon with glow
            AnimatedBuilder(
              animation: _loadingGlowCtrl,
              builder: (_, __) {
                final glow = _loadingGlowCtrl.value;
                return Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGrad,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.violet.withValues(
                          alpha: 0.35 + 0.35 * glow,
                        ),
                        blurRadius: 28 + 24 * glow,
                        spreadRadius: 2 + 4 * glow,
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _loadingGlowCtrl,
                      builder: (_, __) {
                        final scale = 0.88 + 0.12 * _loadingGlowCtrl.value;
                        return Transform.scale(
                          scale: scale,
                          child: const Icon(
                            Icons.description_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Stylish card with progress
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _loadingMessage,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This may take a moment for large documents…',
                    style: TextStyle(
                      color: subColor,
                      fontSize: 11.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Gradient animated progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedBuilder(
                      animation: _loadingBounceCtrl,
                      builder: (_, __) {
                        return LinearProgressIndicator(
                          value: null, // indeterminate
                          minHeight: 5,
                          backgroundColor:
                              AppColors.violet.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.lerp(
                              const Color(0xFF7B61FF),
                              const Color(0xFF00D4FF),
                              _loadingBounceCtrl.value,
                            )!,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bouncing dots
                  AnimatedBuilder(
                    animation: _loadingBounceCtrl,
                    builder: (_, __) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final phase = (i / 4.0);
                          final t = (_loadingBounceCtrl.value + phase) % 1.0;
                          final bounce = t < 0.5 ? t * 2 : (1 - t) * 2;
                          final scale = 0.5 + 0.5 * bounce;
                          final opacity = 0.3 + 0.7 * bounce;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF7B61FF)
                                          .withValues(alpha: opacity),
                                      const Color(0xFF00D4FF)
                                          .withValues(alpha: opacity),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              onPressed: _pickFile,
            ),
          ],
        ),
      ),
    );
  }
}
