import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import '../services/api_client.dart';

// ══════════════════════════════════════════
// EXAM PREDICTION SCREEN — 4 tabs:
// 1. Dashboard    — overview + quick predict
// 2. Weak Topics  — subjects needing attention
// 3. Performance  — charts + trends
// 4. Study Plan   — AI recommendations
// ══════════════════════════════════════════

class ExamPredictionScreen extends StatefulWidget {
  const ExamPredictionScreen({super.key});
  @override
  State<ExamPredictionScreen> createState() => _ExamPredictionScreenState();
}

class _ExamPredictionScreenState extends State<ExamPredictionScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  int _selectedTab = 0;

  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  bool _mlOffline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted) setState(() => _selectedTab = _tabCtrl.index);
    });
    _loadDashboard();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() { _loading = true; _error = null; _mlOffline = false; });
    try {
      final res = await MLService.getDashboard();
      if (mounted) {
        setState(() { _dashboard = res; _loading = false; });
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.message.contains('offline') || e.statusCode == 503) {
          setState(() { _mlOffline = true; _loading = false; });
        } else {
          setState(() { _error = e.message; _loading = false; });
        }
      }
    } catch (_) {
      if (mounted) setState(() {
        _mlOffline = true; _loading = false;
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
          _buildHeader(),
          _buildTabBar(),
          Expanded(child: _loading
            ? _buildLoading()
            : _mlOffline
            ? _buildMLOffline()
            : _error != null
            ? _buildError()
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _DashboardTab(dashboard: _dashboard!),
                  _WeakTopicsTab(
                    weakTopics: (_dashboard!['weakTopics']
                      as List<dynamic>? ?? [])
                      .map((e) => e as Map<String, dynamic>).toList()),
                  _PerformanceTab(
                    performance: _dashboard!['performance']
                      as Map<String, dynamic>?),
                  _StudyPlanTab(
                    recommendations: (_dashboard!['recommendations']
                      as List<dynamic>? ?? [])
                      .map((e) => e as Map<String, dynamic>).toList()),
                ])),
        ])),
      ]));
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFF48C6EF), Color(0xFF6F86D6)])
              .createShader(b),
          child: const Text('AI Analytics',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
              color: Colors.white, fontFamily: 'Georgia'))),
        const Text('Exam prediction & performance',
          style: AppTextStyles.sub),
      ]),
      const Spacer(),
      GestureDetector(
        onTap: _loadDashboard,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF48C6EF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF48C6EF).withOpacity(0.3))),
          child: const Icon(Icons.refresh_rounded,
            color: Color(0xFF48C6EF), size: 20))),
    ]));

  Widget _buildTabBar() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder)),
      child: Row(children: [
        _tabItem(0, '📊', 'Overview'),
        _tabItem(1, '⚠️', 'Weak'),
        _tabItem(2, '📈', 'Progress'),
        _tabItem(3, '📚', 'Plan'),
      ])));

  Widget _tabItem(int index, String emoji, String label) {
    final active = _selectedTab == index;
    return Expanded(child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _tabCtrl.animateTo(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? const LinearGradient(
            colors: [Color(0xFF48C6EF), Color(0xFF6F86D6)]) : null,
          borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            color: active ? Colors.white : AppColors.textMuted,
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ]))));
  }

  Widget _buildLoading() => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircularProgressIndicator(color: Color(0xFF48C6EF)),
      SizedBox(height: 16),
      Text('Loading AI analytics...', style: AppTextStyles.sub),
    ]));

  Widget _buildMLOffline() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 90, height: 90,
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.gold.withOpacity(0.3))),
        child: const Center(child: Text('🤖',
          style: TextStyle(fontSize: 44)))),
      const SizedBox(height: 24),
      const Text('ML Service Offline',
        style: TextStyle(color: AppColors.textWhite,
          fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('The AI analytics service is not running.\nStart it to see your exam predictions.',
        style: AppTextStyles.sub, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      GlassCard(child: Column(children: [
        const Text('To start the ML service:',
          style: TextStyle(color: AppColors.textWhite,
            fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(10)),
          child: const Text(
            'cd backened/MLModels\npython app.py',
            style: TextStyle(color: AppColors.cyan,
              fontSize: 13, fontFamily: 'monospace'))),
      ])),
      const SizedBox(height: 20),
      GlowButton(text: 'Retry', icon: Icons.refresh_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF48C6EF), Color(0xFF6F86D6)]),
        onPressed: _loadDashboard),
    ])));

  Widget _buildError() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      buildErrorBanner(_error!),
      const SizedBox(height: 16),
      GlowButton(text: 'Retry', icon: Icons.refresh_rounded,
        onPressed: _loadDashboard),
    ])));
}

