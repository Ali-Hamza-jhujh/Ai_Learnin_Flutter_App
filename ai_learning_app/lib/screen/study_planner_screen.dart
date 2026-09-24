import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../core/theme/app_typography.dart';

class StudyPlanMilestone {
  final int dayNumber;
  final String title;
  final String description;
  final String actionType; // notes, quiz, flashcards
  bool completed;

  StudyPlanMilestone({
    required this.dayNumber,
    required this.title,
    required this.description,
    required this.actionType,
    this.completed = false,
  });
}

class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key});

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  final _titleCtrl = TextEditingController(text: 'Final Exam Prep');
  final _subjectCtrl = TextEditingController(text: 'General Science');
  final _topicsCtrl = TextEditingController(text: 'Cell Biology, Genetics, Metabolism, Ecology');
  DateTime _examDate = DateTime.now().add(const Duration(days: 10));
  List<StudyPlanMilestone> _milestones = [];

  @override
  void initState() {
    super.initState();
    _generateSchedule();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    _topicsCtrl.dispose();
    super.dispose();
  }

  void _generateSchedule() {
    final daysRemaining = _examDate.difference(DateTime.now()).inDays + 1;
    final topics = _topicsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    List<StudyPlanMilestone> list = [];
    int topicIdx = 0;
    for (int d = 1; d <= daysRemaining; d++) {
      String currentTopic = topics.isNotEmpty ? topics[topicIdx % topics.length] : 'Topic $d';
      if (d == daysRemaining) {
        list.add(StudyPlanMilestone(
          dayNumber: d,
          title: 'Final Revision & Mock Quiz',
          description: 'Review all weak areas and attempt full practice exam.',
          actionType: 'quiz',
        ));
      } else if (d % 2 == 1) {
        list.add(StudyPlanMilestone(
          dayNumber: d,
          title: 'Study & Notes: $currentTopic',
          description: 'Generate AI Study Notes and review key terms.',
          actionType: 'notes',
        ));
        topicIdx++;
      } else {
        list.add(StudyPlanMilestone(
          dayNumber: d,
          title: 'Active Recall: $currentTopic',
          description: 'Attempt 15 Practice MCQs & rate Flashcards via SRS.',
          actionType: 'flashcards',
        ));
      }
    }

    setState(() {
      _milestones = list;
    });
  }

  int get _daysLeft => _examDate.difference(DateTime.now()).inDays + 1;

  double get _completionProgress {
    if (_milestones.isEmpty) return 0.0;
    int done = _milestones.where((m) => m.completed).length;
    return done / _milestones.length;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _completionProgress;
    final progressPct = (progress * 100).toInt();

    return ScaffoldMessenger(
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.bg,
        navigationBar: CupertinoNavigationBar(
          leading: const CupertinoNavigationBarBackButton(previousPageTitle: ''),
          backgroundColor: AppColors.bgCard.withValues(alpha: 0.8),
          middle: Text('AI Study Planner',
              style: AppTypography.titleLarge.copyWith(fontSize: 18, color: AppColors.textWhite)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium Visual Countdown Banner with Circular Ring Progress
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1E36), Color(0xFF1E1035)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyan.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Circular Ring Progress
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 76,
                            height: 76,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyan),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$progressPct%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'done',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_daysLeft Days Remaining',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Inter'),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _titleCtrl.text,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _subjectCtrl.text,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Exam Config Sheet
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('EXAM SETTINGS', style: AppTextStyles.label),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _examDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() {
                                  _examDate = picked;
                                  _generateSchedule();
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.cyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.edit_calendar_rounded, color: AppColors.cyan, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Change Date (${_examDate.day}/${_examDate.month})',
                                    style: const TextStyle(color: AppColors.cyan, fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Exam Name',
                        hint: 'e.g. Biology Midterm',
                        controller: _titleCtrl,
                        prefixIcon: Icons.edit_note_rounded,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Topics to Cover (comma separated)',
                        hint: 'e.g. Genetics, Photosynthesis',
                        controller: _topicsCtrl,
                        prefixIcon: Icons.list_alt_rounded,
                      ),
                      const SizedBox(height: 16),
                      GlowButton(
                        text: 'Re-generate AI Timeline',
                        icon: Icons.auto_awesome_rounded,
                        onPressed: _generateSchedule,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Daily Milestones List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('DAILY MILESTONES', style: AppTextStyles.label),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$progressPct% Complete',
                        style: const TextStyle(color: AppColors.cyan, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _milestones.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final m = _milestones[i];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          m.completed = !m.completed;
                        });
                        HapticFeedback.selectionClick();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: m.completed
                              ? const Color(0xFF0C1625)
                              : AppColors.bgCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: m.completed 
                                ? AppColors.cyan.withValues(alpha: 0.5) 
                                : AppColors.inputBorder,
                            width: m.completed ? 1.5 : 1.0,
                          ),
                          boxShadow: m.completed ? [
                            BoxShadow(
                              color: AppColors.cyan.withValues(alpha: 0.05),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ] : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: m.completed
                                    ? AppColors.cyan.withValues(alpha: 0.15)
                                    : AppColors.violet.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  'D${m.dayNumber}',
                                  style: TextStyle(
                                    color: m.completed ? AppColors.cyan : AppColors.violet,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.title,
                                    style: TextStyle(
                                      color: m.completed ? AppColors.textMuted : AppColors.textWhite,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      decoration: m.completed ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    m.description,
                                    style: AppTextStyles.body.copyWith(fontSize: 11, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              m.completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: m.completed ? AppColors.cyan : AppColors.textMuted,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
