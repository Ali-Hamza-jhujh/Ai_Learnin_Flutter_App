import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class ActivityHeatmap extends StatelessWidget {
  final Map<String, dynamic> data;

  const ActivityHeatmap({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Generate last 90 days for the heatmap
    final now = DateTime.now();
    final days = List.generate(90, (i) => now.subtract(Duration(days: 89 - i)));
    
    // Group into columns of 7 (weeks)
    final columns = <List<DateTime>>[];
    for (int i = 0; i < days.length; i += 7) {
      columns.add(days.sublist(i, i + 7 > days.length ? days.length : i + 7));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true, // scroll to the most recent end
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columns.map((col) {
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              children: col.map((date) {
                final dateStr = date.toIso8601String().split('T')[0];
                final count = data[dateStr] ?? 0;
                return Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: _getColor(count),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.inputBorder, width: 0.5),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getColor(dynamic count) {
    final c = (count as num).toInt();
    if (c == 0) return AppColors.inputBg;
    if (c < 2) return AppColors.cyan.withValues(alpha: 0.3);
    if (c < 5) return AppColors.cyan.withValues(alpha: 0.6);
    return AppColors.cyan;
  }
}
