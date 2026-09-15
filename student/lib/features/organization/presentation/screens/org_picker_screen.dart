import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_colors.dart';
import 'package:student_mobile/app/widgets/primary_button.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/organization/data/organization_repository.dart';
import 'package:student_mobile/features/organization/domain/organization_summary.dart';

/// S-05 Org / institute picker — choose active organization after sign-in.
class OrgPickerScreen extends StatefulWidget {
  const OrgPickerScreen({
    super.key,
    this.organizationRepository,
    this.autoSelectSingle = true,
  });

  final OrganizationGateway? organizationRepository;
  final bool autoSelectSingle;

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
      if (replace) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.onboarding,
          (route) => false,
        );
      }
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
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Choose institute'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading || _selecting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.brand),
            SizedBox(height: 16),
            Text(
              'Loading your institutes…',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    if (_error != null && _items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Try again', onPressed: _load),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No institute yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Your account is signed in, but it is not linked to an institute '
              'or learning workspace yet. Ask your institute admin to invite you, '
              'then try again.',
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        children: [
          const Text(
            'Select where you want to continue learning.',
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: AppColors.muted,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          ..._items.map((org) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _select(org, replace: false),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.brandSoft),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.brandSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            org.name.isNotEmpty
                                ? org.name[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              color: AppColors.brand,
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
                                  color: AppColors.ink,
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
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
