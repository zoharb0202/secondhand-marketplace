library;

import 'dart:math' as math;

const double kPickupProximityHalfLifeKm = 8.0;

const double kPickupMaxDistancePenalty = 0.20;

double proximityMultiplier(double? distanceKm) {
  if (distanceKm == null || distanceKm.isNaN) return 1.0;
  final km = distanceKm <= 0 ? 0.0 : distanceKm;
  const halfLife = kPickupProximityHalfLifeKm;
  const maxPenalty = kPickupMaxDistancePenalty;

  final nearness = math.pow(0.5, km / halfLife).toDouble();
  return 1.0 - maxPenalty * (1.0 - nearness);
}

double affinityWithProximity(double affinity, double? distanceKm) {
  final decayed = affinity * proximityMultiplier(distanceKm);
  return decayed.clamp(0.0, 1.0);
}

double normalisedTrend(double? raw, double batchMax) {
  if (raw == null || raw <= 0 || batchMax <= 0) return 0.0;
  return (raw / batchMax).clamp(0.0, 1.0);
}

const double kColdStartAffinityCeiling = 0.45;

const double kColdStartRecencyHalfLifeDays = 7.0;

double coldStartAffinity(Duration age) {
  final days = age.inMilliseconds / Duration.millisecondsPerDay;
  if (days <= 0) return kColdStartAffinityCeiling;
  return kColdStartAffinityCeiling *
      math.pow(0.5, days / kColdStartRecencyHalfLifeDays).toDouble();
}

const double kFreshnessTieBreak = 1e-9;

const double kFreshnessTieBreakHalfLifeDays = 30.0;

double freshnessTieBreak(Duration age) {
  final days = age.inMilliseconds / Duration.millisecondsPerDay;
  if (days <= 0) return kFreshnessTieBreak;
  return kFreshnessTieBreak *
      math.pow(0.5, days / kFreshnessTieBreakHalfLifeDays).toDouble();
}
