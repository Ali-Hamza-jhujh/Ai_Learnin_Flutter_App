import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/group_service.dart';
import '../services/api_client.dart';
import '../utils/app_theme.dart';
import 'group_invite_popup.dart';
import 'notes_screen.dart';
import 'mcq_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _group;
  bool _loading = true;
  String? _error;
  late TabController _tabController;
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentUser();
    _loadGroup();
  }

  Future<void> _loadCurrentUser() async {
    final user = await TokenManager.getUser();
    if (mounted) {
      setState(() => _currentUser = user);
    }
  }

  Future<void> _loadGroup() async {
    try {
      final res = await GroupService.getGroupDetails(widget.groupId);
      if (mounted) {
        setState(() {
          _group = res['data'];
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load group details: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  void _sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    final text = _msgCtrl.text.trim();
    _msgCtrl.clear();
    
    try {
      final res = await GroupService.postMessage(widget.groupId, text);
      if (mounted) {
        setState(() {
          _group!['messages'].add(res['data']);
        });
        _scrollToBottom();
      }
    } catch (e) {
      // Ignore
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isContentOwner(Map<String, dynamic> content) {
    if (_currentUser == null) return false;
    
    final contentUserId = content['userId']?.toString() ?? 
                         content['user']?['_id']?.toString() ??
                         content['user']?.toString();
    
    final currentUserId = _currentUser!['_id']?.toString() ?? 
                         _currentUser!['id']?.toString() ??
                         _currentUser!['userId']?.toString();
    
    return contentUserId == currentUserId;
  }

  bool _isGroupCreator() {
    if (_currentUser == null || _group == null) return false;
    
    final currentUserId = _currentUser!['_id']?.toString() ?? 
                         _currentUser!['id']?.toString() ??
                         _currentUser!['userId']?.toString();
    
    final createdBy = _group!['createdBy']?.toString();
    
    return createdBy == currentUserId;
  }

  bool _isGroupAdmin() {
    if (_currentUser == null) return false;
    
    final currentUserId = _currentUser!['_id']?.toString() ?? 
                         _currentUser!['id']?.toString() ??
                         _currentUser!['userId']?.toString();
    
    final groupMembers = _group?['members'] as List<dynamic>?;
    if (groupMembers != null) {
      for (final member in groupMembers) {
        final memberUser = member['user'] as Map<String, dynamic>?;
        if (memberUser != null) {
          final memberUserId = memberUser['_id']?.toString() ?? 
                              memberUser['id']?.toString();
          if (memberUserId == currentUserId && member['role'] == 'admin') {
            return true;
          }
        }
      }
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.bgCard,
        middle: Text(_group?['name'] ?? 'Loading...', style: const TextStyle(color: AppColors.textWhite)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back, color: AppColors.textWhite),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isGroupCreator())
              GestureDetector(
                onTap: () async {
                  final confirmed = await showCupertinoDialog<bool>(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('Delete Group'),
                      content: const Text('Are you sure you want to delete this group? This action cannot be undone.'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('Cancel'),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          child: const Text('Delete'),
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    try {
                      await GroupService.deleteGroup(widget.groupId);
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      // Ignore error
                    }
                  }
                },
                child: const Icon(CupertinoIcons.delete, color: AppColors.error, size: 24),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_group != null) {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (context) => GroupInvitePopup(groupName: _group!['name'], inviteCode: _group!['inviteCode']),
                  );
                }
              },
              child: const Icon(CupertinoIcons.qrcode, color: AppColors.cyan, size: 24),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
                : Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        indicatorColor: AppColors.violet,
                        labelColor: AppColors.violetLight,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(text: 'Chat'),
                          Tab(text: 'Leaderboard'),
                          Tab(text: 'Shared Content'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildChatTab(),
                            _buildLeaderboardTab(),
                            _buildSharedContentTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildChatTab() {
    final messages = _group!['messages'] as List<dynamic>? ?? [];
    final isAdmin = _isGroupAdmin();
    final currentUserId = _currentUser!['_id']?.toString() ?? 
                         _currentUser!['id']?.toString() ??
                         _currentUser!['userId']?.toString();
    
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final sender = msg['sender'];
              final senderId = sender['_id']?.toString() ?? sender['id']?.toString();
              final isOwnMessage = senderId == currentUserId;
              final canDelete = isAdmin || isOwnMessage;
              
              return GestureDetector(
                onTap: () async {
                  if (canDelete) {
                    final action = await showCupertinoModalPopup<String>(
                      context: context,
                      builder: (BuildContext context) {
                        return CupertinoActionSheet(
                          title: const Text('Message Options'),
                          message: const Text('Choose an action'),
                          actions: [
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.pop(context, 'delete');
                              },
                              isDestructiveAction: true,
                              child: const Text('Delete Message'),
                            ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Cancel'),
                          ),
                        );
                      },
                    );
                    
                    if (action == 'delete') {
                      final confirmed = await showCupertinoDialog<bool>(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text('Delete Message'),
                          content: const Text('Are you sure you want to delete this message?'),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.pop(context, false),
                            ),
                            CupertinoDialogAction(
                              isDestructiveAction: true,
                              child: const Text('Delete'),
                              onPressed: () => Navigator.pop(context, true),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        try {
                          await GroupService.deleteMessage(widget.groupId, msg['_id']);
                          _loadGroup();
                        } catch (e) {
                          // Ignore error
                        }
                      }
                    }
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: isOwnMessage ? MainAxisAlignment.start : MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isOwnMessage) ...[
                        CircleAvatar(
                          backgroundColor: AppColors.cyan,
                          radius: 16,
                          child: Text(sender['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isOwnMessage ? AppColors.violet : AppColors.bgCard,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isOwnMessage ? const Radius.circular(4) : const Radius.circular(16),
                              bottomRight: isOwnMessage ? const Radius.circular(16) : const Radius.circular(4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isOwnMessage)
                                Text(sender['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.cyan, fontSize: 12)),
                              if (isOwnMessage) const SizedBox(height: 4),
                              Text(msg['text'], style: TextStyle(color: isOwnMessage ? Colors.white : AppColors.textWhite, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                      if (!isOwnMessage) ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: AppColors.violet,
                          radius: 16,
                          child: Text(sender['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.bgCard,
          child: Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _msgCtrl,
                  placeholder: 'Type a message...',
                  style: const TextStyle(color: AppColors.textWhite),
                  decoration: BoxDecoration(
                    color: AppColors.inputBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.violet,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTab() {
    final members = List<dynamic>.from(_group!['members'] ?? []);
    // Sort by XP descending
    members.sort((a, b) => ((b['user']['xp'] ?? 0) as num).compareTo((a['user']['xp'] ?? 0) as num));
    final isAdmin = _isGroupAdmin();
    final currentUserId = _currentUser!['_id']?.toString() ?? 
                         _currentUser!['id']?.toString() ??
                         _currentUser!['userId']?.toString();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final user = member['user'];
        final memberUserId = user['_id']?.toString() ?? user['id']?.toString();
        final isCurrentUser = memberUserId == currentUserId;
        final canRemove = isAdmin && !isCurrentUser && member['role'] != 'admin';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: index == 0 ? AppColors.gold : AppColors.inputBorder, width: index == 0 ? 2 : 1),
          ),
          child: Row(
            children: [
              Text('#${index + 1}', style: TextStyle(color: index == 0 ? AppColors.gold : Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              CircleAvatar(backgroundColor: AppColors.violet.withOpacity(0.3), child: Text(user['name'][0].toUpperCase(), style: const TextStyle(color: AppColors.textWhite))),
              const SizedBox(width: 16),
              Expanded(child: Text(user['name'], style: const TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.bold))),
              Text('${user['xp']} XP', style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold)),
              if (canRemove) ...[
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 30,
                  onPressed: () async {
                    final confirmed = await showCupertinoDialog<bool>(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: const Text('Remove User'),
                        content: Text('Are you sure you want to remove ${user['name']} from the group?'),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.pop(context, false),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            child: const Text('Remove'),
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      try {
                        if (memberUserId != null) {
                          await GroupService.removeUser(widget.groupId, memberUserId);
                          _loadGroup();
                        }
                      } catch (e) {
                        // Ignore error
                      }
                    }
                  },
                  child: const Icon(CupertinoIcons.person_badge_minus, color: Colors.red, size: 20),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSharedContentTab() {
    final notes = (_group?['sharedNotes'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final mcqs = (_group?['sharedMcqs'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final isAdmin = _isGroupAdmin();

    if (notes.isEmpty && mcqs.isEmpty) {
      return const Center(
        child: Text(
          'No shared content in this group yet.\nGo to your Notes or Quizzes to share!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notes.isNotEmpty) ...[
            const Text(
              'Shared Notes',
              style: TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...notes.map((note) {
              final isOwner = _isContentOwner(note);
              final canDelete = isAdmin || isOwner;
              
              return GestureDetector(
                onLongPress: () async {
                  if (canDelete) {
                    final confirmed = await showCupertinoDialog<bool>(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: const Text('Remove from Group'),
                        content: const Text('Are you sure you want to remove this note from the group?'),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.pop(context, false),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            child: const Text('Remove'),
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      try {
                        await GroupService.removeNote(widget.groupId, note['_id']);
                        _loadGroup();
                      } catch (e) {
                        // Ignore error
                      }
                    }
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.violet.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(CupertinoIcons.doc_plaintext, color: AppColors.violet),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note['title'] ?? 'Untitled Note',
                              style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mode: ${note['mode'] ?? 'Full'}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        color: AppColors.violet,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NoteViewerScreen(
                                noteId: note['_id'],
                                title: note['title'] ?? 'Notes',
                                fromGroup: true,
                              ),
                            ),
                          );
                        },
                        child: const Text('View', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
          if (mcqs.isNotEmpty) ...[
            const Text(
              'Shared Quizzes',
              style: TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...mcqs.map((mcq) {
              final isOwner = _isContentOwner(mcq);
              final canDelete = isAdmin || isOwner;
              
              return GestureDetector(
                onLongPress: () async {
                  if (canDelete) {
                    final confirmed = await showCupertinoDialog<bool>(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: const Text('Remove from Group'),
                        content: const Text('Are you sure you want to remove this quiz from the group?'),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.pop(context, false),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            child: const Text('Remove'),
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      try {
                        await GroupService.removeMcq(widget.groupId, mcq['_id']);
                        _loadGroup();
                      } catch (e) {
                        // Ignore error
                      }
                    }
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(CupertinoIcons.question_square, color: AppColors.cyan),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mcq['title'] ?? 'Untitled Quiz',
                              style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Difficulty: ${mcq['difficulty'] ?? 'Medium'} • Mode: ${mcq['mode'] ?? 'Practice'}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        color: AppColors.cyan,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TakeTestScreen(
                                mcqId: mcq['_id'],
                                title: mcq['title'] ?? 'Quiz',
                                fromGroup: true,
                              ),
                            ),
                          );
                        },
                        child: const Text('Solve', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
