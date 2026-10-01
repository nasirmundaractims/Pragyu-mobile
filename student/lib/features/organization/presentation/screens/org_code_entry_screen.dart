import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/widgets/student_screen_kit.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/auth_navigation.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/organization/data/organization_repository.dart';
import 'package:student_mobile/features/organization/domain/organization_membership_models.dart';

/// Enter and redeem an organisation membership code.
class OrgCodeEntryScreen extends StatefulWidget {
  const OrgCodeEntryScreen({
    super.key,
    this.organizationRepository,
    this.sessionService,
  });

  final OrganizationGateway? organizationRepository;
  final SessionService? sessionService;

  @override
  State<OrgCodeEntryScreen> createState() => _OrgCodeEntryScreenState();
}

class _OrgCodeEntryScreenState extends State<OrgCodeEntryScreen> {
  late final OrganizationGateway _orgs =
      widget.organizationRepository ?? OrganizationRepository();
  late final SessionService _session =
      widget.sessionService ?? SessionService();
  final _codeController = TextEditingController();

  bool _submitting = false;
  bool _creatingIndividual = false;
  String? _error;
  OrganizationMembershipPreview? _preview;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the organisation code you received.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _preview = null;
    });

    try {
      final preview = await _orgs.lookupMembershipCode(code);
      if (!mounted) return;
      setState(() => _preview = preview);

      final redeemed = await _orgs.redeemMembershipCode(code);
      await _orgs.selectOrganization(redeemed.toOrganizationSummary());
      if (!mounted) return;
      await AuthNavigation.goToResolvedWorkspace(context);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Could not join with that code. Check your connection and try again.';
        _submitting = false;
      });
    }
  }

  Future<void> _continueAsIndividual() async {
    if (_creatingIndividual || _submitting) return;
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
    final busy = _submitting || _creatingIndividual;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: StudentHubPage(
        title: 'Enter organisation code',
        body: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ask your academy for their organisation code, then enter it below.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: StudentHubColors.muted,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _codeController,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Organisation code',
                    hintText: 'ABCD-EFGH',
                  ),
                  onSubmitted: (_) => busy ? null : _submit(),
                ),
                if (_preview != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Joining ${_preview!.organizationName}',
                    style: const TextStyle(
                      color: StudentHubColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: StudentHubColors.danger,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  label: _submitting ? 'Joining…' : 'Join organisation',
                  onPressed: busy ? null : _submit,
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: _creatingIndividual
                      ? 'Opening Individual…'
                      : 'Continue as Individual instead',
                  onPressed: busy ? null : _continueAsIndividual,
                ),
              ],
            ),
          ),
      ),
    );
  }
}