// ══════════════════════════════════════════
// DASHBOARD TAB
// ══════════════════════════════════════════

class _DashboardTab extends StatefulWidget {
  final Map<String, dynamic> dashboard;
  const _DashboardTab({required this.dashboard});
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  final _subjectCtrl = TextEditingController();
  Map<String, dynamic>? _prediction;
  bool _predicting = false;
  String? _predError;

  @override
  void dispose() { _subjectCtrl.dispose(); super.dispose(); }

  Future<void> _predict() async {
    if (_subjectCtrl.text.trim().isEmpty) return;
    setState(() { _predicting = true; _predError = null; });
    try {
      final res = await MLService.predictScore(
        targetSubject: _subjectCtrl.text.trim());
      if (mounted) setState(() {
        _prediction = res['prediction'] as Map<String, dynamic>?;
        _predicting = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _predError = e.message; _predicting = false; });
    } catch (_) {
      if (mounted) setState(() {
        _predError = 'Prediction failed'; _predicting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = widget.dashboard['hasData'] as bool? ?? false;
    final totalTests = (widget.dashboard['totalTests'] as num?)?.toInt() ?? 0;
    final overall = (widget.dashboard['performance']?['overall'])
      as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        if (!hasData) ...[
          _buildNoDataBanner(),
          const SizedBox(height: 24),
        ],

        if (hasData && overall != null) ...[
          // Overall stats
          _sectionTitle('📊', 'Overall Performance'),
          const SizedBox(height: 12),
          Row(children: [
            _miniStat('Tests', '$totalTests',
              const Color(0xFF48C6EF)),
            const SizedBox(width: 10),
            _miniStat('Avg Score',
              '${(overall['averageScore'] as num?)?.toStringAsFixed(1) ?? '0'}%',
              _scoreColor((overall['averageScore'] as num?)?.toDouble() ?? 0)),
            const SizedBox(width: 10),
            _miniStat('Grade',
              overall['overallGrade'] as String? ?? 'N/A',
              AppColors.gold),
            const SizedBox(width: 10),
            _miniStat('Pass Rate',
              '${(overall['passRate'] as num?)?.toStringAsFixed(0) ?? '0'}%',
              AppColors.success),
          ]),
          const SizedBox(height: 20),
        ],

        // Exam prediction
        _sectionTitle('🎯', 'Predict My Score'),
        const SizedBox(height: 12),
        GlassCard(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Enter a subject to predict your exam score:',
            style: AppTextStyles.sub),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Container(
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.inputBorder)),
              child: TextField(
                controller: _subjectCtrl,
                style: const TextStyle(
                  color: AppColors.textWhite, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'e.g. Physics, Math',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  prefixIcon: Icon(Icons.school_outlined,
                    color: AppColors.textMuted, size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14)),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _predict()))),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _predicting ? null : _predict,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF48C6EF), Color(0xFF6F86D6)]),
                  borderRadius: BorderRadius.circular(14)),
                child: _predicting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 20))),
          ]),

          if (_predError != null) ...[
            const SizedBox(height: 12),
            buildErrorBanner(_predError!)],

          if (_prediction != null) ...[
            const SizedBox(height: 16),
            _buildPredictionResult(_prediction!)],
        ])),

        if (hasData) ...[
          const SizedBox(height: 24),
          _sectionTitle('⚡', 'Quick Stats'),
          const SizedBox(height: 12),
          _buildTrendCard(overall),
        ],
      ]));
  }

  Widget _buildNoDataBanner() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        const Color(0xFF48C6EF).withOpacity(0.1),
        const Color(0xFF6F86D6).withOpacity(0.05)]),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: const Color(0xFF48C6EF).withOpacity(0.3))),
    child: Row(children: [
      const Text('💡', style: TextStyle(fontSize: 28)),
      const SizedBox(width: 14),
      const Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Complete MCQ tests first!',
          style: TextStyle(color: AppColors.textWhite,
            fontSize: 14, fontWeight: FontWeight.w700)),
        SizedBox(height: 4),
        Text('Take quizzes to unlock AI predictions\nand performance analytics.',
          style: AppTextStyles.sub),
      ])),
    ]));

  Widget _buildPredictionResult(Map<String, dynamic> pred) {
    final score = (pred['predictedScore'] as num?)?.toDouble() ?? 0;
    final grade = pred['grade'] as String? ?? 'N/A';
    final confidence = pred['confidence'] as String? ?? 'low';
    final message = pred['message'] as String? ?? '';
    final trend = pred['trend'] as String? ?? '';
    final color = _scoreColor(score);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withOpacity(0.1), color.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Score circle
          Container(width: 70, height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Text('${score.toStringAsFixed(0)}%',
                style: TextStyle(color: color, fontSize: 18,
                  fontWeight: FontWeight.w800)),
              Text(grade, style: TextStyle(color: color,
                fontSize: 12, fontWeight: FontWeight.w700)),
            ])),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Predicted Score', style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [
              _confidenceBadge(confidence),
              const SizedBox(width: 8),
              if (trend.isNotEmpty) _trendBadge(trend),
            ]),
          ])),
        ]),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(message, style: AppTextStyles.body.copyWith(
            fontSize: 12, height: 1.5)),
        ],
      ]));
  }

  Widget _buildTrendCard(Map<String, dynamic>? overall) {
    if (overall == null) return const SizedBox.shrink();
    final trend = overall['overallTrend'] as String? ?? 'stable';
    final high = (overall['highestScore'] as num?)?.toDouble() ?? 0;
    final low = (overall['lowestScore'] as num?)?.toDouble() ?? 0;
    final passRate = (overall['passRate'] as num?)?.toDouble() ?? 0;

    return GlassCard(child: Column(children: [
      Row(children: [
        const Text('Overall Trend', style: TextStyle(
          color: AppColors.textWhite, fontSize: 14,
          fontWeight: FontWeight.w600)),
        const Spacer(),
        _trendBadge(trend),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        _trendStat('🏆 Best', '${high.toStringAsFixed(0)}%',
          AppColors.success),
        const SizedBox(width: 16),
        _trendStat('📉 Lowest', '${low.toStringAsFixed(0)}%',
          AppColors.error),
        const SizedBox(width: 16),
        _trendStat('✅ Pass Rate', '${passRate.toStringAsFixed(0)}%',
          AppColors.cyan),
      ]),
    ]));
  }

  Widget _trendStat(String label, String value, Color color) =>
    Expanded(child: Column(children: [
      Text(label, style: AppTextStyles.label.copyWith(fontSize: 10)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color,
        fontSize: 16, fontWeight: FontWeight.w800)),
    ]));

  Widget _miniStat(String label, String value, Color color) =>
    Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [
        Text(value, style: TextStyle(color: color,
          fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label, style: AppTextStyles.label.copyWith(fontSize: 9)),
      ])));
}

