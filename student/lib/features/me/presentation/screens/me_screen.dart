import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/app_network_image.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/alerts/data/alerts_repository.dart';
import 'package:student_mobile/features/catalog/data/marketplace_access_service.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/me/data/me_repository.dart';
import 'package:student_mobile/features/me/domain/me_models.dart';
import 'package:student_mobile/features/organization/presentation/screens/org_picker_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// S-70 Me — profile summary, preferences, institute switch, sign out.
class MeScreen extends StatefulWidget {
  const MeScreen({
    super.key,
    this.meRepository,
    this.homeRepository,
    this.alertsRepository,
  });

  final MeGateway? meRepository;
  final HomeGateway? homeRepository;
  final AlertsGateway? alertsRepository;

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  static const _ink = Color(0xFF1A2B4C);
  static const _muted = Color(0xFF7A8499);
  static const _blue = Color(0xFF2F7BFF);
  static const _pageBg = Color(0xFFF8FAFD);
  static const _danger = Color(0xFFD64545);

  late final MeGateway _me = widget.meRepository ?? MeRepository();
  late final HomeGateway _home = widget.homeRepository ?? HomeRepository();
  late final AlertsGateway _alerts =
      widget.alertsRepository ?? AlertsRepository();
  final MarketplaceAccessService _marketplace =
      MarketplaceAccessService.instance;

