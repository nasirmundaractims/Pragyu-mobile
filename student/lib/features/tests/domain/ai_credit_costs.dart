/// UI-facing AI credit costs aligned with `config/credit_wallet.php`
/// `consumption_rules` (flat fallback amounts).
///
/// Exact billed amount may vary with hybrid pricing; copy should say
/// “uses AI credits” and show these typical costs so students are not surprised.
abstract final class AiCreditCosts {
  static const rewriteRequest = 4;
  static const suggestionGenerate = 3;

  static String rewriteCostLabel({bool regenerate = false}) {
    final verb = regenerate ? 'Regenerate' : 'Request';
    return '$verb AI answer · $rewriteRequest credits';
  }

  static String get rewriteCostHint =>
      'Uses about $rewriteRequest AI credits per rewrite. Optional advanced help after you understand your score.';

  static String get suggestionCostHint =>
      'Generating tips uses about $suggestionGenerate AI credits.';
}
