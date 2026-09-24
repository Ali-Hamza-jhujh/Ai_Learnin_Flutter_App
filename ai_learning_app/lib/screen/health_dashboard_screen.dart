import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_typography.dart';
import '../models/health_snapshot.dart';
import '../services/health_connect_service.dart';
import '../utils/app_theme.dart';

class HealthDashboardScreen extends StatefulWidget {
  const HealthDashboardScreen({super.key});

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen>
    with WidgetsBindingObserver {
  final _svc = HealthConnectService.instance;
  bool _loading = true;
  bool _connecting = false;
  bool _authorized = false;
  bool _sdkReady = true;
  String? _error;
  HealthSnapshot? _snapshot;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
    // Automatically poll and update every 15 seconds while dashboard is open
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_authorized && mounted && !_loading && !_connecting) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _authorized) {
      _refreshData();
    }
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_svc.isSupported) {
        setState(() {
          _loading = false;
          _error = 'Health tracking runs on Android and iPhone.';
        });
        return;
      }
      _sdkReady = await _svc.isHealthConnectReady();
      _authorized = await _svc.hasAuthorization();
      if (_authorized) {
        _snapshot = await _svc.syncAndNotify();
      }
    } catch (_) {
      _error = 'Could not load health data.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshData() async {
    try {
      final snap = await _svc.syncAndNotify();
      if (mounted) setState(() => _snapshot = snap);
    } catch (_) {}
  }

  Future<void> _connect() async {
    setState(() => _connecting = true);
    try {
      _sdkReady = await _svc.isHealthConnectReady();
      if (!_sdkReady) {
        await _svc.installHealthConnect();
        if (mounted) setState(() => _connecting = false);
        return;
      }
      final granted = await _svc.requestPermissions();
      _authorized = granted;
      if (granted) {
        _snapshot = await _svc.syncAndNotify();
      } else if (mounted) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (c) => CupertinoAlertDialog(
            title: const Text('Access not granted'),
            content: const Text(
              'Allow physical activity so this phone can count steps. You can also allow Health Connect types for heart rate and sleep.',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(c),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      _error = 'Could not complete permission request.';
    }
    if (mounted) setState(() => _connecting = false);
  }

  Future<void> _logWater(double ml) async {
    await _svc.logWaterMl(ml);
    if (!mounted) return;
    showCupertinoSuccess(context, 'Logged ${ml.round()} ml water 💧');
    await _refreshData();
  }

  void _openLimits() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LimitsSheet(
        limits: _svc.limits,
        onSave: (next) async {
          await _svc.saveLimits(next);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: CupertinoNavigationBar(
        leading: const CupertinoNavigationBarBackButton(previousPageTitle: ''),
        backgroundColor: AppColors.bgCard.withValues(alpha: 0.9),
        middle: Text(
          'Health',
          style: AppTypography.titleLarge.copyWith(color: AppColors.textWhite, fontSize: 18),
        ),
        trailing: _authorized
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _openLimits,
                child: const Text('Goals'),
              )
            : null,
      ),
      child: Stack(
        children: [
          const SpaceBackground(),
          SafeArea(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : !_authorized
                    ? _permissionGate()
                    : CustomScrollView(
                        slivers: [
                          CupertinoSliverRefreshControl(onRefresh: _refreshData),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                Text('Today', style: AppTypography.displayMedium),
                                const SizedBox(height: 6),
                                const Text(
                                  'Steps are counted on this phone. Heart rate, sleep, and other vitals appear when a watch or fitness app shares them with Health Connect. Nothing is uploaded.',
                                  style: TextStyle(color: AppColors.textMuted, height: 1.45, fontSize: 14),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                                ],
                                const SizedBox(height: 18),
                                if (_snapshot != null) ...[
                                  _heroCards(_snapshot!),
                                  _stepProgressCard(_snapshot!),
                                  const SizedBox(height: 14),
                                  _deviceHubCard(),
                                  const SizedBox(height: 14),
                                  _waterCard(_snapshot!),
                                  const SizedBox(height: 14),
                                  _bodyProfileCard(),
                                  if (_snapshot!.alerts.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    _alertsCard(_snapshot!.alerts),
                                  ],
                                  const SizedBox(height: 22),
                                  Row(
                                    children: [
                                      Text('All metrics', style: AppTypography.titleMedium),
                                      const Spacer(),
                                      Text('${_snapshot!.metrics.length} tracked', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ..._snapshot!.metrics.map(_metricTile),
                                ],
                                const SizedBox(height: 20),
                                _disclaimer(),
                              ]),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _permissionGate() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.violet.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(CupertinoIcons.heart_fill, color: AppColors.violet, size: 30),
        ),
        const SizedBox(height: 20),
        Text('Keep your health data on this phone', style: AppTypography.displayMedium),
        const SizedBox(height: 10),
        const Text(
          'StudyAI reads Health Connect on the device to show your day and to send summaries at 8:00, 14:00, and 20:00, plus an alert if a metric you set is crossed.',
          style: TextStyle(color: AppColors.textSub, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 20),
        _bullet('Activity recognition so this phone can count steps.'),
        _bullet('Health Connect read access for vitals already stored by other apps.'),
        _bullet('Notifications for the three daily summaries and limit alerts.'),
        const SizedBox(height: 28),
        GlowButton(
          text: _sdkReady ? 'Continue' : 'Install Health Connect',
          icon: CupertinoIcons.arrow_right,
          isLoading: _connecting,
          onPressed: _connect,
        ),
        const SizedBox(height: 16),
        _disclaimer(),
      ],
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(CupertinoIcons.checkmark_alt, size: 16, color: AppColors.success),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSub, fontSize: 14, height: 1.4))),
        ],
      ),
    );
  }

  Widget _heroCards(HealthSnapshot s) {
    final distKm = s.distanceMeters != null ? (s.distanceMeters! / 1000) : 0.0;
    final totalCal = s.totalCalories?.round() ?? 0;
    final bmiVal = s.bmi;
    final bmiLabel = bmiVal == null ? '—'
        : bmiVal < 18.5 ? 'Under'
        : bmiVal < 25 ? 'Normal'
        : bmiVal < 30 ? 'Over'
        : 'Obese';

    Widget card({
      required String label,
      required String value,
      required String unit,
      required Color color,
      String? badge,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
            ],
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  if (badge != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(badge, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900, height: 1.0)),
              Text(unit, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            card(
              label: 'STEPS',
              value: _comma(s.steps ?? 0),
              unit: 'steps today',
              color: AppColors.violet,
              badge: s.steps != null && s.steps! >= _svc.limits.stepsGoal ? 'GOAL ✓' : null,
            ),
            const SizedBox(width: 10),
            card(
              label: 'DISTANCE',
              value: distKm.toStringAsFixed(2),
              unit: 'km walked',
              color: AppColors.cyan,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            card(
              label: 'CALORIES',
              value: totalCal.toString(),
              unit: 'kcal burned today',
              color: AppColors.gold,
            ),
            const SizedBox(width: 10),
            card(
              label: 'BMI',
              value: bmiVal == null ? '—' : bmiVal.toStringAsFixed(1),
              unit: 'body mass index',
              color: bmiVal == null ? AppColors.textMuted
                  : bmiVal < 18.5 ? AppColors.cyan
                  : bmiVal < 25 ? AppColors.success
                  : bmiVal < 30 ? AppColors.gold
                  : AppColors.error,
              badge: bmiLabel,
            ),
          ],
        ),
      ],
    );
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

  Widget _stepProgressCard(HealthSnapshot s) {
    final goal = _svc.limits.stepsGoal;
    final steps = s.steps ?? 0;
    final pct = goal <= 0 ? 0.0 : (steps / goal).clamp(0.0, 1.0);
    final remaining = (goal - steps).clamp(0, goal);
    return Container(
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
              const Icon(CupertinoIcons.flame_fill, color: AppColors.violet, size: 16),
              const SizedBox(width: 6),
              const Text('Step goal', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textWhite)),
              const Spacer(),
              Text(
                pct >= 1.0 ? '🎉 Goal reached!' : '$remaining to go',
                style: TextStyle(
                  color: pct >= 1.0 ? AppColors.success : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_comma(steps)} / ${_comma(goal)} steps',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.inputBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 1.0 ? AppColors.success : AppColors.violet,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waterCard(HealthSnapshot s) {
    final waterMl = s.waterMl ?? 0.0;
    final goal = _svc.limits.waterGoalMl;
    final pct = (waterMl / goal).clamp(0.0, 1.0);
    return Container(
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
              const Icon(CupertinoIcons.drop_fill, color: AppColors.cyan, size: 16),
              const SizedBox(width: 6),
              const Text('Hydration', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textWhite)),
              const Spacer(),
              Text('${waterMl.round()} / ${goal.round()} ml',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.inputBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 1.0 ? AppColors.success : AppColors.cyan,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _waterBtn('+ 150 ml', 150),
              const SizedBox(width: 8),
              _waterBtn('+ 250 ml', 250),
              const SizedBox(width: 8),
              _waterBtn('+ 500 ml', 500),
            ],
          ),
        ],
      ),
    );
  }

  Widget _waterBtn(String label, double ml) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _logWater(ml),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cyan.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.cyan, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ),
      ),
    );
  }

  Widget _deviceHubCard() {
    final hasHrOrSleep = _snapshot?.heartRateBpm != null || _snapshot?.sleepHours != null;
    final statusColor = hasHrOrSleep ? AppColors.success : AppColors.cyan;
    final statusText = hasHrOrSleep ? 'Watch Synced & Active' : 'Pair Smartwatch / Devices';
    final subtitleText = hasHrOrSleep
        ? 'Heart rate and sleep are actively syncing via Health Connect.'
        : 'Connect Samsung Galaxy Watch, Apple Watch, Pixel Watch, Fitbit, or Garmin to see real-time vitals.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(CupertinoIcons.device_laptop, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'DEVICE HUB',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hasHrOrSleep ? 'SYNCED' : 'SETUP',
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitleText,
            style: const TextStyle(color: AppColors.textSub, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 9),
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              onPressed: _showDevicePairingSheet,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.link, color: statusColor, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Pair Watch & View Supported Devices',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDevicePairingSheet() {
    String? expandedBrand = 'samsung';

    final devices = [
      {
        'id': 'samsung',
        'name': 'Samsung Galaxy Watch',
        'subtitle': 'Watch 4, 5, 6, 7, Ultra & FE (Wear OS)',
        'icon': '⌚',
        'color': AppColors.violet,
        'metrics': 'Heart Rate, Sleep, SpO₂, ECG, Steps',
        'steps': [
          'Open the Samsung Health app on your phone.',
          'Tap Settings (gear icon) > Connected services > Health Connect.',
          'Turn on "Allow all permissions" (Heart rate, Sleep, Steps).',
          'StudyAI will instantly display your watch\'s real-time vitals.',
        ],
      },
      {
        'id': 'apple',
        'name': 'Apple Watch',
        'subtitle': 'Series 4 through 10, Ultra & SE',
        'icon': '🍏',
        'color': AppColors.cyan,
        'metrics': 'Heart Rate, Resting HR, Sleep, SpO₂, Steps',
        'steps': [
          'Wear your Apple Watch paired to your iPhone.',
          'Open iPhone Settings > Health > Data Access & Devices.',
          'Tap StudyAI and choose "Turn All Categories On".',
          'Vitals recorded by Apple Watch will automatically sync.',
        ],
      },
      {
        'id': 'fitbit',
        'name': 'Google Pixel Watch & Fitbit',
        'subtitle': 'Pixel Watch 1/2/3, Charge, Versa, Sense',
        'icon': '⚡',
        'color': AppColors.gold,
        'metrics': 'Heart Rate, Sleep Stages, Steps, Calories',
        'steps': [
          'Open the Fitbit app on your phone.',
          'Tap your Profile icon > Fitbit settings > Health Connect.',
          'Toggle "Sync with Health Connect" to ON.',
          'Select "Allow all" for full data synchronization.',
        ],
      },
      {
        'id': 'xiaomi',
        'name': 'Xiaomi / Redmi / Amazfit / Zepp',
        'subtitle': 'Mi Band 6/7/8/9, Redmi Watch, Amazfit GTR/GTS',
        'icon': '🏃',
        'color': AppColors.success,
        'metrics': 'Heart Rate, Sleep, Daily Steps',
        'steps': [
          'Open Mi Fitness or Zepp app on your phone.',
          'Go to Profile > Connected apps / Third-party data.',
          'Select Google Health Connect (or Google Fit).',
          'Turn on permission sharing for Heart Rate, Sleep, and Steps.',
        ],
      },
      {
        'id': 'garmin',
        'name': 'Garmin Watch',
        'subtitle': 'Forerunner, Fenix, Venu, Instinct',
        'icon': '🧭',
        'color': AppColors.violet,
        'metrics': 'Heart Rate, Sleep, HRV, SpO₂, Stress',
        'steps': [
          'Open the Garmin Connect app on your phone.',
          'Go to Settings > Connected Apps.',
          'Select Health Connect and toggle write permissions to ON.',
          'Garmin vitals will stream directly into StudyAI.',
        ],
      },
      {
        'id': 'medical',
        'name': 'Smart Medical Monitors',
        'subtitle': 'Omron BP, Accu-Chek Glucose, Withings Scales',
        'icon': '🩺',
        'color': AppColors.error,
        'metrics': 'Blood Pressure, Glucose, Weight, Body Temp',
        'steps': [
          'Pair your medical monitor via Bluetooth to its official app.',
          'In that app\'s settings, enable Health Connect / Apple Health sync.',
          'Blood pressure, glucose, and weight appear automatically.',
        ],
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (ctx, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.violet.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(CupertinoIcons.device_laptop, color: AppColors.violet, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Smartwatch & Device Hub',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textWhite,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Pair any smartwatch or medical monitor',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(ctx),
                            child: const Icon(CupertinoIcons.xmark_circle_fill, color: AppColors.textMuted, size: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.violet.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.violet.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(CupertinoIcons.checkmark_shield_fill, color: AppColors.violet, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'System Health Hub',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textWhite,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'StudyAI reads watches through Google Health Connect (Android) or Apple Health (iOS). Tap below to manage permissions.',
                              style: TextStyle(color: AppColors.textSub, fontSize: 12, height: 1.4),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                color: AppColors.violet,
                                borderRadius: BorderRadius.circular(10),
                                onPressed: () async {
                                  await _svc.openHealthSettings();
                                },
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.gear_alt, color: Colors.white, size: 15),
                                    SizedBox(width: 6),
                                    Text(
                                      'Open Health Connect / App Permissions',
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Select Your Device Brand',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textWhite,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...devices.map((d) {
                        final isExpanded = expandedBrand == d['id'];
                        final color = d['color'] as Color;
                        final steps = d['steps'] as List<String>;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.inputBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isExpanded ? color.withValues(alpha: 0.5) : AppColors.inputBorder,
                              width: isExpanded ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setSheetState(() {
                                    expandedBrand = isExpanded ? null : d['id'] as String;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Text(d['icon'] as String, style: const TextStyle(fontSize: 22)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              d['name'] as String,
                                              style: const TextStyle(
                                                color: AppColors.textWhite,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              d['subtitle'] as String,
                                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                                        color: AppColors.textMuted,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isExpanded) ...[
                                const Divider(height: 1, color: AppColors.divider),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Tracks: ${d['metrics']}',
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Setup Instructions:',
                                        style: TextStyle(
                                          color: AppColors.textWhite,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ...steps.asMap().entries.map((entry) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 18,
                                                height: 18,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: color.withValues(alpha: 0.15),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  '${entry.key + 1}',
                                                  style: TextStyle(
                                                    color: color,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  entry.value,
                                                  style: const TextStyle(
                                                    color: AppColors.textSub,
                                                    fontSize: 12,
                                                    height: 1.35,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          color: AppColors.inputBorder,
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _refreshData();
                            if (!mounted) return;
                            showCupertinoSuccess(context, 'Synced with Health Connect');
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.refresh, color: AppColors.textWhite, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Refresh Synced Vitals',
                                style: TextStyle(
                                  color: AppColors.textWhite,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _bodyProfileCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _svc.getUserProfile(),
      builder: (context, snap) {
        final profile = snap.data;
        final weightKg = profile?['weightKg'] as double? ?? 70.0;
        final heightCm = profile?['heightCm'] as double? ?? 175.0;
        final age = profile?['age'] as int? ?? 22;
        final gender = profile?['gender'] as String? ?? 'male';

        return GestureDetector(
          onTap: () => _showBodyProfileSheet(
              weightKg: weightKg, heightCm: heightCm, age: age, gender: gender),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.violet.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(CupertinoIcons.person_fill, color: AppColors.violet, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Body profile', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textWhite, fontSize: 14)),
                      Text(
                        '${weightKg.toStringAsFixed(0)} kg · ${heightCm.toStringAsFixed(0)} cm · Age $age · $gender',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      const Text('Used for BMR, BMI and calorie calculations', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.chevron_right, color: AppColors.textMuted, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBodyProfileSheet({required double weightKg, required double heightCm, required int age, required String gender}) {
    final wCtrl = TextEditingController(text: weightKg.toStringAsFixed(1));
    final hCtrl = TextEditingController(text: heightCm.toStringAsFixed(0));
    final aCtrl = TextEditingController(text: age.toString());
    String selectedGender = gender;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Body profile', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textWhite, fontSize: 18)),
                const SizedBox(height: 4),
                const Text('Used to calculate BMR, TDEE, BMI and body fat.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 16),
                _profileField('Weight (kg)', wCtrl, hint: 'e.g. 70'),
                _profileField('Height (cm)', hCtrl, hint: 'e.g. 175'),
                _profileField('Age (years)', aCtrl, hint: 'e.g. 22'),
                const SizedBox(height: 8),
                const Text('Gender', style: TextStyle(color: AppColors.textSub, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: ['male', 'female'].map((g) {
                    final selected = selectedGender == g;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setSheetState(() => selectedGender = g),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.violet.withValues(alpha: 0.1) : AppColors.inputBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: selected ? AppColors.violet : AppColors.inputBorder),
                          ),
                          child: Center(
                            child: Text(
                              g[0].toUpperCase() + g.substring(1),
                              style: TextStyle(
                                color: selected ? AppColors.violet : AppColors.textSub,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: AppColors.violet,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () async {
                      await _svc.saveUserProfile(
                        weightKg: double.tryParse(wCtrl.text) ?? weightKg,
                        heightCm: double.tryParse(hCtrl.text) ?? heightCm,
                        age: int.tryParse(aCtrl.text) ?? age,
                        gender: selectedGender,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _refreshData();
                      if (mounted) setState(() {});
                    },
                    child: const Text('Save profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileField(String label, TextEditingController ctrl, {String hint = ''}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSub, fontSize: 13)),
          const SizedBox(height: 4),
          CupertinoTextField(
            controller: ctrl,
            placeholder: hint,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.inputBorder),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertsCard(List<String> alerts) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Alerts', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textWhite)),
          const SizedBox(height: 8),
          ...alerts.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $a', style: const TextStyle(color: AppColors.textSub, fontSize: 13, height: 1.35)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onTapMetric(HealthMetric m) async {
    if (!m.editable) return;
    
    String? val = await showCupertinoDialog<String>(
      context: context,
      builder: (c) {
        final ctrl = TextEditingController();
        return CupertinoAlertDialog(
          title: Text('Update ${m.title}'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: ctrl,
              placeholder: m.unit.isNotEmpty ? 'Enter value in ${m.unit}' : 'Enter value',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(c),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Save'),
              onPressed: () => Navigator.pop(c, ctrl.text),
            ),
          ],
        );
      },
    );

    if (val != null && val.isNotEmpty) {
      final numValue = double.tryParse(val);
      if (numValue != null) {
        if (m.id == 'weight') {
          await _svc.saveUserProfile(weightKg: numValue);
        } else if (m.id == 'height') {
          await _svc.saveUserProfile(heightCm: numValue);
        } else if (m.id == 'water') {
          await _svc.logWaterMl(numValue);
        }
        // Could expand to save other vitals if needed
        await _refreshData();
      }
    }
  }

  Widget _metricTile(HealthMetric m) {
    // Dot color: green if has real value, grey if sensor unavailable (still showing —)
    final hasValue = m.valueLabel != '—';
    final dotColor = m.alert
        ? AppColors.gold
        : hasValue
            ? AppColors.success
            : AppColors.inputBorder;

    return GestureDetector(
      onTap: () => _onTapMetric(m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: m.alert ? AppColors.gold.withValues(alpha: 0.4) : AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textWhite, fontSize: 14)),
                  if (m.subtitle.isNotEmpty)
                    Text(m.subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.2)),
                ],
              ),
            ),
            Text(
              m.unit.isEmpty ? m.valueLabel : '${m.valueLabel} ${m.unit}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: m.alert
                    ? AppColors.gold
                    : hasValue
                        ? AppColors.textWhite
                        : AppColors.textMuted,
              ),
            ),
            if (m.editable) ...[
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.chevron_right, color: AppColors.textMuted, size: 13),
            ],
          ],
        ),
      ),
    );
  }

  Widget _disclaimer() {
    return const Text(
      'Not a medical device. Limits are wellness thresholds, not a diagnosis.',
      style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
    );
  }
}

class _LimitsSheet extends StatefulWidget {
  final HealthLimits limits;
  final Future<void> Function(HealthLimits) onSave;
  const _LimitsSheet({required this.limits, required this.onSave});

  @override
  State<_LimitsSheet> createState() => _LimitsSheetState();
}

class _LimitsSheetState extends State<_LimitsSheet> {
  late HealthLimits _l;

  @override
  void initState() {
    super.initState();
    _l = widget.limits;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Goals & alerts', style: AppTypography.titleLarge.copyWith(color: AppColors.textWhite)),
            const SizedBox(height: 12),
            _switch('Morning summary (08:00)', _l.morning, (v) => setState(() => _l = _l.copyWith(morning: v))),
            _switch('Afternoon summary (14:00)', _l.afternoon, (v) => setState(() => _l = _l.copyWith(afternoon: v))),
            _switch('Evening summary (20:00)', _l.evening, (v) => setState(() => _l = _l.copyWith(evening: v))),
            _switch('Alert when a metric crosses a limit', _l.limitAlerts, (v) => setState(() => _l = _l.copyWith(limitAlerts: v))),
            const SizedBox(height: 8),
            _num('Step goal', _l.stepsGoal.toDouble(), (v) => _l = _l.copyWith(stepsGoal: v.round())),
            _num('Heart rate high (bpm)', _l.heartRateHigh, (v) => _l = _l.copyWith(heartRateHigh: v)),
            _num('Heart rate low (bpm)', _l.heartRateLow, (v) => _l = _l.copyWith(heartRateLow: v)),
            _num('SpO₂ low (%)', _l.spo2Low, (v) => _l = _l.copyWith(spo2Low: v)),
            _num('Systolic high (mmHg)', _l.systolicHigh, (v) => _l = _l.copyWith(systolicHigh: v)),
            _num('Diastolic high (mmHg)', _l.diastolicHigh, (v) => _l = _l.copyWith(diastolicHigh: v)),
            _num('Glucose high (mg/dL)', _l.glucoseHigh, (v) => _l = _l.copyWith(glucoseHigh: v)),
            _num('Glucose low (mg/dL)', _l.glucoseLow, (v) => _l = _l.copyWith(glucoseLow: v)),
            _num('Temperature high (°C)', _l.tempHighC, (v) => _l = _l.copyWith(tempHighC: v)),
            _num('Water goal (ml)', _l.waterGoalMl, (v) => _l = _l.copyWith(waterGoalMl: v)),
            const SizedBox(height: 12),
            GlowButton(
              text: 'Save',
              onPressed: () async {
                await widget.onSave(_l);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textWhite, fontSize: 14))),
          CupertinoSwitch(value: value, activeTrackColor: AppColors.violet, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _num(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSub, fontSize: 13))),
          SizedBox(
            width: 90,
            child: CupertinoTextField(
              placeholder: value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              padding: const EdgeInsets.all(8),
              onChanged: (s) {
                final n = double.tryParse(s);
                if (n != null) onChanged(n);
              },
            ),
          ),
        ],
      ),
    );
  }
}
