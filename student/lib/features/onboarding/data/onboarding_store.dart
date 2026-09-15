abstract class OnboardingStore {
  Future<bool> hasCompleted();
  Future<void> markCompleted();
  Future<void> clear();
}
