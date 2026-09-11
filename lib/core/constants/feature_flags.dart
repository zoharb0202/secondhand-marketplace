class FeatureFlags {
  static const bool paymentEnabled = false;
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE');
}
