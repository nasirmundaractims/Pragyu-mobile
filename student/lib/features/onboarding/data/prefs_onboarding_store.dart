import 'package:shared_preferences/shared_preferences.dart';

import 'package:student_mobile/features/onboarding/data/onboarding_store.dart';

class PrefsOnboardingStore implements OnboardingStore {
  PrefsOnboardingStore({this._prefs});

  static const _key = 'pragyu.student.onboarding_completed';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<bool> hasCompleted() async {
    final prefs = await _ensurePrefs();
    return prefs.getBool(_key) ?? false;
  }

  @override
  Future<void> markCompleted() async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(_key, true);
  }

  @override
  Future<void> clear() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(_key);
  }
}
