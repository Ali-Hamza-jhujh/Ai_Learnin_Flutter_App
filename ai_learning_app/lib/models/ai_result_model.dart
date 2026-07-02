import '../../core/errors/app_exceptions.dart';

class AIResult {
  final Map<String, dynamic> data;
  final String provider;
  final List<dynamic> skipped;
  final bool cached;
  final bool showDisclaimer;

  AIResult({
    required this.data,
    required this.provider,
    this.skipped = const [],
    this.cached = false,
    this.showDisclaimer = false,
  });

  factory AIResult.fromJson(Map<String, dynamic> json) {
    return AIResult(
      data: (json['data'] as Map<String, dynamic>?) ?? json,
      provider: json['provider']?.toString() ?? 'unknown',
      skipped: (json['skipped'] as List?) ?? const [],
      cached: json['cached'] == true,
      showDisclaimer: json['showDisclaimer'] == true,
    );
  }
}