// ══════════════════════════════════════════
// WEAK TOPICS TAB
// ══════════════════════════════════════════

class _WeakTopicsTab extends StatelessWidget {
  final List<Map<String, dynamic>> weakTopics;
  const _WeakTopicsTab({required this.weakTopics});

  @override
  Widget build(BuildContext context) {
    if (weakTopics.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
          const Text('🌟', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text('No Weak Topics!',
            style: TextStyle(color: AppColors.textWhite,
              fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Great job! You\'re performing well\nacross all your subjects.',
            style: AppTextStyles.sub, textAlign: TextAlign.center),
        ])));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.error.withOpacity(0.2))),
          child: Row(children: [
            const Text('⚠️', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(child: Text(
              '${weakTopics.length} topic${weakTopics.length == 1 ? '' : 's'} need your attention',
              style: const TextStyle(color: AppColors.textWhite,
                fontSize: 14, fontWeight: FontWeight.w600))),
          ])),
        const SizedBox(height: 16),

        ...weakTopics.map((topic) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _weakTopicCard(topic))),
      ]);
  }

  Widget _weakTopicCard(Map<String, dynamic> topic) {
    final subject = topic['subject'] as String? ?? '';
    final chapter = topic['chapter'] as String? ?? '';
    final avg = (topic['averageScore'] as num?)?.toDouble() ?? 0;
    final severity = topic['severity'] as String? ?? 'weak';
    final trend = topic['trend'] as String? ?? 'stable';
    final suggestion = topic['suggestion'] as String? ?? '';
    final attempts = (topic['attempts'] as num?)?.toInt() ?? 0;

    final severityColor = severity == 'critical'
      ? AppColors.error : severity == 'weak'
      ? AppColors.gold : const Color(0xFF48C6EF);
    final severityEmoji = severity == 'critical' ? '🔴'
      : severity == 'weak' ? '🟡' : '🔵';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: severityColor.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(children: [
          Text(severityEmoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(subject, style: const TextStyle(
              color: AppColors.textWhite, fontSize: 14,
              fontWeight: FontWeight.w700)),
            Text(chapter, style: AppTextStyles.body.copyWith(
              fontSize: 12, color: AppColors.textMuted),
              overflow: TextOverflow.ellipsis),
          ])),
          // Score circle
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: severityColor, width: 2.5)),
            child: Center(child: Text('${avg.toStringAsFixed(0)}%',
              style: TextStyle(color: severityColor, fontSize: 13,
                fontWeight: FontWeight.w800)))),
        ]),
        const SizedBox(height: 12),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: avg / 100, minHeight: 6,
            backgroundColor: AppColors.inputBorder,
            valueColor: AlwaysStoppedAnimation(severityColor))),
        const SizedBox(height: 10),
        Row(children: [
          _trendBadge(trend),
          const SizedBox(width: 8),
          Text('$attempts attempt${attempts == 1 ? '' : 's'}',
            style: AppTextStyles.label.copyWith(fontSize: 10)),
        ]),
        if (suggestion.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: severityColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Text('💡', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Expanded(child: Text(suggestion,
                style: AppTextStyles.body.copyWith(fontSize: 12))),
            ])),
        ],
      ]));
  }
}

