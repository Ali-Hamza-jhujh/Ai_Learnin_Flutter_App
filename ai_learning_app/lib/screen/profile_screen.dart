import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import '../services/api_client.dart';
import '../services/ai_generation_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'skeleton_widgets.dart';
import 'api_keys_settings_screen.dart';   // ← NEW

// ══════════════════════════════════════════
// PROFILE SCREEN
// Unchanged from original except:
//  - Added "AI Provider Keys" row in settings
//  - Tapping it navigates to APIKeysSettingsScreen
// ══════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _level;
  bool _loading = true;
  String? _error;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadProfile();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ProfileService.getStats();
      if (mounted) {
        setState(() {
          _profile = res['profile'] as Map<String, dynamic>?;
          _stats   = res['stats']   as Map<String, dynamic>?;
          _level   = res['level']   as Map<String, dynamic>?;
          _loading = false;
        });
        _fadeCtrl.forward(from: 0);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to load profile'; _loading = false; });
    }
  }

  // ── Getters ───────────────────────────
  String get _name      => _profile?['name']            as String? ?? 'Student';
  String get _email     => _profile?['email']           as String? ?? '';
  String get _subject   => _profile?['subject']         as String? ?? '';
  String get _goal      => _profile?['goal']            as String? ?? '';
  String get _eduLevel  => _profile?['educationLevel']  as String? ?? '';
  int    get _xp        => (_profile?['xp']             as num?)?.toInt()    ?? 0;
  int    get _streak    => (_profile?['streak']         as num?)?.toInt()    ?? 0;
  int    get _levelNum  => (_level?['level']            as num?)?.toInt()    ?? 1;
  String get _levelTitle=> _level?['title']             as String? ?? 'Beginner';
  int    get _progress  => (_level?['progressPercent']  as num?)?.toInt()    ?? 0;
  int    get _xpToNext  => (_level?['xpToNextLevel']    as num?)?.toInt()    ?? 0;
  bool   get _isMaxLevel=> _level?['isMaxLevel']        as bool?  ?? false;
  int    get _notesCount=> (_stats?['notesGenerated']   as num?)?.toInt()    ?? 0;
  int    get _testsCount=> (_stats?['testsCompleted']   as num?)?.toInt()    ?? 0;
  double get _avgScore  => (_stats?['averageTestScore'] as num?)?.toDouble() ?? 0.0;
  int    get _chatCount => (_stats?['chatSessions']     as num?)?.toInt()    ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const SpaceBackground(),
        SafeArea(
          child: _loading
            ? const Center(child: ProfileSkeleton())
            : _error != null
              ? _buildError()
              : FadeTransition(opacity: _fadeAnim, child: _buildContent())),
      ]));
  }

  Widget _buildError() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      buildErrorBanner(_error!),
      const SizedBox(height: 16),
      GlowButton(text: 'Retry', icon: Icons.refresh_rounded,
          onPressed: _loadProfile),
    ])));

  Widget _buildContent() => RefreshIndicator(
    color: AppColors.violet,
    backgroundColor: AppColors.bgCard,
    onRefresh: _loadProfile,
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(children: [
        _buildProfileHeader(),
        _buildXPSection(),
        _buildStatsGrid(),
        _buildAchievements(),
        _buildStudyInfo(),
        _buildSettingsSection(),   // ← contains new AI Keys row
      ])));

  // ── PROFILE HEADER ────────────────────
  Widget _buildProfileHeader() => Container(
    margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
          colors: [Color(0xFF1A1060), Color(0xFF0D1535)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: AppColors.violet.withOpacity(0.3))),
    child: Column(children: [
      Row(children: [
        // Avatar
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGrad,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppColors.violet.withOpacity(0.4),
                blurRadius: 20, offset: const Offset(0, 8))]),
          child: Center(child: Text(
            _name.isNotEmpty ? _name[0].toUpperCase() : 'S',
            style: const TextStyle(color: Colors.white,
                fontSize: 28, fontWeight: FontWeight.w800)))),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(_name, style: const TextStyle(color: AppColors.textWhite,
              fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_email, style: AppTextStyles.body.copyWith(fontSize: 12),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(gradient: AppColors.primaryGrad,
                borderRadius: BorderRadius.circular(20)),
            child: Text('Lv.$_levelNum · $_levelTitle',
              style: const TextStyle(color: Colors.white,
                  fontSize: 11, fontWeight: FontWeight.w700))),
        ])),
        GestureDetector(
          onTap: _showEditProfile,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.violet.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.violet.withOpacity(0.3))),
            child: const Icon(Icons.edit_outlined,
                color: AppColors.violetLight, size: 18))),
      ]),
      const SizedBox(height: 20),
      Column(children: [
        Row(children: [
          const Text('⚡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text('$_xp XP', style: const TextStyle(color: AppColors.textWhite,
              fontSize: 14, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(_isMaxLevel ? 'Max Level!'
              : '$_xpToNext XP to Lv.${_levelNum + 1}',
            style: AppTextStyles.label.copyWith(fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progress / 100, minHeight: 8,
            backgroundColor: AppColors.inputBorder,
            valueColor: const AlwaysStoppedAnimation(AppColors.violet))),
        const SizedBox(height: 6),
        Row(children: [
          ShaderMask(
            shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
            child: Text('$_progress% to next level',
              style: const TextStyle(color: Colors.white,
                  fontSize: 11, fontWeight: FontWeight.w600))),
          const Spacer(),
          if (_streak > 0)
            Row(children: [
              const Text('🔥', style: TextStyle(fontSize: 12)),
              Text(' $_streak day streak',
                style: const TextStyle(color: AppColors.gold,
                    fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
        ]),
      ]),
    ]));

  // ── XP SECTION ────────────────────────
  Widget _buildXPSection() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
    child: Row(children: [
      _xpCard('⚡', '$_xp',      'Total XP',   AppColors.violet),
      const SizedBox(width: 12),
      _xpCard('🔥', '$_streak',  'Day Streak',  AppColors.gold),
      const SizedBox(width: 12),
      _xpCard('🏆', 'Lv.$_levelNum', 'Level',  AppColors.cyan),
    ]));

  Widget _xpCard(String emoji, String value, String label, Color color) =>
    Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08),
            blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color,
            fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.label.copyWith(fontSize: 10)),
      ])));

  // ── STATS GRID ────────────────────────
  Widget _buildStatsGrid() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('📊', 'Study Stats'),
      const SizedBox(height: 12),
      Row(children: [
        _statCard('📝', '$_notesCount', 'Notes\nGenerated',  AppColors.violet),
        const SizedBox(width: 12),
        _statCard('✅', '$_testsCount', 'Tests\nCompleted',  const Color(0xFF00C9A7)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _statCard('📊', '${_avgScore.toStringAsFixed(1)}%', 'Average\nScore',
            _avgScore >= 70 ? AppColors.success : AppColors.gold),
        const SizedBox(width: 12),
        _statCard('🤖', '$_chatCount', 'AI Tutor\nSessions', const Color(0xFFFF6B6B)),
      ]),
    ]));

  Widget _statCard(String emoji, String value, String label, Color color) =>
    Expanded(child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(emoji,
              style: const TextStyle(fontSize: 20)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(value, style: TextStyle(color: color,
              fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: AppTextStyles.label.copyWith(
              fontSize: 10, height: 1.4)),
        ])),
      ])));

  // ── ACHIEVEMENTS ──────────────────────
  Widget _buildAchievements() {
    final achievements = [
      {'emoji':'📝','title':'Note Taker',    'unlocked':_notesCount >= 1, 'color':AppColors.violet},
      {'emoji':'🎯','title':'Quiz Master',   'unlocked':_testsCount >= 5, 'color':const Color(0xFF00C9A7)},
      {'emoji':'🔥','title':'7-Day Streak',  'unlocked':_streak >= 7,     'color':AppColors.gold},
      {'emoji':'⚡','title':'500 XP',        'unlocked':_xp >= 500,       'color':AppColors.cyan},
      {'emoji':'🏆','title':'Level 5',       'unlocked':_levelNum >= 5,   'color':const Color(0xFFFF6B6B)},
      {'emoji':'👑','title':'Level 10',      'unlocked':_levelNum >= 10,  'color':AppColors.gold},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('🏅', 'Achievements'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: achievements.map((a) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _achievementBadge(
              a['emoji'] as String, a['title'] as String,
              a['unlocked'] as bool, a['color'] as Color))).toList())),
      ]));
  }

  Widget _achievementBadge(String emoji, String title, bool unlocked, Color color) =>
    Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: unlocked ? color.withOpacity(0.1) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: unlocked
            ? color.withOpacity(0.4) : AppColors.inputBorder)),
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          Text(emoji, style: TextStyle(fontSize: 28,
              color: unlocked ? null : Colors.white.withOpacity(0.3))),
          if (!unlocked)
            const Positioned(bottom: 0, right: 0,
              child: Text('🔒', style: TextStyle(fontSize: 12))),
        ]),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(
            color: unlocked ? color : AppColors.textMuted,
            fontSize: 10, fontWeight: FontWeight.w600, height: 1.3),
            textAlign: TextAlign.center, maxLines: 2),
      ]));

  // ── STUDY INFO ────────────────────────
  Widget _buildStudyInfo() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('📚', 'Study Profile'),
      const SizedBox(height: 12),
      GlassCard(child: Column(children: [
        _infoRow('🎓', 'Education',
            _eduLevel.isEmpty ? 'Not set' : _capitalise(_eduLevel)),
        _divider(),
        _infoRow('📖', 'Subject', _subject.isEmpty ? 'Not set' : _subject),
        _divider(),
        _infoRow('🎯', 'Goal',    _goal.isEmpty    ? 'Not set' : _goal),
      ])),
    ]));

  Widget _infoRow(String emoji, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 12),
      Text(label, style: AppTextStyles.body.copyWith(
          color: AppColors.textMuted)),
      const Spacer(),
      Flexible(child: Text(value, style: const TextStyle(
          color: AppColors.textWhite, fontSize: 14,
          fontWeight: FontWeight.w600),
        textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
    ]));

  Widget _divider() => Divider(
      color: AppColors.inputBorder, height: 1, thickness: 1);

  // ══════════════════════════════════════════
  // SETTINGS SECTION
  // KEY CHANGE: Added "AI Provider Keys" row
  // ══════════════════════════════════════════
  Widget _buildSettingsSection() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('⚙️', 'Settings'),
      const SizedBox(height: 12),
      GlassCard(child: Column(children: [

        // ── NEW: AI Provider Keys ────────────
        _settingRow(
          Icons.key_rounded,
          'AI Provider Keys',
          'Gemini, Groq, Cerebras + Offline AI',
          AppColors.violet,
          onTap: () => Navigator.push(context,
            fadeSlideRoute(const APIKeysSettingsScreen()))),
        _divider(),
        // ── END NEW ─────────────────────────

        _settingRow(Icons.leaderboard_rounded, 'Leaderboard',
            'See your ranking', AppColors.cyan,
            onTap: _openLeaderboard),
        _divider(),
        _settingRow(Icons.lock_outline_rounded, 'Change Password',
            'Update your password', AppColors.violet,
            onTap: _showChangePassword),
        _divider(),
        _settingRow(Icons.person_outline_rounded, 'Edit Profile',
            'Update your info', const Color(0xFF00C9A7),
            onTap: _showEditProfile),
        _divider(),
        _settingRow(Icons.notifications_outlined, 'Study Reminder',
            'Set daily reminder time', AppColors.gold,
            onTap: _showReminderPicker),
        _divider(),
        _settingRow(Icons.logout_rounded, 'Logout',
            'Sign out of StudyAI', AppColors.error,
            onTap: _confirmLogout, isDestructive: true),
      ])),
      const SizedBox(height: 16),
      Center(child: Text('StudyAI v1.0.0 · Made with ❤️ for students',
          style: AppTextStyles.label.copyWith(fontSize: 11))),
    ]));

  Widget _settingRow(IconData icon, String title, String subtitle,
      Color color, {required VoidCallback onTap, bool isDestructive = false}) =>
    GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(title, style: TextStyle(
                color: isDestructive ? AppColors.error : AppColors.textWhite,
                fontSize: 14, fontWeight: FontWeight.w600)),
            Text(subtitle, style: AppTextStyles.body.copyWith(fontSize: 12)),
          ])),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 20),
        ])));

  // ── REMINDER PICKER ───────────────────
  void _showReminderPicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.violet, surface: AppColors.bgCard)),
        child: child!));
    if (picked != null && mounted) {
      await NotificationService.scheduleDailyReminder(
          hour: picked.hour, minute: picked.minute);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            successSnackBar('Reminder set for ${picked.format(context)} 🔔'));
      }
    }
  }

  // ── LEADERBOARD ───────────────────────
  void _openLeaderboard() => Navigator.push(context,
    PageRouteBuilder(
      pageBuilder: (_, a, __) => const _LeaderboardScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
          child: child)),
      transitionDuration: const Duration(milliseconds: 350)));

  // ── EDIT PROFILE ──────────────────────
  void _showEditProfile() {
    final nameCtrl    = TextEditingController(text: _name);
    final subjectCtrl = TextEditingController(text: _subject);
    final goalCtrl    = TextEditingController(text: _goal);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheet(
        title: '✏️ Edit Profile',
        child: Column(children: [
          AppTextField(label:'Name', hint:'Your name',
              controller:nameCtrl, prefixIcon:Icons.person_outline),
          const SizedBox(height:16),
          AppTextField(label:'Subject', hint:'e.g. Computer Science',
              controller:subjectCtrl, prefixIcon:Icons.book_outlined),
          const SizedBox(height:16),
          AppTextField(label:'Goal', hint:'Your study goal',
              controller:goalCtrl, prefixIcon:Icons.flag_outlined,
              textInputAction:TextInputAction.done),
          const SizedBox(height:24),
          GlowButton(
            text: 'Save Changes', icon: Icons.check_rounded,
            onPressed: () async {
              try {
                await ProfileService.updateProfile(
                    name:nameCtrl.text.trim(),
                    subject:subjectCtrl.text.trim(),
                    goal:goalCtrl.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadProfile();
                  ScaffoldMessenger.of(context).showSnackBar(
                      successSnackBar('Profile updated! ✅'));
                }
              } catch (_) {}
            }),
        ])));
  }

  // ── CHANGE PASSWORD ───────────────────
  void _showChangePassword() {
    final currentCtrl = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => _BottomSheet(
          title: '🔐 Change Password',
          child: Column(children: [
            if (error != null) ...[
              buildErrorBanner(error!), const SizedBox(height: 16)],
            AppTextField(label:'Current Password', hint:'Enter current password',
                controller:currentCtrl, prefixIcon:Icons.lock_outline,
                isPassword:true),
            const SizedBox(height:16),
            AppTextField(label:'New Password', hint:'At least 6 characters',
                controller:newCtrl, prefixIcon:Icons.lock_outline,
                isPassword:true),
            const SizedBox(height:16),
            AppTextField(label:'Confirm New Password', hint:'Re-enter new password',
                controller:confirmCtrl, prefixIcon:Icons.lock_outline,
                isPassword:true, textInputAction:TextInputAction.done),
            const SizedBox(height:24),
            GlowButton(
              text: 'Change Password', icon: Icons.check_rounded,
              onPressed: () async {
                if (newCtrl.text != confirmCtrl.text) {
                  setModal(() => error = 'Passwords do not match');
                  return;
                }
                try {
                  await ProfileService.changePassword(
                      currentPassword:currentCtrl.text,
                      newPassword:newCtrl.text);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                        successSnackBar('Password changed! 🔐'));
                  }
                } on ApiException catch (e) {
                  setModal(() => error = e.message);
                } catch (_) {
                  setModal(() => error = 'Something went wrong');
                }
              }),
          ]))));
  }

  // ── LOGOUT ────────────────────────────
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('👋', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text('Log Out?', style: TextStyle(
                color: AppColors.textWhite, fontSize: 20,
                fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('You will need to sign in again.',
                style: AppTextStyles.sub, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.inputBorder)),
                  child: const Text('Cancel', textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSub,
                          fontWeight: FontWeight.w600))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  await AuthService.logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (r) => false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.error.withOpacity(0.3))),
                  child: const Text('Log Out', textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.error,
                          fontWeight: FontWeight.w700))))),
            ]),
          ]))));
  }

  Widget _sectionTitle(String emoji, String title) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 18)),
    const SizedBox(width: 8),
    ShaderMask(
      shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
      child: Text(title, style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: Colors.white, fontFamily: 'Georgia'))),
  ]);

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ══════════════════════════════════════════
// LEADERBOARD SCREEN — unchanged from original
// ══════════════════════════════════════════

