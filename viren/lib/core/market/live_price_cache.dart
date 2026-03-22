import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'market_data_service.dart';
import 'market_status.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LivePriceCache — Single source of truth for current market prices.
//
// Holds a Map<symbol, StockQuote> that every screen reads from.
// Updates itself every 30 seconds during market hours when the app is
// in the foreground. Individual screens (StockDetailScreen) can request
// faster updates for their own symbol.
//
// Battery design:
//   - 30s refresh during market hours (foreground only)
//   - No refresh outside market hours
//   - No refresh when no symbols registered
//   - MarketDataService has its own 3-min cache — rapid calls are free
// ─────────────────────────────────────────────────────────────────────────────

class LivePriceState {
  final Map<String, StockQuote> quotes;
  final DateTime? lastUpdated;
  final bool isLoading;

  const LivePriceState({
    this.quotes = const {},
    this.lastUpdated,
    this.isLoading = false,
  });

  LivePriceState copyWith({
    Map<String, StockQuote>? quotes,
    DateTime? lastUpdated,
    bool? isLoading,
  }) {
    return LivePriceState(
      quotes: quotes ?? this.quotes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  StockQuote? quoteFor(String symbol) =>
      quotes[symbol.toUpperCase()];

  String get lastUpdatedLabel {
    if (lastUpdated == null) return 'Not yet loaded';
    final diff = DateTime.now().difference(lastUpdated!);
    if (diff.inSeconds < 60) return 'Updated ${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    return 'Updated ${diff.inHours}h ago';
  }
}

class LivePriceCacheNotifier extends Notifier<LivePriceState> {
  Timer? _refreshTimer;
  final Set<String> _symbols = {};

  @override
  LivePriceState build() {
    return const LivePriceState();
  }

  /// Register symbols to watch. Called by screens on mount.
  /// Safe to call multiple times — deduplicates.
  void registerSymbols(List<String> symbols) {
    final upper = symbols.map((s) => s.toUpperCase()).toSet();
    final added = upper.difference(_symbols);
    if (added.isEmpty) return;
    _symbols.addAll(added);
    // Fetch immediately for newly registered symbols
    _fetchAll();
  }

  /// Start the 30-second refresh timer (call on app foreground).
  void startRefresh() {
    _refreshTimer?.cancel();
    if (!MarketStatusHelper.isMarketOpen()) return;
    if (_symbols.isEmpty) return;

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (MarketStatusHelper.isMarketOpen()) {
        _fetchAll();
      } else {
        stopRefresh();
      }
    });
  }

  /// Stop the refresh timer (call on app background).
  void stopRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Force an immediate refresh. Called on pull-to-refresh.
  Future<void> forceRefresh() async {
    ref.read(_marketDataServiceProvider).clearCache();
    await _fetchAll();
  }

  /// Fetch a single symbol faster (for StockDetailScreen live mode).
  Future<void> fetchSymbol(String symbol) async {
    final upper = symbol.toUpperCase();
    try {
      final quote = await ref.read(_marketDataServiceProvider).fetchQuote(upper);
      if (quote != null) {
        final updated = Map<String, StockQuote>.from(state.quotes);
        updated[upper] = quote;
        state = state.copyWith(
          quotes: updated,
          lastUpdated: DateTime.now(),
        );
      }
    } catch (_) {}
  }

  Future<void> _fetchAll() async {
    if (_symbols.isEmpty) return;
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    final updated = Map<String, StockQuote>.from(state.quotes);
    await Future.wait(
      _symbols.map((sym) async {
        try {
          final quote = await ref.read(_marketDataServiceProvider).fetchQuote(sym);
          if (quote != null) updated[sym] = quote;
        } catch (_) {}
      }),
    );

    state = state.copyWith(
      quotes: updated,
      lastUpdated: DateTime.now(),
      isLoading: false,
    );
  }

  // No override necessary for dispose in Notifier, it's not a StatefulWidget anymore.
  // Actually riverpod handles disposal via ref.onDispose
}

// Single instance of MarketDataService shared across the cache
final _marketDataServiceProvider = Provider<MarketDataService>((ref) {
  return MarketDataService();
});

/// Global live price cache — never autoDisposed.
/// All screens read from this instead of fetching independently.
final livePriceCacheProvider =
    NotifierProvider<LivePriceCacheNotifier, LivePriceState>(() {
  return LivePriceCacheNotifier();
});

/// Convenience selector — get a single quote without watching the whole map.
final liveQuoteProvider = Provider.family<StockQuote?, String>((ref, symbol) {
  return ref.watch(livePriceCacheProvider).quoteFor(symbol);
});
