import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/widgets/student_screen_kit.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/auth_navigation.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/organization/data/organization_repository.dart';

/// First-time association: organisation code vs continue as Individual.
class OrgAssociationScreen extends StatefulWidget {
  const OrgAssociationScreen({
    super.key,
    this.organizationRepository,
    this.sessionService,
  });

  final OrganizationGateway? organizationRepository;
  final SessionService? sessionService;

  @override
  State<OrgAssociationScreen> createState() => _OrgAssociationScreenState();
}

class _OrgAssociationScreenState extends State<OrgAssociationScreen> {
  late final OrganizationGateway _orgs =
      widget.organizationRepository ?? OrganizationRepository();
  late final SessionService _session =
      widget.sessionService ?? SessionService();

  bool _creatingIndividual = false;
  String? _error;

  Future<void> _continueAsIndividual() async {
    if (_creatingIndividual) return;
    setState(() {
      _creatingIndividual = true;
      _error = null;
    });

    try {
      final cached = await _session.readCachedUser();
      final displayName = [
        cached?.firstName,
        cached?.lastName,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
      final userId = cached?.id ?? 'student';

      final workspace = await _orgs.ensureIndividualWorkspace(
        displayName: displayName.isEmpty ? 'Student' : displayName,
        userId: userId,
      );
      await _orgs.selectOrganization(workspace);
      if (!mounted) return;
      await AuthNavigation.goToResolvedWorkspace(context);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _creatingIndividual = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not open Individual learning. Please try again.';
        _creatingIndividual = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: StudentHubColors.pageBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome to Pragyu',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: StudentHubColors.ink,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Are you associated with an organisation?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: StudentHubColors.ink,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Organisation students learn inside their academy. '
                  'Individual students get Pragyu’s public marketplace and courses.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: StudentHubColors.muted,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 28),
                _ChoiceCard(
                  icon: Icons.apartment_outlined,
                  title: 'Yes, I have an organisation code',
                  subtitle: 'Join your academy or coaching institute',
                  onTap: _creatingIndividual
                      ? null
                      : () => Navigator.of(context)
                          .pushNamed(AppRoutes.orgCodeEntry),
                ),
                const SizedBox(height: 14),
                _ChoiceCard(
                  icon: Icons.person_outline,
                  title: 'No, continue as Individual',
                  subtitle: 'Marketplace, public courses, and exam series',
                  onTap: _creatingIndividual ? null : _continueAsIndividual,
                  loading: _creatingIndividual,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: StudentHubColors.danger,
                      height: 1.4,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  'You can join an organisation later with a code if your plans change.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: StudentHubColors.muted,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudentHubColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: StudentHubColors.blueSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon, color: StudentHubColors.blue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: StudentHubColors.ink,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: StudentHubColors.muted,
                        height: 1.35,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: StudentHubColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