class _LeaderboardScreen extends StatefulWidget {
  const _LeaderboardScreen();
  @override
  State<_LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<_LeaderboardScreen> {
  List<Map<String, dynamic>> _board = [];
  int _myRank = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ProfileService.getLeaderboard();
      if (mounted) setState(() {
        _board = (res['leaderboard'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>).toList();
        _myRank = (res['myRank'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Failed to load leaderboard'; _loading = false;
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textSub, size: 20),
                onPressed: () => Navigator.pop(context)),
              Expanded(child: ShaderMask(
                shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
                child: const Text('Leaderboard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: Colors.white, fontFamily: 'Georgia'),
                  textAlign: TextAlign.center))),
              const SizedBox(width: 44),
            ])),
          Expanded(child: _loading
            ? const Center(child: ProfileSkeleton())
            : _error != null
              ? Center(child: buildErrorBanner(_error!))
              : _buildBoard()),
        ])),
      ]));
  }

  Widget _buildBoard() => RefreshIndicator(
    color: AppColors.violet, backgroundColor: AppColors.bgCard,
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      children: [
        if (_myRank > 0) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.violet.withOpacity(0.2),
                AppColors.cyan.withOpacity(0.1)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.violet.withOpacity(0.3))),
            child: Row(children: [
              const Text('📍', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text('Your rank: #$_myRank',
                style: const TextStyle(color: AppColors.textWhite,
                    fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              ShaderMask(
                shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
                child: const Text('Keep studying!',
                  style: TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w600))),
            ])),
          const SizedBox(height: 16),
        ],
        if (_board.length >= 3) ...[
          _buildPodium(), const SizedBox(height: 16)],
        ..._board.skip(3).map((u) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _leaderboardRow(u))),
      ]));

  Widget _buildPodium() {
    final top3 = _board.take(3).toList();
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: _podiumCard(top3[1], 2, 100)),
        const SizedBox(width: 8),
        Expanded(child: _podiumCard(top3[0], 1, 130)),
        const SizedBox(width: 8),
        Expanded(child: _podiumCard(top3[2], 3, 80)),
      ]));
  }

  Widget _podiumCard(Map<String, dynamic> user, int rank, double minH) {
    final isMe  = user['isMe'] as bool? ?? false;
    final name  = user['name'] as String? ?? '';
    final xp    = (user['xp'] as num?)?.toInt() ?? 0;
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';
    final color = rank == 1 ? AppColors.gold
        : rank == 2 ? const Color(0xFFB0C4DE)
        : const Color(0xFFCD7F32);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minH),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.violet.withOpacity(0.2) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe ? AppColors.violet : color.withOpacity(0.3),
            width: isMe ? 2 : 1)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(medal, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'S',
              style: TextStyle(color: color, fontSize: 14,
                  fontWeight: FontWeight.w800)))),
          const SizedBox(height: 4),
          Text(name.split(' ').first,
            style: const TextStyle(color: AppColors.textWhite,
                fontSize: 11, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
          Text('${_fmt(xp)} XP',
            style: TextStyle(color: color,
                fontSize: 10, fontWeight: FontWeight.w700)),
        ])));
  }

  Widget _leaderboardRow(Map<String, dynamic> user) {
    final rank  = (user['rank']  as num?)?.toInt() ?? 0;
    final name  = user['name']   as String? ?? '';
    final xp    = (user['xp']   as num?)?.toInt() ?? 0;
    final level = (user['level'] as num?)?.toInt() ?? 1;
    final isMe  = user['isMe']   as bool? ?? false;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMe ? AppColors.violet.withOpacity(0.1) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? AppColors.violet.withOpacity(0.4) : AppColors.inputBorder,
          width: isMe ? 1.5 : 1)),
      child: Row(children: [
        SizedBox(width: 32,
          child: Text('#$rank', style: TextStyle(
            color: rank <= 10 ? AppColors.gold : AppColors.textMuted,
            fontSize: 13, fontWeight: FontWeight.w700))),
        Container(width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: isMe ? AppColors.primaryGrad : null,
            color: isMe ? null : AppColors.inputBg,
            borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'S',
            style: TextStyle(
              color: isMe ? Colors.white : AppColors.textSub,
              fontSize: 14, fontWeight: FontWeight.w700)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(children: [
            Text(name, style: TextStyle(
              color: isMe ? AppColors.textWhite : AppColors.textLight,
              fontSize: 14, fontWeight: FontWeight.w600)),
            if (isMe) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(gradient: AppColors.primaryGrad,
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('You', style: TextStyle(color: Colors.white,
                    fontSize: 9, fontWeight: FontWeight.w700))),
            ],
          ]),
          Text('Level $level',
              style: AppTextStyles.label.copyWith(fontSize: 10)),
        ])),
        Text('${_fmt(xp)} XP',
          style: const TextStyle(color: AppColors.gold,
              fontSize: 13, fontWeight: FontWeight.w700)),
      ]));
  }

  String _fmt(int xp) {
    if (xp >= 1000) return '${(xp / 1000).toStringAsFixed(1)}k';
    return '$xp';
  }
}

// ══════════════════════════════════════════
// REUSABLE BOTTOM SHEET
// ══════════════════════════════════════════

class _BottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _BottomSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28), topRight: Radius.circular(28))),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.inputBorder,
              borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (b) => AppColors.primaryGrad.createShader(b),
          child: Text(title, style: const TextStyle(fontSize: 20,
              fontWeight: FontWeight.w800, color: Colors.white,
              fontFamily: 'Georgia'))),
        const SizedBox(height: 24),
        child,
      ]))));
}

// ── Helper ────────────────────────────────
SnackBar successSnackBar(String msg) => SnackBar(
  content: Row(children: [
    const Icon(Icons.check_circle_rounded, color: AppColors.success),
    const SizedBox(width: 10),
    Text(msg, style: const TextStyle(color: Colors.white)),
  ]),
  backgroundColor: AppColors.bgCard,
  behavior: SnackBarBehavior.floating,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  margin: const EdgeInsets.all(16));