  bool _loading = true;
  bool _savingHours = false;
  bool _savingProfile = false;
  bool _signingOut = false;
  String? _error;
  MeSnapshot? _snapshot;
  HomeProgressSummary _progress = const HomeProgressSummary();
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _marketplace.addListener(_onMarketplaceChanged);
    _marketplace.ensureLoaded();
    _load();
  }

  @override
  void dispose() {
    _marketplace.removeListener(_onMarketplaceChanged);
    super.dispose();
  }

  void _onMarketplaceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Marketplace is non-blocking for Me profile.
      unawaited(_marketplace.ensureLoaded(force: true));
      final snapshot = await _me.loadMe();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadExtras();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to load profile. Pull to retry.';
      });
    }
  }

  Future<void> _loadExtras() async {
    try {
      final home = await _home.loadHome();
      if (!mounted) return;
      setState(() => _progress = home.progressOrEmpty);
    } catch (_) {}
    try {
      final unread = await _alerts.unreadCount();
      if (!mounted) return;
      setState(() => _unread = unread < 0 ? 0 : unread);
    } catch (_) {}
  }

  Future<void> _saveStudyHours(double hours) async {
    final snapshot = _snapshot;
    final profileId = snapshot?.studentProfile?.id;
    if (snapshot == null || profileId == null || profileId.isEmpty) return;
    setState(() {
      _savingHours = true;
      _snapshot = snapshot.copyWith(dailyStudyHours: hours);
    });
    try {
      await _me.setDailyStudyHours(
        studentProfileId: profileId,
        hours: hours,
      );
      if (!mounted) return;
      setState(() => _savingHours = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingHours = false;
        _snapshot = snapshot;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save study hours.")),
      );
    }
  }

  Future<void> _editProfile() async {
    final snapshot = _snapshot;
    if (snapshot == null || _savingProfile) return;

    final nameController = TextEditingController(text: snapshot.displayName);
    final phoneController = TextEditingController(
      text: snapshot.userProfile?.phone ?? '',
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Edit profile',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) return;
                  Navigator.of(context).pop(true);
                },
                style: FilledButton.styleFrom(backgroundColor: _blue),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      phoneController.dispose();
    });

    if (saved != true || !mounted) return;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name is required.')),
      );
      return;
    }

    setState(() => _savingProfile = true);
    try {
      final updated = await _me.updateProfile(
        displayName: name,
        phone: phone,
      );
      if (!mounted) return;
      setState(() {
        _savingProfile = false;
        _snapshot = snapshot.copyWith(userProfile: updated);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingProfile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : "Couldn't update profile.",
          ),
        ),
      );
    }
  }

  Future<void> _switchInstitute() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const OrgPickerScreen(
          autoSelectSingle: false,
          allowBack: true,
          afterSelectRoute: AppRoutes.home,
          clearStackOnSelect: true,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _ratePragyu() async {
    final config = AppConfig.instance;
    final url = Theme.of(context).platform == TargetPlatform.iOS
        ? (config.iosStoreUrl ?? config.androidStoreUrl)
        : (config.androidStoreUrl ?? config.iosStoreUrl);
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Store listing URL is not configured yet. Thanks for supporting Pragyu!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the store page.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text(
          "You'll need to sign in again to access your courses and tests.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await _me.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.welcome,
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't log out. Try again.")),
      );
    }
  }

  void _openTab(int index) => StudentShell.of(context)?.goToTab(index);

  String get _initials {
    final name = _snapshot?.displayName.trim() ?? '';
    if (name.isEmpty) return 'Me';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? 'Me' : letters;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          child: Column(
            children: [
              _ProfileHeader(
                unread: _unread,
                onAlerts: () =>
                    Navigator.of(context).pushNamed(AppRoutes.alerts),
                onSettings: () =>
                    Navigator.of(context).pushNamed(AppRoutes.settings),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: _blue,
                  onRefresh: _load,
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _snapshot == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const SizedBox(height: 120),
          const Center(child: CircularProgressIndicator(color: _blue)),
          const SizedBox(height: 48),
          _LogoutButton(signingOut: _signingOut, onPressed: _signOut),
        ],
      );
    }

    if (_error != null && _snapshot == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
        children: [
          Text(
            _error!,
            softWrap: true,
            style: const TextStyle(color: _danger, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(backgroundColor: _blue),
            child: const Text('Retry'),
          ),
          const SizedBox(height: 28),
          _LogoutButton(signingOut: _signingOut, onPressed: _signOut),
        ],
      );
    }

    final snapshot = _snapshot!;
    final profile = snapshot.studentProfile;
    final hoursLabel = snapshot.dailyStudyHours ==
            snapshot.dailyStudyHours.roundToDouble()
        ? snapshot.dailyStudyHours.round().toString()
        : snapshot.dailyStudyHours.toStringAsFixed(1);
    final codeStatus = [
      if (profile?.studentCode != null && profile!.studentCode!.isNotEmpty)
        profile.studentCode!,
      if (profile?.status != null && profile!.status!.isNotEmpty)
        profile.status!,
    ].join(' · ');
    final score = _progress.averageScorePercent ?? _progress.overallPercent;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        const Text(
          'Me',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _muted,
            letterSpacing: 0.4,
          ),
        ),
        if (_error != null) ...[
          Text(
            _error!,
            softWrap: true,
            style: const TextStyle(color: _danger, height: 1.4),
          ),
          const SizedBox(height: 12),
        ],
        _ProfileBanner(
          name: snapshot.displayName,
          email: snapshot.user.email,
          phone: snapshot.userProfile?.phone,
          organizationName: snapshot.contextTitle,
          contextLabel: snapshot.contextSubtitle,
          codeStatus: codeStatus,
          initials: _initials,
          avatarUrl: snapshot.userProfile?.avatarUrl,
          saving: _savingProfile,
          onEdit: _editProfile,
        ),
        const SizedBox(height: 14),
        _StatsRow(
          courses: _progress.coursesEnrolled,
          tests: _progress.testsAttempted,
          scorePercent: score,
          learningHours: snapshot.dailyStudyHours.round(),
        ),
        const SizedBox(height: 14),
        if (_marketplace.available) ...[
          _UpgradeBanner(
            onUpgrade: () =>
                Navigator.of(context).pushNamed(AppRoutes.catalog),
          ),
          const SizedBox(height: 18),
        ] else
          const SizedBox(height: 4),
        _SectionTitle(
          title: 'My Learning',
          action: 'View All',
          onAction: () => _openTab(1),
        ),
        const SizedBox(height: 10),
        _LearningShortcuts(
          onCourses: () => _openTab(1),
          onTests: () => _openTab(2),
          onNotes: () =>
              Navigator.of(context).pushNamed(AppRoutes.notesBookmarks),
          onMarketplace: _marketplace.available
              ? () => Navigator.of(context).pushNamed(AppRoutes.catalog)
              : null,
        ),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Account & Settings'),
        const SizedBox(height: 10),
        _MenuCard(
          children: [
            _MenuTile(
              icon: Icons.person_outline_rounded,
              tint: _blue,
              soft: const Color(0xFFE8F0FF),
              title: 'Edit Profile',
              subtitle: 'Update your personal information',
              onTap: _editProfile,
              trailing: TextButton(
                onPressed: _savingProfile ? null : _editProfile,
                child: const Text('Edit'),
              ),
            ),
            _MenuTile(
              icon: Icons.notifications_none_rounded,
              tint: const Color(0xFFE85D75),
              soft: const Color(0xFFFFEEF1),
              title: 'Notification preferences',
              subtitle: 'Manage your notification preferences',
              onTap: () => Navigator.of(context)
                  .pushNamed(AppRoutes.notificationPreferences),
            ),
            _MenuTile(
              icon: Icons.settings_outlined,
              tint: const Color(0xFF22A06B),
              soft: const Color(0xFFE8F8F0),
              title: 'App Settings',
              subtitle: 'Theme, language and app preferences',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.settings),
            ),
            _MenuTile(
              icon: Icons.help_outline_rounded,
              tint: const Color(0xFFF08A3C),
              soft: const Color(0xFFFFF2E8),
              title: 'Help & About',
              subtitle: 'Get help or contact us',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.helpAbout),
              showDivider: false,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _StudyHoursCard(
          hoursLabel: hoursLabel,
          value: snapshot.dailyStudyHours.clamp(0, 16),
          saving: _savingHours,
          enabled: profile != null && !_savingHours,
          onChanged: (value) {
            setState(() {
              _snapshot = snapshot.copyWith(dailyStudyHours: value);
            });
          },
          onChangeEnd: _saveStudyHours,
        ),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'More'),
        const SizedBox(height: 10),
        _MenuCard(
          children: [
            _MenuTile(
              icon: Icons.auto_awesome,
              tint: const Color(0xFF7B61FF),
              soft: const Color(0xFFF0EBFF),
              title: 'AI Mentor',
              subtitle: 'Ask doubts and get study guidance',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.aiMentor),
            ),
            _MenuTile(
              icon: Icons.insights_outlined,
              tint: _blue,
              soft: const Color(0xFFE8F0FF),
              title: 'My Performance',
              subtitle: 'Scores, streak, and subject analytics',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.performance),
            ),
            _MenuTile(
              icon: Icons.trending_down_rounded,
              tint: const Color(0xFFE85D75),
              soft: const Color(0xFFFFEEF1),
              title: 'Weak Topics',
              subtitle: 'Focus areas that need practice',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.weakTopics),
            ),
            _MenuTile(
              icon: Icons.calendar_month_outlined,
              tint: const Color(0xFF2F7BFF),
              soft: const Color(0xFFE8F1FF),
              title: 'Calendar',
              subtitle: 'Live classes and test deadlines',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.calendar),
            ),
            _MenuTile(
              icon: Icons.event_note_outlined,
              tint: const Color(0xFF22A06B),
              soft: const Color(0xFFE8F8F0),
              title: 'Study Planner',
              subtitle: 'Weekly plans and goals',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.studyPlanner),
            ),
            _MenuTile(
              icon: Icons.lightbulb_outline_rounded,
              tint: const Color(0xFFF08A3C),
              soft: const Color(0xFFFFF2E8),
              title: 'Recommendations',
              subtitle: 'AI next actions for you',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.recommendations),
            ),
            _MenuTile(
              icon: Icons.dashboard_customize_outlined,
              tint: const Color(0xFF7B61FF),
              soft: const Color(0xFFF0EBFF),
              title: 'Exam Workspace',
              subtitle: 'Pattern-aware practice hub',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.examWorkspace),
            ),
            _MenuTile(
              icon: Icons.quiz_outlined,
              tint: const Color(0xFF2F7BFF),
              soft: const Color(0xFFE8F1FF),
              title: 'Exam Series',
              subtitle: 'Packs, mocks, and question banks',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.examSeries),
            ),
            _MenuTile(
              icon: Icons.fact_check_outlined,
              tint: const Color(0xFF22A06B),
              soft: const Color(0xFFE8F8F0),
              title: 'Attendance',
              subtitle: 'Present, absent, and late marks',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.attendance),
            ),
            _MenuTile(
              icon: Icons.menu_book_outlined,
              tint: _blue,
              soft: const Color(0xFFE8F0FF),
              title: 'Tutorials',
              subtitle: 'Guides and how-to articles',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.tutorials),
            ),
            _MenuTile(
              icon: Icons.payments_outlined,
              tint: const Color(0xFF22A06B),
              soft: const Color(0xFFE8F8F0),
              title: 'Payments',
              subtitle: 'Fees, invoices, and AI Balance',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.payments),
            ),
            _MenuTile(
              icon: Icons.campaign_outlined,
              tint: const Color(0xFFF08A3C),
              soft: const Color(0xFFFFF2E8),
              title: 'Announcements',
              subtitle: 'Institute and course notices',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.announcements),
            ),
            _MenuTile(
              icon: Icons.apartment_outlined,
              tint: const Color(0xFF7B61FF),
              soft: const Color(0xFFF0EBFF),
              title: snapshot.isIndividualWorkspace
                  ? 'Join organisation'
                  : 'Switch organisation',
              subtitle: snapshot.isIndividualWorkspace
                  ? 'Enter an organisation code'
                  : (snapshot.organizationName?.isNotEmpty == true
                      ? snapshot.organizationName!
                      : 'Choose another academy'),
              onTap: snapshot.isIndividualWorkspace
                  ? () => Navigator.of(context).pushNamed(AppRoutes.orgCodeEntry)
                  : _switchInstitute,
            ),
            _MenuTile(
              icon: Icons.star_outline_rounded,
              tint: const Color(0xFFF5A623),
              soft: const Color(0xFFFFF6E5),
              title: 'Rate Pragyu',
              subtitle: 'Share your feedback',
              onTap: _ratePragyu,
            ),
            _MenuTile(
              icon: Icons.info_outline_rounded,
              tint: _blue,
              soft: const Color(0xFFE8F0FF),
              title: 'About Pragyu',
              subtitle: 'Our mission, vision and version info',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.helpAbout),
              showDivider: false,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _LogoutButton(signingOut: _signingOut, onPressed: _signOut),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.unread,
    required this.onAlerts,
    required this.onSettings,
  });

  final int unread;
  final VoidCallback onAlerts;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final badge = unread > 99 ? '99+' : '$unread';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PragyuLogo(height: PragyuLogo.headerHeight, semanticsLabel: 'Pragyu'),
                SizedBox(height: 2),
                Text(
                  'Learn • Practice • Grow',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: _MeScreenState._muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Alerts',
                onPressed: onAlerts,
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: _MeScreenState._ink,
                ),
              ),
              if (unread > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: const Icon(
              Icons.settings_outlined,
              color: _MeScreenState._ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({
    required this.name,
    required this.email,
    required this.initials,
    required this.saving,
    required this.onEdit,
    this.phone,
    this.organizationName,
    this.contextLabel,
    this.codeStatus = '',
    this.avatarUrl,
  });

  final String name;
  final String email;
  final String? phone;
  final String? organizationName;
  final String? contextLabel;
  final String codeStatus;
  final String initials;
  final String? avatarUrl;
  final bool saving;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final url = avatarUrl?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _MeScreenState._blue, width: 2),
                    ),
                    child: ClipOval(
                      child: url != null && url.isNotEmpty
                          ? AppNetworkImage(url: url, fit: BoxFit.cover)
                          : _InitialAvatar(initials: initials),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: _MeScreenState._blue,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: saving ? null : onEdit,
                        child: const SizedBox(
                          width: 26,
                          height: 26,
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _MeScreenState._ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: _MeScreenState._muted,
                      ),
                    ),
                    if (phone != null && phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        phone!,
                        softWrap: true,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _MeScreenState._muted,
                        ),
                      ),
                    ],
                    if (organizationName != null &&
                        organizationName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        organizationName!,
                        softWrap: true,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: _MeScreenState._muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (contextLabel != null &&
                          contextLabel!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          contextLabel!,
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _MeScreenState._blue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                    if (codeStatus.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        codeStatus,
                        softWrap: true,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _MeScreenState._muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Text(
                      'Aspiring for a better tomorrow 🚀',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _MeScreenState._ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Student',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _MeScreenState._blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!narrow) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE8F3FF), Color(0xFFDCEEFF)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      '“Discipline today, success tomorrow.” 🌱',
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        height: 1.35,
                        color: _MeScreenState._ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _MeScreenState._ink,
      alignment: Alignment.center,
      child: Text(
        initials.length > 2 ? initials.substring(0, 2) : initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.courses,
    required this.tests,
    required this.scorePercent,
    required this.learningHours,
  });

  final int courses;
  final int tests;
  final int scorePercent;
  final int learningHours;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.school_outlined,
        const Color(0xFF22A06B),
        const Color(0xFFE8F8F0),
        '$courses',
        'Enrolled Courses',
      ),
      (
        Icons.track_changes_outlined,
        const Color(0xFF7B61FF),
        const Color(0xFFF0EBFF),
        '$tests',
        'Tests Attempted',
      ),
      (
        Icons.bar_chart_rounded,
        const Color(0xFFF08A3C),
        const Color(0xFFFFF2E8),
        '$scorePercent%',
        'Average Score',
      ),
      (
        Icons.schedule_rounded,
        _MeScreenState._blue,
        const Color(0xFFE8F0FF),
        '$learningHours',
        'Learning Hours',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxWidth < 360;
        if (tight) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: _StatCard(
                    icon: item.$1,
                    tint: item.$2,
                    soft: item.$3,
                    value: item.$4,
                    label: item.$5,
                  ),
                ),
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: items[i].$1,
                  tint: items[i].$2,
                  soft: items[i].$3,
                  value: items[i].$4,
                  label: items[i].$5,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.tint,
    required this.soft,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color tint;
  final Color soft;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: tint, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: _MeScreenState._ink,
            ),
          ),
          Text(
            label,
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10.5,
              height: 1.2,
              color: _MeScreenState._muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  const _UpgradeBanner({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3EEFF), Color(0xFFFFEEF5)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE4D7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFF7B61FF),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Pragyu Plus',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF5B3FA0),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Get unlimited access to premium courses, test series and AI mentor.',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    height: 1.3,
                    color: Color(0xFF7A6AA8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onUpgrade,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7B61FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Upgrade Now',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                SizedBox(width: 2),
                Icon(Icons.arrow_forward_rounded, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            softWrap: true,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _MeScreenState._ink,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: _MeScreenState._blue,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

class _LearningShortcuts extends StatelessWidget {
  const _LearningShortcuts({
    required this.onCourses,
    required this.onTests,
    required this.onNotes,
    this.onMarketplace,
  });

  final VoidCallback onCourses;
  final VoidCallback onTests;
  final VoidCallback onNotes;
  final VoidCallback? onMarketplace;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'My Courses',
        'Continue learning',
        Icons.menu_book_outlined,
        _MeScreenState._blue,
        const Color(0xFFE8F0FF),
        onCourses,
      ),
      (
        'My Tests',
        'View performance',
        Icons.assignment_outlined,
        const Color(0xFF22A06B),
        const Color(0xFFE8F8F0),
        onTests,
      ),
      (
        'Notes & Bookmarks',
        'Saved notes and items',
        Icons.bookmark_border_rounded,
        const Color(0xFFF08A3C),
        const Color(0xFFFFF2E8),
        onNotes,
      ),
      if (onMarketplace != null)
        (
          'Browse marketplace',
          'Courses and packs',
          Icons.storefront_outlined,
          const Color(0xFF7B61FF),
          const Color(0xFFF0EBFF),
          onMarketplace!,
        ),
    ];

    return SizedBox(
      height: 108,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) const SizedBox(width: 10),
              Builder(
                builder: (context) {
                  final item = items[index];
                  return InkWell(
                    onTap: item.$6,
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      width: 118,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      decoration: BoxDecoration(
                        color: item.$5,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(item.$3, color: item.$4, size: 22),
                          const SizedBox(height: 18),
                          Text(
                            item.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: _MeScreenState._ink,
                            ),
                          ),
                          Text(
                            item.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: _MeScreenState._muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6EAF2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(children: children),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.tint,
    required this.soft,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.showDivider = true,
  });

  final IconData icon;
  final Color tint;
  final Color soft;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 2),
          onTap: onTap,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          title: Text(
            title,
            softWrap: true,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              color: _MeScreenState._ink,
              fontSize: 14.5,
            ),
          ),
          subtitle: Text(
            subtitle,
            softWrap: true,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: _MeScreenState._muted,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
          trailing: trailing ??
              const Icon(
                Icons.chevron_right_rounded,
                color: _MeScreenState._muted,
              ),
        ),
        if (showDivider) const Divider(height: 1, color: Color(0xFFF0F2F7)),
      ],
    );
  }
}