// ══════════════════════════════════════════
// PERFORMANCE TAB
// ══════════════════════════════════════════

class _PerformanceTab extends StatelessWidget {
  final Map<String, dynamic>? performance;
  const _PerformanceTab({this.performance});

  @override
  Widget build(BuildContext context) {
    if (performance == null) {
      return const Center(child: Text('No performance data yet.',
        style: AppTextStyles.sub));
    }

    final subjects = (performance!['subjects'] as List<dynamic>? ?? [])
      .map((e) => e as Map<String, dynamic>).toList();
    final history = (performance!['scoreHistory'] as List<dynamic>? ?? [])
      .map((e) => e as Map<String, dynamic>).toList();
    final diffBreakdown = performance!['difficultyBreakdown']
      as Map<String, dynamic>? ?? {};
    final best = performance!['bestSubject'] as Map<String, dynamic>?;
    final worst = performance!['worstSubject'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [

        // Best/worst
        if (best != null || worst != null) ...[
          Row(children: [
            if (best != null) Expanded(child: _subjectHighlight(
              '🏆 Best', best, AppColors.success)),
            if (best != null && worst != null) const SizedBox(width: 12),
            if (worst != null) Expanded(child: _subjectHighlight(
              '📉 Needs Work', worst, AppColors.error)),
          ]),
          const SizedBox(height: 20),
        ],

        // Score history chart
        if (history.isNotEmpty) ...[
          _sectionTitle('📈', 'Score History'),
          const SizedBox(height: 12),
          GlassCard(child: Column(children: [
            const Text('Last 10 Tests',
              style: TextStyle(color: AppColors.textMuted,
                fontSize: 12)),
            const SizedBox(height: 16),
            _buildBarChart(history),
          ])),
          const SizedBox(height: 20),
        ],

        // Per-subject breakdown
        if (subjects.isNotEmpty) ...[
          _sectionTitle('📚', 'By Subject'),
          const SizedBox(height: 12),
          ...subjects.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _subjectRow(s))),
          const SizedBox(height: 20),
        ],

        // Difficulty breakdown
        if (diffBreakdown.isNotEmpty) ...[
          _sectionTitle('🎯', 'By Difficulty'),
          const SizedBox(height: 12),
          GlassCard(child: Column(
            children: diffBreakdown.entries.map((e) {
              final score = (e.value as num).toDouble();
              final color = e.key == 'easy' ? AppColors.success
                : e.key == 'medium' ? AppColors.gold : AppColors.error;
              final emoji = e.key == 'easy' ? '😊'
                : e.key == 'medium' ? '🎯' : '🔥';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Text('$emoji ${_capitalise(e.key)}',
                    style: const TextStyle(color: AppColors.textLight,
                      fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score / 100, minHeight: 8,
                      backgroundColor: AppColors.inputBorder,
                      valueColor: AlwaysStoppedAnimation(color)))),
                  const SizedBox(width: 12),
                  Text('${score.toStringAsFixed(0)}%',
                    style: TextStyle(color: color,
                      fontSize: 13, fontWeight: FontWeight.w700)),
                ]));
            }).toList())),
        ],
      ]));
  }

  Widget _subjectHighlight(String label, Map<String, dynamic> subj,
      Color color) {
    final name = subj['subject'] as String? ?? '';
    final avg = (subj['averageScore'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(label, style: TextStyle(color: color,
          fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(color: AppColors.textWhite,
          fontSize: 14, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text('${avg.toStringAsFixed(1)}%', style: TextStyle(
          color: color, fontSize: 20, fontWeight: FontWeight.w800)),
      ]));
  }

  Widget _buildBarChart(List<Map<String, dynamic>> history) {
    final maxScore = history.fold<double>(0, (max, e) {
      final s = (e['score'] as num?)?.toDouble() ?? 0;
      return s > max ? s : max;
    });

    return SizedBox(height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: history.map((h) {
          final score = (h['score'] as num?)?.toDouble() ?? 0;
          final height = maxScore > 0 ? (score / maxScore) * 90 : 10.0;
          final color = _scoreColor(score);
          final idx = (h['index'] as num?)?.toInt() ?? 0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('${score.toStringAsFixed(0)}',
              style: TextStyle(color: color, fontSize: 8,
                fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Container(
              width: 22, height: height.clamp(6.0, 90.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.5)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 4),
            Text('T$idx', style: AppTextStyles.label.copyWith(
              fontSize: 8)),
          ]);
        }).toList()));
  }

  Widget _subjectRow(Map<String, dynamic> s) {
    final name = s['subject'] as String? ?? '';
    final avg = (s['averageScore'] as num?)?.toDouble() ?? 0;
    final tests = (s['totalTests'] as num?)?.toInt() ?? 0;
    final status = s['status'] as String? ?? 'average';
    final trend = s['trend'] as String? ?? 'stable';
    final color = status == 'strong' ? AppColors.success
      : status == 'average' ? AppColors.gold : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(color: AppColors.textWhite,
            fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: avg / 100, minHeight: 5,
              backgroundColor: AppColors.inputBorder,
              valueColor: AlwaysStoppedAnimation(color))),
          const SizedBox(height: 6),
          Row(children: [
            Text('$tests test${tests == 1 ? '' : 's'}',
              style: AppTextStyles.label.copyWith(fontSize: 10)),
            const SizedBox(width: 8),
            _trendBadge(trend),
          ]),
        ])),
        const SizedBox(width: 14),
        Text('${avg.toStringAsFixed(0)}%',
          style: TextStyle(color: color, fontSize: 18,
            fontWeight: FontWeight.w800)),
      ]));
  }
}

