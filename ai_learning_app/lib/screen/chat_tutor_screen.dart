import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import '../services/api_client.dart';

// ══════════════════════════════════════════
// CHAT TUTOR SCREEN — 3 screens:
// 1. ChatList     — all chat sessions
// 2. NewChat      — create session + optional PDF
// 3. ChatRoom     — streaming AI conversation
// ══════════════════════════════════════════

class ChatTutorScreen extends StatefulWidget {
  const ChatTutorScreen({super.key});
  @override
  State<ChatTutorScreen> createState() => _ChatTutorScreenState();
}

class _ChatTutorScreenState extends State<ChatTutorScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _chats = [];
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
    _loadChats();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ChatService.getMyChats();
      final list = res['chats'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _chats = list.map((e) => e as Map<String, dynamic>).toList();
          _loading = false;
        });
        _fadeCtrl.forward(from: 0);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to load chats'; _loading = false; });
    }
  }

  Future<void> _deleteChat(String chatId) async {
    try {
      await ChatService.deleteChat(chatId);
      if (mounted) setState(() => _chats.removeWhere((c) => c['_id'] == chatId));
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
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B)))
              : _error != null
                ? _buildError()
                : _chats.isEmpty
                  ? _buildEmpty()
                  : _buildChatList()),
        ])),
        Positioned(bottom: 24, right: 24, child: _buildFAB()),
      ]));
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]).createShader(b),
          child: const Text('AI Tutor',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
              color: Colors.white, fontFamily: 'Georgia'))),
        Text('${_chats.length} conversation${_chats.length == 1 ? '' : 's'}',
          style: AppTextStyles.sub),
      ]),
      const Spacer(),
      IconButton(
        onPressed: _loadChats,
        icon: const Icon(Icons.refresh_rounded, color: AppColors.textSub)),
    ]));

  Widget _buildEmpty() => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 100, height: 100,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.3),
            blurRadius: 24, offset: const Offset(0, 8))]),
        child: const Center(child: Text('🤖', style: TextStyle(fontSize: 48)))),
      const SizedBox(height: 24),
      ShaderMask(
        shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
        child: const Text('Ask Anything',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
            color: Colors.white, fontFamily: 'Georgia'))),
      const SizedBox(height: 8),
      const Text('Start a conversation with your\nAI study tutor anytime.',
        style: AppTextStyles.sub, textAlign: TextAlign.center),
      const SizedBox(height: 32),
      GlowButton(
        text: 'Start Chatting',
        icon: Icons.chat_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
        onPressed: _openNewChat),
    ])));

  Widget _buildError() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      buildErrorBanner(_error!),
      const SizedBox(height: 16),
      GlowButton(
        text: 'Retry',
        icon: Icons.refresh_rounded,
        onPressed: _loadChats),
    ])));

  Widget _buildChatList() => FadeTransition(
    opacity: _fadeAnim,
    child: RefreshIndicator(
      color: const Color(0xFFFF6B6B),
      backgroundColor: AppColors.bgCard,
      onRefresh: _loadChats,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
        itemCount: _chats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _chatCard(_chats[i]))));

  Widget _chatCard(Map<String, dynamic> chat) {
    final title = chat['title'] as String? ?? 'Chat';
    final subject = chat['subject'] as String? ?? '';
    final hasDoc = chat['hasDocument'] as bool? ?? false;
    final msgCount = (chat['totalMessages'] as num?)?.toInt() ?? 0;
    final date = _formatDate(chat['updatedAt'] as String?);

    return Dismissible(
      key: Key(chat['_id'] as String),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.2),
          borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_rounded, color: AppColors.error)),
      onDismissed: (_) => _deleteChat(chat['_id'] as String),
      child: GestureDetector(
        onTap: () => _openChat(chat['_id'] as String, title),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.inputBorder)),
          child: Row(children: [
            Container(width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                borderRadius: BorderRadius.circular(16)),
              child: Center(child: Text(
                hasDoc ? '📄' : '🤖',
                style: const TextStyle(fontSize: 22)))),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                style: const TextStyle(color: AppColors.textWhite,
                  fontSize: 15, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                if (subject.isNotEmpty) ...[
                  Text(subject, style: AppTextStyles.body.copyWith(
                    color: AppColors.cyan, fontSize: 12)),
                  const SizedBox(width: 8),
                ],
                Text('$msgCount msg${msgCount == 1 ? '' : 's'}',
                  style: AppTextStyles.label.copyWith(fontSize: 11)),
                const Spacer(),
                Text(date, style: AppTextStyles.label.copyWith(fontSize: 10)),
              ]),
            ])),
            const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 18),
          ]))));
  }

  Widget _buildFAB() => GestureDetector(
    onTap: () { HapticFeedback.mediumImpact(); _openNewChat(); },
    child: Container(width: 60, height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: const Color(0xFFFF6B6B).withOpacity(0.5),
          blurRadius: 20, offset: const Offset(0, 8))]),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28)));

  void _openNewChat() async {
    final result = await Navigator.push<String?>(context,
      PageRouteBuilder<String?>(
        pageBuilder: (_, a, __) => const _NewChatScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child)),
        transitionDuration: const Duration(milliseconds: 350)));

    if (result != null && mounted) {
      _loadChats();
      _openChat(result, 'New Chat');
    }
  }

  void _openChat(String chatId, String title) {
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, a, __) => _ChatRoomScreen(chatId: chatId, title: title),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 300)));
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ══════════════════════════════════════════
// NEW CHAT SCREEN
// ══════════════════════════════════════════

