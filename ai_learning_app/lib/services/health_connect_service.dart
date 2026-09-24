import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../models/health_snapshot.dart';
import 'notification_service.dart';

const _kLimitsKey = 'health_limits_v1';
const _kLastAlertsKey = 'health_last_alert_fingerprints';
const _kAuthorizedKey = 'health_authorized';
const healthBackgroundTask = 'health_limit_check';

@pragma('vm:entry-point')
void healthBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await NotificationService.initialize();
      await HealthConnectService.instance.syncAndNotify(fromBackground: true);
    } catch (_) {}
    return true;
  });
}

class HealthConnectService {
  HealthConnectService._();
  static final HealthConnectService instance = HealthConnectService._();

  final Health _health = Health();
  bool _configured = false;
  HealthLimits limits = const HealthLimits();
  HealthSnapshot? lastSnapshot;
  HealthConnectSdkStatus? sdkStatus;

  /// Focused set — Health Connect recommends asking only for types the app uses.
  static const List<HealthDataType> _preferredTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.WATER,
    HealthDataType.WEIGHT,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.BODY_TEMPERATURE,
  ];

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  StreamSubscription<StepCount>? _stepSub;
  int _phoneStepsToday = 0;

  List<HealthDataType> get types {
    if (!isSupported) return const [];
    return _preferredTypes.where(_health.isDataTypeAvailable).toList();
  }

  List<HealthDataAccess> get _accessForTypes {
    const writable = {
      HealthDataType.STEPS,
      HealthDataType.WATER,
      HealthDataType.WEIGHT,
    };
    return types
        .map((t) => writable.contains(t)
            ? HealthDataAccess.READ_WRITE
            : HealthDataAccess.READ)
        .toList();
  }

  Future<void> bootstrap() async {
    await _loadLimits();
    await NotificationService.initialize();
    if (!isSupported) return;
    await _configure();
    await _restorePhoneSteps();
    await _listenPhoneSteps();
    await NotificationService.scheduleDailyHealthChecks(limits);
    try {
      await Workmanager().initialize(healthBackgroundDispatcher);
      await Workmanager().registerPeriodicTask(
        healthBackgroundTask,
        healthBackgroundTask,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.notRequired),
      );
    } catch (_) {}
  }

  Future<void> _configure() async {
    if (_configured) return;
    try {
      await _health.configure();
      if (Platform.isAndroid) {
        sdkStatus = await _health.getHealthConnectSdkStatus();
      }
      _configured = true;
    } catch (_) {
      _configured = false;
    }
  }

  Future<bool> isHealthConnectReady() async {
    if (!isSupported) return false;
    await _configure();
    if (Platform.isIOS) return true;
    sdkStatus = await _health.getHealthConnectSdkStatus();
    return sdkStatus == HealthConnectSdkStatus.sdkAvailable;
  }

  Future<void> installHealthConnect() async {
    if (!Platform.isAndroid) return;
    await _health.installHealthConnect();
  }

  Future<bool> hasAuthorization() async {
    if (!isSupported) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAuthorizedKey) == true;
  }

  Future<void> openHealthSettings() async {
    try {
      if (Platform.isAndroid) {
        if (sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
          await installHealthConnect();
        } else {
          await openAppSettings();
        }
      } else {
        await openAppSettings();
      }
    } catch (_) {
      await openAppSettings();
    }
  }

  Future<Map<String, dynamic>> getDiagnostics() async {
    final prefs = await SharedPreferences.getInstance();
    final auth = prefs.getBool(_kAuthorizedKey) ?? false;
    final lastFetch = lastSnapshot?.fetchedAt;

    bool motionGranted = false;
    if (!kIsWeb && Platform.isAndroid) {
      motionGranted = await Permission.activityRecognition.isGranted;
    } else if (!kIsWeb && Platform.isIOS) {
      motionGranted = true;
    }

    return {
      'isSupported': isSupported,
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'sdkAvailable': Platform.isIOS || sdkStatus == HealthConnectSdkStatus.sdkAvailable,
      'authorized': auth,
      'motionSensorGranted': motionGranted,
      'phoneStepsToday': _phoneStepsToday,
      'lastSyncTime': lastFetch,
    };
  }

  /// One-time onboarding. Asking Health Connect again after a grant can reset it.
  Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    await _configure();

    if (await hasAuthorization()) {
      await _listenPhoneSteps();
      return true;
    }

    if (Platform.isAndroid) {
      await Permission.notification.request();
      await Permission.activityRecognition.request();
      sdkStatus = await _health.getHealthConnectSdkStatus();
      if (sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
        await installHealthConnect();
        sdkStatus = await _health.getHealthConnectSdkStatus();
        if (sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
          return false;
        }
      }
    }

    var hcOk = false;
    try {
      hcOk = await _health.requestAuthorization(
        types,
        permissions: _accessForTypes,
      );
    } catch (_) {
      hcOk = false;
    }
    try {
      await _health.requestHealthDataHistoryAuthorization();
      await _health.requestHealthDataInBackgroundAuthorization();
    } catch (_) {}

    await _listenPhoneSteps();

    final motionOk = !Platform.isAndroid ||
        await Permission.activityRecognition.isGranted;
    final granted = hcOk || motionOk;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAuthorizedKey, granted);
    return granted;
  }

  Future<void> _restorePhoneSteps() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (prefs.getString('health_step_day') == today) {
      _phoneStepsToday = prefs.getInt('health_phone_steps_today') ?? 0;
    }
  }

  Future<void> _listenPhoneSteps() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    if (Platform.isAndroid && !await Permission.activityRecognition.isGranted) {
      return;
    }
    if (_stepSub != null) return;
    await _restorePhoneSteps();
    try {
      _stepSub = Pedometer.stepCountStream.listen(
        _onPhoneStepCount,
        onError: (_) {},
      );
    } catch (_) {}
  }

  Future<void> _onPhoneStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDay = prefs.getString('health_step_day');
    var baseline = prefs.getInt('health_step_baseline');
    if (savedDay != today || baseline == null) {
      baseline = event.steps;
      await prefs.setString('health_step_day', today);
      await prefs.setInt('health_step_baseline', baseline);
    }
    _phoneStepsToday = (event.steps - baseline).clamp(0, 250000);
    await prefs.setInt('health_phone_steps_today', _phoneStepsToday);
    await _writeStepsToHealthConnect(_phoneStepsToday);
  }

  DateTime? _lastStepWrite;
  int _lastWrittenSteps = -1;

  Future<void> _writeStepsToHealthConnect(int steps) async {
    if (steps <= 0 || steps == _lastWrittenSteps) return;
    final now = DateTime.now();
    if (_lastStepWrite != null &&
        now.difference(_lastStepWrite!) < const Duration(minutes: 5)) {
      return;
    }
    _lastStepWrite = now;
    _lastWrittenSteps = steps;
    try {
      final start = DateTime(now.year, now.month, now.day);
      await _health.writeHealthData(
        value: steps.toDouble(),
        type: HealthDataType.STEPS,
        startTime: start,
        endTime: now,
        recordingMethod: RecordingMethod.automatic,
      );
    } catch (_) {}
  }

  Future<int> phoneStepsToday() async {
    await _restorePhoneSteps();
    return _phoneStepsToday;
  }

  Future<HealthSnapshot> syncAndNotify({bool fromBackground = false}) async {
    final snapshot = await fetchToday();
    lastSnapshot = snapshot;
    await NotificationService.refreshScheduledBodies(snapshot, limits);
    if (limits.limitAlerts) {
      await _notifyLimitBreaches(snapshot);
    }
    return snapshot;
  }

  Future<HealthSnapshot> fetchToday() async {
    if (!isSupported) {
      return HealthSnapshot(fetchedAt: DateTime.now());
    }
    await _configure();
    await _listenPhoneSteps();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final lookback = now.subtract(const Duration(days: 7));
    final sleepStart = now.subtract(const Duration(hours: 36));

    final points = <HealthDataPoint>[];
    for (final type in types) {
      try {
        points.addAll(await _health.getHealthDataFromTypes(
          types: [type],
          startTime: type.name.startsWith('SLEEP') ? sleepStart : lookback,
          endTime: now,
        ));
      } catch (_) {}
    }

    int? hcSteps;
    try {
      hcSteps = await _health.getTotalStepsInInterval(midnight, now);
    } catch (_) {
      hcSteps = _sum(
        points.where((p) => p.dateTo.isAfter(midnight)).toList(),
        HealthDataType.STEPS,
      )?.round();
    }
    final phoneSteps = await phoneStepsToday();
    final steps = math.max(hcSteps ?? 0, phoneSteps);

    final prefs = await SharedPreferences.getInstance();
    final userWeight = prefs.getDouble('health_user_weight_kg') ?? 70.0;
    final userHeight = prefs.getDouble('health_user_height_cm') ?? 175.0;
    final userAge = prefs.getInt('health_user_age') ?? 22;
    final userGender = prefs.getString('health_user_gender') ?? 'male';
    final isMale = userGender.toLowerCase() == 'male';

    final strideMeters = userHeight * (isMale ? 0.415 : 0.413) / 100.0;
    final distanceFromSteps = steps > 0 ? steps * strideMeters : null;
    final kcalFromSteps = steps > 0 ? steps * 0.042 * (userWeight / 70.0) : null;
    final bmrDaily = (10 * userWeight) + (6.25 * userHeight) - (5 * userAge) + (isMale ? 5 : -161);
    final dayFraction = (now.hour * 60 + now.minute) / 1440.0;
    final bmrSoFar = bmrDaily * dayFraction;

    final todayPoints =
        points.where((p) => !p.dateTo.isBefore(midnight)).toList();

    final heart = _latest(points, HealthDataType.HEART_RATE);
    final restHr = _latest(points, HealthDataType.RESTING_HEART_RATE);
    var spo2 = _latest(points, HealthDataType.BLOOD_OXYGEN);
    if (spo2 != null && spo2 <= 1.0) spo2 *= 100;
    final systolic = _latest(points, HealthDataType.BLOOD_PRESSURE_SYSTOLIC);
    final diastolic = _latest(points, HealthDataType.BLOOD_PRESSURE_DIASTOLIC);
    final glucose = _latest(points, HealthDataType.BLOOD_GLUCOSE);
    final temp = _latest(points, HealthDataType.BODY_TEMPERATURE);
    
    final hcWeight = _latest(points, HealthDataType.WEIGHT);
    if (hcWeight != null && !prefs.containsKey('health_user_weight_kg')) {
      await saveUserProfile(weightKg: hcWeight);
    }
    final weight = hcWeight ?? userWeight;

    final hcHeight = _latest(points, HealthDataType.HEIGHT);
    if (hcHeight != null && !prefs.containsKey('health_user_height_cm')) {
      await saveUserProfile(heightCm: hcHeight < 3 ? hcHeight * 100 : hcHeight);
    }
    final height = hcHeight != null && hcHeight < 3 ? hcHeight * 100 : (hcHeight ?? userHeight);

    final hcBmi = _latest(points, HealthDataType.BODY_MASS_INDEX);
    final bmi = hcBmi ?? (weight / ((height / 100.0) * (height / 100.0)));

    final hcFat = _latest(points, HealthDataType.BODY_FAT_PERCENTAGE);
    var fatPct = hcFat;
    if (fatPct != null && fatPct <= 1.0) fatPct *= 100;
    fatPct ??= (1.20 * bmi) + (0.23 * userAge) - (isMale ? 16.2 : 5.4);

    final hcDistance = _sum(todayPoints, HealthDataType.DISTANCE_DELTA);
    final distance = (hcDistance != null && hcDistance > 0) ? hcDistance : distanceFromSteps;
    
    final hcActiveKcal = _sum(todayPoints, HealthDataType.ACTIVE_ENERGY_BURNED);
    final activeKcal = (hcActiveKcal != null && hcActiveKcal > 0) ? hcActiveKcal : kcalFromSteps;
    
    final hcTotalKcal = _sum(todayPoints, HealthDataType.TOTAL_CALORIES_BURNED);
    final totalKcal = (hcTotalKcal != null && hcTotalKcal > 0) ? hcTotalKcal : (bmrSoFar + (activeKcal ?? 0));
    
    final todayKey = now.toIso8601String().substring(0, 10);
    final localWaterMl = prefs.getDouble('health_water_ml_$todayKey') ?? 0.0;
    final hcWaterL = _sum(todayPoints, HealthDataType.WATER);
    final hcWaterMl = hcWaterL == null ? null : hcWaterL * 1000;
    // Always show water: 0ml is meaningful (nothing logged yet today)
    final waterMl = math.max(hcWaterMl ?? 0, localWaterMl);
    
    final sleepHours = _sleepHours(points);
    final hcFlights = _sum(todayPoints, HealthDataType.FLIGHTS_CLIMBED)?.round();
    final flights = (hcFlights != null && hcFlights > 0) ? hcFlights : (steps > 0 ? (steps / 380).floor() : 0);
    
    final resp = _latest(points, HealthDataType.RESPIRATORY_RATE);
    final hrv = _latest(points, HealthDataType.HEART_RATE_VARIABILITY_RMSSD);
    final workouts =
        todayPoints.where((p) => p.type == HealthDataType.WORKOUT).length;

    final snapshot = HealthSnapshot(
      fetchedAt: now,
      steps: steps,
      heartRateBpm: heart,
      restingHeartRateBpm: restHr,
      spo2Percent: spo2,
      systolic: systolic,
      diastolic: diastolic,
      glucose: glucose,
      bodyTempC: temp,
      weightKg: weight,
      heightCm: height,
      bodyFatPercent: fatPct,
      bmi: bmi,
      distanceMeters: distance,
      activeCalories: activeKcal,
      totalCalories: totalKcal,
      waterMl: waterMl,
      sleepHours: sleepHours,
      flightsClimbed: flights,
      respiratoryRate: resp,
      hrvMs: hrv,
      workoutCount: workouts,
    );
    lastSnapshot = _withMetrics(snapshot);
    return lastSnapshot!;
  }

  HealthSnapshot _withMetrics(HealthSnapshot s) {
    final alerts = _buildAlerts(s);
    final metrics = <HealthMetric>[
      HealthMetric(
        id: 'steps',
        title: 'Steps',
        valueLabel: s.steps == null ? '—' : _comma(s.steps!),
        unit: 'steps',
        numeric: s.steps?.toDouble(),
        subtitle: 'This phone + Health Connect',
        alert: s.steps != null && s.steps! >= limits.stepsGoal,
        alertMessage: s.steps != null && s.steps! >= limits.stepsGoal
            ? 'Daily step goal reached'
            : null,
      ),
      HealthMetric(
        id: 'hr',
        title: 'Heart rate',
        valueLabel: s.heartRateBpm == null ? '—' : s.heartRateBpm!.round().toString(),
        unit: 'bpm',
        numeric: s.heartRateBpm,
        subtitle: s.heartRateBpm == null
            ? 'Needs watch or fitness app'
            : 'Latest sample',
        alert: _hrAlert(s.heartRateBpm),
        editable: true,
      ),
      HealthMetric(
        id: 'rhr',
        title: 'Resting heart rate',
        valueLabel: s.restingHeartRateBpm == null
            ? '—'
            : s.restingHeartRateBpm!.round().toString(),
        unit: 'bpm',
        numeric: s.restingHeartRateBpm,
        subtitle: 'Typical: 60–80 bpm',
      ),
      HealthMetric(
        id: 'spo2',
        title: 'Blood oxygen',
        valueLabel: s.spo2Percent == null ? '—' : s.spo2Percent!.toStringAsFixed(0),
        unit: '%',
        numeric: s.spo2Percent,
        subtitle: 'SpO₂ sensor required',
        alert: s.spo2Percent != null && s.spo2Percent! < limits.spo2Low,
      ),
      HealthMetric(
        id: 'bp',
        title: 'Blood pressure',
        valueLabel: (s.systolic == null || s.diastolic == null)
            ? '—'
            : '${s.systolic!.round()}/${s.diastolic!.round()}',
        unit: 'mmHg',
        subtitle: 'Systolic / diastolic',
        alert: _bpAlert(s),
        editable: true,
      ),
      HealthMetric(
        id: 'glucose',
        title: 'Blood glucose',
        valueLabel: s.glucose == null ? '—' : s.glucose!.toStringAsFixed(0),
        unit: 'mg/dL',
        numeric: s.glucose,
        subtitle: 'Latest sample',
        alert: _glucoseAlert(s.glucose),
        editable: true,
      ),
      HealthMetric(
        id: 'temp',
        title: 'Body temperature',
        valueLabel: s.bodyTempC == null ? '—' : s.bodyTempC!.toStringAsFixed(1),
        unit: '°C',
        numeric: s.bodyTempC,
        subtitle: 'Latest sample',
        alert: s.bodyTempC != null && s.bodyTempC! >= limits.tempHighC,
        editable: true,
      ),
      HealthMetric(
        id: 'sleep',
        title: 'Sleep',
        valueLabel: s.sleepHours == null ? '—' : s.sleepHours!.toStringAsFixed(1),
        unit: 'hours',
        numeric: s.sleepHours,
        subtitle: 'Last night',
        editable: true,
      ),
      HealthMetric(
        id: 'active',
        title: 'Active energy',
        valueLabel: s.activeCalories == null ? '—' : s.activeCalories!.round().toString(),
        unit: 'kcal',
        numeric: s.activeCalories,
        subtitle: s.steps != null && s.steps! > 0 ? 'Calculated from ${_comma(s.steps!)} steps' : 'Calculated from steps',
      ),
      HealthMetric(
        id: 'total_cal',
        title: 'Total calories',
        valueLabel: s.totalCalories == null ? '—' : s.totalCalories!.round().toString(),
        unit: 'kcal',
        numeric: s.totalCalories,
        subtitle: 'Estimated BMR + active burn',
      ),
      HealthMetric(
        id: 'distance',
        title: 'Distance',
        valueLabel: s.distanceMeters == null
            ? '—'
            : (s.distanceMeters! / 1000).toStringAsFixed(2),
        unit: 'km',
        numeric: s.distanceMeters,
        subtitle: 'Calculated from steps & stride',
      ),
      HealthMetric(
        id: 'water',
        title: 'Hydration',
        valueLabel: s.waterMl != null ? s.waterMl!.round().toString() : '0',
        unit: 'ml',
        numeric: s.waterMl,
        subtitle: 'Goal ${limits.waterGoalMl.round()} ml · Tap water section above to log',
        editable: true,
      ),
      HealthMetric(
        id: 'weight',
        title: 'Weight',
        valueLabel: s.weightKg == null ? '—' : s.weightKg!.toStringAsFixed(1),
        unit: 'kg',
        numeric: s.weightKg,
        subtitle: 'Tap to update body profile',
        editable: true,
      ),
      HealthMetric(
        id: 'height',
        title: 'Height',
        valueLabel: s.heightCm == null ? '—' : s.heightCm!.toStringAsFixed(0),
        unit: 'cm',
        numeric: s.heightCm,
        subtitle: 'Tap to update body profile',
        editable: true,
      ),
      HealthMetric(
        id: 'body_fat',
        title: 'Body fat',
        valueLabel: s.bodyFatPercent == null ? '—' : s.bodyFatPercent!.toStringAsFixed(1),
        unit: '%',
        numeric: s.bodyFatPercent,
        subtitle: 'Calculated from BMI & age',
        editable: true,
      ),
      HealthMetric(
        id: 'bmi',
        title: 'BMI',
        valueLabel: s.bmi == null ? '—' : s.bmi!.toStringAsFixed(1),
        unit: '',
        numeric: s.bmi,
        subtitle: s.bmi == null ? '' : (s.bmi! < 18.5 ? 'Underweight ( < 18.5 )' : (s.bmi! < 25 ? 'Normal weight ( 18.5 – 24.9 )' : (s.bmi! < 30 ? 'Overweight ( 25.0 – 29.9 )' : 'Obese ( >= 30.0 )'))),
        editable: true,
      ),
      HealthMetric(
        id: 'floors',
        title: 'Floors climbed',
        valueLabel: s.flightsClimbed == null ? '—' : s.flightsClimbed!.toString(),
        unit: 'floors',
        numeric: s.flightsClimbed?.toDouble(),
        subtitle: 'Estimated from movement',
      ),
      HealthMetric(
        id: 'resp',
        title: 'Respiratory rate',
        valueLabel: s.respiratoryRate == null ? '—' : s.respiratoryRate!.toStringAsFixed(0),
        unit: '/min',
        numeric: s.respiratoryRate,
        subtitle: 'Normal resting: 12–20 /min',
      ),
      HealthMetric(
        id: 'hrv',
        title: 'HRV (RMSSD)',
        valueLabel: s.hrvMs == null ? '—' : s.hrvMs!.toStringAsFixed(0),
        unit: 'ms',
        numeric: s.hrvMs,
        subtitle: 'Heart rate variability',
      ),
      HealthMetric(
        id: 'workouts',
        title: 'Workouts',
        valueLabel: s.workoutCount.toString(),
        unit: 'today',
        numeric: s.workoutCount.toDouble(),
        subtitle: s.workoutCount == 0 ? 'No recorded workout sessions today' : 'Tracked workout sessions',
      ),
    ];

    return HealthSnapshot(
      fetchedAt: s.fetchedAt,
      steps: s.steps,
      heartRateBpm: s.heartRateBpm,
      restingHeartRateBpm: s.restingHeartRateBpm,
      spo2Percent: s.spo2Percent,
      systolic: s.systolic,
      diastolic: s.diastolic,
      glucose: s.glucose,
      bodyTempC: s.bodyTempC,
      weightKg: s.weightKg,
      heightCm: s.heightCm,
      bodyFatPercent: s.bodyFatPercent,
      bmi: s.bmi,
      distanceMeters: s.distanceMeters,
      activeCalories: s.activeCalories,
      totalCalories: s.totalCalories,
      waterMl: s.waterMl,
      sleepHours: s.sleepHours,
      flightsClimbed: s.flightsClimbed,
      respiratoryRate: s.respiratoryRate,
      hrvMs: s.hrvMs,
      workoutCount: s.workoutCount,
      metrics: metrics,
      alerts: alerts,
    );
  }

  List<String> _buildAlerts(HealthSnapshot s) {
    final alerts = <String>[];
    if (_hrAlert(s.heartRateBpm)) {
      alerts.add(
          'Heart rate ${s.heartRateBpm!.round()} bpm is outside ${limits.heartRateLow.round()}–${limits.heartRateHigh.round()} bpm.');
    }
    if (s.spo2Percent != null && s.spo2Percent! < limits.spo2Low) {
      alerts.add('Blood oxygen ${s.spo2Percent!.toStringAsFixed(0)}% is below ${limits.spo2Low.round()}%.');
    }
    if (_bpAlert(s)) {
      alerts.add(
          'Blood pressure ${s.systolic!.round()}/${s.diastolic!.round()} mmHg is above ${limits.systolicHigh.round()}/${limits.diastolicHigh.round()}.');
    }
    if (_glucoseAlert(s.glucose)) {
      alerts.add('Blood glucose ${s.glucose!.toStringAsFixed(0)} mg/dL is outside ${limits.glucoseLow.round()}–${limits.glucoseHigh.round()}.');
    }
    if (s.bodyTempC != null && s.bodyTempC! >= limits.tempHighC) {
      alerts.add('Body temperature ${s.bodyTempC!.toStringAsFixed(1)}°C is at or above ${limits.tempHighC}°C.');
    }
    if (s.steps != null && s.steps! >= limits.stepsGoal) {
      alerts.add('Step goal reached: ${_comma(s.steps!)} / ${limits.stepsGoal}.');
    }
    if (s.waterMl != null && s.waterMl! >= limits.waterGoalMl) {
      alerts.add('Hydration goal reached.');
    }
    final hour = DateTime.now().hour;
    if (hour >= 18 && s.steps != null && s.steps! < (limits.stepsGoal * 0.4)) {
      alerts.add('Evening steps are still low versus your daily goal.');
    }
    return alerts;
  }

  bool _hrAlert(double? hr) =>
      hr != null && (hr > limits.heartRateHigh || hr < limits.heartRateLow);

  bool _bpAlert(HealthSnapshot s) =>
      s.systolic != null &&
      s.diastolic != null &&
      (s.systolic! >= limits.systolicHigh || s.diastolic! >= limits.diastolicHigh);

  bool _glucoseAlert(double? g) =>
      g != null && (g >= limits.glucoseHigh || g <= limits.glucoseLow);

  Future<void> _notifyLimitBreaches(HealthSnapshot snapshot) async {
    if (snapshot.alerts.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateTime.now().toIso8601String().substring(0, 10);
    final stored = prefs.getStringList(_kLastAlertsKey) ?? [];
    final seen = stored.toSet();
    var id = 4100;
    for (final alert in snapshot.alerts) {
      final fingerprint = '$todayKey|$alert';
      if (seen.contains(fingerprint)) continue;
      seen.add(fingerprint);
      await NotificationService.showHealthAlert(
        id: id++,
        title: 'Health alert',
        body: alert,
      );
    }
    await prefs.setStringList(_kLastAlertsKey, seen.toList());
  }

  Future<bool> logWaterMl(double milliliters) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateTime.now().toIso8601String().substring(0, 10);
    final key = 'health_water_ml_$todayKey';
    final current = prefs.getDouble(key) ?? 0.0;
    await prefs.setDouble(key, current + milliliters);

    if (isSupported) {
      try {
        await _configure();
        final now = DateTime.now();
        await _health.writeHealthData(
          value: milliliters / 1000.0,
          type: HealthDataType.WATER,
          startTime: now,
          recordingMethod: RecordingMethod.manual,
        );
      } catch (_) {}
    }
    return true;
  }
  
  Future<void> saveUserProfile({double? weightKg, double? heightCm, int? age, String? gender}) async {
    final prefs = await SharedPreferences.getInstance();
    if (weightKg != null) await prefs.setDouble('health_user_weight_kg', weightKg);
    if (heightCm != null) await prefs.setDouble('health_user_height_cm', heightCm);
    if (age != null) await prefs.setInt('health_user_age', age);
    if (gender != null) await prefs.setString('health_user_gender', gender);
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'weightKg': prefs.getDouble('health_user_weight_kg') ?? 70.0,
      'heightCm': prefs.getDouble('health_user_height_cm') ?? 175.0,
      'age': prefs.getInt('health_user_age') ?? 22,
      'gender': prefs.getString('health_user_gender') ?? 'male',
    };
  }

  Future<bool> logWeightKg(double kg) async {
    if (!isSupported) return false;
    await _configure();
    final now = DateTime.now();
    return _health.writeHealthData(
      value: kg,
      type: HealthDataType.WEIGHT,
      startTime: now,
      recordingMethod: RecordingMethod.manual,
    );
  }

  Future<void> saveLimits(HealthLimits next) async {
    limits = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLimitsKey, jsonEncode(next.toJson()));
    await NotificationService.scheduleDailyHealthChecks(limits);
  }

  Future<void> _loadLimits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLimitsKey);
    if (raw == null) return;
    try {
      limits = HealthLimits.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
  }

  double? _latest(List<HealthDataPoint> points, HealthDataType type) {
    final ofType = points.where((p) => p.type == type).toList()
      ..sort((a, b) => b.dateTo.compareTo(a.dateTo));
    if (ofType.isEmpty) return null;
    return _numeric(ofType.first);
  }

  double? _sum(List<HealthDataPoint> points, HealthDataType type) {
    var total = 0.0;
    var any = false;
    for (final p in points.where((p) => p.type == type)) {
      final n = _numeric(p);
      if (n == null) continue;
      total += n;
      any = true;
    }
    return any ? total : null;
  }

  double? _sleepHours(List<HealthDataPoint> points) {
    final sleepTypes = {
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
    };
    var minutes = 0.0;
    var any = false;
    for (final p in points.where((p) => sleepTypes.contains(p.type))) {
      final n = _numeric(p);
      if (n != null && n > 0) {
        // Plugin may return minutes or hours depending on type.
        minutes += n > 24 ? n : n * 60;
        any = true;
        continue;
      }
      final dur = p.dateTo.difference(p.dateFrom).inMinutes;
      if (dur > 0) {
        minutes += dur;
        any = true;
      }
    }
    if (!any) return null;
    return minutes / 60.0;
  }

  double? _numeric(HealthDataPoint point) {
    final v = point.value;
    if (v is NumericHealthValue) return v.numericValue.toDouble();
    return null;
  }

  String _comma(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final rem = s.length - i;
      if (i > 0 && rem % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
