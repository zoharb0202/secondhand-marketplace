library;

enum FeedSlot { primary, secondary, trending, discovery }

class FeedCandidate<T> {
  final T item;

  final double affinity;

  final double trend;

  final String? categoryKey;
  final String? brandKey;
  final String? sellerKey;

  const FeedCandidate({
    required this.item,
    required this.affinity,
    this.trend = 0,
    this.categoryKey,
    this.brandKey,
    this.sellerKey,
  });
}

class FeedRecipe {
  final List<FeedSlot> pattern;

  final int maxConsecutiveSameCategory;
  final int maxConsecutiveSameBrand;

  final int maxPerSellerPerWindow;

  final double primaryAffinityThreshold;

  final double trendingThreshold;

  const FeedRecipe({
    this.pattern = const [
      FeedSlot.primary,
      FeedSlot.primary,
      FeedSlot.trending,
      FeedSlot.secondary,
      FeedSlot.discovery,
      FeedSlot.primary,
      FeedSlot.discovery,
      FeedSlot.secondary,
      FeedSlot.trending,
      FeedSlot.primary,
    ],
    this.maxConsecutiveSameCategory = 2,
    this.maxConsecutiveSameBrand = 2,
    this.maxPerSellerPerWindow = 3,
    this.primaryAffinityThreshold = 0.5,
    this.trendingThreshold = 0.5,
  });

  int get windowSize => pattern.length;
}

Map<FeedSlot, List<FeedCandidate<T>>> bucketize<T>(
  List<FeedCandidate<T>> candidates,
  FeedRecipe recipe,
) {
  final buckets = {for (final s in FeedSlot.values) s: <FeedCandidate<T>>[]};

  for (final c in candidates) {
    if (c.trend >= recipe.trendingThreshold) {
      buckets[FeedSlot.trending]!.add(c);
    } else if (c.affinity >= recipe.primaryAffinityThreshold) {
      buckets[FeedSlot.primary]!.add(c);
    } else if (c.affinity > 0) {
      buckets[FeedSlot.secondary]!.add(c);
    } else {
      buckets[FeedSlot.discovery]!.add(c);
    }
  }

  buckets[FeedSlot.primary]!.sort((a, b) => b.affinity.compareTo(a.affinity));
  buckets[FeedSlot.secondary]!.sort((a, b) => b.affinity.compareTo(a.affinity));
  buckets[FeedSlot.trending]!.sort((a, b) => b.trend.compareTo(a.trend));
  buckets[FeedSlot.discovery]!.sort((a, b) => b.trend.compareTo(a.trend));

  return buckets;
}

List<T> composeFeed<T>(
  List<FeedCandidate<T>> candidates, {
  FeedRecipe recipe = const FeedRecipe(),
  int? limit,
}) {
  if (candidates.isEmpty) return const [];

  final buckets = bucketize(candidates, recipe);
  final out = <T>[];
  final used = <FeedCandidate<T>>{};

  final target = limit == null
      ? candidates.length
      : (limit < candidates.length ? limit : candidates.length);

  String? lastCategory;
  int sameCategoryRun = 0;
  String? lastBrand;
  int sameBrandRun = 0;
  final sellerCountThisWindow = <String, int>{};

  int emptyRun = 0;

  bool breaksAdjacency(FeedCandidate<T> c) {
    if (c.categoryKey != null &&
        c.categoryKey == lastCategory &&
        sameCategoryRun >= recipe.maxConsecutiveSameCategory) {
      return true;
    }
    if (c.brandKey != null &&
        c.brandKey == lastBrand &&
        sameBrandRun >= recipe.maxConsecutiveSameBrand) {
      return true;
    }
    return false;
  }

  bool breaksSellerCap(FeedCandidate<T> c) =>
      c.sellerKey != null &&
      (sellerCountThisWindow[c.sellerKey] ?? 0) >= recipe.maxPerSellerPerWindow;

  FeedCandidate<T>? take(FeedSlot slot, {int stage = 0}) {
    for (final c in buckets[slot]!) {
      if (used.contains(c)) continue;
      if (stage < 1 && breaksAdjacency(c)) continue;
      if (breaksSellerCap(c)) continue;
      return c;
    }
    return null;
  }

  var currentWindow = 0;
  for (var i = 0; out.length < target; i++) {
    final slotIndex = i % recipe.windowSize;

    final windowOfThisItem = out.length ~/ recipe.windowSize;
    if (windowOfThisItem != currentWindow) {
      currentWindow = windowOfThisItem;
      sellerCountThisWindow.clear();
    }

    final wanted = recipe.pattern[slotIndex];

    FeedCandidate<T>? picked;
    for (var stage = 0; stage <= 1 && picked == null; stage++) {
      picked = take(wanted, stage: stage);
      if (picked != null) break;
      for (final s in FeedSlot.values) {
        if (s == wanted) continue;
        picked = take(s, stage: stage);
        if (picked != null) break;
      }
    }

    if (picked == null) {
      emptyRun++;
      if (emptyRun >= recipe.windowSize) break;
      continue;
    }
    emptyRun = 0;

    used.add(picked);
    out.add(picked.item);

    if (picked.categoryKey != null && picked.categoryKey == lastCategory) {
      sameCategoryRun++;
    } else {
      lastCategory = picked.categoryKey;
      sameCategoryRun = 1;
    }
    if (picked.brandKey != null && picked.brandKey == lastBrand) {
      sameBrandRun++;
    } else {
      lastBrand = picked.brandKey;
      sameBrandRun = 1;
    }
    final sk = picked.sellerKey;
    if (sk != null) {
      sellerCountThisWindow[sk] = (sellerCountThisWindow[sk] ?? 0) + 1;
    }
  }

  return out;
}