class _NewChatScreen extends StatefulWidget {
  const _NewChatScreen();
  @override
  State<_NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<_NewChatScreen> {
  final _titleCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  File? _pdfFile;
  String _fileName = '';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPDF() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf']);
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;
      setState(() {
        _pdfFile = File(path);
        _fileName = result.files.first.name;
      });
    } catch (_) {}
  }

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a chat title');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ChatService.newChat(
        title: _titleCtrl.text.trim(),
        subject: _subjectCtrl.text.trim().isEmpty
          ? null : _subjectCtrl.text.trim(),
        pdfFile: _pdfFile);
      if (mounted) {
        Navigator.pop(context, res['chatId'] as String?);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Failed to create chat';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const SpaceBackground(),
        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textSub, size: 20),
                onPressed: () => Navigator.pop(context)),
              const Spacer(),
              ShaderMask(
                shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
                child: const Text('New Chat',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: Colors.white))),
              const Spacer(),
              const SizedBox(width: 44),
            ])),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              const SizedBox(height: 32),
              Container(width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFFFF6B6B).withOpacity(0.4),
                    blurRadius: 24, offset: const Offset(0, 8))]),
                child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 40)))),
              const SizedBox(height: 20),
              const Text('Start a conversation',
                style: TextStyle(color: AppColors.textWhite,
                  fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Ask your AI tutor anything.\nOptionally attach a PDF for context.',
                style: AppTextStyles.sub, textAlign: TextAlign.center),
              const SizedBox(height: 32),

              if (_error != null) ...[
                buildErrorBanner(_error!),
                const SizedBox(height: 20),
              ],

              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  AppTextField(
                    label: 'Chat Title',
                    hint: 'e.g. Physics Doubts, Exam Prep',
                    controller: _titleCtrl,
                    prefixIcon: Icons.chat_outlined),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Subject (optional)',
                    hint: 'e.g. Mathematics, Chemistry',
                    controller: _subjectCtrl,
                    prefixIcon: Icons.book_outlined,
                    textInputAction: TextInputAction.done),

                  const SizedBox(height: 20),
                  const Divider(color: AppColors.inputBorder),
                  const SizedBox(height: 16),

                  const Row(children: [
                    Text('📎', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text('Attach PDF (optional)',
                      style: TextStyle(color: AppColors.textWhite,
                        fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    'Attach your textbook or notes so the AI\ncan answer questions about it.',
                    style: AppTextStyles.body.copyWith(fontSize: 12)),
                  const SizedBox(height: 12),

                  GestureDetector(
                    onTap: _pickPDF,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _pdfFile != null
                          ? const Color(0xFFFF6B6B).withOpacity(0.06)
                          : AppColors.inputBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _pdfFile != null
                            ? const Color(0xFFFF6B6B) : AppColors.inputBorder,
                          width: 1.5)),
                      child: Row(children: [
                        Text(_pdfFile != null ? '📄' : '📁',
                          style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(
                          _pdfFile != null ? _fileName : 'Tap to select PDF',
                          style: TextStyle(
                            color: _pdfFile != null
                              ? AppColors.textWhite : AppColors.textMuted,
                            fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis)),
                        if (_pdfFile != null)
                          GestureDetector(
                            onTap: () => setState(() {
                              _pdfFile = null;
                              _fileName = '';
                            }),
                            child: const Icon(Icons.close_rounded,
                              color: AppColors.textMuted, size: 16)),
                      ]))),
                ])),

              const SizedBox(height: 24),
              GlowButton(
                text: 'Start Chat',
                icon: Icons.chat_rounded,
                isLoading: _loading,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                onPressed: _create),
              const SizedBox(height: 40),
            ]))),
        ])),
      ]));
  }
}

// ══════════════════════════════════════════
// CHAT ROOM SCREEN
// ══════════════════════════════════════════

