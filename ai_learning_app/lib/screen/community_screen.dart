import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/app_theme.dart';
import '../services/api_client.dart';
import 'community_post_detail_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  List<dynamic> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      final res = await ApiClient.get('/api/community/posts');
      if (mounted) {
        setState(() {
          _posts = res['data'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load posts');
    }
  }

  void _showCreatePostDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Ask the Community'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: titleCtrl,
              placeholder: 'Title',
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: bodyCtrl,
              placeholder: 'Details',
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;
              Navigator.pop(context);
              await ApiClient.post('/api/community/posts', body: {
                'title': titleCtrl.text,
                'body': bodyCtrl.text,
                'subject': 'General',
              });
              _loadPosts();
            },
            child: const Text('Post', style: TextStyle(color: AppColors.cyan)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.bgCard,
        middle: const Text('Community Q&A', style: TextStyle(color: AppColors.textWhite)),
        trailing: GestureDetector(
          onTap: _showCreatePostDialog,
          child: const Icon(CupertinoIcons.plus, color: AppColors.cyan),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return _buildPostCard(post);
                },
              ),
      ),
    );
  }

  Widget _buildPostCard(dynamic post) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => CommunityPostDetailScreen(initialPost: post),
          ),
        ).then((_) => _loadPosts());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.violet,
                  radius: 16,
                  child: Text((post['author']['name'] as String)[0].toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Text(post['author']['name'], style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(8)),
                  child: Text(post['subject'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(post['title'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(post['body'], style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(CupertinoIcons.chat_bubble_2, color: Colors.grey, size: 16),
                const SizedBox(width: 4),
                Text('${(post['answers'] as List).length} Answers', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

