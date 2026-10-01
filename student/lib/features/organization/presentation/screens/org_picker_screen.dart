import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/widgets/student_screen_kit.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/auth_navigation.dart';
import 'package:student_mobile/features/organization/data/organization_repository.dart';
import 'package:student_mobile/features/organization/domain/organization_summary.dart';

/// Named-route args for [OrgPickerScreen] (`AppRoutes.orgPicker`).
class OrgPickerArgs {
  const OrgPickerArgs({
    this.autoSelectSingle = true,
    this.allowBack = false,
    this.afterSelectRoute = AppRoutes.home,
    this.clearStackOnSelect = false,
  });

  final bool autoSelectSingle;
  final bool allowBack;
  final String afterSelectRoute;
  final bool clearStackOnSelect;

  factory OrgPickerArgs.fromObject(Object? raw) {
    if (raw is OrgPickerArgs) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return OrgPickerArgs(
        autoSelectSingle: map['autoSelectSingle'] != false &&
            map['auto_select_single'] != false,
        allowBack: map['allowBack'] == true || map['allow_back'] == true,
        afterSelectRoute: map['afterSelectRoute']?.toString() ??
            map['after_select_route']?.toString() ??
            AppRoutes.home,
        clearStackOnSelect: map['clearStackOnSelect'] == true ||
            map['clear_stack_on_select'] == true,
      );
    }
    return const OrgPickerArgs();
  }
}

/// S-05 Org / institute picker — choose active organization after sign-in.
class OrgPickerScreen extends StatefulWidget {
  const OrgPickerScreen({
    super.key,
    this.organizationRepository,
    this.autoSelectSingle = true,
    this.allowBack = false,
    this.afterSelectRoute = AppRoutes.home,
    this.clearStackOnSelect = false,
  });

  final OrganizationGateway? organizationRepository;
  final bool autoSelectSingle;
  final bool allowBack;
  final String afterSelectRoute;
  final bool clearStackOnSelect;

  factory OrgPickerScreen.fromArgs(OrgPickerArgs args) {
    return OrgPickerScreen(
      autoSelectSingle: args.autoSelectSingle,
      allowBack: args.allowBack,
      afterSelectRoute: args.afterSelectRoute,
      clearStackOnSelect: args.clearStackOnSelect,
    );
  }

  @override
  State<OrgPickerScreen> createState() => _OrgPickerScreenState();
}

class _OrgPickerScreenState extends State<OrgPickerScreen> {
  late final OrganizationGateway _orgs =
      widget.organizationRepository ?? OrganizationRepository();

  bool _loading = true;
  bool _selecting = false;
  String? _error;
  List<OrganizationSummary> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _orgs.listOrganizations();
      if (!mounted) return;

      if (items.length == 1 && widget.autoSelectSingle) {
        await _select(items.first, replace: true);
        return;
      }

      // Prefer previously selected org if still present — still show picker
      // when multiple so the student can confirm/switch.
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load institutes. Pull to retry.';
        _loading = false;
      });
      assert(() {
        // ignore: avoid_print
        print('org_picker load failed: $error');
        return true;
      }());
    }
  }

  Future<void> _select(
    OrganizationSummary organization, {
    required bool replace,
  }) async {
    if (_selecting) return;
    setState(() => _selecting = true);
    try {
      await _orgs.selectOrganization(organization);
      if (!mounted) return;
      final route = widget.afterSelectRoute;
      AuthNavigation.goAndClear(context, route);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selecting = false;
        _error = 'Could not save institute selection. Try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: StudentHubPage(
        title: 'Choose institute',
        showBack: widget.allowBack,
        onBack: widget.allowBack
            ? () => Navigator.of(context).maybePop()
            : null,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading || _selecting) {
      return const AppLoadingState(padding: EdgeInsets.zero);
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: AppErrorState(
          message: _error!,
          onRetry: _load,
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.school_outlined,
          title: 'Set up your learning space',
          message:
              'Join an organisation with a code, or continue as an Individual '
              'learner on Pragyu.',
          actionLabel: 'Continue',
          onAction: () => AuthNavigation.goAndClear(
            context,
            AppRoutes.orgAssociation,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: StudentHubColors.blue,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        children: [
          const Text(
            'Select where you want to continue learning.',
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: StudentHubColors.muted,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: StudentHubColors.danger,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 20),
          for (final org in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: StudentHubColors.surface,
                borderRadius:
                    BorderRadius.circular(StudentHubColors.cardRadius),
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(StudentHubColors.cardRadius),
                  onTap: () => _select(org, replace: false),
                  child: Ink(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        StudentHubColors.cardRadius,
                      ),
                      border: Border.all(color: StudentHubColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: StudentHubColors.blueSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            org.name.isNotEmpty
                                ? org.name[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              color: StudentHubColors.blue,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                org.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: StudentHubColors.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  org.typeLabel,
                                  if (org.status != null &&
                                      org.status!.isNotEmpty)
                                    org.status,
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: StudentHubColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: StudentHubColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