// ══════════════════════════════════════════
// STUDY PLAN TAB
// ══════════════════════════════════════════

class _StudyPlanTab extends StatelessWidget {
  final List<Map<String, dynamic>> recommendations;
  const _StudyPlanTab({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return const Center(child: Text('No recommendations yet.',
        style: AppTextStyles.sub));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              Color(0xFF48C6EF), Color(0xFF6F86D6)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            const Text('🤖', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your AI Study Plan',
                style: TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w800)),
              Text('${recommendations.length} personalized recommendations',
                style: TextStyle(color: Colors.white.withOpacity(0.8),
                  fontSize: 12)),
            ])),
          ])),
        const SizedBox(height: 16),

        ...recommendations.asMap().entries.map((entry) {
          final i = entry.key;
          final rec = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _recCard(rec, i + 1));
        }),
      ]);
  }

  Widget _recCard(Map<String, dynamic> rec, int priority) {
    final type = rec['type'] as String? ?? '';
    final subject = rec['subject'] as String? ?? '';
    final chapter = rec['chapter'] as String? ?? '';
    final reason = rec['reason'] as String? ?? '';
    final action = rec['action'] as String? ?? '';
    final hours = (rec['estimatedStudyHours'] as num?)?.toInt() ?? 1;

    final typeConfig = _typeConfig(type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (typeConfig['color'] as Color).withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(children: [
          // Priority badge
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGrad,
              borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('$priority',
              style: const TextStyle(color: Colors.white,
                fontSize: 12, fontWeight: FontWeight.w800)))),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(subject, style: const TextStyle(
              color: AppColors.textWhite, fontSize: 14,
              fontWeight: FontWeight.w700)),
            if (chapter.isNotEmpty && chapter != 'General')
              Text(chapter, style: AppTextStyles.body.copyWith(
                fontSize: 12), overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (typeConfig['color'] as Color).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20)),
            child: Text(typeConfig['label'] as String,
              style: TextStyle(
                color: typeConfig['color'] as Color, fontSize: 10,
                fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        // Reason
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('📍 ', style: TextStyle(fontSize: 12)),
          Expanded(child: Text(reason, style: AppTextStyles.body
            .copyWith(fontSize: 12))),
        ]),
        const SizedBox(height: 8),
        // Action
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF48C6EF).withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF48C6EF).withOpacity(0.15))),
          child: Row(children: [
            const Text('✅ ', style: TextStyle(fontSize: 12)),
            Expanded(child: Text(action, style: AppTextStyles.body
              .copyWith(fontSize: 12))),
          ])),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.access_time_rounded,
            color: AppColors.textMuted, size: 14),
          const SizedBox(width: 4),
          Text('~$hours hour${hours == 1 ? '' : 's'} estimated',
            style: AppTextStyles.label.copyWith(fontSize: 11)),
        ]),
      ]));
  }

  Map<String, dynamic> _typeConfig(String type) {
    switch (type) {
      case 'urgent_revision':
        return {'label': '🔴 Urgent', 'color': AppColors.error};
      case 'focused_practice':
        return {'label': '🎯 Practice', 'color': AppColors.gold};
      case 'prevent_decline':
        return {'label': '📉 Declining', 'color': const Color(0xFFFF8E53)};
      case 'improvement':
        return {'label': '📈 Improve', 'color': const Color(0xFF48C6EF)};
      case 'maintenance':
        return {'label': '✨ Maintain', 'color': AppColors.success};
      default:
        return {'label': '📚 Study', 'color': AppColors.violet};
    }
  }
}

