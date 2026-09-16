import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/exam_series/domain/exam_series_models.dart';
import 'package:student_mobile/features/organization/data/organization_repository.dart';
import 'package:student_mobile/features/organization/domain/organization_summary.dart';

abstract class ExamSeriesGateway {
  Future<ExamSeriesHubSnapshot> loadHub();
  Future<ExamSeriesDetailSnapshot> loadDetail(ExamSeriesDetailArgs args);
  Future<void> ensureSellerWorkspace(ExamSeriesPack pack);
}

class ExamSeriesRepository implements ExamSeriesGateway {
  ExamSeriesRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
    OrganizationGateway? organizationGateway,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService(),
        _orgs = organizationGateway ?? OrganizationRepository();

  final ApiClient _api;
  final SessionService _session;
  final OrganizationGateway _orgs;

  @override
  Future<ExamSeriesHubSnapshot> loadHub() async {
    final session = await _requireSession();
    final across = await _listPacks(session, '/exam-series/mine-across');
    if (across.isNotEmpty) {
      return ExamSeriesHubSnapshot(
        packs: across,
        activeOrganizationId: session.organizationId,
      );
    }

    final mine = await _listPacks(session, '/exam-series/me');
    final orgName = await _activeOrgName();
    final packs = mine
        .map(
          (pack) => ExamSeriesPack(
            id: pack.id,
            title: pack.title,
            description: pack.description,
            itemCount: pack.itemCount,
            items: pack.items,
            organizationId: pack.organizationId ?? session.organizationId,
            organizationName: pack.organizationName ?? orgName,
            entitlementSource: pack.entitlementSource,
            workspaceOrganizationId:
                pack.workspaceOrganizationId ?? session.organizationId,
            workspaceHint: pack.workspaceHint,
          ),
        )
        .toList(growable: false);

    return ExamSeriesHubSnapshot(
      packs: packs,
      activeOrganizationId: session.organizationId,
    );
  }

  @override
  Future<void> ensureSellerWorkspace(ExamSeriesPack pack) async {
    final session = await _requireSession();
    final sellerId = pack.sellerOrganizationId;
    if (sellerId.isEmpty) {
      throw ApiException(
        message:
            'This pack is missing workspace access. Contact support if this continues.',
        statusCode: 0,
      );
    }
    if (sellerId == session.organizationId) return;

    final orgs = await _orgs.listOrganizations();
    OrganizationSummary? match;
    for (final org in orgs) {
      if (org.id == sellerId) {
        match = org;
        break;
      }
    }
    match ??= OrganizationSummary(
      id: sellerId,
      name: pack.organizationName ?? 'Seller workspace',
    );
    await _orgs.selectOrganization(match);
  }

  @override
  Future<ExamSeriesDetailSnapshot> loadDetail(ExamSeriesDetailArgs args) async {
    if (args.seriesId.isEmpty) {
      throw ApiException(
        message: 'Exam series id is required.',
        statusCode: 0,
      );
    }

    var session = await _requireSession();
    final sellerId = (args.organizationId ?? '').trim();
    if (sellerId.isNotEmpty && sellerId != session.organizationId) {
      await ensureSellerWorkspace(
        ExamSeriesPack(
          id: args.seriesId,
          title: args.title ?? 'Exam series',
          organizationId: sellerId,
          organizationName: args.organizationName,
          workspaceOrganizationId: sellerId,
        ),
      );
      session = await _requireSession();
    }

    final seriesEnvelope = await _api.get(
      '/exam-series/${args.seriesId}',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final pack = ExamSeriesPack.fromJson(_asMap(seriesEnvelope['data']));
    if (pack.id.isEmpty) {
      throw ApiException(
        message:
            'Series not found in this workspace. Open Question Bank and use Open pack so the correct seller workspace is selected.',
        statusCode: 404,
      );
    }

    ExamSeriesRank? rank;
    var rankUnavailable = false;
    try {
      final rankEnvelope = await _api.get(
        '/exam-series/${args.seriesId}/rank/me',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      rank = ExamSeriesRank.fromJson(_asMap(rankEnvelope['data']));
    } catch (_) {
      rankUnavailable = true;
    }

    return ExamSeriesDetailSnapshot(
      pack: ExamSeriesPack(
        id: pack.id,
        title: pack.title,
        description: pack.description,
        itemCount: pack.itemCount,
        items: pack.items,
        organizationId: pack.organizationId ?? args.organizationId,
        organizationName: pack.organizationName ?? args.organizationName,
        entitlementSource: pack.entitlementSource,
        workspaceOrganizationId:
            pack.workspaceOrganizationId ?? args.organizationId,
        workspaceHint: pack.workspaceHint,
      ),
      rank: rank,
      rankUnavailable: rankUnavailable,
    );
  }

  Future<List<ExamSeriesPack>> _listPacks(
    SessionContext session,
    String path,
  ) async {
    try {
      final envelope = await _api.get(
        path,
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map(
            (row) => ExamSeriesPack.fromJson(
              row.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .where((pack) => pack.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _activeOrgName() async {
    try {
      final orgs = await _orgs.listOrganizations();
      final activeId = await _orgs.readActiveOrganizationId();
      for (final org in orgs) {
        if (org.id == activeId) return org.name;
      }
    } catch (_) {}
    return null;
  }

  Future<SessionContext> _requireSession() async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }
    return session;
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }
}
