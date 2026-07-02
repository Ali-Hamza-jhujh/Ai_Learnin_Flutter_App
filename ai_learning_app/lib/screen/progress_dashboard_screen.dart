import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/lumio_theme.dart';
import '../services/api_service.dart';

class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  Map<String, dynamic>? _dashboard;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await MLService.getDashboard();
      if (mounted) setState(() {
        _dashboard = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Progress Dashboard', style: AppTypography.titleLarge),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.violet))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _metricCard('Predicted Readiness', '${_readiness()}%'),
                const SizedBox(height: 16),
                Container(
                  height: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: LumioDecorations.lumioCard(),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: const [
                            FlSpot(0, 2),
                            FlSpot(1, 3),
                            FlSpot(2, 2.8),
                            FlSpot(3, 4),
                            FlSpot(4, 3.6),
                          ],
                          isCurved: true,
                          color: AppColors.cyan,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _metricCard('Average Score',
                    '${_dashboard?['averageScore'] ?? _dashboard?['stats']?['averageScore'] ?? 0}%'),
                _metricCard('Weak Topics',
                    '${(_dashboard?['weakTopics'] as List?)?.length ?? 0} to review'),
              ],
            ),
    );
  }

  int _readiness() {
    final avg = (_dashboard?['averageScore'] as num?)?.toDouble() ?? 55;
    return avg.clamp(0, 100).round();
  }

  Widget _metricCard(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: LumioDecorations.lumioCard(glowing: true),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyLarge),
          Text(value, style: AppTypography.titleLarge.copyWith(color: AppColors.cyan)),
        ],
      ),
    );
  }
}