// ══════════════════════════════════════════
// SHARED HELPERS
// ══════════════════════════════════════════

Color _scoreColor(double score) {
  if (score >= 80) return AppColors.success;
  if (score >= 60) return AppColors.gold;
  return AppColors.error;
}

Widget _sectionTitle(String emoji, String title) => Row(children: [
  Text(emoji, style: const TextStyle(fontSize: 18)),
  const SizedBox(width: 8),
  ShaderMask(
    shaderCallback: (b) => const LinearGradient(
      colors: [Color(0xFF48C6EF), Color(0xFF6F86D6)]).createShader(b),
    child: Text(title, style: const TextStyle(
      fontSize: 18, fontWeight: FontWeight.w700,
      color: Colors.white, fontFamily: 'Georgia'))),
]);

Widget _trendBadge(String trend) {
  final config = {
    'improving': {'emoji': '📈', 'color': AppColors.success},
    'declining': {'emoji': '📉', 'color': AppColors.error},
    'stable': {'emoji': '➡️', 'color': AppColors.textMuted},
    'insufficient_data': {'emoji': '❓', 'color': AppColors.textMuted},
  };
  final c = config[trend] ?? {'emoji': '➡️', 'color': AppColors.textMuted};
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: (c['color'] as Color).withOpacity(0.1),
      borderRadius: BorderRadius.circular(8)),
    child: Text('${c['emoji']} $trend',
      style: TextStyle(color: c['color'] as Color,
        fontSize: 10, fontWeight: FontWeight.w600)));
}

Widget _confidenceBadge(String confidence) {
  final colors = {
    'high': AppColors.success,
    'medium': AppColors.gold,
    'low': AppColors.error,
  };
  final color = colors[confidence] ?? AppColors.textMuted;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8)),
    child: Text('$confidence confidence',
      style: TextStyle(color: color,
        fontSize: 10, fontWeight: FontWeight.w600)));
}

String _capitalise(String s) =>
  s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);