class _ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String title;
  const _ChatRoomScreen({required this.chatId, required this.title});
  @override
  State<_ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<_ChatRoomScreen>
    with TickerProviderStateMixin {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<_ChatMessage> _messages = [];
  bool _loadingHistory = true;
  bool _isTyping = false;
  String _streamingReply = '';

  // FIX 1: Three separate controllers for staggered dot animation
  late AnimationController _dot1Ctrl;
  late AnimationController _dot2Ctrl;
  late AnimationController _dot3Ctrl;

  @override
  void initState() {
    super.initState();

    // FIX 1: Staggered dot animations with proper delays
    _dot1Ctrl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);

    _dot2Ctrl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 600));
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _dot2Ctrl.repeat(reverse: true);
    });

    _dot3Ctrl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 600));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _dot3Ctrl.repeat(reverse: true);
    });

    _loadHistory();
  }

  @override
  void dispose() {
    _dot1Ctrl.dispose();
    _dot2Ctrl.dispose();
    _dot3Ctrl.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await ChatService.getChatById(widget.chatId);
      final chat = res['chat'] as Map<String, dynamic>;
      final msgs = (chat['messages'] as List<dynamic>? ?? [])
          .map((m) => m as Map<String, dynamic>).toList();
      if (mounted) {
        setState(() {
          _messages = msgs.map((m) => _ChatMessage(
            role: m['role'] as String? ?? 'user',
            content: m['content'] as String? ?? '')).toList();
          _loadingHistory = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isTyping) return;

    HapticFeedback.lightImpact();
    _msgCtrl.clear();

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _isTyping = true;
      _streamingReply = '';
    });
    _scrollToBottom();

    try {
      final stream = ChatService.sendMessageStream(widget.chatId, text);
      await for (final chunk in stream) {
        if (mounted) {
          setState(() => _streamingReply += chunk);
          _scrollToBottom();
        }
      }
      // FIX 2: Check mounted before setState after stream completes
      if (mounted) {
        if (_streamingReply.isNotEmpty) {
          setState(() {
            _messages.add(_ChatMessage(
              role: 'assistant', content: _streamingReply));
            _streamingReply = '';
            _isTyping = false;
          });
        } else {
          setState(() { _isTyping = false; _streamingReply = ''; });
        }
        _scrollToBottom();
      }
    } catch (streamError) {
      // FIX 3: Fallback to non-streaming with original error preserved
      try {
        final res = await ChatService.sendMessage(widget.chatId, text);
        final reply = res['reply'] as String? ?? 'Sorry, I could not respond.';
        if (mounted) {
          setState(() {
            _messages.add(_ChatMessage(role: 'assistant', content: reply));
            _streamingReply = '';
            _isTyping = false;
          });
          _scrollToBottom();
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _messages.add(const _ChatMessage(
              role: 'assistant',
              content: 'Sorry, something went wrong. Please try again.'));
            _streamingReply = '';
            _isTyping = false;
          });
        }
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut);
      }
    });
  }

  // FIX 4: Properly structured async clear chat dialog
  void _clearChat() {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🗑️', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            const Text('Clear History?',
              style: TextStyle(color: AppColors.textWhite,
                fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('This will delete all messages\nin this chat.',
              style: AppTextStyles.sub, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(dialogCtx),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.inputBg,
                    borderRadius: BorderRadius.circular(12)),
                  child: const Text('Cancel',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSub,
                      fontWeight: FontWeight.w600))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () async {
                  Navigator.pop(dialogCtx);
                  try {
                    await ChatService.clearChat(widget.chatId);
                    if (mounted) setState(() => _messages = []);
                  } catch (_) {}
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.error.withOpacity(0.3))),
                  child: const Text('Clear',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.error,
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
        SafeArea(child: Column(children: [
          // ── Header ──────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgCard.withOpacity(0.8),
              border: Border(bottom: BorderSide(
                color: AppColors.inputBorder))),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textSub, size: 20),
                onPressed: () => Navigator.pop(context)),
              Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                  borderRadius: BorderRadius.circular(12)),
                child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 18)))),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title,
                  style: const TextStyle(color: AppColors.textWhite,
                    fontSize: 15, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
                // FIX 5: Removed AnimatedBuilder on disposed controller
                Text(
                  _isTyping ? 'Typing...' : 'AI Tutor · Online',
                  style: TextStyle(
                    color: _isTyping
                      ? const Color(0xFFFF6B6B) : AppColors.success,
                    fontSize: 11, fontWeight: FontWeight.w500)),
              ])),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.textMuted, size: 20),
                onPressed: _clearChat),
            ])),

          // ── Messages ──────────────────────
          Expanded(
            child: _loadingHistory
              ? const Center(child: CircularProgressIndicator(
                  color: Color(0xFFFF6B6B)))
              : _messages.isEmpty && !_isTyping
              ? _buildWelcome()
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _messages.length && _isTyping) {
                      return _buildStreamingBubble();
                    }
                    return _buildMessageBubble(_messages[i]);
                  })),

          // ── Input bar ───────────────────
          _buildInputBar(),
        ])),
      ]));
  }

  // FIX 6: Quick prompt tap now triggers setState to rebuild send button
  Widget _buildWelcome() => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🤖', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 16),
      ShaderMask(
        shaderCallback: (b) => const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]).createShader(b),
        child: const Text('Hi! I\'m your AI Tutor',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
            color: Colors.white, fontFamily: 'Georgia'),
          textAlign: TextAlign.center)),
      const SizedBox(height: 10),
      const Text(
        'Ask me anything about your studies.\nI\'m here to help you understand and learn.',
        style: AppTextStyles.sub, textAlign: TextAlign.center),
      const SizedBox(height: 28),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
        children: [
          'Explain this topic',
          'Give me examples',
          'Quiz me',
          'Simplify this',
        ].map((p) => GestureDetector(
          onTap: () {
            // FIX 6: setState so send button activates immediately
            setState(() => _msgCtrl.text = p);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF6B6B).withOpacity(0.3))),
            child: Text(p, style: const TextStyle(
              color: Color(0xFFFF6B6B), fontSize: 12,
              fontWeight: FontWeight.w600))))).toList()),
    ])));

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        left: isUser ? 60 : 0,
        right: isUser ? 0 : 60),
      child: Row(
        mainAxisAlignment: isUser
          ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(width: 30, height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                borderRadius: BorderRadius.circular(10)),
              child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 14)))),
            const SizedBox(width: 8),
          ],
          Flexible(child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: isUser ? const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]) : null,
              color: isUser ? null : AppColors.bgCard,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18)),
              border: isUser ? null : Border.all(
                color: AppColors.inputBorder)),
            child: SelectableText(msg.content,
              style: TextStyle(
                color: isUser ? Colors.white : AppColors.textLight,
                fontSize: 14, height: 1.6)))),
          if (isUser) const SizedBox(width: 8),
        ]));
  }

  Widget _buildStreamingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 60),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(width: 30, height: 30,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
            borderRadius: BorderRadius.circular(10)),
          child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 14)))),
        const SizedBox(width: 8),
        Flexible(child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18)),
            border: Border.all(color: AppColors.inputBorder)),
          // FIX 7: Show streaming text if available, else show dots
          child: _streamingReply.isNotEmpty
            ? SelectableText(_streamingReply,
                style: const TextStyle(color: AppColors.textLight,
                  fontSize: 14, height: 1.6))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                _dot(_dot1Ctrl),
                const SizedBox(width: 4),
                _dot(_dot2Ctrl),
                const SizedBox(width: 4),
                _dot(_dot3Ctrl),
              ]))),
      ]));
  }

  // FIX 1: Each dot takes its own controller for real staggered animation
  Widget _dot(AnimationController ctrl) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withOpacity(
            0.3 + (ctrl.value * 0.7)),
          shape: BoxShape.circle)));
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withOpacity(0.95),
        border: Border(top: BorderSide(color: AppColors.inputBorder))),
      child: Row(children: [
        Expanded(child: Container(
          decoration: BoxDecoration(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.inputBorder)),
          child: TextField(
            controller: _msgCtrl,
            style: const TextStyle(
              color: AppColors.textWhite, fontSize: 15),
            maxLines: 4,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Ask anything...',
              hintStyle: TextStyle(color: AppColors.textMuted),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 18, vertical: 12)),
            onChanged: (_) => setState(() {})))),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _isTyping ? null : _sendMessage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: _msgCtrl.text.trim().isNotEmpty && !_isTyping
                ? const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)])
                : null,
              color: _msgCtrl.text.trim().isEmpty || _isTyping
                ? AppColors.inputBg : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _msgCtrl.text.trim().isNotEmpty && !_isTyping
                ? [BoxShadow(
                    color: const Color(0xFFFF6B6B).withOpacity(0.4),
                    blurRadius: 12, offset: const Offset(0, 4))]
                : null),
            child: _isTyping
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF6B6B), strokeWidth: 2))
              : Icon(Icons.send_rounded,
                  color: _msgCtrl.text.trim().isNotEmpty
                    ? Colors.white : AppColors.textMuted,
                  size: 22))),
      ]));
  }
}

// ── Message model ─────────────────────────
class _ChatMessage {
  final String role;
  final String content;
  const _ChatMessage({required this.role, required this.content});
}