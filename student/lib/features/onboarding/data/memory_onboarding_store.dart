import 'package:student_mobile/features/onboarding/data/onboarding_store.dart';

class MemoryOnboardingStore implements OnboardingStore {
  MemoryOnboardingStore({this.completed = false});

  bool completed;

  @override
  Future<bool> hasCompleted() async => completed;

  @override
  Future<void> markCompleted() async {
    completed = true;
  }

  @override
  Future<void> clear() async {
    completed = false;
  }
}
