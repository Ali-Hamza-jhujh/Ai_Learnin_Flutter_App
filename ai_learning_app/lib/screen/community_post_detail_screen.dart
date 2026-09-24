import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/app_theme.dart';
import '../services/api_client.dart';
import 'package:intl/intl.dart';

class CommunityPostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> initialPost;

  const CommunityPostDetailScreen({super.key, required this.initialPost});

  @override
  State<CommunityPostDetailScreen> createState() => _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends State<CommunityPostDetailScreen> {
  late Map<String, dynamic> _post;
  final TextEditingController _answerCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
  }

  Future<void> _refreshPost() async {
    try {
      final res = await ApiClient.get('/api/community/posts');
      final posts = res['data'] ?? [];
      final updated = posts.firstWhere(
        (p) => p['_id'] == _post['_id'],
        orElse: () => null,
      );
      if (updated != null && mounted) {
        setState(() {
          _post = updated;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing post: $e');
    }
  }

  Future<void> _submitAnswer() async {
    final text = _answerCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await ApiClient.post('/api/community/posts/${_post['_id']}/answer', body: {
        'body': text,
      });
      _answerCtrl.clear();
      FocusScope.of(context).unfocus();
      await _refreshPost();
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: const Text('Failed to submit answer. Please try again.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(_),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final answers = _post['answers'] as List? ?? [];
    final authorName = _post['author']?['name'] ?? 'Anonymous';
    final initial = authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.bgCard,
        middle: const Text('Post Details', style: TextStyle(color: AppColors.textWhite)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back, color: AppColors.cyan),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Original Post Card
                  Container(
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
                              radius: 18,
                              child: Text(initial, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(authorName, style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDate(_post['createdAt']),
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(8)),
                              child: Text(_post['subject'] ?? 'General', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(_post['title'] ?? '', style: const TextStyle(color: AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text(
                          _post['body'] ?? '',
                          style: const TextStyle(color: AppColors.textSub, fontSize: 15, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Answers Header
                  Row(
                    children: [
                      const Text(
                        'Answers',
                        style: TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.violet.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.violet.withOpacity(0.5)),
                        ),
                        child: Text(
                          '${answers.length}',
                          style: const TextStyle(color: AppColors.cyan, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (answers.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      alignment: Alignment.center,
                      child: const Column(
                        children: [
                          Icon(CupertinoIcons.chat_bubble_2, color: Colors.grey, size: 48),
                          const SizedBox(height: 12),
                          Text('No answers yet. Be the first to answer!', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                    )
                  else
                    ...answers.map((answer) {
                      final ansAuthorName = answer['author']?['name'] ?? 'Anonymous';
                      final ansInitial = ansAuthorName.isNotEmpty ? ansAuthorName[0].toUpperCase() : '?';
                      final isAI = answer['isAI'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.inputBorder.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isAI ? Colors.teal : AppColors.inputBorder,
                                  radius: 14,
                                  child: isAI 
                                      ? const Icon(Icons.smart_toy, size: 12, color: Colors.white)
                                      : Text(ansInitial, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isAI ? 'Lumio AI' : ansAuthorName,
                                  style: TextStyle(
                                    color: isAI ? Colors.tealAccent : AppColors.textWhite,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                if (isAI) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.teal),
                                    ),
                                    child: const Text('AI', style: TextStyle(color: Colors.tealAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  _formatDate(answer['createdAt']),
                                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              answer['body'] ?? '',
                              style: const TextStyle(color: AppColors.textWhite, fontSize: 14, height: 1.3),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),

            // Input Bar at the Bottom
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                border: Border(top: BorderSide(color: AppColors.inputBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _answerCtrl,
                      placeholder: 'Write an answer...',
                      placeholderStyle: const TextStyle(color: Colors.grey),
                      style: const TextStyle(color: AppColors.textWhite),
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _submitting
                      ? const CupertinoActivityIndicator()
                      : CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Icon(CupertinoIcons.paperplane_fill, color: AppColors.cyan),
                          onPressed: _submitAnswer,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
