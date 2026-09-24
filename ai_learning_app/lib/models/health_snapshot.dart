class HealthMetric {
  final String id;
  final String title;
  final String valueLabel;
  final String unit;
  final double? numeric;
  final String subtitle;
  final bool alert;
  final String? alertMessage;
  final bool editable;

  const HealthMetric({
    required this.id,
    required this.title,
    required this.valueLabel,
    required this.unit,
    this.numeric,
    this.subtitle = '',
    this.alert = false,
    this.alertMessage,
    this.editable = false,
  });
}

class HealthSnapshot {
  final DateTime fetchedAt;
  final int? steps;
  final double? heartRateBpm;
  final double? restingHeartRateBpm;
  final double? spo2Percent;
  final double? systolic;
  final double? diastolic;
  final double? glucose;
  final double? bodyTempC;
  final double? weightKg;
  final double? heightCm;
  final double? bodyFatPercent;
  final double? bmi;
  final double? distanceMeters;
  final double? activeCalories;
  final double? totalCalories;
  final double? waterMl;
  final double? sleepHours;
  final int? flightsClimbed;
  final double? respiratoryRate;
  final double? hrvMs;
  final int workoutCount;
  final List<HealthMetric> metrics;
  final List<String> alerts;

  const HealthSnapshot({
    required this.fetchedAt,
    this.steps,
    this.heartRateBpm,
    this.restingHeartRateBpm,
    this.spo2Percent,
    this.systolic,
    this.diastolic,
    this.glucose,
    this.bodyTempC,
    this.weightKg,
    this.heightCm,
    this.bodyFatPercent,
    this.bmi,
    this.distanceMeters,
    this.activeCalories,
    this.totalCalories,
    this.waterMl,
    this.sleepHours,
    this.flightsClimbed,
    this.respiratoryRate,
    this.hrvMs,
    this.workoutCount = 0,
    this.metrics = const [],
    this.alerts = const [],
  });

  String get summaryLine {
    final parts = <String>[];
    if (steps != null) parts.add('${_fmt(steps!)} steps');
    if (heartRateBpm != null) parts.add('${heartRateBpm!.round()} bpm');
    if (sleepHours != null) parts.add('${sleepHours!.toStringAsFixed(1)}h sleep');
    if (activeCalories != null) parts.add('${activeCalories!.round()} kcal');
    if (parts.isEmpty) return 'No health samples in the last 24 hours yet.';
    return parts.join(' · ');
  }

  static String _fmt(num n) {
    if (n >= 1000) {
      return n.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
    }
    return n.toStringAsFixed(0);
  }
}

class HealthLimits {
  final int stepsGoal;
  final double heartRateHigh;
  final double heartRateLow;
  final double spo2Low;
  final double systolicHigh;
  final double diastolicHigh;
  final double glucoseHigh;
  final double glucoseLow;
  final double tempHighC;
  final double waterGoalMl;
  final double activeCaloriesGoal;
  final bool morning;
  final bool afternoon;
  final bool evening;
  final bool limitAlerts;

  const HealthLimits({
    this.stepsGoal = 10000,
    this.heartRateHigh = 120,
    this.heartRateLow = 50,
    this.spo2Low = 94,
    this.systolicHigh = 140,
    this.diastolicHigh = 90,
    this.glucoseHigh = 180,
    this.glucoseLow = 70,
    this.tempHighC = 38.0,
    this.waterGoalMl = 2000,
    this.activeCaloriesGoal = 400,
    this.morning = true,
    this.afternoon = true,
    this.evening = true,
    this.limitAlerts = true,
  });

  HealthLimits copyWith({
    int? stepsGoal,
    double? heartRateHigh,
    double? heartRateLow,
    double? spo2Low,
    double? systolicHigh,
    double? diastolicHigh,
    double? glucoseHigh,
    double? glucoseLow,
    double? tempHighC,
    double? waterGoalMl,
    double? activeCaloriesGoal,
    bool? morning,
    bool? afternoon,
    bool? evening,
    bool? limitAlerts,
  }) {
    return HealthLimits(
      stepsGoal: stepsGoal ?? this.stepsGoal,
      heartRateHigh: heartRateHigh ?? this.heartRateHigh,
      heartRateLow: heartRateLow ?? this.heartRateLow,
      spo2Low: spo2Low ?? this.spo2Low,
      systolicHigh: systolicHigh ?? this.systolicHigh,
      diastolicHigh: diastolicHigh ?? this.diastolicHigh,
      glucoseHigh: glucoseHigh ?? this.glucoseHigh,
      glucoseLow: glucoseLow ?? this.glucoseLow,
      tempHighC: tempHighC ?? this.tempHighC,
      waterGoalMl: waterGoalMl ?? this.waterGoalMl,
      activeCaloriesGoal: activeCaloriesGoal ?? this.activeCaloriesGoal,
      morning: morning ?? this.morning,
      afternoon: afternoon ?? this.afternoon,
      evening: evening ?? this.evening,
      limitAlerts: limitAlerts ?? this.limitAlerts,
    );
  }

  Map<String, dynamic> toJson() => {
        'stepsGoal': stepsGoal,
        'heartRateHigh': heartRateHigh,
        'heartRateLow': heartRateLow,
        'spo2Low': spo2Low,
        'systolicHigh': systolicHigh,
        'diastolicHigh': diastolicHigh,
        'glucoseHigh': glucoseHigh,
        'glucoseLow': glucoseLow,
        'tempHighC': tempHighC,
        'waterGoalMl': waterGoalMl,
        'activeCaloriesGoal': activeCaloriesGoal,
        'morning': morning,
        'afternoon': afternoon,
        'evening': evening,
        'limitAlerts': limitAlerts,
      };

  factory HealthLimits.fromJson(Map<String, dynamic> json) {
    return HealthLimits(
      stepsGoal: (json['stepsGoal'] as num?)?.toInt() ?? 10000,
      heartRateHigh: (json['heartRateHigh'] as num?)?.toDouble() ?? 120,
      heartRateLow: (json['heartRateLow'] as num?)?.toDouble() ?? 50,
      spo2Low: (json['spo2Low'] as num?)?.toDouble() ?? 94,
      systolicHigh: (json['systolicHigh'] as num?)?.toDouble() ?? 140,
      diastolicHigh: (json['diastolicHigh'] as num?)?.toDouble() ?? 90,
      glucoseHigh: (json['glucoseHigh'] as num?)?.toDouble() ?? 180,
      glucoseLow: (json['glucoseLow'] as num?)?.toDouble() ?? 70,
      tempHighC: (json['tempHighC'] as num?)?.toDouble() ?? 38.0,
      waterGoalMl: (json['waterGoalMl'] as num?)?.toDouble() ?? 2000,
      activeCaloriesGoal: (json['activeCaloriesGoal'] as num?)?.toDouble() ?? 400,
      morning: json['morning'] as bool? ?? true,
      afternoon: json['afternoon'] as bool? ?? true,
      evening: json['evening'] as bool? ?? true,
      limitAlerts: json['limitAlerts'] as bool? ?? true,
    );
  }
}
