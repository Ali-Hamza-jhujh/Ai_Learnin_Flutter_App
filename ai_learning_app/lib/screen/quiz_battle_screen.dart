import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/app_theme.dart';
import '../services/api_client.dart';

class QuizBattleScreen extends StatefulWidget {
  const QuizBattleScreen({super.key});

  @override
  State<QuizBattleScreen> createState() => _QuizBattleScreenState();
}

class _QuizBattleScreenState extends State<QuizBattleScreen> {
  List<dynamic> _battles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBattles();
  }

  Future<void> _loadBattles() async {
    try {
      final res = await ApiClient.get('/api/battle/my');
      if (mounted) {
        setState(() {
          _battles = res['data'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showChallengeDialog() {
    final opponentIdCtrl = TextEditingController();
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Challenge a Friend'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: opponentIdCtrl,
              placeholder: 'Opponent User ID',
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
              if (opponentIdCtrl.text.isEmpty) return;
              Navigator.pop(context);
              // Mock MCQ set ID for now
              await ApiClient.post('/api/battle/challenge', body: {
                'opponentId': opponentIdCtrl.text,
                'mcqSetId': '60d5ecb74d6bb892b70f0891'
              });
              _loadBattles();
            },
            child: const Text('Challenge', style: TextStyle(color: AppColors.gold)),
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
        middle: const Text('Quiz Battles ⚔️', style: TextStyle(color: AppColors.textWhite)),
        trailing: GestureDetector(
          onTap: _showChallengeDialog,
          child: const Icon(CupertinoIcons.add, color: AppColors.gold),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _battles.isEmpty
                ? const Center(child: Text('No active battles. Challenge someone!', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _battles.length,
                    itemBuilder: (context, index) {
                      final battle = _battles[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Vs. ${(battle['opponent']?['name']) ?? 'Unknown'}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Status: ${battle['status']}', style: TextStyle(color: battle['status'] == 'active' ? AppColors.success : Colors.grey)),
                              ],
                            ),
                            CupertinoButton(
                              color: AppColors.gold,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              onPressed: () {},
                              child: const Text('Play'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