class _StudyHoursCard extends StatelessWidget {
  const _StudyHoursCard({
    required this.hoursLabel,
    required this.value,
    required this.saving,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String hoursLabel;
  final double value;
  final bool saving;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Daily study hours',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    color: _MeScreenState._ink,
                  ),
                ),
              ),
              if (saving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _MeScreenState._blue,
                  ),
                )
              else
                Text(
                  hoursLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _MeScreenState._blue,
                    fontSize: 18,
                  ),
                ),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: 16,
            divisions: 32,
            activeColor: _MeScreenState._blue,
            label: hoursLabel,
            onChanged: enabled ? onChanged : null,
            onChangeEnd: enabled ? onChangeEnd : null,
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({
    required this.signingOut,
    required this.onPressed,
  });

  final bool signingOut;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: signingOut ? null : onPressed,
        icon: Icon(
          Icons.logout_rounded,
          color: signingOut ? _MeScreenState._muted : _MeScreenState._danger,
        ),
        label: Text(
          signingOut ? 'Logging out…' : 'Logout',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: signingOut ? _MeScreenState._muted : _MeScreenState._danger,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFFFF1F1),
          side: BorderSide(
            color: signingOut
                ? _MeScreenState._muted.withValues(alpha: 0.4)
                : const Color(0xFFFFD0D0),
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
