import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/app/widgets/pragyu_logo.dart';
import 'package:student_mobile/app/widgets/student_screen_kit.dart';
import 'package:student_mobile/core/config/app_config.dart';

/// S-77 Help & About — version, support, legal links.
class HelpAboutScreen extends StatefulWidget {
  const HelpAboutScreen({super.key});

  @override
  State<HelpAboutScreen> createState() => _HelpAboutScreenState();
}

class _HelpAboutScreenState extends State<HelpAboutScreen> {
  String _versionLabel = '…';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionLabel = '${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _versionLabel = '1.0.0');
    }
  }

  Future<void> _openUrl(String? url) async {
    final raw = url?.trim() ?? '';
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      _toast('Invalid link.');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      _toast('Could not open link.');
    }
  }

  Future<void> _emailSupport() async {
    final email = AppConfig.instance.supportEmail?.trim() ?? '';
    if (email.isEmpty) return;
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'Pragyu Student app help'},
    );
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      _toast('Could not open email app.');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.instance;
    final supportEmail = config.supportEmail?.trim() ?? '';
    final privacyUrl = config.privacyUrl?.trim() ?? '';
    final termsUrl = config.termsUrl?.trim() ?? '';
    final hasSupport = supportEmail.isNotEmpty;
    final hasPrivacy = privacyUrl.isNotEmpty;
    final hasTerms = termsUrl.isNotEmpty;
    final hasSupportSection = hasSupport || hasPrivacy || hasTerms;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: StudentHubPage(
        title: 'Help & About',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            _AboutHero(
              appName: config.appName,
              versionLabel: _versionLabel,
            ),
            if (hasSupportSection) ...[
              const SizedBox(height: 18),
              const StudentSectionHeader(title: 'Support & legal'),
              const SizedBox(height: 10),
              if (hasSupport) ...[
                _LinkTile(
                  icon: Icons.mail_outline_rounded,
                  tint: StudentHubColors.blue,
                  soft: StudentHubColors.blueSoft,
                  title: 'Contact support',
                  subtitle: supportEmail,
                  trailing: Icons.chevron_right_rounded,
                  onTap: _emailSupport,
                ),
                if (hasPrivacy || hasTerms) const SizedBox(height: 10),
              ],
              if (hasPrivacy) ...[
                _LinkTile(
                  icon: Icons.privacy_tip_outlined,
                  tint: const Color(0xFF7B61FF),
                  soft: const Color(0xFFF0EBFF),
                  title: 'Privacy policy',
                  subtitle: 'How we handle your data',
                  trailing: Icons.open_in_new_rounded,
                  onTap: () => _openUrl(privacyUrl),
                ),
                if (hasTerms) const SizedBox(height: 10),
              ],
              if (hasTerms)
                _LinkTile(
                  icon: Icons.description_outlined,
                  tint: const Color(0xFF22A06B),
                  soft: const Color(0xFFE8F8F0),
                  title: 'Terms of use',
                  subtitle: 'Rules for using Pragyu',
                  trailing: Icons.open_in_new_rounded,
                  onTap: () => _openUrl(termsUrl),
                ),
            ],
            const SizedBox(height: 18),
            const Text(
              'For course, fee, or account questions, contact your institute admin.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                height: 1.4,
                color: StudentHubColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero({
    required this.appName,
    required this.versionLabel,
  });

  final String appName;
  final String versionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
        border: Border.all(color: StudentHubColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StudentHubColors.blueSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const PragyuLogo(
              height: 36,
              semanticsLabel: 'Pragyu',
            ),
          ),
          const SizedBox(height: 14),
          Text(
            appName,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: StudentHubColors.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: StudentHubColors.pageBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: StudentHubColors.border),
            ),
            child: Text(
              'Version $versionLabel',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: StudentHubColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'For course, fee, or account questions, contact your institute admin. '
            'Use the options below for app support and legal information.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: StudentHubColors.muted,
              height: 1.4,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.tint,
    required this.soft,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color soft;
  final String title;
  final String subtitle;
  final IconData trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StudentHubColors.cardRadius),
            border: Border.all(color: StudentHubColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tint, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: StudentHubColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        height: 1.35,
                        color: StudentHubColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(trailing, size: 18, color: StudentHubColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
