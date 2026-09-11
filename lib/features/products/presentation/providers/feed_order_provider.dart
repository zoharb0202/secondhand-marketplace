import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/product_model.dart';
import 'product_provider.dart';

enum FeedSource { forYou, following }

final feedSourceProvider = StateProvider<FeedSource>(
  (ref) => FeedSource.forYou,
);

final feedOrderEpochProvider = StateProvider<int>((ref) => 0);

const Duration kFeedResumeRerankThreshold = Duration(seconds: 60);

class StableFeed {
  final List<ProductModel> products;

  final Set<String> newArrivalIds;

  final bool isRefreshing;
  final Object? error;
  const StableFeed({
    required this.products,
    this.newArrivalIds = const <String>{},
    this.isRefreshing = false,
    this.error,
  });

  int get newArrivalCount => newArrivalIds.length;
}

class FeedOrderNotifier extends StateNotifier<AsyncValue<StableFeed>> {
  FeedOrderNotifier() : super(const AsyncValue.loading());

  List<String> _orderedIds = [];
  DateTime _rankedAt = DateTime.now();

  final Set<String> _newArrivalIds = {};

  List<ProductModel>? _lastUpstreamProducts;

  void resetOrder() {
    _rankedAt = DateTime.now();
    _newArrivalIds.clear();
    _orderedIds = [];

    final cached = _lastUpstreamProducts;
    if (cached != null) {
      _applyOrdering(cached);
    }
  }

  void resetOrderForNewQuery() {
    _rankedAt = DateTime.now();
    _newArrivalIds.clear();
    _orderedIds = [];
    _lastUpstreamProducts = null;

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        StableFeed(products: current.products, isRefreshing: true),
      );
    }
  }

  void ingest(AsyncValue<List<ProductModel>> upstream) {
    upstream.when(
      data: (products) {
        _lastUpstreamProducts = products;
        _applyOrdering(products);
      },
      loading: () {
        if (!state.hasValue) {
          state = const AsyncValue.loading();
        } else {
          final current = state.value!;
          state = AsyncValue.data(
            StableFeed(
              products: current.products,
              newArrivalIds: current.newArrivalIds,
              isRefreshing: true,
            ),
          );
        }
      },
      error: (err, st) {
        if (!state.hasValue) {
          state = AsyncValue.error(err, st);
        } else {
          final current = state.value!;
          state = AsyncValue.data(
            StableFeed(
              products: current.products,
              newArrivalIds: current.newArrivalIds,
              isRefreshing: false,
              error: err,
            ),
          );
        }
      },
    );
  }

  void _applyOrdering(List<ProductModel> products) {
    final byId = <String, ProductModel>{for (final p in products) p.id: p};

    final ordered = <ProductModel>[];
    for (final id in _orderedIds) {
      final p = byId[id];
      if (p != null) ordered.add(p);
    }
    final keptIds = ordered.map((p) => p.id).toSet();

    for (final p in products) {
      if (keptIds.contains(p.id)) continue;
      ordered.add(p);
      if (p.createdAt.isAfter(_rankedAt)) _newArrivalIds.add(p.id);
    }

    _orderedIds = ordered.map((p) => p.id).toList();

    final presentIds = _orderedIds.toSet();
    _newArrivalIds.retainWhere(presentIds.contains);

    state = AsyncValue.data(
      StableFeed(
        products: ordered,
        newArrivalIds: Set<String>.unmodifiable(_newArrivalIds),
      ),
    );
  }
}

final feedOrderProvider =
    StateNotifierProvider<FeedOrderNotifier, AsyncValue<StableFeed>>((ref) {
      final source = ref.watch(feedSourceProvider);
      final notifier = FeedOrderNotifier();

      ref.listen(activeFiltersProvider, (_, __) {
        if (source == FeedSource.forYou) {
          notifier.resetOrderForNewQuery();
        } else {
          notifier.resetOrder();
        }
      });
      ref.listen(feedOrderEpochProvider, (_, __) => notifier.resetOrder());

      if (source == FeedSource.forYou) {
        ref.listen<AsyncValue<List<ProductModel>>>(
          productsStreamProvider,
          (_, next) => notifier.ingest(next),
          fireImmediately: true,
        );
      } else {
        ref.listen<AsyncValue<List<ProductModel>>>(
          followedSellersFeedProvider,
          (_, next) => notifier.ingest(next),
          fireImmediately: true,
        );
      }

      return notifier;
    });
