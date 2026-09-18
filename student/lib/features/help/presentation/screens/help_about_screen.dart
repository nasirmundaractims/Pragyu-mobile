import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:student_mobile/app/theme/app_colors.dart';
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
    if (raw.isEmpty) {
      _toast('Link is not configured for this build.');
      return;
    }
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
    if (email.isEmpty) {
      _toast('Support email is not configured for this build.');
      return;
    }
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.instance;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Help & About'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.brandSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.appName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Version $_versionLabel',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'For course, fee, or account questions, contact your institute admin. '
                        'Use the options below for app support and legal information.',
                        style: TextStyle(
                          color: AppColors.muted,
                          height: 1.4,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.brandSoft),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.mail_outline,
                          color: AppColors.brand,
                        ),
                        title: const Text(
                          'Contact support',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        subtitle: Text(
                          config.supportEmail ?? 'Not configured',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _emailSupport,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.privacy_tip_outlined,
                          color: AppColors.brand,
                        ),
                        title: const Text(
                          'Privacy policy',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                        onTap: () => _openUrl(config.privacyUrl),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.description_outlined,
                          color: AppColors.brand,
                        ),
                        title: const Text(
                          'Terms of use',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                        onTap: () => _openUrl(config.termsUrl),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
